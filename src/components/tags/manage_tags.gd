extends ConfirmationDialog

@export var _tag_scene: PackedScene

@onready var _item_tags_container: HFlowContainer = %ItemTagsContainer
@onready var _all_tags_container: HFlowContainer = %AllTagsContainer
@onready var _create_tag_dialog: ConfirmationDialog = $CreateTagDialog
@onready var _new_tag_name_edit: LineEdit = %NewTagNameEdit
@onready var _create_tag_button: Button = %CreateTagButton
@onready var action_buttons: Array[Button] = [
	_create_tag_dialog.get_ok_button(), # HACK: utils.set_dialog_status() relies on this variable, so we use the dialog's OK button.
]

var _on_confirm_callback

func _ready() -> void:
#	super._ready()
	
	$VBoxContainer/Label.theme_type_variation = "HeaderMedium"
	$VBoxContainer/Label3.theme_type_variation = "HeaderMedium"
	
	_item_tags_container.custom_minimum_size = Vector2(0, 100) * Config.EDSCALE
	_all_tags_container.custom_minimum_size = Vector2(0, 100) * Config.EDSCALE
	
	_create_tag_dialog.about_to_popup.connect(func():
		_new_tag_name_edit.clear()
		_new_tag_name_edit.grab_focus()
	)
	
	_create_tag_dialog.confirmed.connect(func():
		_add_to_all_tags(_new_tag_name_edit.text)
	)
	
	_create_tag_button.pressed.connect(func():
		_create_tag_dialog.popup_centered(
			Vector2(500, 0) * Config.EDSCALE
		)
	)
	_create_tag_button.icon = get_theme_icon("Add", "EditorIcons")
	
	confirmed.connect(func():
		if _on_confirm_callback:
			_on_confirm_callback.call(_get_approved_tags())
		_on_confirm_callback = null
	)
	canceled.connect(func():
		_on_confirm_callback = null
	)
	
	_new_tag_name_edit.text_changed.connect(func(new_text):
		if new_text.strip_edges().is_empty():
			utils.set_dialog_status(_create_tag_dialog, tr("Tag name can't be empty."), utils.DialogStatus.ERROR)
			return
		
		if new_text.to_lower() != new_text:
			utils.set_dialog_status(_create_tag_dialog, tr("Tag name must be lowercase."), utils.DialogStatus.ERROR)
			return
		
		if new_text.contains(" "):
			utils.set_dialog_status(_create_tag_dialog, tr("Tag name can't contain spaces."), utils.DialogStatus.ERROR)
			return
		
		utils.set_dialog_status(_create_tag_dialog, "", utils.DialogStatus.SUCCESS)
	)


func init(item_tags, all_tags, on_confirm):
	_on_confirm_callback = on_confirm
	
	_clear_tag_container_children(_item_tags_container)
	for tag in Set.of(item_tags).values():
		_add_to_item_tags(tag)

	_clear_tag_container_children(_all_tags_container)
	for tag in Set.of(all_tags).values():
		_add_to_all_tags(tag)


func _add_to_item_tags(tag):
	if not _has_tag_with_text(tag):
		_add_tag_control_to(
			_item_tags_container, 
			tag, 
			true,
			func(tag_control): tag_control.queue_free()
		)


func _add_to_all_tags(tag):
	_all_tags_container.remove_child(_create_tag_button)
	_add_tag_control_to(
		_all_tags_container, 
		tag, 
		false,
		func(_arg): _add_to_item_tags(tag)
	)
	_all_tags_container.add_child(_create_tag_button)


func _has_tag_with_text(text):
	return _get_approved_tags().has(text.to_lower())


func _clear_tag_container_children(container):
	for tag in container.get_children():
		if not tag is Button:
			tag.free()


func _add_tag_control_to(parent, text, display_close, on_pressed=null):
	var tag_control = _tag_scene.instantiate()
	parent.add_child(tag_control)
	tag_control.init(text, display_close)
	if on_pressed:
		tag_control.pressed.connect(func(): on_pressed.call(tag_control))


func _get_approved_tags():
	var raw_tags = (
		_item_tags_container.get_children()
			.map(func(x): return x.text)
			.filter(func(text): return text is String)
			.map(func(text): return text.to_lower())
	)
	return Set.of(raw_tags).values()
