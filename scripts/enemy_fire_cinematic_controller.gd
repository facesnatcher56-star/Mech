extends Node

signal cinematic_ended

@export_group("Cinematic Timing")
## Time to hold on the enemy camera before firing.
@export var pre_fire_hold: float = 2.0
## Time to hold on the enemy camera after firing before returning to the player.
@export var post_fire_hold: float = 1.0

@export_group("Action Cam Adjustments")
## Distance from camera to trigger slow motion.
@export var trigger_distance: float = 40.0
## Slow motion time scale (0.01 = 1% speed, 1.0 = normal speed).
@export_range(0.01, 1.0, 0.01) var action_time_scale: float = 0.6
## How long to hold on the impact (in world seconds).
@export var linger_duration: float = .2
## FOV for the action cameras.
@export var action_fov: float = 65.0

@export_group("Cameras")
@export var firing_sequence_cam: Camera3D
@export var action_cam_a: Camera3D
@export var action_cam_b: Camera3D

func configure_cameras(firing_cam: Camera3D, cam_a: Camera3D, cam_b: Camera3D) -> void:
	if firing_cam:
		firing_sequence_cam = firing_cam
	if cam_a:
		action_cam_a = cam_a
	if cam_b:
		action_cam_b = cam_b

var active: bool = false
var phase: int = 0 # 0: idle, 1: firing, 2: tracking, 3: linger
var active_shell: Node3D = null
var shot_muzzle_pos: Vector3 = Vector3.ZERO
var target_impact_pos: Vector3 = Vector3.ZERO
var timer: float = 0.0
var selected_action_cam: Camera3D = null

var _saved_player_cam: Camera3D = null
var _saved_cin_cam: Camera3D = null

func begin(fire_callable: Callable, player_camera: Camera3D, cinematic_camera: Camera3D, player_is_dead: bool, interrupt_callable: Callable) -> void:
	if player_is_dead:
		fire_callable.call()
		return

	var enemy_cam := firing_sequence_cam
	if not enemy_cam:
		fire_callable.call()
		return

	active = true
	phase = 1
	timer = 0.0
	_saved_player_cam = player_camera
	_saved_cin_cam = cinematic_camera

	if interrupt_callable.is_valid():
		interrupt_callable.call()

	if player_camera:
		player_camera.current = false
	if cinematic_camera:
		cinematic_camera.current = false
	enemy_cam.current = true

	var pre_hold = pre_fire_hold
	if enemy_cam.get("pre_fire_hold") != null:
		pre_hold = enemy_cam.pre_fire_hold

	get_tree().create_timer(pre_hold).timeout.connect(func():
		fire_callable.call()
		var post_hold = post_fire_hold
		if enemy_cam.get("post_fire_hold") != null:
			post_hold = enemy_cam.post_fire_hold
		
		get_tree().create_timer(post_hold).timeout.connect(func():
			_transition_to_action_cam()
		)
	)

func set_active_shell(shell: Node3D, impact_pos: Vector3) -> void:
	active_shell = shell
	target_impact_pos = impact_pos
	if is_instance_valid(active_shell):
		shot_muzzle_pos = active_shell.global_position

func _transition_to_action_cam() -> void:
	var cam_a = action_cam_a
	var cam_b = action_cam_b

	if not cam_a and not cam_b:
		end()
		return

	# Pick closest to impact
	if cam_a and cam_b:
		var dist_a = cam_a.global_position.distance_to(target_impact_pos)
		var dist_b = cam_b.global_position.distance_to(target_impact_pos)
		selected_action_cam = cam_a if dist_a < dist_b else cam_b
	else:
		selected_action_cam = cam_a if cam_a else cam_b

	selected_action_cam.fov = action_fov
	selected_action_cam.current = true
	phase = 2
	timer = 0.0

func update(delta: float) -> void:
	if not active:
		return
	
	# Use unscaled delta so timer represents real-world seconds
	var real_delta = delta / Engine.time_scale if Engine.time_scale > 0.001 else delta
	timer += real_delta
	
	if phase == 2:
		_update_tracking(delta)
	elif phase == 3:
		if timer >= linger_duration:
			end()

func _update_tracking(_delta: float) -> void:
	if not is_instance_valid(active_shell) or not selected_action_cam:
		phase = 3
		timer = 0.0
		return

	var shell_pos = active_shell.global_position
	selected_action_cam.look_at(shell_pos, Vector3.UP)

	# Check if shell is 20 units past the target
	var dist_muzzle_to_shell = shell_pos.distance_to(shot_muzzle_pos)
	var dist_muzzle_to_target = target_impact_pos.distance_to(shot_muzzle_pos)
	
	if dist_muzzle_to_shell > dist_muzzle_to_target + 20.0:
		end()
		return

	var dist = selected_action_cam.global_position.distance_to(shell_pos)
	if Engine.time_scale > action_time_scale and dist <= trigger_distance:
		Engine.time_scale = action_time_scale

func end() -> void:
	phase = 0
	active = false
	Engine.time_scale = 1.0
	if selected_action_cam:
		selected_action_cam.current = false
	if firing_sequence_cam:
		firing_sequence_cam.current = false
	
	if _saved_player_cam:
		_saved_player_cam.current = true
	
	active_shell = null
	selected_action_cam = null
	cinematic_ended.emit()

func is_active() -> bool:
	return active
