extends Control

var _progress_bar: ProgressBar
var _loading_path: String = "res://scenes/main.tscn"
var _is_loading: bool = false

func _ready() -> void:
	# Build UI programmatically for a standalone screen
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Solid industrial dark background
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.05, 0.05, 0.06, 1.0)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 40)
	center.add_child(vbox)
	
	var title := Label.new()
	title.text = "BATTLE COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	vbox.add_child(title)
	
	var continue_btn := Button.new()
	continue_btn.name = "ContinueButton"
	continue_btn.text = "CONTINUE"
	continue_btn.custom_minimum_size = Vector2(240, 60)
	vbox.add_child(continue_btn)
	continue_btn.pressed.connect(_on_continue_pressed)
	
	# Progress bar for loading
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(400, 30)
	_progress_bar.visible = false
	vbox.add_child(_progress_bar)
	
	# Fade in the whole screen for aesthetic
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	if _is_loading:
		var progress = []
		var status = ResourceLoader.load_threaded_get_status(_loading_path, progress)
		
		if status == 1: # ResourceLoader.THREADED_LOAD_IN_PROGRESS
			_progress_bar.value = progress[0] * 100
		elif status == 3: # ResourceLoader.THREADED_LOAD_LOADED
			_is_loading = false
			var new_scene = ResourceLoader.load_threaded_get(_loading_path)
			get_tree().change_scene_to_packed(new_scene)
		elif status == 2 or status == 0: # THREADED_LOAD_FAILED or THREADED_LOAD_INVALID_RESOURCE
			_is_loading = false
			print("Loading failed!")

func _on_continue_pressed() -> void:
	if _is_loading:
		return
	
	# Hide button, show loading bar
	var btn = find_child("ContinueButton")
	if btn:
		btn.visible = false
	
	_progress_bar.visible = true
	_progress_bar.value = 0
	
	# Start threaded loading
	var err = ResourceLoader.load_threaded_request(_loading_path)
	if err == OK:
		_is_loading = true
	else:
		print("Failed to start loading: ", err)
		# Fallback to direct loading if threaded fails
		get_tree().change_scene_to_file(_loading_path)
