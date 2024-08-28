extends ConfirmationDialog


signal imported(project_path, editor_path, and_edit, callback)


@onready var _browse_project_path_button: Button = %BrowseProjectPathButton
@onready var _browse_project_path_dialog: FileDialog = $BrowseProjectPathDialog
@onready var _project_path_edit: LineEdit = %ProjectPathEdit
@onready var _message_label: Label = %MessageLabel
@onready var _status_rect: TextureRect = %StatusRect
@onready var _editors_option_button: OptionButton = %EditorsOptionButton
@onready var _version_hint_value = %VersionHintValue
@onready var action_buttons: Array[Button] = [
	get_ok_button(),
	add_button(tr("Import"), false, "just_import"),
]

var _editor_options = []
var _callback = null


func _ready() -> void:
#	super._ready()
	min_size = Vector2i(300, 0) * Config.EDSCALE
	_validate()
	_browse_project_path_button.pressed.connect(func():
		if _project_path_edit.text.is_empty():
			_browse_project_path_dialog.current_dir = ProjectSettings.globalize_path(
				Config.DEFAULT_PROJECTS_PATH.ret()
			)
		else:
			_browse_project_path_dialog.current_path = _project_path_edit.text
		_browse_project_path_dialog.popup_centered_ratio(0.5)
	)
	var filters = utils.PROJECT_CONFIG_FILENAMES.duplicate()
	filters.append("*.zip")
	_browse_project_path_dialog.filters = filters
	_browse_project_path_dialog.file_selected.connect(func(path):
		_project_path_edit.text = path
		_validate()
		_sort_options(false)
	)
	_editors_option_button.item_selected.connect(func(_arg): 
		_validate()	
	)
	_project_path_edit.text_changed.connect(func(arg: String):
		_validate()
		_sort_options(false)
	)
	
	visibility_changed.connect(func():
		if not visible:
			_callback = null
	)
	
	custom_action.connect(func(action):
		if action == "just_import":
			_on_confirmed(false)
	)


func init(project_path, editor_options, callback=null):
	_callback = callback
	_set_editor_options(editor_options)
	_project_path_edit.text = project_path
	_validate()
	_sort_options(true)


func _set_editor_options(options):
	_editor_options = options
	_editors_option_button.clear()
	for idx in range(len(options)):
		var opt = options[idx]
		_editors_option_button.add_item(opt.label)
		_editors_option_button.set_item_metadata(idx, opt)


func _on_confirmed(edit) -> void:
	imported.emit(
		_project_path_edit.text, 
		_editors_option_button.get_item_metadata(_editors_option_button.selected).path,
		edit,
		_callback
	)
	visible = false


func _validate():
	var path = _project_path_edit.text.strip_edges()
	
	var file = path.get_file()
	if FileAccess.file_exists(path) and (utils.PROJECT_CONFIG_FILENAMES.has(file) or file.get_extension() == "zip"):
		var version_metadata = _editors_option_button.get_selected_metadata()
		var version = utils.extract_version_from_string(version_metadata.version_hint)
		if (file == utils.PROJECT_CONFIG_FILENAMES[0] and version[0] < 3) or (file == utils.PROJECT_CONFIG_FILENAMES[1] and version[0] > 2):
			utils.set_dialog_status(self, tr("This project cannot be edited in the selected editor."), utils.DialogStatus.ERROR)
			return false
		
		utils.set_dialog_status(self, "", utils.DialogStatus.SUCCESS)
		return true
	
	utils.set_dialog_status(self, tr("Please choose a %s file." % utils.combine_strings_into_sentence(_browse_project_path_dialog.filters)), utils.DialogStatus.ERROR)
	return false


func _sort_options(reset_editor_options):
	if utils.PROJECT_CONFIG_FILENAMES.has(_project_path_edit.text.get_file()):
		var cfg = Projects.ExternalProjectInfo.new(_project_path_edit.text)
		cfg.load(false)
		if reset_editor_options:
			cfg.sort_editor_options(_editor_options)
			_set_editor_options(_editor_options)
		_version_hint_value.text = "%s: %s" % [tr("version hint"), cfg.version_hint] if not cfg.version_hint.is_empty() else ""
	else:
		_version_hint_value.text = ""
