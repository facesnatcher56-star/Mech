extends Control

signal ammo_selected(type_key: String)

const AMMO_TYPES: Dictionary = {
	"STANDARD": {
		"label": "STANDARD",
		"desc":  "General purpose",
		"color": Color(0.4, 1.0, 0.4),
		"tooltip": [
			"DMG  18 torso / 14 leg / 18 fallback",
			"VAR  ±20%",
			"CRIT  5% chance  ×2.0",
			"",
			"Reliable all-rounder.",
			"No special effects.",
			"Good default choice.",
		],
	},
	"AP": {
		"label": "ARMOR-PIERCING",
		"desc":  "High penetration",
		"color": Color(1.0, 0.75, 0.2),
		"tooltip": [
			"DMG  24 torso / 12 leg / 8 fallback",
			"VAR  ±15%",
			"CRIT  2% chance  ×1.75",
			"",
			"Best raw torso damage.",
			"Tight variance — consistent hits.",
			"Poor leg damage. No splash.",
		],
	},
	"HE": {
		"label": "HIGH-EXPLOSIVE",
		"desc":  "Splash adjacent part",
		"color": Color(1.0, 0.35, 0.15),
		"tooltip": [
			"DMG  14 torso / 16 leg / 12 fallback",
			"VAR  ±25%",
			"CRIT  4% chance  ×1.5",
			"SPLASH  6 dmg to one adjacent part",
			"",
			"Best leg damage in the kit.",
			"Torso hit splashes a random leg.",
			"Leg hit splashes back to torso.",
			"Good for leg-break victories.",
		],
	},
	"INCENDIARY": {
		"label": "INCENDIARY",
		"desc":  "Burn on hit part",
		"color": Color(1.0, 0.15, 0.05),
		"tooltip": [
			"DMG  10 torso / 9 leg / 7 fallback",
			"VAR  ±10%",
			"CRIT  3% chance  ×1.5",
			"BURN  3 dmg × 3 ticks  every 4s",
			"",
			"Weak immediate impact.",
			"Burn is part-specific — torso hit",
			"burns torso, leg hit burns leg.",
			"Repeat hits stack burn damage,",
			"reset the 4s tick timer.",
		],
	},
	"SHRAPNEL": {
		"label": "SHRAPNEL",
		"desc":  "Fragments hit 2 parts",
		"color": Color(0.7, 0.7, 0.9),
		"tooltip": [
			"DMG  12 torso / 13 leg / 10 fallback",
			"VAR  ±30%",
			"CRIT  6% chance  ×1.5",
			"FRAG  4 dmg to 2 random other parts",
			"",
			"Highest crit chance.",
			"Wide variance — chaotic damage.",
			"Always hits all 3 parts.",
			"Bad for finishing one specific part.",
			"Good for softening everything.",
		],
	},
	"CONCUSSION": {
		"label": "CONCUSSION",
		"desc":  "Delays fire cycle",
		"color": Color(0.4, 0.85, 1.0),
		"tooltip": [
			"DMG  13 torso / 11 leg / 9 fallback",
			"VAR  ±15%",
			"CRIT  3% chance  ×1.5",
			"STAGGER  +1.5–2.5s to fire timer",
			"",
			"If Zezlan is reloading:",
			"  delays next shot by stagger time.",
			"",
			"If Zezlan is already aiming:",
			"  cancels aim — full reload reset.",
			"",
			"Buys time. Best when low on health.",
		],
	},
	"BREACH": {
		"label": "BREACH",
		"desc":  "Cracks armor for +25%",
		"color": Color(0.9, 0.5, 1.0),
		"tooltip": [
			"DMG  16 torso / 10 leg / 6 fallback",
			"VAR  ±20%",
			"CRIT  4% chance  ×1.75",
			"CRACK  next hit to same part +25%",
			"",
			"First hit cracks the part.",
			"Any following hit triggers +25%",
			"bonus damage and removes crack.",
			"",
			"Hitting cracked part with Breach",
			"triggers old crack, applies new one.",
			"Rewards repeat targeting.",
		],
	},
}

const WHEEL_RADIUS  := 280.0
const INNER_RADIUS  := 104.0
const RING_STROKE   := 4.0
const WEDGE_GAP_RAD := deg_to_rad(2.5)

const BG_COLOR      := Color(0.03, 0.06, 0.03, 0.92)
const STROKE_DIM    := Color(0.25, 0.55, 0.25, 0.7)
const STROKE_HOT    := Color(0.5, 1.0, 0.5, 1.0)
const TEXT_DIM      := Color(0.35, 0.65, 0.35, 0.9)
const TEXT_HOT      := Color(0.9, 1.0, 0.9, 1.0)
const INNER_BG      := Color(0.02, 0.04, 0.02, 1.0)
const TOOLTIP_BG    := Color(0.03, 0.06, 0.03, 0.96)

var _selected_key: String  = "STANDARD"
var _hovered_index: int    = -1
var _pulse_t: float        = 0.0
var _keys: Array           = []

func _ready() -> void:
	_keys = AMMO_TYPES.keys()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func open() -> void:
	_keys = AMMO_TYPES.keys()
	_hovered_index = _keys.find(_selected_key)
	_pulse_t = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	get_tree().paused = true
	queue_redraw()

func force_close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _confirm_selection() -> void:
	if _hovered_index >= 0 and _hovered_index < _keys.size():
		_selected_key = _keys[_hovered_index]
	force_close()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ammo_selected.emit(_selected_key)

