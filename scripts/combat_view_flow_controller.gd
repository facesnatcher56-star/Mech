extends Node

signal analog_hud_visibility_changed(is_visible: bool)
signal analog_heartbeat_play_requested()
signal analog_heartbeat_stop_requested()
signal target_dossier_show_requested()
signal target_dossier_hide_requested()
signal targeting_stroke_reset_requested()
signal targeting_drift_changed(multiplier: float)
signal fire_sequence_requested(shot_lock: Dictionary)

var cockpit: Node = null
var combat_view_state: int = 0
var is_transitioning: bool = false
var current_analog_drift_multiplier: float = 1.0

var view_transition_tween: Tween
var aim_camera_session_start: Vector3 = Vector3.ZERO
var aim_camera_session_target: Vector3 = Vector3.ZERO
var aim_camera_chunk_stage: int = 0

# Set via set_runtime_refs() after all controllers are initialized
var _gun_cam: Camera3D = null
var _fire_cam: Camera3D = null
var _cinematic_camera: Camera3D = null
var _player_camera: Camera3D = null
var _analog_targeting: Node = null
var _aim_solution: Node = null
var _enemy_fire_cinematic: Node = null

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", cockpit)
	combat_view_state = int(config.get("combat_view_state", combat_view_state))
	is_transitioning = bool(config.get("is_transitioning", is_transitioning))
	current_analog_drift_multiplier = float(config.get("current_analog_drift_multiplier", current_analog_drift_multiplier))

func set_runtime_refs(refs: Dictionary) -> void:
	_gun_cam = refs.get("gun_cam") as Camera3D
	_fire_cam = refs.get("fire_cam") as Camera3D
	_cinematic_camera = refs.get("cinematic_camera") as Camera3D
	_player_camera = refs.get("player_camera") as Camera3D
	_analog_targeting = refs.get("analog_targeting_controller")
	_aim_solution = refs.get("analog_aim_solution_controller")
	_enemy_fire_cinematic = refs.get("enemy_fire_cinematic_controller")

func sync_plain_gun_camera(guncam_fov: float) -> void:
	if not _gun_cam or not _cinematic_camera:
		return
	_cinematic_camera.global_transform = _gun_cam.global_transform
	_cinematic_camera.fov = guncam_fov

func update_analog_camera_presentation(delta: float, last_ray_result: Dictionary, aim_zoom_blend_speed: float, aim_camera_chunk_jump_amount: float, aim_camera_chunk_settle_speed: float) -> void:
	if _is_enemy_fire_cinematic_active():
		return
	if not _gun_cam or not _cinematic_camera:
		return

	var start_pos = aim_camera_session_start if aim_camera_session_start != Vector3.ZERO else _gun_cam.global_position
	var target_pos = start_pos
	var target_point = _get_analog_target_point(last_ray_result)
	var camera_target_point = aim_camera_session_target if aim_camera_session_target != Vector3.ZERO else _get_analog_camera_target_point(last_ray_result)
	var zoom_stage := 1
	if _aim_solution:
		zoom_stage = _aim_solution.get_zoom_stage()

	if camera_target_point != Vector3.ZERO:
		var progress = clampf(float(zoom_stage) / 5.0, 0.0, 1.0)
		target_pos = start_pos.lerp(camera_target_point, progress)

	if aim_camera_chunk_stage != zoom_stage:
		aim_camera_chunk_stage = zoom_stage
		_cinematic_camera.global_position = _cinematic_camera.global_position.lerp(target_pos, aim_camera_chunk_jump_amount)

	_cinematic_camera.global_position = _cinematic_camera.global_position.lerp(target_pos, clampf(aim_camera_chunk_settle_speed * delta, 0.0, 1.0))

	if _aim_solution:
		_cinematic_camera.fov = lerpf(_cinematic_camera.fov, _aim_solution.get_stage_fov(), aim_zoom_blend_speed * delta)
		current_analog_drift_multiplier = lerpf(current_analog_drift_multiplier, _aim_solution.get_stage_drift_multiplier(), aim_zoom_blend_speed * delta)
		targeting_drift_changed.emit(current_analog_drift_multiplier)

	if target_point != Vector3.ZERO:
		var drifted_point = _get_drifted_analog_target_point(target_point, delta, last_ray_result)
		_cinematic_camera.look_at(drifted_point, Vector3.UP)

