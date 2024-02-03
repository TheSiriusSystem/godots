extends "res://src/components/projects/install_project_dialog/install_project_dialog.gd"

signal created(path)

const GD3_DEFAULT_ENV_TRES := """[gd_resource type="Environment" load_steps=2 format=2]\n
[sub_resource type="ProceduralSky" id=1]\n
[resource]
background_mode = 2
background_sky = SubResource( 1 )"""
const GD4_ICON_SVG := """<svg height="128" width="128" xmlns="http://www.w3.org/2000/svg"><rect x="2" y="2" width="124" height="124" rx="14" fill="#363d52" stroke="#212532" stroke-width="4"/><g transform="scale(.101) translate(122 122)"><g fill="#fff"><path d="M105 673v33q407 354 814 0v-33z"/><path fill="#478cbf" d="m105 673 152 14q12 1 15 14l4 67 132 10 8-61q2-11 15-15h162q13 4 15 15l8 61 132-10 4-67q3-13 15-14l152-14V427q30-39 56-81-35-59-83-108-43 20-82 47-40-37-88-64 7-51 8-102-59-28-123-42-26 43-46 89-49-7-98 0-20-46-46-89-64 14-123 42 1 51 8 102-48 27-88 64-39-27-82-47-48 49-83 108 26 42 56 81zm0 33v39c0 276 813 276 813 0v-39l-134 12-5 69q-2 10-14 13l-162 11q-12 0-16-11l-10-65H447l-10 65q-4 11-16 11l-162-11q-12-3-14-13l-5-69z"/><path d="M483 600c3 34 55 34 58 0v-86c-3-34-55-34-58 0z"/><circle cx="725" cy="526" r="90"/><circle cx="299" cy="526" r="90"/></g><g fill="#414042"><circle cx="307" cy="532" r="60"/><circle cx="717" cy="532" r="60"/></g></g></svg>"""
const GITIGNORE := """# Godot-specific ignores
.import/
.godot/
export.cfg
export_presets.cfg
.fscache

# Imported translations (automatically generated from CSV files)
*.translation

# Mono-specific ignores
.mono/
data_*/
mono_crash.*.json"""
const GITATTRIBUTES := """# Normalize EOL for all files that Git considers text files.
* text=auto eol=lf"""

@onready var _renderer_container: VBoxContainer = %RendererContainer
@onready var _renderer_options: VBoxContainer = %RendererOptions
@onready var _renderer_info: Label = %RendererInfo
@onready var _svg_container: HBoxContainer = %SvgContainer
@onready var _svg_check_box: CheckBox = %SvgCheckBox
@onready var _vcs_metadata_option_button: OptionButton = %VCSMetadataOptionButton
@onready var _just_create_button: Button = add_button(tr("Create"), false, "just_create")

var _renderer_option_group: ButtonGroup = ButtonGroup.new()

func _ready():
	super._ready()
	
	for option in _renderer_options.get_children():
		option.button_group = _renderer_option_group
	
	_renderer_option_group.pressed.connect(func(button):
		var data = get_appropriate_renderer_data(button)
		if data:
			_renderer_info.text = data.info
	)
	_svg_check_box.button_pressed = Cache.smart_value(self, "use_svg", true).ret(false)
	
	custom_action.connect(func(action):
		if action == "just_create":
			_on_confirmed(false)
			visible = false
	)

func get_appropriate_renderer_data(option: CheckBox):
	var keys = option.data.keys()
	
	# Sort by latest local editors.
	keys.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	keys.reverse()
	
	for key in keys:
		var version: PackedInt32Array = utils.extract_version_from_string(key)
		if _selected_version[0] == version[0]:
			var version_number_count = len(version)
			var match_score = 1
			for i in range(1, version_number_count):
				if _selected_version[i] >= version[i]:
					match_score += 1
			return option.data[key] if match_score == version_number_count else {}
	return {}

func _error(text):
	super._error(text)
	_just_create_button.disabled = _ok_button.disabled

func _warning(text):
	super._warning(text)
	_just_create_button.disabled = _ok_button.disabled

func _success(text):
	super._success(text)
	_just_create_button.disabled = _ok_button.disabled

