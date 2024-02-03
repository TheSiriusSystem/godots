extends "res://src/components/projects/install_project_dialog/install_project_dialog.gd"

signal about_to_install(project_name, project_dir)

var handle_dir_is_not_empty = null


func _handle_dir_is_not_empty(path):
	if handle_dir_is_not_empty != null:
		return handle_dir_is_not_empty.call(self, path)
	else:
		return super._handle_dir_is_not_empty(path)


func _on_confirmed(edit):
	about_to_install.emit(
		_project_name_edit.text.strip_edges(),
		_project_path_line_edit.text.strip_edges()
	)
