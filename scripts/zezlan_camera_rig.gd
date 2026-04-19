extends Node3D

@export var switch_to_key: Key = KEY_2
@export var switch_back_key: Key = KEY_1
@export var mouse_sensitivity: float = 0.003
@export var zoom_sensitivity: float = 5.0
@export var min_fov: float = 10.0
@export var max_fov: float = 120.0
@export var zoom_blend_speed: float = 10.0
@export var orbit_distance: float = 10.0
@export var min_orbit_distance: float = 2.0
@export var max_orbit_distance: float = 60.0
@export var distance_zoom_sensitivity: float = 1.0
@export var use_distance_zoom: bool = false

@onready var test_camera: Camera3D = $Camera3D

var target_fov: float = 75.0
var target_orbit_distance: float = 10.0
var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	yaw = rotation.y
	pitch = rotation.x
	orbit_distance = clampf(orbit_distance, min_orbit_distance, max_orbit_distance)
	target_orbit_distance = orbit_distance
	if test_camera:
		target_fov = test_camera.fov
		test_camera.position = Vector3(0.0, 0.0, orbit_distance)
		test_camera.rotation = Vector3.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == switch_to_key:
			_activate_camera()
			return
		if event.physical_keycode == switch_back_key and _is_active():
			_return_to_player_camera()
			return

	if not _is_active():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-80.0), deg_to_rad(80.0))
		rotation = Vector3(pitch, yaw, 0.0)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(-1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(1.0)

func _process(delta: float) -> void:
	if _is_active() and test_camera:
		test_camera.fov = lerpf(test_camera.fov, target_fov, zoom_blend_speed * delta)
		orbit_distance = lerpf(orbit_distance, target_orbit_distance, zoom_blend_speed * delta)
		test_camera.position = Vector3(0.0, 0.0, orbit_distance)

func _apply_zoom(direction: float) -> void:
	if use_distance_zoom:
		target_orbit_distance = clampf(target_orbit_distance + direction * distance_zoom_sensitivity, min_orbit_distance, max_orbit_distance)
	else:
		target_fov = clampf(target_fov + direction * zoom_sensitivity, min_fov, max_fov)

func _activate_camera() -> void:
	if not test_camera:
		return
	test_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _return_to_player_camera() -> void:
	var player = get_tree().get_first_node_in_group("player")
	var player_camera: Camera3D = null
	if player:
		player_camera = player.get_node_or_null("Camera3D") as Camera3D
	if not player_camera:
		player_camera = get_tree().get_first_node_in_group("player_camera") as Camera3D
	if not player_camera and get_tree().current_scene:
		player_camera = get_tree().current_scene.get_node_or_null("Camera3D") as Camera3D
	if not player_camera and get_tree().current_scene:
		player_camera = get_tree().current_scene.get_node_or_null("PlayerOrbitCamera") as Camera3D
	if player_camera:
		player_camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _is_active() -> bool:
	return test_camera != null and test_camera.current
