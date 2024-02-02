extends ConfirmationDialogAutoFree

signal project_changed(new_name, new_description, new_version_hint)

@onready var _name_edit: LineEdit = %LineEdit
@onready var _description_edit: TextEdit = %TextEdit
@onready var _version_hint_edit: LineEdit = %LineEdit2


func _ready() -> void:
	super._ready()
	
	min_size = Vector2(350, 0) * Config.EDSCALE
	
	confirmed.connect(func():
		project_changed.emit(
			_name_edit.text.strip_edges(),
			_description_edit.text.strip_edges(),
			_version_hint_edit.text.strip_edges()
		)
	)
	
	_name_edit.text_changed.connect(_on_name_text_changed)


func init(initial_name, initial_description, initial_version_hint):
	_name_edit.text = initial_name
	_description_edit.text = initial_description
	_version_hint_edit.text = initial_version_hint
	_on_name_text_changed(_name_edit.text)


func _on_name_text_changed(new_text):
	get_ok_button().disabled = new_text.strip_edges().is_empty()
