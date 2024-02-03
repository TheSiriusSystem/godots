extends ConfirmationDialog


signal imported(project_path, editor_path, and_edit)


@onready var _browse_project_path_button: Button = %BrowseProjectPathButton
@onready var _browse_project_path_dialog: FileDialog = $BrowseProjectPathDialog
@onready var _project_path_edit: LineEdit = %ProjectPathEdit
@onready var _message_label = %MessageLabel
@onready var _status_rect = %StatusRect
@onready var _editors_option_button: OptionButton = %EditorsOptionButton
@onready var _version_hint_value = %VersionHintValue
@onready var _ok_button = get_ok_button()
@onready var _just_import_button = add_button(tr("Import"), false, "just_import")

var _editor_options = []


func _ready() -> void:
#	super._ready()
	min_size = Vector2i(300, 0) * Config.EDSCALE
	_browse_project_path_button.pressed.connect(func():
		if _project_path_edit.text.is_empty():
			_browse_project_path_dialog.current_dir = _get_default_project_path()
		else:
			_browse_project_path_dialog.current_path = _project_path_edit.text
		_browse_project_path_dialog.popup_centered_ratio(0.5)
	)
	_browse_project_path_dialog.file_selected.connect(func(path):
		_project_path_edit.text = path
		_validate()
		_sort_options()
	)
	_browse_project_path_dialog.filters = utils.PROJECT_CONFIG_FILENAMES
	_browse_project_path_dialog.filters.push_back("*.zip")
	_editors_option_button.item_selected.connect(func(_arg): 
		_validate()
	)
	_project_path_edit.text_changed.connect(func(arg: String):
		_validate()
		_sort_options()
	)
	
	confirmed.connect(_on_confirmed.bind(true))
	custom_action.connect(func(action):
		if action == "just_import":
			_on_confirmed(false)
			visible = false
	)

	add_button(tr("Import"), false, "just_import")


func init(project_path, editor_options):
	_editor_options = editor_options
	_set_editor_options(editor_options)
	_project_path_edit.text = project_path if not project_path.is_empty() else _get_default_project_path()
	_validate()
	_sort_options()


func _set_editor_options(options):
	_editors_option_button.clear()
	for idx in range(len(options)):
		var opt = options[idx]
		_editors_option_button.add_item(opt.label)
		_editors_option_button.set_item_metadata(idx, opt)


func _get_default_project_path():
	return ProjectSettings.globalize_path(Config.DEFAULT_PROJECTS_PATH.ret())


func _on_confirmed(edit) -> void:
	imported.emit(
		_project_path_edit.text, 
		_editors_option_button.get_selected_metadata().path,
		edit
	)


func _validate():
	var path = _project_path_edit.text.strip_edges()
	var file = path.get_file()
	if utils.PROJECT_CONFIG_FILENAMES.has(file) or path.get_extension() == "zip":
		var version_metadata = _editors_option_button.get_selected_metadata()
		var selected_version = utils.extract_version_from_string(version_metadata.version_hint)
		if (file == utils.PROJECT_CONFIG_FILENAMES[0] and selected_version[0] < 3) or (file == utils.PROJECT_CONFIG_FILENAMES[1] and selected_version[0] > 2):
			_error(tr("This project cannot be edited in %s." % version_metadata.label))
			return
		
		_set_message("", "success")
		_update_ok_button_available(true)
		return
	
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		var filename_quotes = ""
		for i in range(len(utils.PROJECT_CONFIG_FILENAMES)):
			filename_quotes += "\"%s\"" % utils.PROJECT_CONFIG_FILENAMES[i]
			if i < utils.PROJECT_CONFIG_FILENAMES.size() - 1:
				filename_quotes += ", "
		_error(tr("Please choose a %s or \".zip\" file." % filename_quotes))
		return
	
	if _editors_option_button.selected == -1:
		_error(tr("Please choose an editor to bind."))
		return
	
	_error(tr("The path specified doesn't exist."))


func _update_ok_button_available(enabled):
	_ok_button.disabled = enabled
	_just_import_button.disabled = enabled


func _error(text):
	_set_message(text, "error")
	_update_ok_button_available(false)


func _set_message(text, type):
	var new_icon = null
	if type == "error":
		_message_label.add_theme_color_override("font_color", get_theme_color("error_color", "Editor"))
		_message_label.modulate = Color(1, 1, 1, 1)
		new_icon = get_theme_icon("StatusError", "EditorIcons")
	elif type == "success":
		_message_label.remove_theme_color_override("font_color")
		_message_label.modulate = Color(1, 1, 1, 0)
		new_icon = get_theme_icon("StatusSuccess", "EditorIcons")
	_message_label.text = text
	_status_rect.texture = new_icon
	
	var window_size = size
	var contents_min_size = get_contents_minimum_size()
	if window_size.x < contents_min_size.x or window_size.y < contents_min_size.y:
		size = Vector2(
			max(window_size.x, contents_min_size.x), 
			max(window_size.y, contents_min_size.y)
		)


func _sort_options():
	if _project_path_edit.text.get_file() in utils.PROJECT_CONFIG_FILENAMES:
		var cfg = Projects.ExternalProjectInfo.new(_project_path_edit.text)
		cfg.load(false)
		cfg.sort_editor_options(_editor_options)
		_version_hint_value.text = "%s: %s" % [tr("version hint"), cfg.version_hint] if not cfg.version_hint.is_empty() else ""
		_set_editor_options(_editor_options)
	else:
		_version_hint_value.text = ""
