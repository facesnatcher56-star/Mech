extends Control

@export var ring_radius_ratio: float = 0.42 # ~84% of height
@export var ring_width: float = 12.0
@export var major_tick_length: float = 48.0
@export var minor_tick_length: float = 16.0
@export var stadia_width_ratio: float = 0.75 
@export var hud_color: Color = Color(0.55, 0.65, 0.40, 1.0) # Brighter, more "phosphor" green
@export var dim_color: Color = Color(0.12, 0.18, 0.10, 0.7)
@export var active_marker_color: Color = Color(0.85, 0.80, 0.50, 0.98)
@export var secondary_marker_color: Color = Color(0.35, 0.45, 0.25, 0.8)
@export var amber_color: Color = Color(1.0, 0.65, 0.1, 0.8)
@export var cyan_color: Color = Color(0.2, 0.85, 1.0, 0.8)

var hit_chance: float = 0.0
var range_band: String = "LONG"
var aligned: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.size_changed.connect(queue_redraw)

func set_solution(new_hit_chance: float, new_range_band: String, is_aligned: bool) -> void:
	hit_chance = clampf(new_hit_chance, 0.0, 1.0)
	range_band = new_range_band
	aligned = is_aligned
	queue_redraw()

func _draw() -> void:
	var center = size * 0.5
	var v_size = get_viewport_rect().size
	var r = v_size.y * ring_radius_ratio
	var font = get_theme_default_font()
	var t = Time.get_ticks_msec() * 0.001
	var quality = clampf(hit_chance, 0.0, 1.0)
	var flicker = 0.97 + sin(t * 50.0) * 0.02 + sin(t * 120.0) * 0.01

	var ap = r + 40.0
	var black    = Color(0.00, 0.00, 0.00, 0.99)
	var glass    = Color(0.02, 0.04, 0.02, 0.20)
	var phosphor = Color(0.50, 0.58, 0.34, flicker)
	var dim      = Color(0.22, 0.26, 0.15, 0.72)
	var bead_dk  = Color(0.10, 0.12, 0.08, 0.92)
	var bead_lt  = Color(0.32, 0.38, 0.22, 1.00)
	var white    = Color(0.95, 0.95, 0.90, 1.00)

	# --- APERTURE MASKING ---
	draw_rect(Rect2(0, 0, size.x, center.y - ap), black)
	draw_rect(Rect2(0, center.y + ap, size.x, size.y - (center.y + ap)), black)
	draw_rect(Rect2(0, center.y - ap, center.x - ap, ap * 2.0), black)
	draw_rect(Rect2(center.x + ap, center.y - ap, size.x - (center.x + ap), ap * 2.0), black)
	var segs = 96
	for i in range(segs):
		var a0 = TAU * float(i) / float(segs)
		var a1 = TAU * float(i + 1) / float(segs)
		var p0 = center + Vector2(cos(a0), sin(a0)) * ap
		var p1 = center + Vector2(cos(a1), sin(a1)) * ap
		var am = (a0 + a1) * 0.5
		var corner = center + Vector2(sign(cos(am)) * ap, sign(sin(am)) * ap)
		draw_colored_polygon(PackedVector2Array([p0, p1, corner]), black)
	draw_circle(center, ap, glass)

	# --- OUTER BEZEL ---
	draw_arc(center, ap + 10.0, 0.0, TAU, 128, Color(0.06, 0.06, 0.05, 1.0), 22.0)
	draw_arc(center, ap + 1.0,  0.0, TAU, 128, Color(0.18, 0.18, 0.14, 1.0),  2.5)

	# --- BEADED RING ---
	var bead_count = 108
	for i in range(bead_count):
		var angle = TAU * float(i) / float(bead_count)
		var bp = center + Vector2(cos(angle), sin(angle)) * r
		var major = (i % 9 == 0)
		draw_arc(bp, 4.5 if major else 3.2, 0.0, TAU, 10, bead_lt if major else bead_dk, 1.8 if major else 1.2)

	# --- ROTATING NUMBERED DIAL ---
	var labels = ["MG", "0", "4", "6", "8", "10", "12", "14", "16", "18", "20", "22", "24", "26", "28", "30", "32", "34", "36", "MWF"]
	var dial_rot = t * 0.04 * lerpf(1.2, 0.08, quality) - PI * 0.5
	for i in range(labels.size()):
		var angle = dial_rot + TAU * float(i) / float(labels.size())
		var lp = center + Vector2(cos(angle), sin(angle)) * (r + 28.0)
		draw_string(font, lp - Vector2(9.0, -4.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, dim)

	# --- INNER TICK MARKS ---
	for i in range(40):
		var angle = TAU * float(i) / 40.0
		var d = Vector2(cos(angle), sin(angle))
		var major = (i % 5 == 0)
		draw_line(center + d * (r - (22.0 if major else 10.0)), center + d * (r - 2.0),
				phosphor if major else dim, 2.0 if major else 1.0)

	# --- HORIZONTAL SWEEP LINE + TRIANGLES ---
	var sweep  = (sin(t * 1.8) * 0.55 + sin(t * 2.93) * 0.28 + sin(t * 0.47) * 0.17) * (1.0 - quality * 0.72) * r * 0.36
	var lx0    = center.x - r * 0.94
	var lx1    = center.x + r * 0.94
	draw_line(Vector2(lx0, center.y), Vector2(lx1, center.y), dim, 1.5)
	for i in range(9):
		var lx = lx0 + (lx1 - lx0) * float(i) / 8.0
		var h  = 10.0 if (i % 4 == 0) else 5.0
		draw_line(Vector2(lx, center.y - h * 0.5), Vector2(lx, center.y + h * 0.5), dim, 1.0)
	var spread = (1.0 - quality) * r * 0.32 + 18.0
	for tx in [-spread * 1.55, -spread, -spread * 0.42, spread * 0.42, spread, spread * 1.55]:
		_draw_tri(Vector2(center.x + tx + sweep * 0.25, center.y), 5.0, dim)
	_draw_tri(Vector2(center.x + sweep, center.y), 9.0, phosphor)

	# --- CROSSHAIR ---
	draw_line(center + Vector2(-14, 0), center + Vector2(14, 0), Color(0, 0, 0, 0.85), 5.0)
	draw_line(center + Vector2(0, -14), center + Vector2(0, 14), Color(0, 0, 0, 0.85), 5.0)
	draw_line(center + Vector2(-11, 0), center + Vector2(11, 0), phosphor, 1.5)
	draw_line(center + Vector2(0, -11), center + Vector2(0, 11), phosphor, 1.5)

	# --- RANGE LABEL (top-center, inside ring) ---
	var rw = 110.0
	var rh = 28.0
	var rp = Vector2(center.x - rw * 0.5, center.y - r * 0.82)
	draw_rect(Rect2(rp, Vector2(rw, rh)), Color(0, 0, 0, 0.88), true)
	draw_rect(Rect2(rp, Vector2(rw, rh)), dim, false, 1.0)
	draw_string(font, rp + Vector2(rw * 0.5 - 18.0, rh - 8.0), range_band, HORIZONTAL_ALIGNMENT_LEFT, rw - 12.0, 14, white)

	# --- SOLUTION QUALITY GAUGE (mechanical instrument housing) ---
	var gw    = 210.0
	var gh    = 88.0
	var gx    = center.x + r * 0.30
	var gy    = center.y + r * 0.44
	var grect = Rect2(gx, gy, gw, gh)

	# Housing
	draw_rect(grect, Color(0.0, 0.0, 0.0, 0.88), true)
	draw_rect(grect, dim, false, 2.0)
	draw_rect(Rect2(gx + 4, gy + 4, gw - 8, gh - 8), dim.darkened(0.5), false, 1.0)
	# Corner rivets
	for cx2 in [gx + 7, gx + gw - 7]:
		for cy2 in [gy + 7, gy + gh - 7]:
			draw_circle(Vector2(cx2, cy2), 3.0, dim)

	# Large percentage number
	var pct = "%.1f%%" % (quality * 100.0)
	draw_string(font, Vector2(gx + 12, gy + 52), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, white)

	# Scale bar with tick marks
	var bar_rect = Rect2(gx + 10, gy + gh - 20, gw - 20, 8)
	draw_rect(bar_rect, Color(0.04, 0.05, 0.03, 1.0), true)
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * quality, bar_rect.size.y)), phosphor, true)
	draw_rect(bar_rect, dim.darkened(0.2), false, 1.0)
	for i in range(11):
		var tx2 = bar_rect.position.x + bar_rect.size.x * float(i) / 10.0
		var th  = 5.0 if (i % 5 == 0) else 3.0
		draw_line(Vector2(tx2, bar_rect.position.y - th), Vector2(tx2, bar_rect.position.y), dim, 1.0)

func _draw_tri(pos: Vector2, half: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-half, -half),
		pos + Vector2( half, -half),
		pos + Vector2(0.0,   half * 0.7),
	]), color)
