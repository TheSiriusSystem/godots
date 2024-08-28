extends "res://src/components/projects/install_project_dialog/install_project_dialog.gd"

signal created(path)

const RENDERER_METADATA := [
	{
		"3.1.0": {
			"name": "OpenGL ES 3.0",
			"info": """•  Higher visual quality.
•  All features available.
•  Incompatible with older hardware.
•  Not recommended for web games.""",
			"cfg_values": {
				"rendering": {
					"quality/driver/driver_name": "GLES3",
				},
			},
		},
		"4.0.0": {
			"name": "Forward+",
			"info": """•  Supports desktop platforms only.
•  Advanced 3D graphics available.
•  Can scale to large complex scenes.
•  Uses RenderingDevice backend.
•  Slower rendering of simple scenes.""",
			"cfg_values": {
				"rendering": {
					"renderer/rendering_method": "forward_plus",
				},
			},
		},
	},
	{
		"3.1.0": {
			"name": "OpenGL ES 2.0",
			"info": """•  Lower visual quality.
•  Some features not available.
•  Works on most hardware.
•  Recommended for web games.""",
			"cfg_values": {
				"rendering": {
					"quality/driver/driver_name": "GLES2",
					"vram_compression/import_etc": true,
					"vram_compression/import_etc2": false,
				},
			},
		},
		"4.0.0": {
			"name": "Mobile",
			"info": """•  Supports desktop + mobile platforms.
•  Less advanced 3D graphics.
•  Less scalable for complex scenes.
•  Uses RenderingDevice backend.
•  Fast rendering of simple scenes.""",
			"cfg_values": {
				"rendering": {
					"renderer/rendering_method": "mobile",
				},
			},
		},
	},
	{
		"4.0.0": {
			"name": "Compatibility",
			"info": """•  Supports desktop, mobile + web platforms.
•  Least advanced 3D graphics (currently work-in-progress).
•  Intended for low-end/older devices.
•  Uses OpenGL 3 backend (OpenGL 3.3/ES 3.0/WebGL2).
•  Fastest rendering of simple scenes.""",
			"cfg_values": {
				"rendering": {
					"renderer/rendering_method": "gl_compatibility",
					"renderer/rendering_method.mobile": "gl_compatibility",
				},
			},
		},
	},
]
const VERSION_CONTROL_METADATA := {
	"None": {
		"directories": [],
		"files": {},
	},
	"Git": {
		"directories": [],
		"files": {
			".gitignore": """# Godot-specific ignores
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
mono_crash.*.json""",
			".gitattributes": """# Normalize EOL for all files that Git considers text files.
* text=auto eol=lf""",
		},
	},
}

@onready var _renderer_container: VBoxContainer = %RendererContainer
@onready var _renderer_options: VBoxContainer = %RendererOptions
@onready var _renderer_info: Label = %RendererInfo
@onready var _hq_icon_switch: HBoxContainer = %HQIconSwitch
@onready var _hq_icon_check_box: CheckBox = %HQIconCheckBox
@onready var _vcs_option_button = %VCSOptionButton

var _renderer_option_group: ButtonGroup = ButtonGroup.new()

func _ready():
	super._ready()
	action_buttons.push_back(add_button(tr("Create"), false, "just_create"))
	
	for vcs in VERSION_CONTROL_METADATA.keys():
		_vcs_option_button.add_item(vcs)
		_vcs_option_button.set_item_metadata(_vcs_option_button.item_count - 1, VERSION_CONTROL_METADATA[vcs])
	
	for option in _renderer_options.get_children():
		option.button_group = _renderer_option_group
	_renderer_option_group.pressed.connect(func(button):
		var config = _get_appropriate_renderer_config(button)
		if config:
			_renderer_info.text = config.info
	)
	
	custom_action.connect(func(action):
		if action == "just_create":
			_on_confirmed(false)
	)


func _on_editor_selected(idx):
	var visible_renderer_options = 0
	var options = _renderer_option_group.get_buttons()
	
	for option in options:
		var data = _get_appropriate_renderer_config(option)
		if data:
			option.visible = true
			option.text = data.name
			visible_renderer_options += 1
		else:
			option.visible = false
	
	if visible_renderer_options > 0:
		_renderer_container.visible = true
		for option in options:
			if option.visible:
				if not option.button_pressed:
					option.button_pressed = true
				else:
					# Workaround for pressed() not being emitted if the button is already pressed.
					_renderer_option_group.pressed.emit(option)
				break
	else:
		_renderer_container.visible = false
	_hq_icon_switch.visible = _selected_version[0] >= 4
	
	size.y = 0


