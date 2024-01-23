class_name GodotsReleases


class I:
	func async_load():
		pass
	
	func all() -> Array[Release]:
		return []
	
	func async_has_newest_version() -> bool:
		return false


class Default extends I:
	var _src: Src
	var _data: Array[Release] = []
	var _fetched = false
	
	func _init(src: Src):
		_src = src
	
	func async_load():
		var json = await _src.async_all()
		
		var latest = {'value': null}
		var check_is_latest = func(release: Release):
			if latest.value != null or release.is_draft or release.is_prerelease:
				return
			release._mark_as_latest()
			latest.value = release

		_data.clear()
		for el in json:
			var release = Release.new(el)
			_data.append(release)
			check_is_latest.call(release)

		var release: Release
		if Config.ONLY_STABLE_UPDATES.ret() and latest.value:
			release = latest.value
		elif len(_data) > 0:
			release = _data[0]
		if release != null and release.tag_name != Config.VERSION:
			release._mark_as_ready_to_update()
		_fetched = true

	func async_has_newest_version() -> bool:
		if _fetched:
			for r in _data:
				if r.is_ready_to_update:
					return true
			return false
		else:
			var release: GodotsReleases.Release
			if Config.ONLY_STABLE_UPDATES.ret():
				var json = await _src.async_latest()
				release = _to_release_or_null(json)
			else:
				var json = await _src.async_recent()
				release = _to_release_or_null(json)
			return release.tag_name != Config.VERSION

	func all() -> Array[Release]:
		return _data
	
	func _to_release_or_null(json):
		if json != null:
			return Release.new(json)
		else:
			return null



class Src:
	func async_all():
		pass

	func async_latest():
		pass
	
	func async_recent():
		pass



class SrcFileSystem extends Src:
	var _filename: String
	
	func _init(filename: String):
		_filename = filename
	
	func async_all():
		var file = FileAccess.open(_filename, FileAccess.READ)
		var content = file.get_as_text()
		return JSON.parse_string(content)

	func async_latest():
		var json = self.async_all()
		for el in json:
			var release = Release.new(el)
			if not release.is_prerelease and not release.is_draft:
				return el
		return null
	
	func async_recent():
		var json = self.async_all()
		for el in json:
			return el
		return null


class SrcGithub extends Src:
	const headers = ["Accept: application/vnd.github.v3+json"]
	
	func async_all():
		var json = await _get_json(Config.RELEASES_API_ENDPOINT)
		if json:
			return json
		else:
			return []

	func async_latest():
		var json = await _get_json(Config.RELEASES_LATEST_API_ENDPOINT)
		if not json is Dictionary:
			return null
		if json.get('message', '') == 'Not Found':
			return null
		return json
	
	func async_recent():
		var json = await _get_json(Config.RELEASES_API_ENDPOINT + "?per_page=1")
		for el in json:
			return el
		return null
	
	func _get_json(url):
		var response = HttpClient.Response.new(
			await HttpClient.async_http_get(url, headers)
		)
		var json = response.to_json()
		return json


class Release:
	var _json: Dictionary
	var _is_latest = false
	var _is_ready_to_update = false
	
	var name: String:
		get: return _json.name
	
	var tag_name: String:
		get: return _json.get('tag_name', '')
	
	var tags: Array[String]:
		get: return _get_tags()
	
	var html_url: String:
		get: return _json.html_url
	
	var assets: Array[ReleaseAsset]:
		get: return _get_assets()
	
	var is_draft: bool:
		get: return _json.get("draft", true)
	
	var is_prerelease: bool:
		get: return _json.get("prerelease", true)
	
	var is_latest: bool:
		get: return _is_latest
	
	var is_ready_to_update: bool:
		get: return _is_ready_to_update
	
	func _init(json):
		_json = json
	
	func _get_tags():
		var tags: Array[String] = []
#		if len(_json.tag_name) > 1:
#			tags.append(_json.tag_name.substr(1))
		if _is_ready_to_update:
			tags.append(tr("newest"))
		if _json.prerelease:
			tags.append(tr("pre-release"))
		if is_latest:
			tags.append(tr("latest"))
		if is_draft:
			tags.append(tr("draft"))
		return tags
	
	func _get_assets():
		var assets: Array[ReleaseAsset] = []
		for asset in _json.get("assets", []):
			assets.append(ReleaseAsset.new(asset))
		return assets
	
	func _mark_as_latest():
		_is_latest = true
	
	func _mark_as_ready_to_update():
		_is_ready_to_update = true


class ReleaseAsset:
	var _json: Dictionary
	
	var name: String:
		get: return _json.get("name", "")
	
	var browser_download_url: String:
		get: return _json.get("browser_download_url", "")
	
	func _init(json):
		_json = json
	
	func is_godots_bin_for_current_platform():
		var zip_name
		if OS.has_feature("windows"):
			zip_name = "Windows.Desktop.zip"
		elif OS.has_feature("macos"):
			zip_name = "macOS.zip"
		elif OS.has_feature("linux"):
			zip_name = "LinuxX11.zip"
		return name == zip_name