func begin_aim_flow(is_reloading: bool, normal_view_state: int, gun_cam_state: int, analog_aim_state: int, transition_time: float, guncam_fov: float) -> void:
	if is_reloading or is_transitioning or combat_view_state != normal_view_state:
		return
	if not _player_camera or not _cinematic_camera or not _gun_cam:
		return

	is_transitioning = true
	combat_view_state = gun_cam_state
	analog_hud_visibility_changed.emit(false)
	_kill_transition()

	var start_transform = _player_camera.global_transform
	var start_fov = _player_camera.fov
	_cinematic_camera.global_transform = start_transform
	_cinematic_camera.fov = start_fov
	_cinematic_camera.near = _player_camera.near
	_cinematic_camera.far = _player_camera.far
	_player_camera.current = false
	_cinematic_camera.current = true

	view_transition_tween = cockpit.create_tween()
	view_transition_tween.tween_method(func(t):
		_cinematic_camera.global_transform = start_transform.interpolate_with(_gun_cam.global_transform, t)
		_cinematic_camera.fov = lerpf(start_fov, guncam_fov, t)
	, 0.0, 1.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	view_transition_tween.finished.connect(func():
		is_transitioning = false
		enter_analog_aim_view(analog_aim_state)
	)

func enter_analog_aim_view(analog_aim_state: int, last_ray_result: Dictionary = {}) -> void:
	if _is_enemy_fire_cinematic_active():
		return
	combat_view_state = analog_aim_state
	if _player_camera:
		_player_camera.current = false
	if _cinematic_camera:
		_cinematic_camera.current = true
	analog_hud_visibility_changed.emit(true)
	analog_heartbeat_play_requested.emit()
	target_dossier_show_requested.emit()
	aim_camera_session_start = _gun_cam.global_position if _gun_cam else (_cinematic_camera.global_position if _cinematic_camera else Vector3.ZERO)
	aim_camera_session_target = _get_analog_camera_target_point(last_ray_result)
	aim_camera_chunk_stage = 0
	if _aim_solution:
		_aim_solution.reset_for_aim()
		current_analog_drift_multiplier = _aim_solution.get_stage_drift_multiplier()
	targeting_drift_changed.emit(current_analog_drift_multiplier)
	targeting_stroke_reset_requested.emit()

func resume_analog_aim_view(analog_aim_state: int, last_ray_result: Dictionary = {}) -> void:
	if _is_enemy_fire_cinematic_active():
		return
	combat_view_state = analog_aim_state
	if _player_camera:
		_player_camera.current = false
	if _cinematic_camera:
		_cinematic_camera.current = true
	analog_hud_visibility_changed.emit(true)
	analog_heartbeat_play_requested.emit()
	target_dossier_show_requested.emit()
	aim_camera_session_start = _cinematic_camera.global_position if _cinematic_camera else Vector3.ZERO
	aim_camera_session_target = _get_analog_camera_target_point(last_ray_result)
	aim_camera_chunk_stage = 0
	if _aim_solution:
		current_analog_drift_multiplier = _aim_solution.get_stage_drift_multiplier()
	targeting_drift_changed.emit(current_analog_drift_multiplier)

func return_to_fire_cam_then_fire(shot_lock: Dictionary, firing_state: int, return_time: float) -> void:
	if not _fire_cam or not _cinematic_camera:
		return

	is_transitioning = true
	combat_view_state = firing_state
	analog_hud_visibility_changed.emit(false)
	analog_heartbeat_stop_requested.emit()
	_kill_transition()

	var start_transform = _cinematic_camera.global_transform
	var start_fov = _cinematic_camera.fov
	view_transition_tween = cockpit.create_tween()
	view_transition_tween.tween_method(func(t):
		_cinematic_camera.global_transform = start_transform.interpolate_with(_fire_cam.global_transform, t)
		_cinematic_camera.fov = lerpf(start_fov, _fire_cam.fov, t)
	, 0.0, 1.0, return_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	view_transition_tween.finished.connect(func():
		is_transitioning = false
		begin_fire_sequence_from_lock(shot_lock, firing_state)
	)

func begin_fire_sequence_from_lock(shot_lock: Dictionary, firing_state: int) -> void:
	combat_view_state = firing_state
	analog_hud_visibility_changed.emit(false)
	analog_heartbeat_stop_requested.emit()
	fire_sequence_requested.emit(shot_lock)

func reset_to_normal(normal_view_state: int) -> void:
	_kill_transition()
	combat_view_state = normal_view_state
	is_transitioning = false
	analog_hud_visibility_changed.emit(false)
	analog_heartbeat_stop_requested.emit()
	target_dossier_hide_requested.emit()

func _kill_transition() -> void:
	if view_transition_tween and view_transition_tween.is_running():
		view_transition_tween.kill()

func _get_analog_target_point(last_ray_result: Dictionary) -> Vector3:
	if _analog_targeting:
		return _analog_targeting.get_target_point(last_ray_result)
	return Vector3.ZERO

func _get_analog_camera_target_point(last_ray_result: Dictionary) -> Vector3:
	if _analog_targeting:
		return _analog_targeting.get_camera_target_point(last_ray_result)
	return _get_analog_target_point(last_ray_result)

func _get_drifted_analog_target_point(target_point: Vector3, delta: float, last_ray_result: Dictionary) -> Vector3:
	var quality := 0.0
	var stroke_speed_multiplier := 1.0
	if _aim_solution:
		quality = _aim_solution.get_quality()
		stroke_speed_multiplier = _aim_solution.get_stage_stroke_speed_multiplier()
	if _analog_targeting:
		return _analog_targeting.get_drifted_target_point(target_point, delta, quality, stroke_speed_multiplier)
	return target_point

func _is_enemy_fire_cinematic_active() -> bool:
	if _enemy_fire_cinematic and _enemy_fire_cinematic.has_method("is_active"):
		return _enemy_fire_cinematic.is_active()
	return false
