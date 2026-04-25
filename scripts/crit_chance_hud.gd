extends Control

const AIM_CRIT_START := 0.20
const AIM_CRIT_BASE  := 0.05

var _pct_label: Label
var _last_pct: int = -1

func _ready() -> void:
	anchor_left   = 1.0
	anchor_top    = 0.0
	anchor_right  = 1.0
	anchor_bottom = 0.0
	offset_left   = -120.0
	offset_top    = 20.0
	offset_right  = -20.0
	offset_bottom = 70.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var title := Label.new()
	title.text = "CRIT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.55))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	_pct_label = Label.new()
	_pct_label.text = "20%"
	_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pct_label.add_theme_font_size_override("font_size", 27)
	_pct_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_pct_label)

func update_crit(crit: float) -> void:
	var pct := roundi(crit * 100.0)
	var t := clampf((crit - AIM_CRIT_BASE) / (AIM_CRIT_START - AIM_CRIT_BASE), 0.0, 1.0)
	var col := Color(1.0, lerpf(0.55, 0.2, t), lerpf(0.55, 0.05, t), lerpf(0.55, 1.0, t))
	_pct_label.add_theme_color_override("font_color", col)

	if pct != _last_pct:
		_last_pct = pct
		_pct_label.text = "%d%%" % pct
		var tw := create_tween()
		tw.tween_property(_pct_label, "modulate:a", 0.5, 0.03)
		tw.tween_property(_pct_label, "modulate:a", 1.0, 0.06)
