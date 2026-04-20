extends Node

var cockpit: Node = null
var combat_view_state: int = 0
var is_transitioning: bool = false
var current_analog_drift_multiplier: float = 1.0

var view_transition_tween: Tween
var aim_camera_session_start: Vector3 = Vector3.ZERO
var aim_camera_session_target: Vector3 = Vector3.ZERO
var aim_camera_chunk_stage: int = 0

var get_gun_camera_callable: Callable
var get_fire_camera_callable: Callable
var get_analog_target_point_callable: Callable
var get_analog_camera_target_point_callable: Callable
var get_drifted_analog_target_point_callable: Callable
var set_analog_hud_visible_callable: Callable
var play_analog_heartbeat_callable: Callable
var stop_analog_heartbeat_callable: Callable
var show_target_dossier_callable: Callable
var hide_target_dossier_callable: Callable
var reset_aim_solution_callable: Callable
var reset_targeting_stroke_callable: Callable
var set_targeting_drift_callable: Callable
var begin_fire_sequence_callable: Callable
var state_changed_callable: Callable

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", cockpit)
	combat_view_state = int(config.get("combat_view_state", combat_view_state))
	is_transitioning = bool(config.get("is_transitioning", is_transitioning))
	current_analog_drift_multiplier = float(config.get("current_analog_drift_multiplier", current_analog_drift_multiplier))
	get_gun_camera_callable = config.get("get_gun_camera_callable", Callable())
	get_fire_camera_callable = config.get("get_fire_camera_callable", Callable())
	get_analog_target_point_callable = config.get("get_analog_target_point_callable", Callable())
	get_analog_camera_target_point_callable = config.get("get_analog_camera_target_point_callable", Callable())
	get_drifted_analog_target_point_callable = config.get("get_drifted_analog_target_point_callable", Callable())
	set_analog_hud_visible_callable = config.get("set_analog_hud_visible_callable", Callable())
	play_analog_heartbeat_callable = config.get("play_analog_heartbeat_callable", Callable())
	stop_analog_heartbeat_callable = config.get("stop_analog_heartbeat_callable", Callable())
	show_target_dossier_callable = config.get("show_target_dossier_callable", Callable())
	hide_target_dossier_callable = config.get("hide_target_dossier_callable", Callable())
	reset_aim_solution_callable = config.get("reset_aim_solution_callable", Callable())
	reset_targeting_stroke_callable = config.get("reset_targeting_stroke_callable", Callable())
	set_targeting_drift_callable = config.get("set_targeting_drift_callable", Callable())
	begin_fire_sequence_callable = config.get("begin_fire_sequence_callable", Callable())
	state_changed_callable = config.get("state_changed_callable", Callable())

func get_state() -> Dictionary:
	return {
		"combat_view_state": combat_view_state,
		"is_transitioning": is_transitioning,
		"current_analog_drift_multiplier": current_analog_drift_multiplier
	}

func sync_plain_gun_camera(cinematic_camera: Camera3D, guncam_fov: float) -> void:
	var gun_camera = _get_gun_camera()
	if not gun_camera or not cinematic_camera:
		return
	cinematic_camera.global_transform = gun_camera.global_transform
	cinematic_camera.fov = guncam_fov

func update_analog_camera_presentation(delta: float, cinematic_camera: Camera3D, aim_solution_controller: Node, aim_zoom_blend_speed: float, aim_camera_chunk_jump_amount: float, aim_camera_chunk_settle_speed: float) -> void:
	var gun_camera = _get_gun_camera()
	if not gun_camera or not cinematic_camera:
		return

	var start_pos = aim_camera_session_start if aim_camera_session_start != Vector3.ZERO else gun_camera.global_position
	var target_pos = start_pos
	var target_point = _get_analog_target_point()
	var camera_target_point = aim_camera_session_target if aim_camera_session_target != Vector3.ZERO else _get_analog_camera_target_point()
	var progress = 0.0
	var zoom_stage := 1
	if aim_solution_controller:
		zoom_stage = aim_solution_controller.get_zoom_stage()

	if camera_target_point != Vector3.ZERO:
		progress = clampf(float(zoom_stage) / 5.0, 0.0, 1.0)
		target_pos = start_pos.lerp(camera_target_point, progress)

	if aim_camera_chunk_stage != zoom_stage:
		aim_camera_chunk_stage = zoom_stage
		cinematic_camera.global_position = cinematic_camera.global_position.lerp(target_pos, aim_camera_chunk_jump_amount)

	cinematic_camera.global_position = cinematic_camera.global_position.lerp(target_pos, clampf(aim_camera_chunk_settle_speed * delta, 0.0, 1.0))

	if aim_solution_controller:
		cinematic_camera.fov = lerpf(cinematic_camera.fov, aim_solution_controller.get_stage_fov(), aim_zoom_blend_speed * delta)
		current_analog_drift_multiplier = lerpf(current_analog_drift_multiplier, aim_solution_controller.get_stage_drift_multiplier(), aim_zoom_blend_speed * delta)
		_set_targeting_drift(current_analog_drift_multiplier)
		_emit_state_changed()

	if target_point != Vector3.ZERO:
		var drifted_point = _get_drifted_analog_target_point(target_point, delta)
		cinematic_camera.look_at(drifted_point, Vector3.UP)

