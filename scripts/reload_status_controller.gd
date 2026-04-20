extends Node

var max_spread: float = 0.1
var reload_duration: float = 2.5
var spread_recovery_speed: float = 0.5

var is_reloading: bool = false
var reload_timer: float = 0.0
var current_spread: float = 0.0

func configure(config: Dictionary) -> void:
	max_spread = float(config.get("max_spread", max_spread))
	reload_duration = float(config.get("reload_duration", reload_duration))
	spread_recovery_speed = float(config.get("spread_recovery_speed", spread_recovery_speed))
	current_spread = float(config.get("current_spread", current_spread))
	is_reloading = bool(config.get("is_reloading", is_reloading))
	reload_timer = float(config.get("reload_timer", reload_timer))

func start_reload() -> void:
	is_reloading = true
	reload_timer = 0.0
	current_spread = max_spread

func update(delta: float) -> Dictionary:
	var reload_progress = 0.0

	if is_reloading:
		reload_timer += delta
		current_spread = max_spread
		reload_progress = 1.0 - (reload_timer / reload_duration)
		if reload_timer >= reload_duration:
			is_reloading = false
	else:
		reload_progress = 1.0
		current_spread = lerpf(current_spread, 0.0, delta * spread_recovery_speed)

	return get_state(reload_progress)

func get_state(reload_progress: float = 1.0) -> Dictionary:
	return {
		"is_reloading": is_reloading,
		"reload_timer": reload_timer,
		"current_spread": current_spread,
		"reload_progress": reload_progress
	}
