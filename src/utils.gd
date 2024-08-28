class_name utils


enum VersionMatchMode {
	NONSTRICT,
	STRICT_FORBID_LEADING_CHARACTERS,
	STRICT_REQUIRE_TWO_COMPONENTS,
}
enum DialogStatus {
	SUCCESS,
	WARNING,
	ERROR,
}

const EDITOR_VERSION_ARRAY: PackedInt32Array = [
	0, # major
	0, # minor
	0, # patch
	0, # w
]
const PROJECT_CONFIG_FILENAMES: PackedStringArray = [
	"project.godot", # Godot 3+
	"engine.cfg", # Godot 1-2
]


static func extract_version_from_string(text: String, return_null_on_no_match: bool = false, match_mode: VersionMatchMode = VersionMatchMode.NONSTRICT):
	var version: PackedInt32Array = EDITOR_VERSION_ARRAY.duplicate()
	
	var pattern = "^"
	if match_mode != VersionMatchMode.STRICT_FORBID_LEADING_CHARACTERS:
		pattern += "(?:\\D+)?"
	for i in range(len(EDITOR_VERSION_ARRAY)):
		if i == 0:
			pattern += "(\\d+)"
		else:
			pattern += "(?:\\.(\\d+))"
			if match_mode != VersionMatchMode.STRICT_REQUIRE_TWO_COMPONENTS or i > 1:
				pattern += "?"
	pattern += "(?:.+?)?$"
	var regex = RegEx.create_from_string(pattern)
	var result = regex.search(text)
	if result:
		for group in range(1, result.get_group_count() + 1):
			var component = result.get_string(group)
			if component.is_valid_int():
				version[group - 1] = maxi(int(component), 0)
	elif return_null_on_no_match:
		return null
	return version


static func extract_version_metadata_from_string(text: String) -> Dictionary:
	text = text.to_lower()
	
	var metadata = {
		"stage": "stable",
		"is_mono": utils.extract_version_from_string(text)[0] >= 3 and text.contains("mono"),
		"is_custom_build": text.contains("custom_build") or text.contains("custom build"),
	}
	var regex = RegEx.create_from_string("(?:dev|alpha|beta|rc)(?:-|\\+|_|\\.)?(?:\\d+)?")
	var result: RegExMatch = regex.search(text)
	if result:
		metadata.stage = result.get_string()
	
	return metadata


static func version_to_string(version, include_metadata: bool = false, max_components: int = 0, match_mode: VersionMatchMode = VersionMatchMode.NONSTRICT) -> String:
	var text = ""
	
	if typeof(version) == TYPE_STRING:
		# Preserve the passed string so version metadata can be extracted.
		text = version
		
		version = utils.extract_version_from_string(text, true, match_mode)
	
	if typeof(version) == TYPE_PACKED_INT32_ARRAY:
		var version_string = ""
		
		var components: PackedStringArray = []
		if max_components == 0:
			for i in range(len(version)):
				if i <= 1 or version[i] > 0:
					max_components = i + 1
		for i in range(max_components):
			components.push_back(str(version[i]))
		
		version_string = ".".join(components)
		if include_metadata:
			text = text.to_lower()
			
			var version_metadata = {
				"stage": "stable",
				"is_mono": version[0] >= 3 and text.contains("mono"),
				"is_custom_build": text.contains("custom_build") or text.contains("custom build"),
			}
			var regex = RegEx.create_from_string("(?:dev|alpha|beta|rc)(?:-|\\+|_|\\.)?(?:\\d+)?")
			var result: RegExMatch = regex.search(text)
			if result:
				version_metadata.stage = result.get_string()
			
			var identifiers: PackedStringArray = [version_metadata.stage]
			if version_metadata.is_mono:
				identifiers.push_back("mono")
			if version_metadata.is_custom_build:
				identifiers.push_back("custom_build")
			
			version_string += "-" + "-".join(identifiers)
		print("Final: %s %s" % [version_string, "(included metadata)" if include_metadata else ""])
		return version_string
	else:
		print("No version string %s" % ["(included metadata)" if include_metadata else ""])
		return ""


static func guess_editor_name(file_name: String, match_mode: VersionMatchMode = VersionMatchMode.NONSTRICT):
	var possible_editor_name = file_name.get_file()
	var format = Config.NEW_EDITOR_NAME_FORMAT.ret()
	if format.contains("%s"):
		var base_dir = file_name.get_base_dir()
		possible_editor_name = utils.version_to_string(file_name.get_basename().trim_prefix(base_dir + "/"), true, 0, match_mode)
		if possible_editor_name.is_empty():
			possible_editor_name = utils.version_to_string(base_dir.trim_prefix(base_dir.get_base_dir() + "/"), true, 0, match_mode)
		possible_editor_name = (format % possible_editor_name) if not possible_editor_name.is_empty() else file_name.get_file().trim_suffix(".%s" % file_name.get_extension())
	else:
		var tokens_to_replace: PackedStringArray = [
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
			".%s" % file_name.get_extension(),
			"_",
			"-"
		]
		for token in tokens_to_replace:
			possible_editor_name = possible_editor_name.replace(token, " ")
		possible_editor_name = possible_editor_name.strip_edges()
	return possible_editor_name


