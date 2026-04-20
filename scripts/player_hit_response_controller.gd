extends Node

var cockpit: Node3D = null
var player_damage_model: Node = null
var projectile_cinematic_controller: Node = null
var dossier_presenter: Node = null

var start_reload_callable: Callable
var get_hp_snapshot_callable: Callable

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", cockpit)
	start_reload_callable = config.get("start_reload_callable", Callable())
	get_hp_snapshot_callable = config.get("get_hp_snapshot_callable", Callable())
	refresh_runtime_refs(config)

func refresh_runtime_refs(config: Dictionary) -> void:
	player_damage_model = config.get("player_damage_model", player_damage_model)
	projectile_cinematic_controller = config.get("projectile_cinematic_controller", projectile_cinematic_controller)
	dossier_presenter = config.get("dossier_presenter", dossier_presenter)

func apply_hit(camera: Camera3D, current_is_dead: bool) -> bool:
	if current_is_dead:
		return true
	if not player_damage_model or not player_damage_model.has_method("apply_hit"):
		return current_is_dead

	var damage_result: Dictionary = player_damage_model.apply_hit()
	if not bool(damage_result.get("applied", false)):
		return bool(damage_result.get("destroyed", current_is_dead))

	var is_dead = bool(damage_result.get("destroyed", false))
	_start_reload()
	_show_player_hit(damage_result)
	_abort_outgoing_cinematic()
	_play_hit_shake(camera)

	if is_dead:
		_play_player_death()

	return is_dead

func _start_reload() -> void:
	if start_reload_callable.is_valid():
		start_reload_callable.call()

func _show_player_hit(damage_result: Dictionary) -> void:
	if not dossier_presenter or not dossier_presenter.has_method("show_player_hit"):
		return
	var snapshot = _get_hp_snapshot()
	dossier_presenter.show_player_hit(str(damage_result.get("part_key", "torso")), damage_result.get("snapshot", snapshot))

func _get_hp_snapshot() -> Dictionary:
	if get_hp_snapshot_callable.is_valid():
		return get_hp_snapshot_callable.call()
	return {}

func _abort_outgoing_cinematic() -> void:
	if projectile_cinematic_controller and projectile_cinematic_controller.has_method("is_active"):
		if projectile_cinematic_controller.is_active():
			projectile_cinematic_controller.end()

func _play_hit_shake(camera: Camera3D) -> void:
	if not cockpit or not camera:
		return
	for i in range(10):
		var shake_tween = cockpit.create_tween()
		shake_tween.tween_property(camera, "h_offset", randf_range(-0.5, 0.5), 0.03)
		shake_tween.tween_property(camera, "v_offset", randf_range(-0.5, 0.5), 0.03)
	var reset_tween = cockpit.create_tween()
	reset_tween.tween_property(camera, "h_offset", 0.0, 0.05).set_delay(0.3)
	reset_tween.tween_property(camera, "v_offset", 0.0, 0.05).set_delay(0.3)

func _play_player_death() -> void:
	if not cockpit:
		return
	var death_tween = cockpit.create_tween()
	death_tween.tween_property(cockpit, "rotation_degrees:z", 85.0, 2.0).set_trans(Tween.TRANS_SINE)
	death_tween.tween_property(cockpit, "position:y", -2.0, 2.0).set_parallel(true)
