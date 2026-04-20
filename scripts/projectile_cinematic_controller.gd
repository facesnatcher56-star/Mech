extends Node

signal shot_missed(hit_pos: Vector3)
signal cinematic_ended()

var cockpit: Node3D = null
var cinematic_camera: Camera3D = null
var player_camera: Camera3D = null
var side_cam_mortar_sound: AudioStreamPlayer = null
var analog_targeting_controller: Node = null

var firecam_duration: float = 0.5
var firecam_fov: float = 75.0
var side_cam_left_group: String = "side_cam_left"
var side_cam_right_group: String = "side_cam_right"
var side_camera_left_local_offset: Vector3 = Vector3(8.5, 0.5, 12.0)
var side_camera_right_local_offset: Vector3 = Vector3(-8.5, 0.5, 12.0)
var side_camera_trigger_distance: float = 40.0
var side_camera_fov: float = 60.0
var side_camera_time_scale: float = 0.05
var side_camera_look_at_height_bias: float = 0.0
var side_camera_position_blend: float = 1.0
var side_camera_linger_duration: float = 1.5
var travel_fast_forward: float = 3.5

var active_shell: Node3D = null
var phase: int = 0 # 0 = off, 1 = fire cam, 2 = side track, 3 = linger
var target_hit_point: Vector3 = Vector3.ZERO
var shot_muzzle_pos: Vector3 = Vector3.ZERO
var timer: float = 0.0
var has_missed_shot: bool = false
var shot_resolved: bool = false
var shot_will_hit_enemy: bool = false
var side_camera_anchor: Node3D = null
var side_camera_active: bool = false

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", null) as Node3D
	cinematic_camera = config.get("cinematic_camera", null) as Camera3D
	player_camera = config.get("player_camera", null) as Camera3D
	side_cam_mortar_sound = config.get("side_cam_mortar_sound", null) as AudioStreamPlayer
	analog_targeting_controller = config.get("analog_targeting_controller", analog_targeting_controller)
	firecam_duration = float(config.get("firecam_duration", firecam_duration))
	firecam_fov = float(config.get("firecam_fov", firecam_fov))
	side_cam_left_group = str(config.get("side_cam_left_group", side_cam_left_group))
	side_cam_right_group = str(config.get("side_cam_right_group", side_cam_right_group))
	side_camera_left_local_offset = config.get("side_camera_left_local_offset", side_camera_left_local_offset)
	side_camera_right_local_offset = config.get("side_camera_right_local_offset", side_camera_right_local_offset)
	side_camera_trigger_distance = float(config.get("side_camera_trigger_distance", side_camera_trigger_distance))
	side_camera_fov = float(config.get("side_camera_fov", side_camera_fov))
	side_camera_time_scale = float(config.get("side_camera_time_scale", side_camera_time_scale))
	side_camera_look_at_height_bias = float(config.get("side_camera_look_at_height_bias", side_camera_look_at_height_bias))
	side_camera_position_blend = float(config.get("side_camera_position_blend", side_camera_position_blend))
	side_camera_linger_duration = float(config.get("side_camera_linger_duration", side_camera_linger_duration))
	travel_fast_forward = float(config.get("travel_fast_forward", travel_fast_forward))

func begin_fire_cam(fire_camera: Camera3D, muzzle_pos: Vector3, focal_point: Vector3, will_hit_enemy: bool, anchor: Node3D) -> void:
	phase = 1
	shot_muzzle_pos = muzzle_pos
	target_hit_point = focal_point
	timer = 0.0
	has_missed_shot = false
	shot_resolved = false
	shot_will_hit_enemy = will_hit_enemy
	side_camera_active = false
	side_camera_anchor = anchor
	active_shell = null
	if fire_camera and cinematic_camera:
		cinematic_camera.global_transform = fire_camera.global_transform
		cinematic_camera.fov = fire_camera.fov

func set_active_shell(shell: Node3D) -> void:
	active_shell = shell
	if active_shell:
		shot_muzzle_pos = active_shell.global_position

func is_active() -> bool:
	return phase > 0

func is_shot_resolved() -> bool:
	return shot_resolved

func mark_shell_hit(hit_pos: Vector3) -> void:
	target_hit_point = hit_pos
	shot_resolved = true

func mark_direct_miss(hit_pos: Vector3) -> bool:
	if has_missed_shot:
		return false
	target_hit_point = hit_pos
	has_missed_shot = true
	shot_resolved = true
	return true

func end() -> void:
	phase = 0
	Engine.time_scale = 1.0
	if cinematic_camera:
		cinematic_camera.current = false
	if player_camera:
		player_camera.current = true
	active_shell = null
	cinematic_ended.emit()

