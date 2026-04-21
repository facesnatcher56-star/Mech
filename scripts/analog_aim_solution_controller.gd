extends Node

var aim_settle_speed: float = 0.045
var post_fire_solution_penalty: float = 0.65
var post_fire_recovery_time: float = 0.45
var accuracy_slowdown_power: float = 3.0
var short_range_max: float = 45.0
var medium_range_max: float = 110.0
var minimum_max_hit_chance: float = 0.70
var short_max_hit_chance: float = 0.92
var medium_max_hit_chance: float = 0.78
var long_max_hit_chance: float = 0.70
var stage_thresholds := [0.0, 0.20, 0.40, 0.60, 0.80]
var camera_stage_times := [0.0, 0.35, 0.35, 0.35, 0.35]
var stage_fovs := [44.0, 38.0, 32.0, 26.0, 20.0]
var drift_multipliers := [3.20, 2.40, 1.80, 1.30, 1.0]
var stroke_speed_multipliers := [1.0, 1.0, 1.0, 1.0, 1.0]

var aim_settle: float = 0.09
var hit_chance: float = 0.0
var fire_recovery: float = 0.0
var zoom_stage: int = 1
var solution_stage: int = 1
var camera_stage_elapsed: float = 0.0
var stage_bump_timer: float = 0.0
var smooth_max_accuracy: float = 0.7

func configure(config: Dictionary) -> void:
	aim_settle_speed = float(config.get("aim_settle_speed", aim_settle_speed))
	post_fire_solution_penalty = float(config.get("post_fire_solution_penalty", post_fire_solution_penalty))
	post_fire_recovery_time = float(config.get("post_fire_recovery_time", post_fire_recovery_time))
	accuracy_slowdown_power = float(config.get("accuracy_slowdown_power", accuracy_slowdown_power))
	short_range_max = float(config.get("short_range_max", short_range_max))
	medium_range_max = float(config.get("medium_range_max", medium_range_max))
	minimum_max_hit_chance = float(config.get("minimum_max_hit_chance", minimum_max_hit_chance))
	short_max_hit_chance = float(config.get("short_max_hit_chance", short_max_hit_chance))
	medium_max_hit_chance = float(config.get("medium_max_hit_chance", medium_max_hit_chance))
	long_max_hit_chance = float(config.get("long_max_hit_chance", long_max_hit_chance))
	stage_thresholds = config.get("stage_thresholds", stage_thresholds)
	camera_stage_times = config.get("camera_stage_times", camera_stage_times)
	stage_fovs = config.get("stage_fovs", stage_fovs)
	drift_multipliers = config.get("drift_multipliers", drift_multipliers)
	stroke_speed_multipliers = config.get("stroke_speed_multipliers", stroke_speed_multipliers)

func reset_for_aim() -> void:
	aim_settle = 0.09
	hit_chance = 0.0
	fire_recovery = 0.0
	zoom_stage = 1
	solution_stage = 1
	camera_stage_elapsed = 0.0
	stage_bump_timer = 0.0
	smooth_max_accuracy = 0.7
	_update_solution_stage()

func update(delta: float, range_m: float) -> Dictionary:
	if fire_recovery > 0.0:
		fire_recovery = max(0.0, fire_recovery - delta)

	var current_curve = 1.0 - pow(1.0 - aim_settle, accuracy_slowdown_power)
	var effective_speed = aim_settle_speed
	if current_curve > 0.5:
		var factor = clampf(remap(current_curve, 0.5, 1.0, 1.0, 0.0), 0.0, 1.0)
		effective_speed *= (0.05 + 0.95 * pow(factor, 2.0))

	aim_settle = min(1.0, aim_settle + effective_speed * delta)
	_update_solution_stage()
	_update_camera_stage(delta)
	if stage_bump_timer > 0.0:
		stage_bump_timer = max(0.0, stage_bump_timer - delta)

	var max_accuracy = _get_max_accuracy_for_range(range_m)
	smooth_max_accuracy = lerpf(smooth_max_accuracy, max_accuracy, delta * 2.5)
	hit_chance = _calculate_displayed_hit_chance(smooth_max_accuracy)
	return get_display_state(range_m)

