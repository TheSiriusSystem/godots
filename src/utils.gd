class_name utils


const PROJECT_CONFIG_FILENAMES: PackedStringArray = [
	"project.godot",
	"engine.cfg"
]


static func guess_editor_name(file_name: String):
	var possible_editor_name = file_name.get_file()
	var tokens_to_replace = []
	tokens_to_replace.append_array([
		"x11.64", 
		"linux.64",
		"linux.x86_64", 
		"linux.x86_32",
		"osx.universal",
		"macos.universal",
		"osx.fat",
		"osx32",
		"osx64",
		"win64",
		"win32",
		".%s" % file_name.get_extension()
	])
	tokens_to_replace.append_array(["_", "-"])
	for token in tokens_to_replace:
		possible_editor_name = possible_editor_name.replace(token, " ")
	possible_editor_name = possible_editor_name.strip_edges()
	return possible_editor_name


static func find_project_configs(dir_path) -> Array[edir.DirListResult]:
	var project_configs = edir.list_recursive(
		ProjectSettings.globalize_path(dir_path), 
		false,
		(func(x: edir.DirListResult): 
			return x.is_file and PROJECT_CONFIG_FILENAMES.has(x.file)),
		(func(x: String): 
			return not x.get_file().begins_with("."))
	)
	return project_configs


static func response_to_json(response, safe=true):
	var string = response[3].get_string_from_utf8()
	if safe:
		return parse_json_safe(string)
	else:
		return JSON.parse_string(string)


static func parse_json_safe(string):
	var json = JSON.new()
	var err = json.parse(string)
	if err != OK:
		return null
	else:
		return json.data


static func fit_height(max_height, cur_size: Vector2i, callback):
	var scale_ratio = max_height / (cur_size.y * Config.EDSCALE)
	if scale_ratio < 1:
		callback.call(Vector2i(
			cur_size.x * Config.EDSCALE * scale_ratio,
			cur_size.y * Config.EDSCALE * scale_ratio
		))


static func disconnect_all(obj: Object):
	for obj_signal in obj.get_signal_list():
		for connection in obj.get_signal_connection_list(obj_signal.name):
			obj.disconnect(obj_signal.name, connection.callable)


static func extract_version_from_string(text: String, return_null_on_no_match: bool = false):
	var version: PackedInt32Array = [0, 0, 0]
	
	var regex = RegEx.create_from_string("^(?:\\D+)?(?<major>\\d+)(?:\\.(?<minor>\\d+))?(?:\\.(?<patch>\\d+))?(?:.+?)?$")
	var result = regex.search(text)
	if result:
		for group in range(result.get_group_count() + 1):
			var component = result.get_string(group)
			if component.is_valid_int():
				version[group - 1] = int(component)
	elif return_null_on_no_match:
		return null
	return version


static func get_version_string(text: String) -> String:
	var version = utils.extract_version_from_string(text, true)
	if version:
		var array: PackedStringArray = []
		for version_number in version:
			array.push_back(str(version_number))
		return ".".join(array)
	else:
		return ""