func begin_aim_flow(is_reloading: bool, camera: Camera3D, cinematic_camera: Camera3D, normal_view_state: int, gun_cam_state: int, analog_aim_state: int, transition_time: float, guncam_fov: float) -> void:
	if is_reloading or is_transitioning or combat_view_state != normal_view_state:
		return
	if not camera or not cinematic_camera:
		return
	var gun_camera = _get_gun_camera()
	if not gun_camera:
		return

	is_transitioning = true
	combat_view_state = gun_cam_state
	_set_analog_hud_visible(false)
	_kill_transition()

	var start_transform = camera.global_transform
	var start_fov = camera.fov
	cinematic_camera.global_transform = start_transform
	cinematic_camera.fov = start_fov
	cinematic_camera.near = camera.near
	cinematic_camera.far = camera.far
	camera.current = false
	cinematic_camera.current = true
	_emit_state_changed()

	view_transition_tween = cockpit.create_tween()
	view_transition_tween.tween_method(func(t):
		cinematic_camera.global_transform = start_transform.interpolate_with(gun_camera.global_transform, t)
		cinematic_camera.fov = lerpf(start_fov, guncam_fov, t)
	, 0.0, 1.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	view_transition_tween.finished.connect(func():
		is_transitioning = false
		enter_analog_aim_view(camera, cinematic_camera, analog_aim_state)
	)

func enter_analog_aim_view(camera: Camera3D, cinematic_camera: Camera3D, analog_aim_state: int) -> void:
	combat_view_state = analog_aim_state
	if camera:
		camera.current = false
	if cinematic_camera:
		cinematic_camera.current = true
	_set_analog_hud_visible(true)
	_play_analog_heartbeat()
	_show_target_dossier()
	var gun_camera = _get_gun_camera()
	aim_camera_session_start = gun_camera.global_position if gun_camera else cinematic_camera.global_position
	aim_camera_session_target = _get_analog_camera_target_point()
	aim_camera_chunk_stage = 0
	current_analog_drift_multiplier = _reset_aim_solution()
	_set_targeting_drift(current_analog_drift_multiplier)
	_reset_targeting_stroke()
	_emit_state_changed()

func return_to_fire_cam_then_fire(shot_lock: Dictionary, cinematic_camera: Camera3D, firing_state: int, return_time: float) -> void:
	var fire_camera = _get_fire_camera()
	if not fire_camera or not cinematic_camera:
		return

	is_transitioning = true
	combat_view_state = firing_state
	_set_analog_hud_visible(false)
	_stop_analog_heartbeat()
	_kill_transition()
	_emit_state_changed()

	var start_transform = cinematic_camera.global_transform
	var start_fov = cinematic_camera.fov
	view_transition_tween = cockpit.create_tween()
	view_transition_tween.tween_method(func(t):
		cinematic_camera.global_transform = start_transform.interpolate_with(fire_camera.global_transform, t)
		cinematic_camera.fov = lerpf(start_fov, fire_camera.fov, t)
	, 0.0, 1.0, return_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	view_transition_tween.finished.connect(func():
		is_transitioning = false
		begin_fire_sequence_from_lock(shot_lock, firing_state)
	)

func begin_fire_sequence_from_lock(shot_lock: Dictionary, firing_state: int) -> void:
	combat_view_state = firing_state
	_set_analog_hud_visible(false)
	_stop_analog_heartbeat()
	_emit_state_changed()
	if begin_fire_sequence_callable.is_valid():
		begin_fire_sequence_callable.call(shot_lock)

func reset_to_normal(normal_view_state: int) -> void:
	combat_view_state = normal_view_state
	is_transitioning = false
	_set_analog_hud_visible(false)
	_stop_analog_heartbeat()
	_hide_target_dossier()
	_emit_state_changed()

func _kill_transition() -> void:
	if view_transition_tween and view_transition_tween.is_running():
		view_transition_tween.kill()

func _emit_state_changed() -> void:
	if state_changed_callable.is_valid():
		state_changed_callable.call(get_state())

func _get_gun_camera() -> Camera3D:
	if get_gun_camera_callable.is_valid():
		return get_gun_camera_callable.call()
	return null

func _get_fire_camera() -> Camera3D:
	if get_fire_camera_callable.is_valid():
		return get_fire_camera_callable.call()
	return null

func _get_analog_target_point() -> Vector3:
	if get_analog_target_point_callable.is_valid():
		return get_analog_target_point_callable.call()
	return Vector3.ZERO

func _get_analog_camera_target_point() -> Vector3:
	if get_analog_camera_target_point_callable.is_valid():
		return get_analog_camera_target_point_callable.call()
	return Vector3.ZERO

func _get_drifted_analog_target_point(target_point: Vector3, delta: float) -> Vector3:
	if get_drifted_analog_target_point_callable.is_valid():
		return get_drifted_analog_target_point_callable.call(target_point, delta)
	return target_point

func _set_analog_hud_visible(is_visible: bool) -> void:
	if set_analog_hud_visible_callable.is_valid():
		set_analog_hud_visible_callable.call(is_visible)

func _play_analog_heartbeat() -> void:
	if play_analog_heartbeat_callable.is_valid():
		play_analog_heartbeat_callable.call()

func _stop_analog_heartbeat() -> void:
	if stop_analog_heartbeat_callable.is_valid():
		stop_analog_heartbeat_callable.call()

func _show_target_dossier() -> void:
	if show_target_dossier_callable.is_valid():
		show_target_dossier_callable.call()

func _hide_target_dossier() -> void:
	if hide_target_dossier_callable.is_valid():
		hide_target_dossier_callable.call()

func _reset_aim_solution() -> float:
	if reset_aim_solution_callable.is_valid():
		return float(reset_aim_solution_callable.call())
	return current_analog_drift_multiplier

func _reset_targeting_stroke() -> void:
	if reset_targeting_stroke_callable.is_valid():
		reset_targeting_stroke_callable.call()

func _set_targeting_drift(multiplier: float) -> void:
	if set_targeting_drift_callable.is_valid():
		set_targeting_drift_callable.call(multiplier)