func get_selected_type() -> String:
	return _selected_key

func _process(delta: float) -> void:
	_hovered_index = _get_hovered_index()
	_pulse_t += delta * 3.5
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.keycode == KEY_Q and event.pressed and not event.echo:
		force_close()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_confirm_selection()

# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var c := size * 0.5
	var n := _keys.size()
	if n == 0:
		return

	draw_circle(c, WHEEL_RADIUS + RING_STROKE, Color(0, 0, 0, 0.55))
	draw_circle(c, WHEEL_RADIUS, BG_COLOR)

	var slice := TAU / n

	for i in n:
		var key: String = _keys[i]
		var info: Dictionary = AMMO_TYPES[key]
		var hot := (i == _hovered_index)
		var seg_color: Color = info["color"]

		var angle_start := i * slice - TAU / 4.0 + WEDGE_GAP_RAD * 0.5
		var angle_end   := angle_start + slice - WEDGE_GAP_RAD
		var steps       := 48

		var pts := PackedVector2Array()
		pts.append(c + Vector2(cos(angle_start), sin(angle_start)) * INNER_RADIUS)
		for s in steps + 1:
			var a := angle_start + s * (angle_end - angle_start) / steps
			pts.append(c + Vector2(cos(a), sin(a)) * WHEEL_RADIUS)
		pts.append(c + Vector2(cos(angle_end), sin(angle_end)) * INNER_RADIUS)
		for s in range(steps, -1, -1):
			var a := angle_start + s * (angle_end - angle_start) / steps
			pts.append(c + Vector2(cos(a), sin(a)) * INNER_RADIUS)

		var fill := seg_color
		fill.a = 0.35 if hot else 0.10
		draw_colored_polygon(pts, fill)

		var pulse := 0.7 + sin(_pulse_t) * 0.3 if hot else 1.0
		var stroke_col := seg_color.lerp(STROKE_HOT, 0.4) if hot else STROKE_DIM
		stroke_col.a *= pulse
		draw_arc(c, WHEEL_RADIUS - RING_STROKE * 0.5, angle_start, angle_end, steps, stroke_col, RING_STROKE * (1.6 if hot else 1.0))

		var mid_angle := (angle_start + angle_end) * 0.5
		var label_r   := (WHEEL_RADIUS + INNER_RADIUS) * 0.5
		var lp        := c + Vector2(cos(mid_angle), sin(mid_angle)) * label_r
		var font      := ThemeDB.fallback_font
		var fsize     := 13
		var lbl: String = info["label"]
		var lw        := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var txt_col: Color = info["color"] if hot else TEXT_DIM
		txt_col.a     = 1.0 if hot else 0.7
		draw_string(font, lp - Vector2(lw * 0.5, -fsize * 0.35), lbl,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, txt_col)

	draw_circle(c, INNER_RADIUS, INNER_BG)
	draw_arc(c, INNER_RADIUS, 0.0, TAU, 48, STROKE_DIM, 2.0)

	var show_key: String = _keys[_hovered_index] if _hovered_index >= 0 else _selected_key
	var show_info: Dictionary = AMMO_TYPES[show_key]
	_draw_tooltip(c, show_info)

func _draw_tooltip(c: Vector2, info: Dictionary) -> void:
	var font       := ThemeDB.fallback_font
	var name_size  := 14
	var stat_size  := 11
	var body_size  := 9
	var line_h     := 11.0
	var col: Color = info["color"]
	var tooltip: Array = info.get("tooltip", [])

	# Total content height
	var total_h := name_size + 4.0 + tooltip.size() * line_h
	var y := c.y - total_h * 0.5

	# Ammo name
	var lbl: String = info["label"]
	var lw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	draw_string(font, Vector2(c.x - lw * 0.5, y + name_size), lbl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, col)
	y += name_size + 4.0

	# Divider
	draw_line(Vector2(c.x - 70, y), Vector2(c.x + 70, y), Color(col.r, col.g, col.b, 0.4), 1.0)
	y += 4.0

	# Tooltip lines
	for line in tooltip:
		var line_str: String = line
		if line_str == "":
			y += line_h * 0.5
			continue
		var is_stat := line_str.begins_with("DMG") or line_str.begins_with("VAR") \
				or line_str.begins_with("CRIT") or line_str.begins_with("BURN") \
				or line_str.begins_with("SPLASH") or line_str.begins_with("FRAG") \
				or line_str.begins_with("STAGGER") or line_str.begins_with("CRACK")
		var fsize := stat_size
		var tcol := col if is_stat else TEXT_DIM
		if is_stat:
			tcol.a = 0.9
		else:
			tcol = TEXT_DIM
		var tw := font.get_string_size(line_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		draw_string(font, Vector2(c.x - tw * 0.5, y + fsize), line_str,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, tcol)
		y += line_h

# ── Hover detection ───────────────────────────────────────────────────────────

func _get_hovered_index() -> int:
	var offset := get_local_mouse_position() - size * 0.5
	var dist   := offset.length()
	if dist < INNER_RADIUS or dist > WHEEL_RADIUS:
		return -1
	var n := _keys.size()
	var angle := fmod(atan2(offset.y, offset.x) + TAU / 4.0 + TAU, TAU)
	var idx   := int(angle / (TAU / n))
	return clampi(idx, 0, n - 1)