func update(delta: float) -> void:
	timer += delta

	if phase == 1:
		if cinematic_camera:
			cinematic_camera.fov = firecam_fov
		if shot_resolved:
			phase = 3
			_update_side_camera_pose(target_hit_point, _get_side_camera_world_position())
			timer = 0.0
			return
		if timer >= firecam_duration:
			phase = 2
			_update_side_camera(0.0)
			timer = 0.0
			return

	if phase == 2:
		_update_side_camera(delta)
		return

	if phase == 3:
		_update_side_camera_pose(target_hit_point, _get_side_camera_world_position())
		if timer >= _get_linger_time():
			timer = 0.0
			end()

func _update_side_camera(_delta: float) -> void:
	if not is_instance_valid(active_shell):
		phase = 3
		timer = 0.0
		return

	var bullet_pos = active_shell.global_position
	var side_camera_zone = _get_side_camera_world_position()
	_update_side_camera_pose(bullet_pos, side_camera_zone)

	var dist_to_camera_zone = bullet_pos.distance_to(side_camera_zone)
	if not side_camera_active:
		if dist_to_camera_zone <= side_camera_trigger_distance:
			side_camera_active = true
			Engine.time_scale = side_camera_time_scale
			if side_cam_mortar_sound:
				side_cam_mortar_sound.play()
		else:
			Engine.time_scale = travel_fast_forward
	else:
		Engine.time_scale = side_camera_time_scale

	var passed_target = _has_shell_passed_target(bullet_pos)
	if passed_target and not shot_will_hit_enemy:
		_resolve_missed_shot_at_target()

	if shot_resolved or passed_target:
		phase = 3
		timer = 0.0
		active_shell = null

func _update_side_camera_pose(bullet_pos: Vector3, side_camera_zone: Vector3) -> void:
	if not cinematic_camera:
		return
	cinematic_camera.fov = side_camera_fov
	var blend = clampf(side_camera_position_blend, 0.0, 1.0)
	if blend >= 1.0:
		cinematic_camera.global_position = side_camera_zone
	else:
		cinematic_camera.global_position = cinematic_camera.global_position.lerp(side_camera_zone, blend)
	cinematic_camera.look_at(bullet_pos + Vector3.UP * side_camera_look_at_height_bias, Vector3.UP)

func _find_marker_in_group(group: String) -> Node3D:
	if group.is_empty():
		return null
	var nodes := get_tree().get_nodes_in_group(group)
	for n in nodes:
		if n is Node3D and is_instance_valid(n):
			return n as Node3D
	return null

func _get_side_camera_world_position() -> Vector3:
	var anchor = _get_side_camera_anchor()
	var use_left := true
	if anchor:
		use_left = anchor.to_local(target_hit_point).x >= 0.0

	var left_marker := _find_marker_in_group(side_cam_left_group)
	var right_marker := _find_marker_in_group(side_cam_right_group)
	if use_left and left_marker:
		return left_marker.global_position
	if not use_left and right_marker:
		return right_marker.global_position
	if left_marker:
		return left_marker.global_position
	if right_marker:
		return right_marker.global_position

	if not anchor:
		var side_dir = (target_hit_point - shot_muzzle_pos).cross(Vector3.UP).normalized()
		return target_hit_point + side_dir * side_camera_left_local_offset.x + Vector3.UP * 2.0

	var side_offset = side_camera_left_local_offset if use_left else side_camera_right_local_offset
	var unscaled_basis = anchor.global_transform.basis.orthonormalized()
	var world_pos = anchor.global_position + unscaled_basis * side_offset
	if world_pos.z > target_hit_point.z + 1.0:
		var mirrored_offset = Vector3(side_offset.x, side_offset.y, -abs(side_offset.z))
		world_pos = anchor.global_position + unscaled_basis * mirrored_offset
	return world_pos

func _get_side_camera_anchor() -> Node3D:
	if side_camera_anchor and is_instance_valid(side_camera_anchor):
		return side_camera_anchor
	if analog_targeting_controller and analog_targeting_controller.has_method("get_target_node"):
		side_camera_anchor = analog_targeting_controller.get_target_node() as Node3D
		if side_camera_anchor:
			return side_camera_anchor
	var current_scene = get_tree().current_scene
	if current_scene:
		var zezlan = current_scene.find_child("zezlan", true)
		if zezlan is Node3D:
			side_camera_anchor = zezlan as Node3D
			return side_camera_anchor
	return null

func _has_shell_passed_target(bullet_pos: Vector3) -> bool:
	var target_vector = target_hit_point - shot_muzzle_pos
	var shell_vector = bullet_pos - shot_muzzle_pos
	if target_vector.length() <= 0.001:
		return false
	return shell_vector.dot(target_vector.normalized()) >= target_vector.length()

func _resolve_missed_shot_at_target() -> void:
	if has_missed_shot:
		shot_resolved = true
		return
	has_missed_shot = true
	shot_missed.emit(target_hit_point)
	shot_resolved = true

func _get_linger_time() -> float:
	if side_camera_active:
		return max(0.0, side_camera_linger_duration)
	return 0.05
