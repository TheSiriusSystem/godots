extends ConfirmationDialogAutoFree

signal settings_changed(new_name, new_description, new_version_hint)

@onready var _name_edit: LineEdit = %NameEdit
@onready var _description_edit: TextEdit = %DescriptionEdit
@onready var _version_hint_edit: LineEdit = %VersionHintEdit



func _ready() -> void:
	super._ready()
	
	min_size = Vector2(400, 0) * Config.EDSCALE
	
	confirmed.connect(func():
		settings_changed.emit(
			_name_edit.text.strip_edges(), 
			_description_edit.text.strip_edges(),
			_version_hint_edit.text.strip_edges()
		)
	)
	
	_version_hint_edit.text_changed.connect(func(_new_text): utils.validate_version_hint_edit(self, false))


func init(initial_name, initial_description, initial_version_hint):
	_name_edit.text = initial_name
	_description_edit.text = initial_description
	_version_hint_edit.text = initial_version_hint
	utils.validate_version_hint_edit(self, false)