func _on_editor_selected(idx):
	super._on_editor_selected(idx)
	var visible_renderer_options = 0
	var buttons = _renderer_option_group.get_buttons()
	
	for option in buttons:
		var data = get_appropriate_renderer_data(option)
		if data:
			option.visible = true
			option.text = data.name
			visible_renderer_options += 1
		else:
			option.visible = false
	
	if visible_renderer_options > 0:
		_renderer_container.visible = true
		for button in buttons:
			if button.visible:
				if not button.button_pressed:
					button.button_pressed = true
				else:
					# Workaround for pressed() not being emitted if the button is already pressed.
					_renderer_option_group.pressed.emit(button)
				break
	else:
		_renderer_container.visible = false
	_svg_container.visible = _selected_version[0] >= 4
	
	size.y = 0

func _on_confirmed(edit):
	var dir = _project_path_line_edit.text.strip_edges()
	var project_file_path = dir.path_join(utils.PROJECT_CONFIG_FILENAMES[0] if _selected_version[0] >= 3 else utils.PROJECT_CONFIG_FILENAMES[1])
	var project_name = _project_name_edit.text.strip_edges()
	
	var check_icon_svg_eligibility = func():
		return _selected_version[0] >= 4 and _svg_check_box.button_pressed
	
	var initial_settings = ConfigFile.new()
	if _selected_version[0] >= 3:
		# Godot 3+ (project.godot)
		initial_settings.set_value("application", "config/name", project_name)
		initial_settings.set_value("application", "config/icon", "res://icon.%s" % ["svg" if check_icon_svg_eligibility.call() else "png"])
		if _selected_version[0] == 3:
			initial_settings.set_value("", "config_version", 3 if _selected_version[1] == 0 else 4)
			initial_settings.set_value("rendering", "environment/default_environment", "res://default_env.tres");
			if _selected_version[1] >= 3:
				initial_settings.set_value("physics", "common/enable_pause_aware_picking", true)
			if _selected_version[1] >= 5:
				initial_settings.set_value("gui", "common/drop_mouse_on_gui_input_disabled", true)
		else:
			initial_settings.set_value("", "config_version", 5)
	else:
		# Godot 1-2 (engine.cfg)
		initial_settings.set_value("application", "name", project_name)
		initial_settings.set_value("godots", "description", "")
		initial_settings.set_value("application", "icon", "res://icon.png")
		if _selected_version[0] == 2 and _selected_version[1] >= 1:
			initial_settings.set_value("physics_2d", "motion_fix_enabled", true)
	var renderer_data = get_appropriate_renderer_data(_renderer_option_group.get_pressed_button())
	if renderer_data.has("keys"):
		for section in renderer_data.keys():
			var keys = renderer_data[section]
			for key in keys.keys():
				initial_settings.set_value(section, key, section[key])
	
	var err = initial_settings.save(project_file_path)
	if err:
		_error("%s %s: %s." % [
			tr("Couldn't create project configuration file in project path."), tr("Code"), err
		])
	else:
		var file_to: FileAccess
		
		if _selected_version[0] == 3:
			var final_string = GD3_DEFAULT_ENV_TRES
			if _selected_version[1] < 5:
				final_string.replace("\n", "")
			file_to = FileAccess.open(dir.path_join("default_env.tres"), FileAccess.WRITE)
			file_to.store_line(final_string)
		
		if check_icon_svg_eligibility.call():
			file_to = FileAccess.open(dir.path_join("icon.svg"), FileAccess.WRITE)
			file_to.store_string(GD4_ICON_SVG)
		else:
			var img: Texture2D
			if _selected_version[0] <= 2:
				img = preload("res://assets/default_project_icon_x.png")
			elif _selected_version[0] == 3:
				img = preload("res://assets/default_project_icon_3.png")
			elif _selected_version[0] == 3:
				img = preload("res://assets/default_project_icon_4.svg")
			img.get_image().save_png(dir.path_join("icon.png"))
		
		match _vcs_metadata_option_button.selected:
			1:
				# Git
				file_to = FileAccess.open(dir.path_join(".gitignore"), FileAccess.WRITE)
				file_to.store_string(GITIGNORE)
				file_to = FileAccess.open(dir.path_join(".gitattributes"), FileAccess.WRITE)
				file_to.store_string(GITATTRIBUTES)
		
		file_to.close()
		created.emit(project_file_path, _editors_option_button.get_selected_metadata().path, edit)
		Cache.smart_value(self, "use_svg", true).put(_svg_check_box.button_pressed)
