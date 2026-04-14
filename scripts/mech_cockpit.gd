extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var steam_particles: GPUParticles3D = $SteamParticles
@onready var reticle = $CanvasLayer/Reticle

var projectile_scene = preload("res://scenes/projectile.tscn")

var original_cam_pos: Vector3
var recoil_tween: Tween
var shake_tween: Tween

# Movement (Legs)
var throttle: float = 0.0
var current_velocity: float = 0.0
var engine_acceleration: float = 0.4
var max_speed: float = 8.0
var distance_walked: float = 0.0
var mech_yaw: float = 0.0 # Direction the legs are facing

# Aiming (Torso)
@export var look_sensitivity: float = 2.0
@export var mouse_sensitivity: float = 0.002
var torso_yaw: float = 0.0
var torso_pitch: float = 0.0

# Accuracy
var current_spread: float = 0.0
var min_spread: float = 0.05
var max_spread: float = 1.0
var recovery_speed: float = 0.25

# Engine Sway
var engine_sway_time: float = 0.0

func _ready():
	original_cam_pos = camera.position
	current_spread = min_spread
	# Using HIDDEN to avoid Deck locking, but still allowing mouse control
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _input(event):
	# Mouse Aiming (Torso Twist & Pitch)
	if event is InputEventMouseMotion:
		torso_yaw -= event.relative.x * mouse_sensitivity
		torso_pitch = clamp(torso_pitch - event.relative.y * mouse_sensitivity, -0.6, 0.4)
		
		# Apply to nodes
		rotation.y = torso_yaw
		camera.rotation.x = torso_pitch

func _process(delta):
	# EMERGENCY EXIT
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

	# 1. Gamepad Aiming (Right Stick)
	var look_vec = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if look_vec.length() > 0.1:
		torso_yaw -= look_vec.x * look_sensitivity * delta
		torso_pitch = clamp(torso_pitch - look_vec.y * look_sensitivity * delta, -0.6, 0.4)
		rotation.y = torso_yaw
		camera.rotation.x = torso_pitch

	# 2. Mech Turning (Legs - A/D or Left Stick X)
	var turn_input = Input.get_axis("ui_right", "ui_left") # Keyboard A/D
	var joy_turn = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	
	if turn_input != 0:
		mech_yaw += turn_input * 1.5 * delta
	elif abs(joy_turn) > 0.1:
		mech_yaw -= joy_turn * 1.5 * delta

	# 3. Throttle (W/S or Left Stick Y)
	var move_input = -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if Input.is_action_pressed("ui_up"):
		throttle = clamp(throttle + delta * 0.5, -0.5, 1.0)
	elif Input.is_action_pressed("ui_down"):
		throttle = clamp(throttle - delta * 0.5, -0.5, 1.0)
	elif abs(move_input) > 0.1:
		throttle = clamp(throttle + move_input * delta * 0.8, -0.5, 1.0)
	
	# 4. Inertia-based Velocity
	var target_velocity = throttle * max_speed
	current_velocity = lerp(current_velocity, target_velocity, engine_acceleration * delta)
	
	# 5. Move the mech in the LEG direction (independent of torso/aim)
	if abs(current_velocity) > 0.05:
		var move_dir = Vector3.FORWARD.rotated(Vector3.UP, mech_yaw)
		position += move_dir * current_velocity * delta
		
		# Footfalls
		distance_walked += abs(current_velocity) * delta
		camera.position.y = original_cam_pos.y + sin(distance_walked * 4.0) * 0.12
		
		# Movement Penalty
		var movement_penalty = abs(current_velocity) / max_speed * 0.4
		current_spread = clamp(current_spread + movement_penalty * delta, min_spread, max_spread)
	else:
		camera.position.y = lerp(camera.position.y, original_cam_pos.y, delta * 5.0)

	# 6. Engine Sway (Subtle additive)
	engine_sway_time += delta
	camera.rotation.z = sin(engine_sway_time * 1.2) * 0.005 # Side sway
	camera.rotation.x = torso_pitch + cos(engine_sway_time * 1.5) * 0.002

	# 7. Combat input
	if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not recoil_tween or not recoil_tween.is_running():
			fire_cannon()
	
	current_spread = lerp(current_spread, min_spread, recovery_speed * delta * 5.0)
	reticle.update_reticle(current_spread, throttle, current_velocity / max_speed)

func fire_cannon():
	spawn_projectile()
	current_spread = max_spread
	if recoil_tween: recoil_tween.kill()
	if shake_tween: shake_tween.kill()
	recoil_tween = create_tween()
	recoil_tween.tween_property(camera, "position:z", original_cam_pos.z + 0.45, 0.06).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	recoil_tween.tween_property(camera, "position:z", original_cam_pos.z, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	apply_heavy_shake(0.2, 0.35)
	steam_particles.restart()
	steam_particles.emitting = true

func spawn_projectile():
	var shell = projectile_scene.instantiate()
	get_tree().root.add_child(shell)
	shell.global_transform = camera.global_transform
	var spread_range = current_spread * 0.15
	shell.rotate_x(randf_range(-spread_range, spread_range))
	shell.rotate_y(randf_range(-spread_range, spread_range))

func apply_heavy_shake(duration: float, intensity: float):
	shake_tween = create_tween()
	var steps = 12
	var step_duration = duration / steps
	for i in range(steps):
		var rand_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(camera, "h_offset", rand_offset.x, step_duration)
		shake_tween.parallel().tween_property(camera, "v_offset", rand_offset.y, step_duration)
	shake_tween.tween_property(camera, "h_offset", 0.0, 0.05)
	shake_tween.parallel().tween_property(camera, "v_offset", 0.0, 0.05)
