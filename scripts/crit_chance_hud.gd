extends Control

const AIM_CRIT_START := 0.20
const AIM_CRIT_BASE  := 0.05

var _pct_label: Label
var _bar: ColorRect
var _bar_bg: ColorRect
var _last_pct: int = -1

func _ready() -> void:
	anchor_left   = 1.0
	anchor_top    = 1.0
	anchor_right  = 1.0
	anchor_bottom = 1.0
	offset_left   = -210.0
	offset_top    = -120.0
	offset_right  = -24.0
	offset_bottom = -28.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var title := Label.new()
	title.text = "CRIT CHANCE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.55))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	_pct_label = Label.new()
	_pct_label.text = "20%"
	_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pct_label.add_theme_font_size_override("font_size", 54)
	_pct_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_pct_label)

	# Window timer bar
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 6)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bar_container)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(_bar_bg)

	_bar = ColorRect.new()
	_bar.anchor_left = 0.0
	_bar.anchor_top = 0.0
	_bar.anchor_right = 1.0
	_bar.anchor_bottom = 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(_bar)

func update_crit(crit: float) -> void:
	var pct := roundi(crit * 100.0)
	# t = 1.0 at full bonus, 0.0 at base
	var t := clampf((crit - AIM_CRIT_BASE) / (AIM_CRIT_START - AIM_CRIT_BASE), 0.0, 1.0)

	var col := Color(
		1.0,
		lerpf(0.55, 0.2, t),
		lerpf(0.55, 0.05, t),
		lerpf(0.55, 1.0, t)
	)
	_pct_label.add_theme_color_override("font_color", col)

	# Bar fill and color
	_bar.anchor_right = t
	_bar.color = col

	if pct != _last_pct:
		_last_pct = pct
		_pct_label.text = "%d%%" % pct
		var tw := create_tween()
		tw.tween_property(_pct_label, "modulate:a", 0.5, 0.03)
		tw.tween_property(_pct_label, "modulate:a", 1.0, 0.06)
