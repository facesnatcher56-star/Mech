extends Node

var active: bool = false

func begin(fire_callable: Callable, player_camera: Camera3D, cinematic_camera: Camera3D, player_is_dead: bool, interrupt_callable: Callable) -> void:
	if player_is_dead:
		fire_callable.call()
		return

	var enemy_cam := _find_scene_camera("FiringSequenceCam")
	if not enemy_cam:
		fire_callable.call()
		return

	active = true
	if interrupt_callable.is_valid():
		interrupt_callable.call()

	if player_camera:
		player_camera.current = false
	if cinematic_camera:
		cinematic_camera.current = false
	enemy_cam.current = true

	get_tree().create_timer(2.0).timeout.connect(func():
		fire_callable.call()
		get_tree().create_timer(2.0).timeout.connect(func():
			enemy_cam.current = false
			if player_camera:
				player_camera.current = true
			active = false
		)
	)

func is_active() -> bool:
	return active

func _find_scene_camera(cam_name: String) -> Camera3D:
	var scene := get_tree().current_scene
	if scene:
		return scene.get_node_or_null(cam_name) as Camera3D
	return null
