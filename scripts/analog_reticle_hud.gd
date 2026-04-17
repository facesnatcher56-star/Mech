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
	var current_ring_radius = v_size.y * ring_radius_ratio
	var font = get_theme_default_font()
	
	var t = Time.get_ticks_msec() * 0.001
	var quality = clampf(hit_chance, 0.0, 1.0)
	
	# --- OLD TECH EFFECTS ---
	var flicker = 0.97 + (sin(t * 50.0) * 0.02) + (sin(t * 120.0) * 0.01) # Stable shimmer
	var h_color = hud_color
	h_color.a *= flicker
	var a_color = amber_color
	a_color.a *= flicker
	var c_color = cyan_color
	c_color.a *= flicker
	var shadow_color = Color(0.0, 0.0, 0.0, 0.9)
	
	var aperture_radius = current_ring_radius + 40.0
	var aperture_color = Color(0.0, 0.0, 0.0, 0.99)
	var glass_color = Color(0.03, 0.06, 0.03, 0.25)
	
	# --- 1. FULL-SCREEN OPTIC HOUSING ---
	draw_rect(Rect2(0, 0, size.x, center.y - aperture_radius), aperture_color)
	draw_rect(Rect2(0, center.y + aperture_radius, size.x, size.y - (center.y + aperture_radius)), aperture_color)
	draw_rect(Rect2(0, center.y - aperture_radius, center.x - aperture_radius, aperture_radius * 2), aperture_color)
	draw_rect(Rect2(center.x + aperture_radius, center.y - aperture_radius, size.x - (center.x + aperture_radius), aperture_radius * 2), aperture_color)
	
	var mask_segments = 96
	for i in range(mask_segments):
		var angle_a = TAU * float(i) / float(mask_segments)
		var angle_b = TAU * float(i + 1) / float(mask_segments)
		var inner_a = center + Vector2(cos(angle_a), sin(angle_a)) * aperture_radius
		var inner_b = center + Vector2(cos(angle_b), sin(angle_b)) * aperture_radius
		var corner_a = center + Vector2(sign(cos(angle_a)) * aperture_radius, sign(sin(angle_a)) * aperture_radius) if abs(cos(angle_a)) > 0.707 else center + Vector2(cos(angle_a) * (aperture_radius/abs(sin(angle_a))), sign(sin(angle_a)) * aperture_radius)
		# (Simplified mask triangle logic for brevity, keeping existing polygon fill)
		var p2 = inner_b
		var p3 = center + Vector2(sign(cos(angle_b)) * aperture_radius, sign(sin(angle_b)) * aperture_radius)
		draw_colored_polygon(PackedVector2Array([inner_a, inner_b, p3, p3]), aperture_color) # Re-drawing corners

	# --- 2. THE BEZEL & STATUS LIGHTS ---
	draw_arc(center, aperture_radius + 12.0, 0.0, TAU, 120, Color(0.12, 0.12, 0.12, 1.0), 24.0)
	
	# Bezier Status Lights (Old glowing bulbs)
	for i in range(4):
		var l_angle = PI * 1.25 + (i * 0.15)
		var l_pos = center + Vector2(cos(l_angle), sin(l_angle)) * (aperture_radius + 20.0)
		var l_color = Color.RED if quality < 0.5 else Color.DARK_GREEN
		if i == 3 and quality > 0.8: l_color = Color.YELLOW
		draw_circle(l_pos, 4.0, l_color.lerp(Color.WHITE, 0.3 * flicker))

	# Rivets
	for i in range(16):
		var screw_angle = (t * 0.02) + TAU * float(i) / 16.0
		var screw_pos = center + Vector2(cos(screw_angle), sin(screw_angle)) * (aperture_radius + 22.0)
		draw_circle(screw_pos, 7.0, Color(0.05, 0.05, 0.05, 1.0))

	draw_circle(center, aperture_radius, glass_color)
	
	# --- 3. DYNAMIC HUD ELEMENTS ---
	var rot_a = t * 0.3 * lerpf(1.0, 0.15, quality)
	
	for i in range(24):
		var angle = rot_a + TAU * float(i) / 24.0
		var dir = Vector2(cos(angle), sin(angle))
		var color = active_marker_color if (i % 6 == 0) else secondary_marker_color
		draw_line(center + dir * (current_ring_radius + 15), center + dir * (current_ring_radius + 35), color, 3.0)

	# Main Static Dial (Cyan accents)
	draw_arc(center, current_ring_radius, 0.0, TAU, 160, c_color.darkened(0.4), 4.0)
	
	for i in range(120):
		var major = i % 10 == 0
		if major:
			var angle = TAU * float(i) / 120.0
			var direction = Vector2(cos(angle), sin(angle))
			draw_line(center + direction * (current_ring_radius - major_tick_length), center + direction * current_ring_radius, h_color, 4.0)

	# --- 4. CENTER STADIA ---
	var stadia_half = (size.x * stadia_width_ratio) * 0.5
	
	# Main Crosshair
	draw_line(center + Vector2(-15, 0), center + Vector2(15, 0), shadow_color, 6.0)
	draw_line(center + Vector2(0, -15), center + Vector2(0, 15), shadow_color, 6.0)
	draw_line(center + Vector2(-12, 0), center + Vector2(12, 0), h_color, 2.0)
	draw_line(center + Vector2(0, -12), center + Vector2(0, 12), h_color, 2.0)

	# --- 5. CALIBRATING PLATES ---
	# Range Plate (Cyan) - Stationary
	var plate_range_pos = center + Vector2(-current_ring_radius * 0.75, -current_ring_radius * 0.65)
	_draw_instrument_plate(plate_range_pos, Vector2(180, 60), "RANGE [STADIA]", range_band, c_color, font)
	
	# Hit Chance Plate (Amber) - Stationary
	var plate_hit_pos = center + Vector2(current_ring_radius * 0.35, current_ring_radius * 0.55)
	var percent_text = str(roundi(hit_chance * 100.0)) + "%"
	_draw_instrument_plate(plate_hit_pos, Vector2(200, 80), "SOLN QUALITY", percent_text, a_color, font, 42)

func _draw_instrument_plate(pos: Vector2, rect_size: Vector2, title: String, value: String, accent_color: Color, font: Font, val_size: int = 32):
	var rect = Rect2(pos, rect_size)
	draw_rect(rect, Color(0, 0, 0, 0.85), true)
	draw_rect(rect, accent_color.darkened(0.6), false, 2.0)
	draw_string(font, rect.position + Vector2(10, 20), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, accent_color.darkened(0.4))
	draw_string(font, rect.position + Vector2(10, rect.size.y - 15), value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, val_size, accent_color)
