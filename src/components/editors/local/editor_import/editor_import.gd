extends ConfirmationDialog

signal imported(editor_name, editor_path)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _path_edit: LineEdit = %PathEdit
@onready var _message_label: Label = %MessageLabel
@onready var _status_rect: TextureRect = %StatusRect
@onready var _browse_button: Button = %BrowseButton
@onready var _file_dialog: FileDialog = $FileDialog
@onready var action_buttons: Array[Button] = [
	get_ok_button(),
]


func _ready() -> void:
#	super._ready()
	
	min_size = Vector2(300, 0) * Config.EDSCALE
	confirmed.connect(func(): 
		imported.emit(_name_edit.text, _path_edit.text)
	)
	_browse_button.pressed.connect(func():
		_file_dialog.popup_centered_ratio(0.5)
		if _path_edit.text.is_empty():
			_file_dialog.current_dir = ProjectSettings.globalize_path(
				Config.VERSIONS_PATH.ret()
			)
		else:
			_file_dialog.current_path = _path_edit.text
	)
	_file_dialog.file_selected.connect(func(dir: String):
		_set_name_and_path(dir)
		_validate()
	)
	_file_dialog.dir_selected.connect(func(path):
		_set_name_and_path(path)
	)
	_name_edit.text_changed.connect(func(_arg): _validate())
	_path_edit.text_changed.connect(func(_arg): _validate())
	
	if OS.has_feature("macos"):
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_file_dialog.filters = ["*.app"]
	else:
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		if OS.has_feature("windows"):
			_file_dialog.filters = ["*.exe"]


func init(editor_name, exec_path):
	_name_edit.text = editor_name
	_path_edit.text = exec_path
	
	_validate()


func _set_name_and_path(path):
	_name_edit.text = utils.guess_editor_name(path, utils.VersionMatchMode.STRICT_REQUIRE_TWO_COMPONENTS)
	if Config.NEW_EDITOR_NAMES_OMIT_STABLE.ret():
		_name_edit.text = _name_edit.text.replace("-stable", "")
	_path_edit.text = path


func _validate():
	var path = _path_edit.text.strip_edges()
	if FileAccess.file_exists(path) and (_file_dialog.filters.has("*.%s" % path.get_file().get_extension()) or len(_file_dialog.filters) == 0):
		if not _name_edit.text.is_empty():
			utils.set_dialog_status(self, "", utils.DialogStatus.SUCCESS)
		else:
			utils.set_dialog_status(self, tr("It would be a good idea to name the editor."), utils.DialogStatus.WARNING)
		return true
	
	if len(_file_dialog.filters) > 0:
		utils.set_dialog_status(self, tr("Please choose a %s file." % utils.combine_strings_into_sentence(_file_dialog.filters)), utils.DialogStatus.ERROR)
	else:
		utils.set_dialog_status(self, tr("Please choose a file."), utils.DialogStatus.ERROR)
	return false
