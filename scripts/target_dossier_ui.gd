extends Control

enum AnchorCorner { BOTTOM_RIGHT, TOP_LEFT, TOP_RIGHT }

@export_group("Layout Adjustments")
@export var anchor_corner: AnchorCorner = AnchorCorner.BOTTOM_RIGHT
@export_range(0.1, 2.0, 0.01) var display_scale: float = 1.0
@export_range(-1000, 1000, 1) var custom_offset_x: float = 0.0
@export_range(-1000, 1000, 1) var custom_offset_y: float = 0.0

@export var minimal_mode: bool = false

@export_group("Visuals")
@export var panel_size: Vector2 = Vector2(210.0, 306.0)
@export var panel_margin: Vector2 = Vector2(22.0, 22.0)
@export var background_color: Color = Color(0.015, 0.018, 0.014, 0.92)
@export var border_color: Color = Color(0.50, 0.47, 0.30, 0.95)
@export var text_color: Color = Color(0.74, 0.78, 0.58, 1.0)
@export var muted_text_color: Color = Color(0.34, 0.39, 0.28, 1.0)
@export var good_color: Color = Color(0.30, 0.64, 0.32, 1.0)
@export var warn_color: Color = Color(0.86, 0.62, 0.18, 1.0)
@export var critical_color: Color = Color(0.86, 0.18, 0.12, 1.0)
@export var flash_color: Color = Color(1.0, 0.86, 0.22, 1.0)

var snapshot: Dictionary = {}
var latest_impact: String = "NO CONTACT"
var flash_part_key: String = ""
var flash_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(true)
	_update_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _process(delta: float) -> void:
	if flash_timer > 0.0:
		flash_timer = max(0.0, flash_timer - delta)
		queue_redraw()
	if snapshot.get("reload", {}).get("aiming", false):
		queue_redraw()

func set_snapshot(new_snapshot: Dictionary) -> void:
	snapshot = new_snapshot
	queue_redraw()

func show_dossier(new_snapshot: Dictionary = {}) -> void:
	if not new_snapshot.is_empty():
		set_snapshot(new_snapshot)
	visible = true
	_update_layout()
	queue_redraw()

func hide_dossier() -> void:
	visible = false
	flash_timer = 0.0

func show_impact_line(text: String, part_key: String = "", new_snapshot: Dictionary = {}) -> void:
	latest_impact = text
	flash_part_key = part_key
	flash_timer = 0.75
	if not new_snapshot.is_empty():
		set_snapshot(new_snapshot)
	visible = true
	queue_redraw()

func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	size = panel_size
	scale = Vector2(display_scale, display_scale)
	
	var scaled_size = panel_size * display_scale
	var base_pos := Vector2.ZERO
	
	if anchor_corner == AnchorCorner.TOP_LEFT:
		pivot_offset = Vector2.ZERO
		base_pos = panel_margin
	elif anchor_corner == AnchorCorner.TOP_RIGHT:
		pivot_offset = Vector2(panel_size.x, 0)
		base_pos = Vector2(viewport_size.x - panel_size.x, 0)
	else:
		pivot_offset = panel_size
		base_pos = Vector2(viewport_size.x - panel_size.x - panel_margin.x, viewport_size.y - panel_size.y - panel_margin.y)

	position = base_pos + Vector2(custom_offset_x, custom_offset_y)