func _on_confirmed(edit):
	var dir = _project_path_line_edit.text.strip_edges()
	var project_file_path = dir.path_join(utils.PROJECT_CONFIG_FILENAMES[1] if _selected_version[0] <= 2 else utils.PROJECT_CONFIG_FILENAMES[0])
	var project_name = _project_name_edit.text.strip_edges()
	
	# [Sirius] In Godot 1-2, new projects' icon paths don't have res:// in the value
	# but this is not replicated as any in-editor changes make it have res:// anyways.
	var icon_path = "res://icon.%s" % ["svg" if _selected_version[0] >= 4 and _hq_icon_check_box.button_pressed else "png"]
	var icon_filename = icon_path.get_file()
	
	var initial_settings = ConfigFile.new()
	if _selected_version[0] <= 2: # engine.cfg
		# [Sirius] Godot 1-2 config files use different spacing. Not gonna bother trying
		# to replicate that here.
		initial_settings.set_value("application", "name", project_name)
		initial_settings.set_value("application", "icon", icon_path)
		
		# Godot 2.1.4+ defaults
		if _selected_version[0] == 2 and ((_selected_version[1] == 1 and _selected_version[2] >= 4) or _selected_version[1] >= 2):
			initial_settings.set_value("physics_2d", "motion_fix_enabled", true)
	else: # project.godot
		initial_settings.set_value("application", "config/name", project_name)
		initial_settings.set_value("application", "config/icon", icon_path)
		if _selected_version[0] == 3:
			initial_settings.set_value("", "config_version", 3 if _selected_version[1] <= 0 else 4)
			initial_settings.set_value("rendering", "environment/default_environment", "res://default_env.tres")
			
			# Godot 3.3+ defaults
			if _selected_version[1] >= 3:
				initial_settings.set_value("physics", "common/enable_pause_aware_picking", true)
			
			# Godot 3.5+ defaults
			if _selected_version[1] >= 5:
				initial_settings.set_value("gui", "common/drop_mouse_on_gui_input_disabled", true)
		else:
			initial_settings.set_value("", "config_version", 5)
	var renderer_config = _get_appropriate_renderer_config(_renderer_option_group.get_pressed_button())
	if renderer_config:
		for section in renderer_config.cfg_values.keys():
			var keys = renderer_config.cfg_values[section]
			for key in keys.keys():
				initial_settings.set_value(section, key, keys[key])
	
	var err = utils.save_project_config(initial_settings, _selected_version, project_file_path)
	if err != OK:
		_create_folder_failed_dialog.dialog_text = "%s: %s." % [tr("Couldn't create project configuration file in project path. Code"), err]
		_create_folder_failed_dialog.popup_centered()
	else:
		var file_to: FileAccess = null
		
		if _selected_version[0] == 3:
			var file_contents = """[gd_resource type="Environment" load_steps=2 format=2]\n
[sub_resource type="ProceduralSky" id=1]\n
[resource]
background_mode = 2
background_sky = SubResource( 1 )"""
			
			# In Godot 3.5+ projects, default_env.tres lines 1-2 have newlines
			if _selected_version[1] < 5:
				file_contents.replace("\n", "")
			
			file_to = FileAccess.open(dir.path_join("default_env.tres"), FileAccess.WRITE)
			file_to.store_line(file_contents)
		
		if icon_filename.get_extension() == "svg":
			file_to = FileAccess.open(dir.path_join(icon_filename), FileAccess.WRITE)
			file_to.store_string(FileAccess.get_file_as_string("res://assets/default_project_icon_4.svg"))
		else:
			var img: Texture2D
			if _selected_version[0] <= 2:
				img = preload("res://assets/default_project_icon_1.png")
			elif _selected_version[0] == 3:
				img = preload("res://assets/default_project_icon_3.png")
			else:
				img = preload("res://assets/default_project_icon_4.svg")
			err = img.get_image().save_png(dir.path_join(icon_filename))
			if err == OK and _selected_version[0] <= 2:
				file_to = FileAccess.open(dir.path_join(icon_filename + ".flags"), FileAccess.WRITE)
				file_to.store_line("gen_mipmaps=false")
		
		var selected_vcs = _vcs_option_button.get_item_text(_vcs_option_button.selected)
		if selected_vcs in VERSION_CONTROL_METADATA:
			var meta = VERSION_CONTROL_METADATA[selected_vcs]
			for directory in meta.directories:
				DirAccess.make_dir_recursive_absolute(dir.path_join(directory))
			for file in meta.files.keys():
				file_to = FileAccess.open(dir.path_join(file), FileAccess.WRITE)
				file_to.store_line(meta.files[file])
		
		if file_to:
			file_to.close()
		created.emit(project_file_path, _editors_option_button.get_selected_metadata().path, edit)
		visible = false


func _get_appropriate_renderer_config(option: CheckBox):
	var meta = RENDERER_METADATA[int(option.name.validate_node_name())]
	var meta_keys = meta.keys()
	
	# Sort by latest local editors
	meta_keys.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) > 0)
	
	for key in meta_keys:
		var version: PackedInt32Array = utils.extract_version_from_string(key, false, utils.VersionMatchMode.STRICT_FORBID_LEADING_CHARACTERS)
		if _selected_version[0] == version[0]:
			var match_score = 1
			for i in range(1, len(version)):
				if _selected_version[i] >= version[i]:
					match_score += 1
			if match_score == len(version):
				return meta[key]
	return null
