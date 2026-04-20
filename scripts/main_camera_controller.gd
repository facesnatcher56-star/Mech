extends Node

var cockpit: Node3D = null
var camera: Camera3D = null
var main_fov: float = 75.0
var min_fov_limit: float = 40.0
var max_fov_limit: float = 82.0
var zoom_sensitivity: float = 5.0
var orbit_target_offset: Vector3 = Vector3(0.0, 1.35, 0.0)
var orbit_distance: float = 0.0
var min_pitch: float = deg_to_rad(-35.0)
var max_pitch: float = deg_to_rad(55.0)
var orbit_blend_speed: float = 12.0
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.0

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", null) as Node3D
	main_fov = float(config.get("main_fov", main_fov))
	min_fov_limit = float(config.get("min_fov_limit", min_fov_limit))
	max_fov_limit = float(config.get("max_fov_limit", max_fov_limit))
	zoom_sensitivity = float(config.get("zoom_sensitivity", zoom_sensitivity))
	orbit_target_offset = config.get("orbit_target_offset", orbit_target_offset)
	orbit_distance = float(config.get("orbit_distance", orbit_distance))
	min_pitch = float(config.get("min_pitch", min_pitch))
	max_pitch = float(config.get("max_pitch", max_pitch))
	orbit_blend_speed = float(config.get("orbit_blend_speed", orbit_blend_speed))
	main_fov = clampf(main_fov, min_fov_limit, max_fov_limit)

func bind_initial_camera() -> Camera3D:
	camera = _find_main_camera()
	if not camera:
		return null
	_detach_main_camera_from_mech()
	_initialize_orbit()
	camera.make_current()
	camera.fov = main_fov
	return camera

func try_bind_camera() -> Camera3D:
	camera = _find_main_camera()
	if not camera:
		return null
	_detach_main_camera_from_mech()
	_initialize_orbit()
	camera.fov = main_fov
	return camera

func handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		main_fov = clampf(main_fov - zoom_sensitivity, min_fov_limit, max_fov_limit)
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		main_fov = clampf(main_fov + zoom_sensitivity, min_fov_limit, max_fov_limit)
		return true
	return false

func handle_orbit_motion(relative: Vector2, sensitivity: float) -> void:
	orbit_yaw -= relative.x * sensitivity
	orbit_pitch = clampf(orbit_pitch + relative.y * sensitivity, min_pitch, max_pitch)

func update_fov(delta: float, is_transitioning: bool) -> void:
	if not camera or is_transitioning:
		return
	main_fov = clampf(main_fov, min_fov_limit, max_fov_limit)
	var real_delta = delta / Engine.time_scale if Engine.time_scale > 0.001 else delta
	camera.fov = lerpf(camera.fov, main_fov, 10.0 * real_delta)

func update_orbit(delta: float, sway_time: float, base_sway_amount: float, current_spread: float) -> void:
	if not camera or not cockpit:
		return
	var real_delta := delta / Engine.time_scale if Engine.time_scale > 0.001 else delta
	var radius := maxf(0.1, orbit_distance)
	var target := cockpit.global_position + orbit_target_offset
	var cos_pitch := cos(orbit_pitch)
	var orbit_offset := Vector3(
		sin(orbit_yaw) * cos_pitch * radius,
		sin(orbit_pitch) * radius,
		cos(orbit_yaw) * cos_pitch * radius
	)
	var blend := clampf(orbit_blend_speed * real_delta, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target + orbit_offset, blend)
	var current_sway := base_sway_amount + (current_spread * 0.05)
	var sway_offset := camera.global_transform.basis.x * (sin(sway_time * 0.8) * current_sway * radius)
	sway_offset += Vector3.UP * (cos(sway_time * 1.1) * current_sway * radius)
	camera.look_at(target + sway_offset, Vector3.UP)

func find_audio_player_3d(node_name: String) -> AudioStreamPlayer3D:
	var player := cockpit.find_child(node_name, true, false) as AudioStreamPlayer3D if cockpit else null
	if player:
		return player
	if camera:
		return camera.find_child(node_name, true, false) as AudioStreamPlayer3D
	return null

func _find_main_camera() -> Camera3D:
	if not cockpit:
		return null
	var child_camera := cockpit.get_node_or_null("Camera3D") as Camera3D
	if child_camera:
		return child_camera
	var grouped_camera := cockpit.get_tree().get_first_node_in_group("player_camera") as Camera3D
	if grouped_camera:
		return grouped_camera
	var current_scene := cockpit.get_tree().current_scene
	if current_scene:
		var player_orbit_camera := current_scene.get_node_or_null("PlayerOrbitCamera") as Camera3D
		if player_orbit_camera:
			return player_orbit_camera
		var root_camera := current_scene.get_node_or_null("Camera3D") as Camera3D
		if root_camera:
			return root_camera
		player_orbit_camera = current_scene.find_child("PlayerOrbitCamera", true, false) as Camera3D
		if player_orbit_camera:
			return player_orbit_camera
	return null

func _detach_main_camera_from_mech() -> void:
	if not camera or not cockpit:
		return
	var scene_root := cockpit.get_tree().current_scene
	if not scene_root:
		scene_root = cockpit.get_tree().root
	if camera.get_parent() == scene_root:
		camera.add_to_group("player_camera")
		return
	var world_transform := camera.global_transform
	var old_parent := camera.get_parent()
	if old_parent:
		old_parent.remove_child(camera)
	scene_root.add_child(camera)
	camera.top_level = false
	camera.global_transform = world_transform
	camera.add_to_group("player_camera")

func _initialize_orbit() -> void:
	if not camera or not cockpit:
		return
	var target := cockpit.global_position + orbit_target_offset
	var camera_offset := camera.global_position - target
	var derived_distance := camera_offset.length()
	if orbit_distance <= 0.0:
		orbit_distance = maxf(0.1, derived_distance)
	if derived_distance > 0.001:
		orbit_yaw = atan2(camera_offset.x, camera_offset.z)
		orbit_pitch = asin(clampf(camera_offset.y / derived_distance, -1.0, 1.0))
	orbit_pitch = clampf(orbit_pitch, min_pitch, max_pitch)
