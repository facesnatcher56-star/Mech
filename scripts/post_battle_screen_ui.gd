extends Control

const AMMO_POOL := [
	{
		"key": "AP", "label": "ARMOR-PIERCING", "color": Color(1.0, 0.75, 0.2),
		"desc": "A narrow-bodied penetrator forged for killing machines through their thickest plates. It does not explode for spectacle; it finds a seam, bites through armor, and leaves the damage where repairs are hardest."
	},
	{
		"key": "HE", "label": "HIGH-EXPLOSIVE", "color": Color(1.0, 0.35, 0.15),
		"desc": "A brute-force demolition round packed to break frames, joints, and support structure. It does not care about elegance — it hits, blooms outward, and makes the whole machine answer for one bad impact."
	},
	{
		"key": "INCENDIARY", "label": "INCENDIARY", "color": Color(1.0, 0.15, 0.05),
		"desc": "A cruel thermal charge that trades instant destruction for lingering ruin. It slips fire into seams, joints, and open wounds, turning armor into an oven and damaged parts into liabilities."
	},
	{
		"key": "SHRAPNEL", "label": "SHRAPNEL", "color": Color(0.7, 0.7, 0.9),
		"desc": "A fragmentation round filled with ugly little answers to exposed armor. One shell becomes a storm of metal, chewing across plates, cables, joints, and anything unlucky enough to be outside the main hull."
	},
	{
		"key": "CONCUSSION", "label": "CONCUSSION", "color": Color(0.4, 0.85, 1.0),
		"desc": "A shock round designed to beat the rhythm out of enemy machinery. Its blast hammers sensors, crew, mounts, and timing gear — not always killing fast, but making the next enemy shot come late or wrong."
	},
	{
		"key": "BREACH", "label": "BREACH", "color": Color(0.9, 0.5, 1.0),
		"desc": "A specialist cracking charge made to open the door for the next shot. It weakens armor instead of finishing the job, marking one section of the enemy machine for a follow-up hit that hurts far worse."
	},
]

var _progress_bar: ProgressBar
var _continue_btn: Button
var _desc_label: Label
var _loading_path: String = "res://scenes/main.tscn"
var _is_loading: bool = false
var _rewards: Array = []
var _selected_index: int = -1
var _card_buttons: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 32)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "BATTLE COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "CHOOSE YOUR REWARD"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(subtitle)

	_rewards = _generate_rewards()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	for i in _rewards.size():
		var card := _make_card(i, _rewards[i])
		hbox.add_child(card)
		_card_buttons.append(card)

	# Description panel — updates on hover
	var desc_container := PanelContainer.new()
	desc_container.custom_minimum_size = Vector2(620, 70)
	var desc_style := StyleBoxFlat.new()
	desc_style.bg_color = Color(0.07, 0.07, 0.09, 0.9)
	desc_style.set_border_width_all(1)
	desc_style.border_color = Color(0.25, 0.25, 0.3, 0.5)
	desc_style.set_corner_radius_all(4)
	desc_style.set_content_margin_all(14)
	desc_container.add_theme_stylebox_override("panel", desc_style)
	vbox.add_child(desc_container)

	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72, 0.85))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_container.add_child(_desc_label)

	_continue_btn = Button.new()
	_continue_btn.name = "ContinueButton"
	_continue_btn.text = "CONTINUE"
	_continue_btn.custom_minimum_size = Vector2(240, 60)
	_continue_btn.visible = false
	vbox.add_child(_continue_btn)
	_continue_btn.pressed.connect(_on_continue_pressed)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(400, 30)
	_progress_bar.visible = false
	vbox.add_child(_progress_bar)

	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)

func _generate_rewards() -> Array:
	var pool := AMMO_POOL.duplicate()
	pool.shuffle()
	var result := []
	for i in 3:
		var entry: Dictionary = pool[i].duplicate()
		entry["amount"] = randi_range(1, 5)
		result.append(entry)
	return result

