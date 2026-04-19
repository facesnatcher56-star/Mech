extends Control

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var name_label: Label = $Panel/NameLabel
@onready var class_label: Label = $Panel/ClassLabel
@onready var reload_label: Label = $Panel/ReloadLabel
@onready var order_label: Label = $Panel/OrderLabel
@onready var response_label: Label = $Panel/ResponseLabel

@export_group("Crew Order UI")
## Display name shown on the crew nameplate.
@export var crew_name: String = "PVT. HALE"
## Combat class shown under the crew name.
@export var crew_class: String = "RPG RIFLEMAN"
## Short callsign shown as the unit tag.
@export var crew_callsign: String = "LANCER-2"
## Seconds before the crew order panel fades after the last line.
@export var hold_time: float = 2.2
## Seconds used for fade in and fade out.
@export var fade_time: float = 0.18

var _hide_timer: SceneTreeTimer = null
var _fade_tween: Tween = null
var _reload_remaining: float = 0.0
var _reload_max: float = 1.0
var _reload_ratio: float = 1.0
var _display_reload_ratio: float = 1.0
var _ready_flash: float = 0.0

func _ready() -> void:
	visible = true
	modulate.a = 1.0
	set_process(true)
	title_label.text = "[CREW-LINK]"
	name_label.text = crew_name
	class_label.text = crew_class
	order_label.text = ""
	response_label.text = ""
	set_reload(0.0, 1.0)
	_update_layout()
	get_viewport().size_changed.connect(_update_layout)

func _update_layout() -> void:
	var vp := get_viewport_rect().size
	set_position(Vector2(22.0, vp.y - size.y - 22.0))

func _process(delta: float) -> void:
	_display_reload_ratio = lerpf(_display_reload_ratio, _reload_ratio, min(1.0, delta * 9.0))
	if _ready_flash > 0.0:
		_ready_flash = maxf(0.0, _ready_flash - delta)
	queue_redraw()

func set_crew_identity(display_name: String, display_class: String) -> void:
	crew_name = display_name
	crew_class = display_class
	if name_label:
		name_label.text = crew_name
	if class_label:
		class_label.text = crew_class

func set_reload(remaining: float, maximum: float) -> void:
	var was_ready := _reload_remaining <= 0.05
	_reload_remaining = maxf(0.0, remaining)
	_reload_max = maxf(0.001, maximum)
	_reload_ratio = clampf(1.0 - (_reload_remaining / _reload_max), 0.0, 1.0)
	if not was_ready and _reload_remaining <= 0.05:
		_ready_flash = 0.8
	if not reload_label:
		return
	if _reload_remaining > 0.05:
		reload_label.text = "RELOAD %.1fs" % _reload_remaining
	else:
		reload_label.text = "RPG ARMED"
	queue_redraw()

func show_order(text: String) -> void:
	order_label.text = "ORDER: " + text
	_show_panel()

func show_response(text: String) -> void:
	response_label.text = "RPG: " + text
	_show_panel()

func show_exchange(order_text: String, response_text: String) -> void:
	order_label.text = "ORDER: " + order_text
	response_label.text = "RPG: " + response_text
	_show_panel()

func _show_panel() -> void:
	visible = true
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, fade_time)
	_hide_timer = get_tree().create_timer(hold_time)
	_hide_timer.timeout.connect(_fade_dialogue)

func _fade_dialogue() -> void:
	order_label.text = ""
	response_label.text = ""

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	var ready_color := Color(0.48, 0.90, 0.40)
	var reload_color := Color(0.95, 0.62, 0.18)
	var dark := Color(0.018, 0.022, 0.018, 0.92)
	var edge := Color(0.43, 0.39, 0.20, 0.95)
	var hot := ready_color.lerp(Color(1.0, 0.9, 0.35), _ready_flash * pulse)
	var bar_color := hot if _reload_remaining <= 0.05 else reload_color

	draw_rect(rect, dark, true)
	draw_rect(rect, edge.darkened(0.25), false, 2.0)
	draw_rect(Rect2(8, 8, 58, 58), Color(0.06, 0.075, 0.055, 0.98), true)
	draw_rect(Rect2(8, 8, 58, 58), edge, false, 1.0)
	draw_line(Vector2(16, 21), Vector2(58, 21), Color(0.68, 0.58, 0.30, 0.8), 2.0)
	draw_line(Vector2(19, 49), Vector2(55, 17), Color(0.18, 0.68, 0.24, 0.7), 2.0)

	var reload_back := Rect2(12, 84, size.x - 24, 12)
	draw_rect(reload_back, Color(0.04, 0.045, 0.035, 1.0), true)
	draw_rect(Rect2(reload_back.position, Vector2(reload_back.size.x * _display_reload_ratio, reload_back.size.y)), bar_color, true)
	draw_rect(reload_back, edge.darkened(0.2), false, 1.0)

	var notch_count := 12
	for i in range(notch_count + 1):
		var x := reload_back.position.x + reload_back.size.x * float(i) / float(notch_count)
		draw_line(Vector2(x, reload_back.position.y), Vector2(x, reload_back.position.y + reload_back.size.y), Color(0, 0, 0, 0.35), 1.0)

	var font := get_theme_default_font()
	draw_string(font, Vector2(74, 21), crew_callsign, HORIZONTAL_ALIGNMENT_LEFT, 110, 13, Color(0.72, 0.68, 0.42))