func disrupt_after_fire(range_m: float) -> Dictionary:
	aim_settle = max(0.09, aim_settle - post_fire_solution_penalty)
	_update_solution_stage()
	fire_recovery = post_fire_recovery_time
	var max_accuracy = _get_max_accuracy_for_range(range_m)
	hit_chance = _calculate_displayed_hit_chance(max_accuracy)
	return get_display_state(range_m)

func get_display_state(range_m: float) -> Dictionary:
	return {
		"hit_chance": hit_chance,
		"range_band": get_range_band(range_m),
		"quality": get_quality(),
		"zoom_stage": zoom_stage,
		"solution_stage": solution_stage
	}

func get_quality() -> float:
	return clampf(aim_settle, 0.0, 1.0)

func get_zoom_stage() -> int:
	return zoom_stage

func get_solution_stage() -> int:
	return solution_stage

func get_stage_fov() -> float:
	return _array_value(stage_fovs, zoom_stage, 44.0)

func get_stage_drift_multiplier() -> float:
	return _array_value(drift_multipliers, solution_stage, 1.0)

func get_stage_stroke_speed_multiplier() -> float:
	return _array_value(stroke_speed_multipliers, solution_stage, 1.0)

func get_range_band(range_m: float) -> String:
	if range_m <= short_range_max:
		return "SHORT"
	if range_m <= medium_range_max:
		return "MEDIUM"
	return "LONG"

func _get_max_accuracy_for_range(range_m: float) -> float:
	var range_max := long_max_hit_chance
	match get_range_band(range_m):
		"SHORT":
			range_max = short_max_hit_chance
		"MEDIUM":
			range_max = medium_max_hit_chance
	return max(range_max, minimum_max_hit_chance)

func _calculate_displayed_hit_chance(max_accuracy: float) -> float:
	var settle_curve = 1.0 - pow(1.0 - get_quality(), accuracy_slowdown_power)
	return max_accuracy * settle_curve

func _update_solution_stage() -> void:
	var next_stage = 1
	for i in range(stage_thresholds.size()):
		if aim_settle >= float(stage_thresholds[i]):
			next_stage = i + 1
	next_stage = clampi(next_stage, 1, 5)
	if next_stage != solution_stage:
		solution_stage = next_stage
		stage_bump_timer = 0.12

func _update_camera_stage(delta: float) -> void:
	if zoom_stage >= 5:
		return
	camera_stage_elapsed += delta
	var stage_interval = max(0.01, _get_camera_stage_time(zoom_stage))
	while camera_stage_elapsed >= stage_interval and zoom_stage < 5:
		camera_stage_elapsed -= stage_interval
		zoom_stage += 1
		stage_interval = max(0.01, _get_camera_stage_time(zoom_stage))

func _get_camera_stage_time(stage: int) -> float:
	return _array_value(camera_stage_times, stage, 0.0)

func _array_value(values: Array, one_based_stage: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index = clampi(one_based_stage - 1, 0, values.size() - 1)
	return float(values[index])

func save_state() -> Dictionary:
	return {
		"aim_settle": aim_settle,
		"solution_stage": solution_stage,
		"zoom_stage": zoom_stage,
		"camera_stage_elapsed": camera_stage_elapsed,
		"fire_recovery": fire_recovery,
	}

func restore_state(state: Dictionary) -> void:
	aim_settle = float(state.get("aim_settle", 0.09))
	solution_stage = int(state.get("solution_stage", 1))
	zoom_stage = int(state.get("zoom_stage", 1))
	camera_stage_elapsed = float(state.get("camera_stage_elapsed", 0.0))
	fire_recovery = float(state.get("fire_recovery", 0.0))
	_update_solution_stage()