func _draw() -> void:
	var font := get_theme_default_font()
	var rect := Rect2(Vector2.ZERO, panel_size)

	if minimal_mode:
		_draw_minimal(font, rect)
		return

	draw_rect(rect, background_color, true)
	draw_rect(rect, border_color.darkened(0.45), false, 4.0)
	draw_rect(Rect2(Vector2(6, 6), panel_size - Vector2(12, 12)), border_color.darkened(0.20), false, 1.0)

	# Header
	var target_name := str(snapshot.get("name", "ZEZLAN"))
	var destroyed   := bool(snapshot.get("destroyed", false))
	var status_text  := "DESTROYED" if destroyed else "ACTIVE"
	var status_color := critical_color if destroyed else warn_color
	draw_string(font, Vector2(14, 20), "TARGET DOSSIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, muted_text_color)
	draw_string(font, Vector2(14, 44), target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, text_color)

	# Structure bar (thin, under header)
	var structure: Dictionary = {"current": 100, "max": 100}
	if snapshot.has("structure") and snapshot["structure"] is Dictionary:
		structure = snapshot["structure"]
	var str_ratio := clampf(float(structure.get("current", 100)) / float(maxi(1, int(structure.get("max", 100)))), 0.0, 1.0)
	var str_bar := Rect2(14, 52, panel_size.x - 28, 5)
	var str_col := _bar_color(str_ratio, false)
	if flash_timer > 0.0 and flash_part_key == "structure":
		str_col = str_col.lerp(flash_color, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.03))
	draw_rect(str_bar, Color(0.02, 0.025, 0.02, 1.0), true)
	draw_rect(Rect2(str_bar.position, Vector2(str_bar.size.x * str_ratio, str_bar.size.y)), str_col, true)
	draw_line(Vector2(12, 59), Vector2(panel_size.x - 12, 59), border_color.darkened(0.5), 1.0)

	# Silhouette part data
	var parts: Dictionary = {}
	if snapshot.has("parts") and snapshot["parts"] is Dictionary:
		parts = snapshot["parts"]
	var torso_d   := _get_part(parts, "torso")
	var arm_l_d   := _get_part(parts, "left_arm")
	var arm_r_d   := _get_part(parts, "right_arm")
	var leg_l_d   := _get_part(parts, "left_leg")
	var leg_r_d   := _get_part(parts, "right_leg")
	var has_arms  := parts.has("left_arm") or parts.has("right_arm")
	var neutral   := Color(0.14, 0.16, 0.11, 0.90)

	# --- MECH SILHOUETTE ---
	# Head
	_draw_sil_part(font, Rect2(83, 64, 44, 20), {}, "HEAD", neutral)
	# Torso
	_draw_sil_part(font, Rect2(69, 88, 72, 68), torso_d, "TORSO")
	# Arms — only drawn when this mech has arm parts
	if has_arms:
		_draw_sil_part(font, Rect2(16,  94, 50, 56), arm_l_d, "L ARM")
		_draw_sil_part(font, Rect2(144, 94, 50, 56), arm_r_d, "R ARM")
	# Legs
	_draw_sil_part(font, Rect2(71,  160, 32, 82), leg_l_d, "L LEG")
	_draw_sil_part(font, Rect2(107, 160, 32, 82), leg_r_d, "R LEG")

	# Reload bar (shown when snapshot includes "reload" data)
	if snapshot.has("reload") and snapshot["reload"] is Dictionary:
		var rl      := snapshot["reload"] as Dictionary
		var rl_prog := clampf(float(rl.get("progress", 1.0)), 0.0, 1.0)
		var rl_lbl  := str(rl.get("label", "WEAPON"))
		var rl_col  := good_color if rl_prog >= 0.95 else (warn_color if rl_prog >= 0.42 else critical_color)
		var rl_stat := "READY" if rl_prog >= 0.95 else ("LOADING" if rl_prog < 0.42 else "ALMOST READY")
		draw_line(Vector2(12, panel_size.y - 56), Vector2(panel_size.x - 12, panel_size.y - 56), border_color.darkened(0.5), 1.0)
		draw_string(font, Vector2(14, panel_size.y - 46), rl_lbl,  HORIZONTAL_ALIGNMENT_LEFT,  -1,  9, muted_text_color)
		var bar_r := Rect2(14, panel_size.y - 39, panel_size.x - 28, 8)
		draw_rect(bar_r, Color(0.02, 0.025, 0.02, 1.0), true)
		draw_rect(Rect2(bar_r.position, Vector2(bar_r.size.x * rl_prog, bar_r.size.y)), rl_col, true)
		draw_rect(bar_r, border_color.darkened(0.4), false, 1.0)

	# Impact line
	draw_rect(Rect2(12, panel_size.y - 32, panel_size.x - 24, 22), Color(0, 0, 0, 0.5), true)
	var is_flash := flash_timer > 0.0
	var imp_color := flash_color.lerp(Color.WHITE, 0.3 * sin(Time.get_ticks_msec() * 0.03)) if is_flash else warn_color
	draw_string(font, Vector2(20, panel_size.y - 15), latest_impact, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 40, 12, imp_color)

