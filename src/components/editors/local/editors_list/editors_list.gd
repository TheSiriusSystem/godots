extends VBoxList

signal item_removed(item_data, remove_dir: bool)
signal item_edited(item_data)
signal item_manage_tags_requested(item_data)


func _post_add(item_data, item_control):
	item_control.removed.connect(
		func(remove_dir): item_removed.emit(item_data, remove_dir)
	)
	item_control.edited.connect(
		func(): item_edited.emit(item_data)
	)
	item_control.manage_tags_requested.connect(
		func(): item_manage_tags_requested.emit(item_data)
	)


func _item_comparator(a, b):
	if a.favorite and not b.favorite:
		return true
	if b.favorite and not a.favorite:
		return false
	match _sort_option_button.selected:
		1: return a.path < b.path
		2: return a.tag_sort_string < b.tag_sort_string
		_: return a.name < b.name
	return a.name < b.name


func _fill_sort_options(btn: OptionButton):
	btn.add_item(tr("Name"))
	btn.add_item(tr("Path"))
	btn.add_item(tr("Tags"))
	
	var last_checked_sort = Cache.smart_value(self, "last_checked_sort", true)
	btn.select(last_checked_sort.ret(0))
	btn.item_selected.connect(func(idx): last_checked_sort.put(idx))