func _make_card(index: int, reward: Dictionary) -> Button:
	var col: Color = reward["color"]

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.08, 0.10, 1.0)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(col.r, col.g, col.b, 0.4)
	normal_style.set_corner_radius_all(4)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 1.0)
	hover_style.set_border_width_all(2)
	hover_style.border_color = Color(col.r, col.g, col.b, 0.9)
	hover_style.set_corner_radius_all(4)

	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(col.r * 0.22, col.g * 0.22, col.b * 0.22, 1.0)
	selected_style.set_border_width_all(3)
	selected_style.border_color = col
	selected_style.set_corner_radius_all(4)

	var dimmed_style := StyleBoxFlat.new()
	dimmed_style.bg_color = Color(0.06, 0.06, 0.07, 1.0)
	dimmed_style.set_border_width_all(2)
	dimmed_style.border_color = Color(0.25, 0.25, 0.25, 0.3)
	dimmed_style.set_corner_radius_all(4)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(190, 230)
	btn.add_theme_stylebox_override("normal",   normal_style)
	btn.add_theme_stylebox_override("hover",    hover_style)
	btn.add_theme_stylebox_override("pressed",  hover_style)
	btn.add_theme_stylebox_override("focus",    normal_style)
	btn.set_meta("normal_style",   normal_style)
	btn.set_meta("selected_style", selected_style)
	btn.set_meta("dimmed_style",   dimmed_style)

	var inner := VBoxContainer.new()
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.offset_left = 16.0
	inner.offset_top = 20.0
	inner.offset_right = -16.0
	inner.offset_bottom = -20.0
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 20)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(inner)

	var name_label := Label.new()
	name_label.text = reward["label"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", col)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(name_label)

	var amount_label := Label.new()
	amount_label.text = "x%d" % reward["amount"]
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 56)
	amount_label.add_theme_color_override("font_color", col)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(amount_label)

	var shells_label := Label.new()
	shells_label.text = "SHELLS"
	shells_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shells_label.add_theme_font_size_override("font_size", 12)
	shells_label.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.5))
	shells_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(shells_label)

	btn.pressed.connect(_on_card_pressed.bind(index))
	btn.mouse_entered.connect(_on_card_hovered.bind(index))
	btn.mouse_exited.connect(_on_card_unhovered)
	return btn

func _on_card_hovered(index: int) -> void:
	if _desc_label:
		_desc_label.text = _rewards[index].get("desc", "")

func _on_card_unhovered() -> void:
	if _desc_label and _selected_index >= 0:
		_desc_label.text = _rewards[_selected_index].get("desc", "")
	elif _desc_label:
		_desc_label.text = ""

func _on_card_pressed(index: int) -> void:
	_selected_index = index
	for i in _card_buttons.size():
		var btn: Button = _card_buttons[i]
		if i == index:
			btn.add_theme_stylebox_override("normal", btn.get_meta("selected_style"))
			btn.add_theme_stylebox_override("hover",  btn.get_meta("selected_style"))
		else:
			btn.add_theme_stylebox_override("normal", btn.get_meta("dimmed_style"))
			btn.add_theme_stylebox_override("hover",  btn.get_meta("dimmed_style"))
			btn.modulate = Color(0.55, 0.55, 0.55)
	_continue_btn.visible = true

func _process(_delta: float) -> void:
	if _is_loading:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
		if status == 1:
			_progress_bar.value = progress[0] * 100
		elif status == 3:
			_is_loading = false
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(_loading_path))
		elif status == 2 or status == 0:
			_is_loading = false
			get_tree().change_scene_to_file(_loading_path)

func _on_continue_pressed() -> void:
	if _is_loading or _selected_index < 0:
		return

	var reward: Dictionary = _rewards[_selected_index]
	var run_state := get_node_or_null("/root/RunState")
	if run_state:
		run_state.add_ammo(reward["key"], reward["amount"])

	_continue_btn.visible = false
	_progress_bar.visible = true
	_progress_bar.value = 0

	var err := ResourceLoader.load_threaded_request(_loading_path)
	if err == OK:
		_is_loading = true
	else:
		get_tree().change_scene_to_file(_loading_path)
