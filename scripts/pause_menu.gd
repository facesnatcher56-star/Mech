extends Control

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var resolution_option: OptionButton
var fullscreen_toggle: CheckButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _has_window_display():
		return
	_build_menu()
	_sync_from_window()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_menu()
		get_viewport().set_input_as_handled()

func _build_menu() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0

	var dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.58)
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	add_child(dim)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210.0
	panel.offset_top = -190.0
	panel.offset_right = 210.0
	panel.offset_bottom = 190.0
	add_child(panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title = Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)

	var resolution_label = Label.new()
	resolution_label.text = "Display Resolution"
	box.add_child(resolution_label)

	resolution_option = OptionButton.new()
	resolution_option.tooltip_text = "Window size to use when not fullscreen."
	for resolution in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [resolution.x, resolution.y])
	box.add_child(resolution_option)

	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "Fullscreen"
	fullscreen_toggle.tooltip_text = "Switch between fullscreen and windowed display."
	box.add_child(fullscreen_toggle)

	var apply_button = Button.new()
	apply_button.text = "Apply Display"
	apply_button.tooltip_text = "Apply the selected resolution and fullscreen mode."
	apply_button.pressed.connect(_apply_display_settings)
	box.add_child(apply_button)

	var resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(_close_menu)
	box.add_child(resume_button)

	var exit_button = Button.new()
	exit_button.text = "Exit Play"
	exit_button.tooltip_text = "Quit the running play session."
	exit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(exit_button)

func _toggle_menu() -> void:
	if visible:
		_close_menu()
	else:
		_open_menu()

func _open_menu() -> void:
	if _has_window_display():
		_sync_from_window()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_menu() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _sync_from_window() -> void:
	if not _has_window_display():
		return
	var current_size = DisplayServer.window_get_size()
	var selected = 0
	var closest_distance = INF
	for i in range(RESOLUTIONS.size()):
		var distance = Vector2(current_size).distance_to(Vector2(RESOLUTIONS[i]))
		if distance < closest_distance:
			closest_distance = distance
			selected = i
	if resolution_option:
		resolution_option.select(selected)
	if fullscreen_toggle:
		var mode = DisplayServer.window_get_mode()
		fullscreen_toggle.button_pressed = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _apply_display_settings() -> void:
	if not _has_window_display():
		return
	var resolution = RESOLUTIONS[resolution_option.selected]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolution)
	_center_window(resolution)
	if fullscreen_toggle.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _center_window(resolution: Vector2i) -> void:
	if not _has_window_display():
		return
	var screen = DisplayServer.window_get_current_screen()
	var screen_pos = DisplayServer.screen_get_position(screen)
	var screen_size = DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(screen_pos + (screen_size - resolution) / 2)

func _has_window_display() -> bool:
	return DisplayServer.get_name() != "headless"
