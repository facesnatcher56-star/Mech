extends Node

const _HIT_STREAM = preload("res://assets/Sounds/hittest.wav")

signal reload_started()

var cockpit: Node3D = null
var player_damage_model: Node = null
var projectile_cinematic_controller: Node = null
var dossier_presenter: Node = null

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", cockpit)
	refresh_runtime_refs(config)

func refresh_runtime_refs(config: Dictionary) -> void:
	player_damage_model = config.get("player_damage_model", player_damage_model)
	projectile_cinematic_controller = config.get("projectile_cinematic_controller", projectile_cinematic_controller)
	dossier_presenter = config.get("dossier_presenter", dossier_presenter)

func apply_hit(camera: Camera3D, current_is_dead: bool, region: String = "BODY") -> bool:
	if current_is_dead:
		return true
	if not player_damage_model or not player_damage_model.has_method("apply_hit"):
		return current_is_dead

	var damage_result: Dictionary = player_damage_model.apply_hit(region)
	if not bool(damage_result.get("applied", false)):
		return bool(damage_result.get("destroyed", current_is_dead))

	var is_dead = bool(damage_result.get("destroyed", false))
	_start_reload()
	_show_player_hit(damage_result)
	_abort_outgoing_cinematic()
	_play_hit_shake(camera)
	_play_hit_sound()

	if is_dead:
		_play_player_death()

	return is_dead

func _start_reload() -> void:
	reload_started.emit()

func _show_player_hit(damage_result: Dictionary) -> void:
	if not dossier_presenter or not dossier_presenter.has_method("show_player_hit"):
		return
	var snapshot = damage_result.get("snapshot", {})
	if snapshot.is_empty() and player_damage_model and player_damage_model.has_method("get_hp_snapshot"):
		snapshot = player_damage_model.get_hp_snapshot()
	
	var is_crit := bool(damage_result.get("is_crit", false))
	var part_key := str(damage_result.get("part_key", "torso"))
	var damage := int(damage_result.get("damage", 0))
	
	var line := "HIT! -%d" % damage
	if is_crit:
		line = "CRIT! -%d" % damage
		part_key = "torso" # Flash torso for crit hits

	dossier_presenter.show_player_hit(part_key, snapshot, line)

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

func _play_hit_sound() -> void:
	if not cockpit:
		return
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = _HIT_STREAM
	cockpit.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _play_player_death() -> void:
	if not cockpit:
		return
	var death_tween = cockpit.create_tween()
	death_tween.set_parallel(true)
	death_tween.tween_property(cockpit, "rotation_degrees:z", 85.0, 2.0).set_trans(Tween.TRANS_SINE)
	death_tween.tween_property(cockpit, "position:y", -2.0, 2.0)