static func find_project_godot_files(dir_path) -> Array[edir.DirListResult]:
	var project_configs = edir.list_recursive(
		ProjectSettings.globalize_path(dir_path), 
		false,
		(func(x: edir.DirListResult): 
			return x.is_file and x.file == "project.godot"),
		(func(x: String): 
			return not x.get_file().begins_with("."))
	)
	return project_configs


static func save_project_config(cfg: ConfigFile, version: PackedInt32Array, project_path: String):
	var err = ERR_FILE_UNRECOGNIZED
	if project_path.get_file() in PROJECT_CONFIG_FILENAMES:
		var file = FileAccess.open(project_path, FileAccess.WRITE)
		file.store_line("; Engine configuration file.")
		if version[0] <= 2 and version[1] <= 0: 
			file.store_line("""; It's best to edit using the editor UI, not directly,
; becausethe parameters that go here are not obvious.""")
		elif (version[0] == 2 and version[1] >= 1) or version[0] >= 3:
			file.store_line("""; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.""")
		file.store_string(""";
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

""" + cfg.encode_to_text())
		err = file.get_error()
		file.close()
	return err


static func find_project_configs(dir_path: String) -> Array[edir.DirListResult]:
	var project_configs = edir.list_recursive(
		ProjectSettings.globalize_path(dir_path), 
		false,
		(func(x: edir.DirListResult): 
			return x.is_file and PROJECT_CONFIG_FILENAMES.has(x.file)),
		(func(x: String): 
			return not x.get_file().begins_with("."))
	)
	return project_configs


static func combine_strings_into_sentence(strings: PackedStringArray) -> String:
	var text = ""
	for i in range(len(strings)):
		text += "\"%s\"" % strings[i].replace("*", "")
		if len(strings) > 1 and i != len(strings) - 1:
			if i < len(strings) - 2:
				text += ", "
			else:
				text += ", or "
	return text


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


static func set_dialog_status(dialog: AcceptDialog, text: String, status: DialogStatus, update_size: bool = true):
	var message_label = dialog.get_node_or_null("%MessageLabel")
	var status_rect = dialog.get_node_or_null("%StatusRect")
	if is_instance_valid(message_label) and is_instance_valid(status_rect):
		var buttons_enabled: bool
		match status:
			DialogStatus.SUCCESS:
				message_label.remove_theme_color_override("font_color")
				status_rect.texture = dialog.get_theme_icon("StatusSuccess", "EditorIcons")
				buttons_enabled = true
			DialogStatus.WARNING:
				message_label.add_theme_color_override("font_color", dialog.get_theme_color("warning_color", "Editor"))
				status_rect.texture = dialog.get_theme_icon("StatusWarning", "EditorIcons")
				buttons_enabled = true
			DialogStatus.ERROR:
				message_label.add_theme_color_override("font_color", dialog.get_theme_color("error_color", "Editor"))
				status_rect.texture = dialog.get_theme_icon("StatusError", "EditorIcons")
				buttons_enabled = false
		message_label.text = text
		
		var buttons = dialog.get("action_buttons")
		if buttons:
			for button in buttons:
				button.disabled = not buttons_enabled
		
		if update_size:
			var window_size = dialog.size
			var contents_min_size = dialog.get_contents_minimum_size()
			if window_size.x < contents_min_size.x or window_size.y < contents_min_size.y:
				dialog.size = Vector2(
					max(window_size.x, contents_min_size.x), 
					max(window_size.y, contents_min_size.y)
				)


static func validate_version_hint_edit(dialog: AcceptDialog, show_error: bool):
	var version_hint_edit = dialog.get_node_or_null("%VersionHintEdit")
	var status_rect = dialog.get_node_or_null("%StatusRect")
	if is_instance_valid(version_hint_edit) and is_instance_valid(status_rect):
		if show_error or not version_hint_edit.text.strip_edges().is_empty():
			if not utils.version_to_string(version_hint_edit.text, true).is_empty():
				utils.set_dialog_status(dialog, "", utils.DialogStatus.SUCCESS)
				return true
			else:
				if not show_error:
					utils.set_dialog_status(dialog, dialog.tr(
						"The version hint specified is invalid. It should follow the version format."
					), utils.DialogStatus.WARNING)
					return true
				else:
					utils.set_dialog_status(dialog, dialog.tr(
						"The version hint specified is invalid."
					), utils.DialogStatus.ERROR)
					return false
		else:
			utils.set_dialog_status(dialog, "", utils.DialogStatus.SUCCESS)
			return true
	return false


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


static func prop_is_readonly():
	assert(false, "Property is readonly")


static func not_implemeted():
	assert(false, "Not Implemented")


static func empty_func():
	pass
