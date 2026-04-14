extends Control

var current_spread: float = 0.0
var current_throttle: float = 0.0
var current_speed_ratio: float = 0.0

func _draw():
	var center = size / 2
	
	# 1. Accuracy Circle (Ring of Red)
	var base_radius = 20.0
	var spread_multiplier = 200.0
	var ring_radius = base_radius + (current_spread * spread_multiplier)
	draw_arc(center, ring_radius, 0, TAU, 64, Color(1, 0, 0, 0.6), 2.0, true)
	
	# Fixed inner crosshair
	draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color.RED, 2.0)
	draw_line(center + Vector2(0, -10), center + Vector2(0, 10), Color.RED, 2.0)
	
	# 2. Throttle Bar (Left Side)
	var bar_width = 15
	var bar_height = 240
	var bar_pos = Vector2(60, center.y - bar_height / 2)
	
	# Background bar
	draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.1, 0.1, 0.1, 0.7))
	
	# Zero/Idle Line (75% down the bar because Forward is 1.0 and Reverse is 0.5)
	var zero_y = bar_pos.y + (bar_height * 0.66)
	draw_line(Vector2(bar_pos.x - 5, zero_y), Vector2(bar_pos.x + bar_width + 5, zero_y), Color.GRAY, 2.0)
	
	# Actual Speed Fill (Orange/Red)
	var speed_px = 0.0
	if current_speed_ratio >= 0:
		speed_px = current_speed_ratio * (bar_height * 0.66)
	else:
		speed_px = current_speed_ratio * (bar_height * 0.33)
	
	var fill_rect = Rect2(bar_pos.x, zero_y, bar_width, -speed_px)
	draw_rect(fill_rect.abs(), Color(1, 0.4, 0, 0.8))
	
	# Target Throttle Marker (Bright White)
	var throttle_px = 0.0
	if current_throttle >= 0:
		throttle_px = current_throttle * (bar_height * 0.66)
	else:
		throttle_px = current_throttle * (bar_height * 0.33)
	
	var marker_y = zero_y - throttle_px
	draw_line(Vector2(bar_pos.x - 8, marker_y), Vector2(bar_pos.x + bar_width + 8, marker_y), Color.WHITE, 3.0)

func update_reticle(spread: float, throttle: float, speed_ratio: float):
	current_spread = spread
	current_throttle = throttle
	current_speed_ratio = speed_ratio
	queue_redraw()