func _draw_minimal(font: Font, rect: Rect2) -> void:
	var rl: Dictionary = snapshot.get("reload", {})
	var rl_prog  := clampf(float(rl.get("progress", 0.0)), 0.0, 1.0)
	var rl_lbl   := str(rl.get("label", "CANNON"))
	var is_aiming := bool(rl.get("aiming", false))

	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	var rl_col: Color
	if is_aiming:
		rl_col = critical_color.lerp(warn_color, pulse)
	else:
		rl_col = good_color if rl_prog >= 0.95 else (warn_color if rl_prog >= 0.42 else critical_color)

	var rl_stat: String
	if is_aiming:
		rl_stat = "AIMING"
	elif rl_prog >= 0.95:
		rl_stat = "READY"
	elif rl_prog >= 0.42:
		rl_stat = "LOADING"
	else:
		rl_stat = "LOADING"

	var target_name := str(snapshot.get("name", "ZEZLAN"))

	draw_rect(rect, background_color, true)
	draw_rect(rect, border_color.darkened(0.45), false, 2.0)

	draw_string(font, Vector2(14, 16), target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, muted_text_color)
	draw_string(font, Vector2(14, 30), rl_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, muted_text_color)
	draw_string(font, Vector2(panel_size.x - 14, 30), rl_stat, HORIZONTAL_ALIGNMENT_RIGHT, -1, 9, rl_col)

	var bar_r := Rect2(14, 36, panel_size.x - 28, 10)
	draw_rect(bar_r, Color(0.02, 0.025, 0.02, 1.0), true)
	draw_rect(Rect2(bar_r.position, Vector2(bar_r.size.x * rl_prog, bar_r.size.y)), rl_col, true)
	draw_rect(bar_r, border_color.darkened(0.4), false, 1.0)

	if flash_timer > 0.0:
		var imp_col := flash_color.lerp(Color.WHITE, 0.3 * sin(Time.get_ticks_msec() * 0.03))
		draw_string(font, Vector2(14, panel_size.y - 6), latest_impact, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 28, 10, imp_col)

func _get_part(parts: Dictionary, key: String) -> Dictionary:
	if parts.has(key) and parts[key] is Dictionary:
		return parts[key]
	return {}

func _draw_sil_part(font: Font, r: Rect2, part: Dictionary, label: String, override_color: Color = Color(-1,-1,-1,-1)) -> void:
	var current := int(part.get("current", 0))
	var maximum := int(part.get("max", 1))
	var broken  := bool(part.get("broken", false))
	var ratio   := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0) if not part.is_empty() else 1.0
	var fill    := override_color if override_color.a >= 0.0 else _bar_color(ratio, broken)

	var key: String = str(part.get("label", label)) if not part.is_empty() else label
	var is_flash := flash_timer > 0.0 and not part.is_empty() and _matches_flash_key(str(key), label)
	if is_flash:
		fill = fill.lerp(flash_color, 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.03))

	# Dark background
	draw_rect(r, fill.darkened(0.62), true)
	# Health fill from bottom
	var fill_h := r.size.y * ratio
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y - fill_h, r.size.x, fill_h), fill, true)
	# Border
	draw_rect(r, border_color.darkened(0.28), false, 1.0)
	# Label at bottom
	draw_string(font, r.position + Vector2(3, r.size.y - 5), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, 9, text_color.darkened(0.2))
	# HP value at top (only if we have data)
	if not part.is_empty():
		var val := "X" if broken else str(current)
		draw_string(font, r.position + Vector2(3, 13), val, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, 11, text_color)

func _bar_color(ratio: float, broken: bool) -> Color:
	if broken or ratio <= 0.25:
		return critical_color
	if ratio <= 0.55:
		return warn_color
	return good_color

func _matches_flash_key(key: String, label: String) -> bool:
	var clean_flash := flash_part_key.to_lower().replace("_", "").replace(" ", "")
	var clean_key := key.to_lower().replace("_", "").replace(" ", "")
	var clean_label := label.to_lower().replace("_", "").replace(" ", "")
	return clean_flash == clean_key or clean_flash == clean_label
