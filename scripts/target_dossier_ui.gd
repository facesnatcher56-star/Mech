extends Control

@export var panel_size: Vector2 = Vector2(340.0, 220.0)
@export var panel_margin: Vector2 = Vector2(28.0, 92.0)
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
	position = Vector2(max(0.0, viewport_size.x - panel_size.x - panel_margin.x), panel_margin.y)

func _draw() -> void:
	var font := get_theme_default_font()
	var body_font_size := 15
	var title_font_size := 22
	var small_font_size := 12
	var rect := Rect2(Vector2.ZERO, panel_size)

	draw_rect(rect, background_color, true)
	draw_rect(rect, border_color.darkened(0.45), false, 4.0)
	draw_rect(Rect2(Vector2(8, 8), panel_size - Vector2(16, 16)), border_color.darkened(0.18), false, 1.0)

	var target_name := str(snapshot.get("name", "ZEZLAN"))
	draw_string(font, Vector2(18, 32), "TARGET DOSSIER", HORIZONTAL_ALIGNMENT_LEFT, -1, small_font_size, muted_text_color)
	draw_string(font, Vector2(18, 58), target_name, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size, text_color)

	var destroyed := bool(snapshot.get("destroyed", false))
	var status_text := "DESTROYED" if destroyed else "ACTIVE"
	var status_color := critical_color if destroyed else warn_color
	draw_string(font, Vector2(panel_size.x - 118, 56), status_text, HORIZONTAL_ALIGNMENT_RIGHT, 100, body_font_size, status_color)

	var y := 82.0
	var structure: Dictionary = {"current": 0, "max": 1}
	if snapshot.has("structure") and snapshot["structure"] is Dictionary:
		structure = snapshot["structure"]
	_draw_bar(font, Rect2(18, y, panel_size.x - 36, 28), "STRUCTURE", int(structure.get("current", 0)), int(structure.get("max", 1)), "structure")

	y += 44.0
	var parts: Dictionary = {}
	if snapshot.has("parts") and snapshot["parts"] is Dictionary:
		parts = snapshot["parts"]
	_draw_part(font, y, parts, "torso")
	y += 32.0
	_draw_part(font, y, parts, "left_leg")
	y += 32.0
	_draw_part(font, y, parts, "right_leg")

	draw_rect(Rect2(18, panel_size.y - 34, panel_size.x - 36, 22), Color(0, 0, 0, 0.45), true)
	draw_string(font, Vector2(26, panel_size.y - 17), latest_impact, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 52, small_font_size, warn_color)

func _draw_part(font: Font, y: float, parts: Dictionary, key: String) -> void:
	var part: Dictionary = {"label": key.to_upper(), "current": 0, "max": 1, "broken": false}
	if parts.has(key) and parts[key] is Dictionary:
		part = parts[key]
	_draw_bar(font, Rect2(18, y, panel_size.x - 36, 22), str(part.get("label", key.to_upper())), int(part.get("current", 0)), int(part.get("max", 1)), key, bool(part.get("broken", false)))

func _draw_bar(font: Font, rect: Rect2, label: String, current: int, maximum: int, key: String, broken: bool = false) -> void:
	var safe_max = max(1, maximum)
	var ratio = clampf(float(current) / float(safe_max), 0.0, 1.0)
	var fill_color := _bar_color(ratio, broken)
	var is_flash := flash_timer > 0.0 and _matches_flash_key(key, label)
	if is_flash:
		fill_color = fill_color.lerp(flash_color, 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.03))

	draw_rect(rect, Color(0.02, 0.025, 0.02, 0.95), true)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill_color, true)
	draw_rect(rect, border_color.darkened(0.35), false, 1.0)

	var value_text := "BROKEN" if broken else "%d/%d" % [current, maximum]
	draw_string(font, rect.position + Vector2(8, rect.size.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x * 0.55, 13, text_color)
	draw_string(font, rect.position + Vector2(rect.size.x - 96, rect.size.y - 6), value_text, HORIZONTAL_ALIGNMENT_RIGHT, 88, 13, text_color)

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
