extends Control

var _layer: CanvasLayer

func _ready() -> void:
	# Build UI programmatically for a single-script setup
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var dim_rect := ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 0.6)
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim_rect)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 40)
	center.add_child(vbox)
	
	var title := Label.new()
	title.text = "BATTLE COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_font_size := 64
	title.add_theme_font_size_override("font_size", title_font_size)
	vbox.add_child(title)
	
	var continue_btn := Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.custom_minimum_size = Vector2(240, 60)
	vbox.add_child(continue_btn)
	continue_btn.pressed.connect(_on_continue_pressed)
	
	# Start hidden
	modulate.a = 0.0
	visible = false

func open() -> void:
	print("[DEBUG] PostBattleScreen: open() called.")
	
	# Create a high-priority layer so we are above the victory cinematic (layer 127/128)
	if not _layer:
		_layer = CanvasLayer.new()
		_layer.layer = 130
		add_child(_layer)
		
		# Move our existing UI components into this layer
		for child in get_children():
			if child != _layer:
				remove_child(child)
				_layer.add_child(child)

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

func _on_continue_pressed() -> void:
	get_tree().reload_current_scene()
