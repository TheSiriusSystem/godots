extends ConfirmationDialogAutoFree

signal settings_changed(new_name, new_version_hint)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _version_hint_edit: LineEdit = %VersionHintEdit
@onready var _autodetect_version_button: Button = %AutodetectVersionButton
@onready var _self_contained_mode_check_box: CheckBox = %ScModeCheckBox
@onready var _autodetect_failed_dialog: AcceptDialog = $AutodetectFailedDialog
@onready var action_buttons: Array[Button] = [
	get_ok_button(),
]


func _ready() -> void:
	super._ready()
	
	min_size = Vector2(350, 0) * Config.EDSCALE
	
	confirmed.connect(func():
		var version = utils.extract_version_from_string(_version_hint_edit.text)
		
		settings_changed.emit(
			_name_edit.text.strip_edges(), 
			_version_hint_edit.text.strip_edges(),
			_self_contained_mode_check_box.button_pressed if version[0] >= 2 else false,
		)
	)
	
	_name_edit.text_changed.connect(func(new_text):
		get_ok_button().disabled = new_text.strip_edges().is_empty()
	)
	
	_version_hint_edit.text_changed.connect(func(_new_text):
		utils.validate_version_hint_edit(self, false)
	)
	
	_autodetect_version_button.pressed.connect(func():
		var version_string = utils.version_to_string(_name_edit.text, true, 0, utils.VersionMatchMode.STRICT_REQUIRE_TWO_COMPONENTS)
		if not version_string.is_empty():
			_version_hint_edit.text = version_string
		else:
			_autodetect_failed_dialog.popup_centered()
		utils.validate_version_hint_edit(self, false)
	)


func init(initial_name, initial_version_hint, initial_self_contained_mode):
	_name_edit.text = initial_name
	_version_hint_edit.text = initial_version_hint
	
	# HACK: [Sirius] Godot 1.x does not support self-contained mode. This type check
	# is to prevent toggling self-contained mode for such versions.
	if typeof(initial_self_contained_mode) == TYPE_BOOL:
		_self_contained_mode_check_box.disabled = false
		_self_contained_mode_check_box.button_pressed = initial_self_contained_mode
	else:
		_self_contained_mode_check_box.disabled = true
		_self_contained_mode_check_box.button_pressed = false
	
	utils.validate_version_hint_edit(self, false)
