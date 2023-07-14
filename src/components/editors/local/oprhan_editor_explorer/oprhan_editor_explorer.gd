extends ConfirmationDialog

const dir_extensions = preload("res://src/extensions/dir.gd")
const editors_ns = preload("res://src/services/local_editors.gd")

@onready var _tree: Tree = $VBoxContainer/Tree

var _local_editors: editors_ns.LocalEditors
var _versions_abs_path: String


func _ready() -> void:
	confirmed.connect(func():
		var selected_dirs = []
		for child in _tree.get_root().get_children():
			if child.get_cell_mode(0) == TreeItem.CELL_MODE_CHECK and child.is_checked(0):
				if child.has_meta("abs_path"):
					selected_dirs.append(child.get_meta("abs_path"))
		
		var delete_confirm = ConfirmationDialogAutoFree.new()
		delete_confirm.dialog_text = "Permanently delete %d item(s)? (No undo!)" % len(selected_dirs)
		delete_confirm.confirmed.connect(func():
			for dir in selected_dirs:
				dir_extensions.remove_recursive(dir)
			hide()
		)
		add_child(delete_confirm)
		delete_confirm.popup_centered()
	)


func init(local_editors, versions_abs_path):
	_local_editors = local_editors
	_versions_abs_path = versions_abs_path


func before_popup():
	_tree.clear()
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_MULTI
	
	var root = _tree.create_item()
	for orphan_dir in self._get_orphan_dirs():
		var item = _tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_text(0, orphan_dir.replace(ProjectSettings.globalize_path(_versions_abs_path), " "))
		item.set_editable(0, true)
		item.set_meta("abs_path", orphan_dir)


func _get_orphan_dirs():
	var all_dirs = DirAccess.get_directories_at(_versions_abs_path)
	var editor_dirs = _local_editors.all().map(func(x): return x.path.get_base_dir())
	var orphan_dirs = []
	for dir in all_dirs:
		var abs_dir_path = ProjectSettings.globalize_path(_versions_abs_path.path_join(dir))
		if abs_dir_path not in editor_dirs:
			orphan_dirs.append(abs_dir_path)
	return orphan_dirs