extends Control

var current_spread: float = 0.0
var max_spread: float = 0.1
var accuracy_pct: int = 100
var reticle_color: Color = Color.GREEN

var current_throttle: float = 0.0
var current_speed: float = 0.0
var reload_progress: float = 0.0 
var current_bob: float = 0.0

func update_reticle(spread: float, maximum_spread: float, throttle: float, speed: float, reload_state: float = 0.0, armor: int = 3, damage_flash: float = 0.0):
	current_spread = spread
	max_spread = maximum_spread
	current_throttle = throttle
	current_speed = speed
	reload_progress = reload_state
	
	var ratio = clamp(spread / maximum_spread, 0.0, 1.0)
	accuracy_pct = int((1.0 - ratio) * 100)
	reticle_color = Color.GREEN.lerp(Color.RED, ratio)
	
	if reload_progress > 0.0:
		reticle_color = Color.DARK_RED 
		accuracy_pct = 0
		
	queue_redraw()

var target_range: float = 0.0
var on_target: bool = false
var range_lerp: float = 0.0

func set_range_info(rng: float, target_acquired: bool):
	target_range = rng
	on_target = target_acquired
	queue_redraw()

func _draw():
	# Apply bobbing to the UI center (scaled)
	var center = (size / 2.0) + Vector2(0, current_bob * 300.0)
	var color = reticle_color
	
	if on_target:
		color = Color.CYAN if accuracy_pct > 80 else Color.YELLOW
	
	var line_width = 2.0
	
	# --- 1. Main Analog Reticle (Stadia Markings) ---
	var chevron_size = 12.0
	var chevron_thickness = 3.0
	draw_line(center, center + Vector2(-chevron_size, chevron_size), color, chevron_thickness)
	draw_line(center, center + Vector2(chevron_size, chevron_size), color, chevron_thickness)
	
	var hz_len = 300.0
	draw_line(center - Vector2(hz_len, 0), center + Vector2(hz_len, 0), color, line_width)
	
	var tick_spacing = 40.0
	for i in range(-7, 8):
		if i == 0: continue
		var x_off = i * tick_spacing
		var is_major = (abs(i) == 5)
		var tick_h = 15.0 if is_major else 7.0
		draw_line(center + Vector2(x_off, -tick_h), center + Vector2(x_off, tick_h), color, line_width)
		if is_major:
			var val = abs(i)
			draw_string(ThemeDB.fallback_font, center + Vector2(x_off - 10, tick_h + 15), str(val), HORIZONTAL_ALIGNMENT_CENTER, -1, 14, color)

	for i in range(1, 5):
		var y_off = i * 60.0
		var mark_w = 40.0 - (i * 5.0)
		draw_line(center + Vector2(-mark_w, y_off), center + Vector2(mark_w, y_off), color, line_width)
		draw_string(ThemeDB.fallback_font, center + Vector2(mark_w + 10, y_off + 5), str(i * 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

	var rf_origin = center + Vector2(-280, 240)
	var rf_base_w = 180.0
	draw_line(rf_origin, rf_origin + Vector2(rf_base_w, 0), color, 2.0)
	
	var points = []
	for i in range(11):
		var t = i / 10.0
		var px = t * rf_base_w
		var py = -100.0 / (1.0 + t * 4.0) 
		points.append(rf_origin + Vector2(px, py))
	
	for i in range(points.size() - 1):
		draw_line(points[i], points[i+1], color, line_width)
		if i % 2 == 0:
			draw_line(points[i], points[i] + Vector2(0, 5), color, 1.0)
			var dist = str(2 + i)
			draw_string(ThemeDB.fallback_font, points[i] + Vector2(-10, -15), dist, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, color)
	
	draw_string(ThemeDB.fallback_font, rf_origin + Vector2(0, 20), "STADIA RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)

	if target_range > 0.1:
		var rng_text = "RNG: " + str(int(target_range)) + "m"
		var rng_pos = center + Vector2(25, -5)
		draw_string(ThemeDB.fallback_font, rng_pos, rng_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		if on_target:
			draw_string(ThemeDB.fallback_font, rng_pos + Vector2(0, -15), "LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.RED)

	# --- 2. Dynamic Accuracy Indicator ---
	var spread_offset = current_spread * 1500.0
	var s_color = color
	var bracket_size = clamp(20.0 - (current_spread * 100.0), 5.0, 20.0)
	var gap = max(spread_offset, 2.0)
	var bracket_thickness = 1.0 if spread_offset > 10.0 else 2.5
	
	# Draw brackets
	for dx in [-1, 1]:
		for dy in [-1, 1]:
			var pos = center + Vector2(dx * gap, dy * gap)
			draw_line(pos, pos + Vector2(dx * -bracket_size, 0), s_color, bracket_thickness)
			draw_line(pos, pos + Vector2(0, dy * -bracket_size), s_color, bracket_thickness)

	# --- 3. Reload Bar ---
	if reload_progress > 0.0:
		var bar_width = 200.0
		var bar_height = 6.0
		var bar_pos = center + Vector2(-bar_width/2.0, 60.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.2, 0.0, 0.0, 0.4))
		draw_rect(Rect2(bar_pos, Vector2(bar_width * (1.0 - reload_progress), bar_height)), Color.RED)
		draw_string(ThemeDB.fallback_font, bar_pos + Vector2(0, -5), "RELOADING", HORIZONTAL_ALIGNMENT_CENTER, bar_width, 12, Color.RED)
	
	# --- 4. Throttle Bar ---
	var t_width = 12.0
	var t_height = 200.0
	var t_pos = Vector2(60.0, (size.y / 2.0) - (t_height / 2.0))
	var zero_line_y = t_pos.y + (t_height * 0.75) 
	
	draw_rect(Rect2(t_pos, Vector2(t_width, t_height)), Color(0.1, 0.1, 0.1, 0.4))
	for i in range(5):
		var ty = t_pos.y + (i * t_height / 4.0)
		draw_line(Vector2(t_pos.x - 5, ty), Vector2(t_pos.x, ty), Color.WHITE, 1.0)
	
	draw_line(Vector2(t_pos.x - 10, zero_line_y), Vector2(t_pos.x + t_width + 10, zero_line_y), Color.WHITE, 2.0)
	
	var speed_offset = (current_speed / 12.0) * (t_height * 0.75)
	if current_speed >= 0:
		draw_rect(Rect2(t_pos.x, zero_line_y - speed_offset, t_width, speed_offset), Color.ORANGE)
	else:
		draw_rect(Rect2(t_pos.x, zero_line_y, t_width, abs(speed_offset)), Color.ORANGE)
		
	var throttle_offset = (current_throttle / 1.0) * (t_height * 0.75)
	if current_throttle >= 0:
		draw_line(Vector2(t_pos.x - 15, zero_line_y - throttle_offset), Vector2(t_pos.x + t_width + 15, zero_line_y - throttle_offset), Color.WHITE, 3.0)
	else:
		throttle_offset = (current_throttle / 0.5) * (t_height * 0.25)
		draw_line(Vector2(t_pos.x - 15, zero_line_y - throttle_offset), Vector2(t_pos.x + t_width + 15, zero_line_y - throttle_offset), Color.WHITE, 3.0)
	
	draw_string(ThemeDB.fallback_font, t_pos + Vector2(-20, -10), "DRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
