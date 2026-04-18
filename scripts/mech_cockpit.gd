extends Node3D

@onready var camera = $Camera3D
@onready var cockpit_mesh = self
const PROJECTILE = preload("res://scenes/projectile.tscn")
const DEFAULT_ANALOG_HEARTBEAT = preload("res://assets/Sounds/heartbeats-61.wav")

enum CombatViewState { NORMAL_VIEW, GUN_CAM_VIEW, ANALOG_AIM_VIEW, FIRING_FROM_FIRE_CAM }

var armor: int = 3
var is_dead: bool = false
var damage_flash_timer: float = 0.0

var target_rotation: Vector3 = Vector3.ZERO
var mouse_sensitivity: float = 0.002
var turret_speed: float = 3.0
var sway_time: float = 0.0
var base_sway_amount: float = 0.0015

var current_spread: float = 0.0
var max_spread: float = 0.1
var is_reloading: bool = false
var reload_timer: float = 0.0
var reload_duration: float = 2.5
@onready var analog_reticle_hud = get_node_or_null("CanvasLayer/AnalogReticleHUD")
@onready var combat_bark_ui = get_node_or_null("CanvasLayer/CombatBarkUI")
@onready var cannon_sound = find_child("CannonSound", true)
var hit_sound = find_child("HitSound", true)
var miss_sound = find_child("MissSound", true)

var visual_barrel: Node3D

@export var visual_barrel_node: Node3D # Assign in Inspector
var muzzle: Node3D

# --- THE CINEMATIC DIRECTOR SETTINGS ---
@export_group("Main Camera")
## Current field of view.
@export var main_fov: float = 75.0
## Maximum possible zoom in (Tight view).
@export var min_fov_limit: float = 40.0
## Maximum possible zoom out (Wide view).
@export var max_fov_limit: float = 140.0
@export var zoom_sensitivity: float = 5.0

@export_group("Gun Cam")
## How long to stay on the gun cam AFTER firing before switching to the impact cam.
@export var guncam_duration: float = 0.1
@export var guncam_fov: float = 75.0

@export_group("Projectile")
## Speed applied to player-fired shells, in world units per second.
@export var projectile_speed: float = 150.0

@export_group("Projectile Collision Debug")
## Enables detailed shell collision tracing for player-fired shells.
@export var projectile_collision_debug_enabled: bool = true
## Physics mask used by the shell debug sweep ray. Default 1 matches the shell collider.
@export_flags_3d_physics var projectile_collision_debug_mask: int = 1
## Prints periodic shell path samples so you can see where the bullet traveled.
@export var projectile_collision_debug_log_path: bool = true
## Seconds between shell path samples when path logging is enabled.
@export var projectile_collision_debug_path_interval: float = 0.05
## If enabled, a swept ray hit resolves the shell immediately instead of only logging a likely tunnel-through.
@export var projectile_collision_debug_resolve_sweep_hits: bool = false

@export_group("Impact Cam")
## Distance from the target to place the impact camera.
@export var impact_cam_distance: float = 10.0
@export var impactcam_timeout: float = 1.5
@export var impactcam_fov: float = 75.0
@export var impactcam_rotation_speed: float = 0.0 # 0 = No rotation
@export var near_miss_sound_distance: float = 4.0

@export_group("Impact Side Camera")
## Enables the Zezlan-relative side tracking impact camera.
@export var impact_side_camera_enabled: bool = true
## Charlie-side camera offset in Zezlan local space, derived from REF_Charlie.
@export var impact_side_camera_left_local_offset: Vector3 = Vector3(1.85, 0.72, -1.76)
## Mirrored Alpha-side camera offset in Zezlan local space.
@export var impact_side_camera_right_local_offset: Vector3 = Vector3(-1.85, 0.72, -1.76)
## Projectile distance from the side camera zone that activates the side camera. Larger values switch to the tracking view earlier.
@export var impact_side_camera_trigger_distance: float = 25.0
## Field of view used after the side camera activates.
@export var impact_side_camera_fov: float = 75.0
## Engine time scale while the side camera tracks the projectile.
@export var impact_side_camera_time_scale: float = 0.05
## Vertical offset added to the projectile look-at target.
@export var impact_side_camera_look_at_height_bias: float = 0.0
## Per-frame blend toward the side camera position. 1.0 snaps instantly.
@export_range(0.0, 1.0, 0.05) var impact_side_camera_position_blend: float = 1.0
## How long to hold the side camera after hit or miss resolution before returning.
@export var impact_side_camera_track_after_resolve_time: float = 0.15

@export_group("Miss/Linger")
@export var linger_duration: float = 1.0
@export var miss_timeout: float = 2.0

@export_group("Analog Aim")
@export var aim_settle_speed: float = 0.045
@export var aim_decay_speed: float = 1.1
@export var stable_velocity_threshold: float = 0.2
@export var alignment_required: bool = true
@export var post_fire_solution_penalty: float = 0.65
@export var post_fire_recovery_time: float = 0.45
@export var analog_target_center_height: float = 4.0
@export var analog_low_accuracy_overshoot_scale: float = 2.4
@export var analog_high_accuracy_overshoot_scale: float = 0.35
## Stroke speed multiplier while solution quality is in stage 1.
@export var stage_1_stroke_speed_multiplier: float = 1.0
## Stroke speed multiplier while solution quality is in stage 2.
@export var stage_2_stroke_speed_multiplier: float = 1.0
## Stroke speed multiplier while solution quality is in stage 3.
@export var stage_3_stroke_speed_multiplier: float = 1.0
## Stroke speed multiplier while solution quality is in stage 4.
@export var stage_4_stroke_speed_multiplier: float = 1.0
## Stroke speed multiplier while solution quality is in stage 5.
@export var stage_5_stroke_speed_multiplier: float = 1.0
@export var analog_low_accuracy_stroke_duration: float = 0.8
@export var analog_high_accuracy_stroke_duration: float = 1.875
@export var analog_max_distance_from_frame: float = 4.0
@export var analog_visible_frame_min_padding: float = 0.35
@export var aim_stage_1_fov: float = 44.0
@export var aim_stage_2_fov: float = 38.0
@export var aim_stage_3_fov: float = 32.0
@export var aim_stage_4_fov: float = 26.0
@export var aim_stage_5_fov: float = 20.0
@export var aim_solution_stage_2_threshold: float = 0.20
@export var aim_solution_stage_3_threshold: float = 0.40
@export var aim_solution_stage_4_threshold: float = 0.60
@export var aim_solution_stage_5_threshold: float = 0.80
@export var aim_zoom_blend_speed: float = 9.0
## Seconds to hold camera/FOV stage 1 before jumping to stage 2.
@export var aim_camera_stage_1_time: float = 0.35
## Seconds to hold camera/FOV stage 2 before jumping to stage 3.
@export var aim_camera_stage_2_time: float = 0.35
## Seconds to hold camera/FOV stage 3 before jumping to stage 4.
@export var aim_camera_stage_3_time: float = 0.35
## Seconds to hold camera/FOV stage 4 before jumping to stage 5.
@export var aim_camera_stage_4_time: float = 0.35
## Portion of a new camera chunk applied immediately when the stage changes. 0 eases fully, 1 snaps to the chunk.
@export_range(0.0, 1.0, 0.05) var aim_camera_chunk_jump_amount: float = 0.75
## How quickly the camera finishes settling after the instant chunk jump. Higher values settle faster.
@export_range(0.1, 40.0, 0.1) var aim_camera_chunk_settle_speed: float = 10.0
@export var stage_1_drift_multiplier: float = 3.20
@export var stage_2_drift_multiplier: float = 2.40
@export var stage_3_drift_multiplier: float = 1.80
@export var stage_4_drift_multiplier: float = 1.30
@export var stage_5_drift_multiplier: float = 1.0
@export var aim_stage_bump: float = 0.012
@export var analog_to_fire_cam_return_time: float = 0.16
@export var short_range_max: float = 45.0
@export var medium_range_max: float = 110.0
@export var minimum_max_hit_chance: float = 0.70
@export var accuracy_slowdown_power: float = 3.0
@export var short_max_hit_chance: float = 0.92
@export var medium_max_hit_chance: float = 0.78
@export var long_max_hit_chance: float = 0.70

@export_group("Analog Aim Heartbeat")
## Heartbeat loop played from the analog aim camera while aiming.
@export var analog_heartbeat_stream: AudioStream = DEFAULT_ANALOG_HEARTBEAT
## Heartbeat loudness while in analog aim.
@export var analog_heartbeat_volume_db: float = 0.0
## Heartbeat playback speed and pitch while in analog aim.
@export var analog_heartbeat_pitch_scale: float = 1.0

var cinematic_camera: Camera3D
var active_shell: Node3D = null
var cinematic_phase: int = 0 # 0 = Off, 1 = Gun Cam, 2 = Impact Cam, 3 = Impact Linger, 4 = Fast Travel
var impact_cam_pos: Vector3 = Vector3.ZERO
var target_hit_point: Vector3 = Vector3.ZERO
var shot_muzzle_pos: Vector3
var cinematic_timer: float = 0.0
var has_missed_shot: bool = false
var shot_resolved: bool = false
var shot_will_hit_enemy: bool = false
var shot_collision_debug_reported: bool = false
var impact_side_camera_anchor: Node3D = null
var impact_side_camera_active: bool = false
var original_camera_rotation: Vector3
var aim_settle: float = 0.09
var hit_chance: float = 0.0
var fire_recovery: float = 0.0
var aim_zoom_stage: int = 1
var aim_solution_stage: int = 1
var aim_camera_stage_elapsed: float = 0.0
var current_analog_drift_multiplier: float = 1.0
var aim_stage_bump_timer: float = 0.0
var smooth_max_accuracy: float = 0.7
var combat_view_state: int = CombatViewState.NORMAL_VIEW
var view_transition_tween: Tween
var analog_sway_rng := RandomNumberGenerator.new()
var analog_stroke_active: bool = false
var analog_stroke_time: float = 0.0
var analog_stroke_duration: float = 0.35
var analog_stroke_start: Vector2 = Vector2.ZERO
var analog_stroke_end: Vector2 = Vector2.ZERO
var analog_stroke_target: Node3D = null
var aim_camera_session_start: Vector3 = Vector3.ZERO
var aim_camera_session_target: Vector3 = Vector3.ZERO
var aim_camera_chunk_stage: int = 0
var analog_heartbeat_player: AudioStreamPlayer

# --- RECOIL TRACKING ---
var recoil_tween: Tween
var visual_barrel_base_pos: Vector3

func _ready():
	add_to_group("player")
	analog_sway_rng.randomize()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if camera:
		camera.make_current()
		original_camera_rotation = camera.rotation
		camera.fov = main_fov
	_set_analog_hud_visible(false)

	target_rotation = rotation

	call_deferred("_setup_big_gun")

	cinematic_camera = Camera3D.new()
	cinematic_camera.current = false
	_setup_analog_heartbeat_player()
	get_tree().root.call_deferred("add_child", cinematic_camera)

func _setup_analog_heartbeat_player() -> void:
	analog_heartbeat_player = AudioStreamPlayer.new()
	analog_heartbeat_player.name = "AnalogHeartbeat"
	analog_heartbeat_player.stream = _make_looping_heartbeat_stream()
	analog_heartbeat_player.volume_db = analog_heartbeat_volume_db
	analog_heartbeat_player.pitch_scale = analog_heartbeat_pitch_scale
	cinematic_camera.add_child(analog_heartbeat_player)

	if not analog_heartbeat_player.finished.is_connected(_on_analog_heartbeat_finished):
		analog_heartbeat_player.finished.connect(_on_analog_heartbeat_finished)

func _make_looping_heartbeat_stream() -> AudioStream:
	if analog_heartbeat_stream is AudioStreamWAV:
		var wav := analog_heartbeat_stream.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return wav
	return analog_heartbeat_stream

func _on_analog_heartbeat_finished() -> void:
	if combat_view_state == CombatViewState.ANALOG_AIM_VIEW and analog_heartbeat_player:
		analog_heartbeat_player.play()

func _play_analog_heartbeat() -> void:
	if not analog_heartbeat_player or not analog_heartbeat_stream:
		return
	analog_heartbeat_player.stream = _make_looping_heartbeat_stream()
	analog_heartbeat_player.volume_db = analog_heartbeat_volume_db
	analog_heartbeat_player.pitch_scale = analog_heartbeat_pitch_scale
	if not analog_heartbeat_player.playing:
		analog_heartbeat_player.play()

func _stop_analog_heartbeat() -> void:
	if analog_heartbeat_player and analog_heartbeat_player.playing:
		analog_heartbeat_player.stop()

func _setup_big_gun():
	# Find the RightArm in the armature to act as our barrel/muzzle source
	visual_barrel = find_child("RightArm", true)

	if visual_barrel:
		# Setup muzzle at the tip of the right arm/gun
		muzzle = visual_barrel.get_node_or_null("Muzzle")
		if not muzzle:
			muzzle = Marker3D.new()
			muzzle.name = "Muzzle"
			# Position it at the end of the gun barrel on the RightArm model
			muzzle.position = Vector3(-0.5, 0.2, 1.2)
			visual_barrel.add_child(muzzle)

func _input(event):
	if is_dead: return
	if not _is_player_view_current():
		return

	# Smooth Zoom Input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_begin_aim_flow()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			main_fov = clamp(main_fov - zoom_sensitivity, min_fov_limit, max_fov_limit)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			main_fov = clamp(main_fov + zoom_sensitivity, min_fov_limit, max_fov_limit)

	if event is InputEventMouseMotion and combat_view_state == CombatViewState.NORMAL_VIEW and not is_reloading and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		target_rotation.y -= event.relative.x * mouse_sensitivity
		target_rotation.x += event.relative.y * mouse_sensitivity
		target_rotation.y = clamp(target_rotation.y, -0.4, 0.4)
		target_rotation.x = clamp(target_rotation.x, -0.3, 0.3)

var current_target_range: float = 0.0
var is_on_target: bool = false
var last_ray_result: Dictionary = {}

func _process(delta):
	if is_dead: return

	# Butter-Smooth Blend
	if camera and not is_transitioning:
		var target_fov = main_fov
		var blend_speed = 10.0
		# Adjust delta to ignore slomo so zoom stays fast
		var real_delta = delta / Engine.time_scale if Engine.time_scale > 0.001 else delta
		camera.fov = lerpf(camera.fov, target_fov, blend_speed * real_delta)

	if damage_flash_timer > 0.0:
		damage_flash_timer = max(0.0, damage_flash_timer - delta)

	# --- Ground Alignment (Stationary) ---
	var ss_ground = get_world_3d().direct_space_state
	var ground_query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 5.0)
	var ground_res = ss_ground.intersect_ray(ground_query)
	if ground_res:
		global_position.y = lerpf(global_position.y, ground_res.position.y + 0.05, delta * 5.0)

	var reload_progress = 0.0

	if is_reloading:
		reload_timer += delta
		current_spread = max_spread
		reload_progress = 1.0 - (reload_timer / reload_duration)

		# Hide reticle during cinematic
		pass

		_update_cinematic(delta)
	else:
		current_spread = lerpf(current_spread, 0.0, delta * 0.5)

	# --- Real-time Ranging ---
	var aim_camera = _get_aim_query_camera()
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = aim_camera.global_position
	query.to = aim_camera.global_position + (-aim_camera.global_transform.basis.z * 1000.0)
	last_ray_result = space_state.intersect_ray(query)

	if last_ray_result:
		current_target_range = aim_camera.global_position.distance_to(last_ray_result.position)
		is_on_target = _is_enemy_collider(last_ray_result.collider)
	else:
		current_target_range = 0.0
		is_on_target = false

	if combat_view_state == CombatViewState.ANALOG_AIM_VIEW:
		_update_analog_aim(delta)

	if combat_view_state == CombatViewState.NORMAL_VIEW:
		rotation.y = lerpf(rotation.y, target_rotation.y, turret_speed * delta)
		rotation.x = lerpf(rotation.x, target_rotation.x, turret_speed * delta)
	else:
		target_rotation = rotation

	sway_time += delta
	var current_sway = base_sway_amount + (current_spread * 0.05)
	camera.rotation.x = original_camera_rotation.x + sin(sway_time * 0.8) * current_sway
	camera.rotation.y = original_camera_rotation.y + cos(sway_time * 1.1) * current_sway
	if combat_view_state == CombatViewState.GUN_CAM_VIEW and not is_transitioning:
		_sync_plain_gun_camera()
	elif combat_view_state == CombatViewState.ANALOG_AIM_VIEW and not is_transitioning:
		_update_analog_camera_presentation(delta)

	if analog_reticle_hud:
		# Range info is handled by the analog HUD now
		pass

	if _is_player_view_current() and Input.is_action_just_pressed("ui_accept"):
		fire_cannon()

func _is_player_view_current() -> bool:
	return camera.current or (cinematic_camera != null and cinematic_camera.current)

func _update_analog_aim(delta: float) -> void:
	var target_point = _get_analog_target_point()
	if target_point != Vector3.ZERO and cinematic_camera != null:
		current_target_range = cinematic_camera.global_position.distance_to(target_point)
		is_on_target = not last_ray_result.is_empty() and last_ray_result.has("collider") and _is_enemy_collider(last_ray_result.collider)

	if fire_recovery > 0.0:
		fire_recovery = max(0.0, fire_recovery - delta)

	# Calculate current UI progress (0.0 to 1.0)
	var current_curve = 1.0 - pow(1.0 - aim_settle, accuracy_slowdown_power)
	var effective_speed = aim_settle_speed

	# Start slowing down once we pass 50% hit chance
	if current_curve > 0.5:
		var factor = clampf(remap(current_curve, 0.5, 1.0, 1.0, 0.0), 0.0, 1.0)
		effective_speed *= (0.05 + 0.95 * pow(factor, 2.0))

	aim_settle = min(1.0, aim_settle + effective_speed * delta)

	_update_aim_solution_stage()
	_update_aim_camera_stage(delta)
	if aim_stage_bump_timer > 0.0:
		aim_stage_bump_timer = max(0.0, aim_stage_bump_timer - delta)

	var max_accuracy = _get_max_accuracy_for_range(current_target_range)
	# Smoothly transition max accuracy to prevent jumps when range bands change
	smooth_max_accuracy = lerpf(smooth_max_accuracy, max_accuracy, delta * 2.5)
	hit_chance = _calculate_displayed_hit_chance(smooth_max_accuracy)

	if analog_reticle_hud:
		analog_reticle_hud.set_solution(hit_chance, _get_range_band(current_target_range), true)

func _get_aim_query_camera() -> Camera3D:
	if combat_view_state != CombatViewState.NORMAL_VIEW and cinematic_camera:
		return cinematic_camera
	return camera

func _get_gun_camera_marker() -> Camera3D:
	return find_child("GunCam_R", true) as Camera3D

func _get_fire_camera_marker() -> Camera3D:
	var fire_camera = find_child("FireCam_R", true) as Camera3D
	if fire_camera:
		return fire_camera
	return _get_gun_camera_marker()

func _get_fire_camera_fov() -> float:
	var fire_camera = _get_fire_camera_marker()
	if fire_camera:
		return fire_camera.fov
	return guncam_fov

func _set_analog_hud_visible(is_visible: bool) -> void:
	if analog_reticle_hud:
		analog_reticle_hud.visible = is_visible

func _is_enemy_collider(collider: Object) -> bool:
	if not collider:
		return false
	if collider is Node:
		var node = collider as Node
		if _is_enemy_target_node(node):
			return true
		var parent = node.get_parent()
		while parent:
			if _is_enemy_target_node(parent):
				return true
			parent = parent.get_parent()
	return false

func _is_enemy_target_node(node: Node) -> bool:
	if not node or _is_player_tree_node(node):
		return false
	if node.is_in_group("enemy"):
		return true

	var node_name = node.name.to_lower()
	if "enemy" in node_name:
		return true
	if "zezlan" in node_name:
		return true
	if "mech" in node_name:
		return true
	return false

func _is_player_tree_node(node: Node) -> bool:
	var current = node
	while current:
		if current.is_in_group("player"):
			return true
		current = current.get_parent()
	return false

func _sync_plain_gun_camera() -> void:
	var gun_camera = _get_gun_camera_marker()
	if not gun_camera:
		return
	cinematic_camera.global_transform = gun_camera.global_transform
	cinematic_camera.fov = guncam_fov

func _update_analog_camera_presentation(delta: float) -> void:
	var gun_camera = _get_gun_camera_marker()
	if not gun_camera:
		return

	var start_pos = aim_camera_session_start if aim_camera_session_start != Vector3.ZERO else gun_camera.global_position
	var target_pos = start_pos
	var target_point = _get_analog_target_point()
	var camera_target_point = aim_camera_session_target if aim_camera_session_target != Vector3.ZERO else _get_analog_camera_target_point()
	var progress = 0.0

	if camera_target_point != Vector3.ZERO:
		progress = clampf(float(aim_zoom_stage) / 5.0, 0.0, 1.0)
		target_pos = start_pos.lerp(camera_target_point, progress)

	if aim_camera_chunk_stage != aim_zoom_stage:
		aim_camera_chunk_stage = aim_zoom_stage
		cinematic_camera.global_position = cinematic_camera.global_position.lerp(target_pos, aim_camera_chunk_jump_amount)

	cinematic_camera.global_position = cinematic_camera.global_position.lerp(target_pos, clampf(aim_camera_chunk_settle_speed * delta, 0.0, 1.0))

	# Blend the FOV and Drift Multiplier
	cinematic_camera.fov = lerpf(cinematic_camera.fov, _get_aim_stage_fov(), aim_zoom_blend_speed * delta)
	current_analog_drift_multiplier = lerpf(current_analog_drift_multiplier, _get_aim_stage_drift_multiplier(), aim_zoom_blend_speed * delta)

	# Point at the drifted target point
	if target_point != Vector3.ZERO:
		var drifted_point = _get_drifted_analog_target_point(target_point, delta)
		cinematic_camera.look_at(drifted_point, Vector3.UP)

func _begin_aim_flow() -> void:
	if is_reloading or is_transitioning or combat_view_state != CombatViewState.NORMAL_VIEW:
		return
	var gun_camera = _get_gun_camera_marker()
	if not gun_camera:
		return

	target_rotation = rotation
	is_transitioning = true
	combat_view_state = CombatViewState.GUN_CAM_VIEW
	_set_analog_hud_visible(false)

	if view_transition_tween and view_transition_tween.is_running():
		view_transition_tween.kill()

	var start_transform = camera.global_transform
	var start_fov = camera.fov
	cinematic_camera.global_transform = start_transform
	cinematic_camera.fov = start_fov
	cinematic_camera.near = camera.near
	cinematic_camera.far = camera.far
	camera.current = false
	cinematic_camera.current = true

	view_transition_tween = create_tween()
	view_transition_tween.tween_method(func(t):
		cinematic_camera.global_transform = start_transform.interpolate_with(gun_camera.global_transform, t)
		cinematic_camera.fov = lerpf(start_fov, guncam_fov, t)
	, 0.0, 1.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	view_transition_tween.finished.connect(func():
		is_transitioning = false
		_enter_analog_aim_view()
	)

func _enter_analog_aim_view() -> void:
	combat_view_state = CombatViewState.ANALOG_AIM_VIEW
	camera.current = false
	cinematic_camera.current = true
	_set_analog_hud_visible(true)
	_play_analog_heartbeat()
	var gun_camera = _get_gun_camera_marker()
	aim_camera_session_start = gun_camera.global_position if gun_camera else cinematic_camera.global_position
	aim_camera_session_target = _get_analog_camera_target_point()
	aim_zoom_stage = 1
	aim_solution_stage = 1
	aim_camera_stage_elapsed = 0.0
	aim_camera_chunk_stage = 0
	_update_aim_solution_stage()
	current_analog_drift_multiplier = _get_aim_stage_drift_multiplier()
	analog_stroke_active = false
	analog_stroke_target = null

func _is_target_aligned() -> bool:
	if not alignment_required:
		return true
	return is_on_target

func _get_analog_target_node() -> Node3D:
	var fallback: Node3D = null
	var nearest = INF
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node):
			fallback = _consider_aim_target_candidate(node, candidates, fallback, nearest)
			if fallback:
				nearest = global_position.distance_to(fallback.global_position)

	var current_scene = get_tree().current_scene
	if current_scene:
		_scan_named_aim_targets(current_scene, candidates, fallback, nearest)
		if not candidates.is_empty():
			fallback = candidates[0]
			nearest = global_position.distance_to(fallback.global_position)
			for candidate in candidates:
				var dist = global_position.distance_to(candidate.global_position)
				if candidate.name == "EnemyMech":
					return candidate
				if dist < nearest:
					nearest = dist
					fallback = candidate
	return fallback

func _consider_aim_target_candidate(node: Node3D, candidates: Array, fallback: Node3D, nearest: float) -> Node3D:
	var enemy_root = _get_enemy_aim_root(node)
	if not enemy_root or candidates.has(enemy_root):
		return fallback
	candidates.append(enemy_root)
	if enemy_root.name == "EnemyMech":
		return enemy_root
	var dist = global_position.distance_to(enemy_root.global_position)
	if dist < nearest:
		return enemy_root
	return fallback

func _scan_named_aim_targets(node: Node, candidates: Array, fallback: Node3D, nearest: float) -> void:
	if node is Node3D and _is_enemy_target_node(node):
		_consider_aim_target_candidate(node as Node3D, candidates, fallback, nearest)
	for child in node.get_children():
		_scan_named_aim_targets(child, candidates, fallback, nearest)

func _get_enemy_aim_root(node: Node3D) -> Node3D:
	var root := node
	var parent = root.get_parent()
	while parent is Node3D and _is_enemy_collider(parent):
		root = parent as Node3D
		parent = root.get_parent()
	return root

func _get_analog_target_point() -> Vector3:
	var target = _get_analog_target_node()
	if target:
		# Prioritize the Torso node for center-mass anchoring
		var torso = target.find_child("Torso", true)
		if torso and torso is Node3D:
			return torso.global_position

		# Fallback to height offset if no torso node is found
		return target.global_position + Vector3.UP * analog_target_center_height

	var current_scene = get_tree().current_scene
	var charlie = current_scene.find_child("REF_Charlie", true) if current_scene else null
	if charlie:
		return charlie.global_position

	if not last_ray_result.is_empty() and last_ray_result.has("position"):
		return last_ray_result.position
	return Vector3.ZERO

func _get_analog_camera_target_point() -> Vector3:
	var current_scene = get_tree().current_scene
	var aim_camera_target = current_scene.find_child("AimCameraTarget", true) if current_scene else null
	if aim_camera_target and aim_camera_target is Node3D:
		return aim_camera_target.global_position
	return _get_analog_target_point()

func _get_drifted_analog_target_point(target_point: Vector3, delta: float) -> Vector3:
	var target = _get_analog_target_node()
	if not target:
		return target_point

	var frame = _build_analog_target_frame(target, target_point)
	if frame.is_empty():
		return target_point

	if not analog_stroke_active or analog_stroke_time >= analog_stroke_duration or analog_stroke_target != target:
		_begin_analog_correction_stroke(frame, target)

	analog_stroke_time = min(analog_stroke_duration, analog_stroke_time + delta)
	var progress = clampf(analog_stroke_time / max(analog_stroke_duration, 0.001), 0.0, 1.0)
	var eased = progress * progress * (3.0 - 2.0 * progress)
	var offset = analog_stroke_start.lerp(analog_stroke_end, eased)
	return frame["center"] + (frame["right"] * offset.x) + (frame["up"] * offset.y)

func _build_analog_target_frame(target: Node3D, fallback_point: Vector3) -> Dictionary:
	if not cinematic_camera or not is_instance_valid(target):
		return {}

	var points: Array = []
	_collect_visible_target_points(target, points)
	if points.is_empty():
		_collect_collision_target_points(target, points)
	if points.is_empty():
		return {}

	var center = Vector3.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	if center == Vector3.ZERO:
		center = fallback_point

	var to_center = center - cinematic_camera.global_position
	if to_center.length() <= 0.01:
		return {}

	var forward = to_center.normalized()
	var right = forward.cross(Vector3.UP).normalized()
	if right.length() < 0.01:
		right = cinematic_camera.global_transform.basis.x.normalized()
	var up = right.cross(forward).normalized()

	var min_offset = Vector2(INF, INF)
	var max_offset = Vector2(-INF, -INF)
	for point in points:
		var rel = point - center
		var projected = Vector2(rel.dot(right), rel.dot(up))
		min_offset.x = min(min_offset.x, projected.x)
		min_offset.y = min(min_offset.y, projected.y)
		max_offset.x = max(max_offset.x, projected.x)
		max_offset.y = max(max_offset.y, projected.y)

	var frame_size = max_offset - min_offset
	var padding = max(analog_visible_frame_min_padding, max(frame_size.x, frame_size.y) * 0.06)
	min_offset -= Vector2.ONE * padding
	max_offset += Vector2.ONE * padding

	return {
		"center": center,
		"right": right,
		"up": up,
		"min": min_offset,
		"max": max_offset
	}

func _collect_visible_target_points(node: Node, points: Array) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh:
			_append_aabb_corners(points, mesh_instance.global_transform, mesh_instance.get_aabb())
	elif node is CSGBox3D:
		var csg_box := node as CSGBox3D
		if csg_box.visible:
			_append_aabb_corners(points, csg_box.global_transform, AABB(-csg_box.size * 0.5, csg_box.size))

	for child in node.get_children():
		_collect_visible_target_points(child, points)

func _collect_collision_target_points(node: Node, points: Array) -> void:
	if node is CollisionShape3D:
		var shape_node := node as CollisionShape3D
		if not shape_node.disabled and shape_node.shape:
			var shape_aabb = _get_shape_local_aabb(shape_node.shape)
			if shape_aabb.size != Vector3.ZERO:
				_append_aabb_corners(points, shape_node.global_transform, shape_aabb)

	for child in node.get_children():
		_collect_collision_target_points(child, points)

func _get_shape_local_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var box := shape as BoxShape3D
		return AABB(-box.size * 0.5, box.size)
	if shape is SphereShape3D:
		var sphere := shape as SphereShape3D
		var radius = sphere.radius
		return AABB(Vector3(-radius, -radius, -radius), Vector3.ONE * radius * 2.0)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		var radius = capsule.radius
		var height = max(capsule.height, radius * 2.0)
		return AABB(Vector3(-radius, -height * 0.5, -radius), Vector3(radius * 2.0, height, radius * 2.0))
	return AABB()

func _append_aabb_corners(points: Array, xform: Transform3D, aabb: AABB) -> void:
	var origin = aabb.position
	var size = aabb.size
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				points.append(xform * (origin + Vector3(size.x * x, size.y * y, size.z * z)))

func _begin_analog_correction_stroke(frame: Dictionary, target: Node3D) -> void:
	var quality = clampf(aim_settle, 0.0, 1.0)
	var crossing = _pick_frame_crossing_point(frame, quality)
	var angle = analog_sway_rng.randf_range(0.0, TAU)
	var direction = Vector2(cos(angle), sin(angle)).normalized()

	if analog_stroke_active and analog_stroke_target == target and _is_offset_outside_frame(analog_stroke_end, frame):
		analog_stroke_start = analog_stroke_end
		direction = (crossing - analog_stroke_start).normalized()
		if direction.length() < 0.01:
			direction = Vector2.RIGHT.rotated(analog_sway_rng.randf_range(0.0, TAU))
	else:
		var start_exit = _get_frame_exit_distance(crossing, -direction, frame)
		analog_stroke_start = crossing - direction * (start_exit + _get_analog_stroke_overshoot(frame, quality))

	var end_exit = _get_frame_exit_distance(crossing, direction, frame)
	analog_stroke_end = crossing + direction * (end_exit + _get_analog_stroke_overshoot(frame, quality))
	var base_duration = lerpf(analog_low_accuracy_stroke_duration, analog_high_accuracy_stroke_duration, quality)
	analog_stroke_duration = base_duration / max(0.05, _get_stage_stroke_speed_multiplier())
	analog_stroke_time = 0.0
	analog_stroke_target = target
	analog_stroke_active = true

func _pick_frame_crossing_point(frame: Dictionary, quality: float) -> Vector2:
	var min_offset = frame["min"]
	var max_offset = frame["max"]
	var center = (min_offset + max_offset) * 0.5
	var half_size = (max_offset - min_offset) * 0.5
	var edge_bias = lerpf(0.78, 0.18, quality)

	if analog_sway_rng.randf() < edge_bias:
		var side = analog_sway_rng.randi_range(0, 3)
		match side:
			0:
				return Vector2(min_offset.x + half_size.x * analog_sway_rng.randf_range(0.0, 0.18), analog_sway_rng.randf_range(min_offset.y, max_offset.y))
			1:
				return Vector2(max_offset.x - half_size.x * analog_sway_rng.randf_range(0.0, 0.18), analog_sway_rng.randf_range(min_offset.y, max_offset.y))
			2:
				return Vector2(analog_sway_rng.randf_range(min_offset.x, max_offset.x), min_offset.y + half_size.y * analog_sway_rng.randf_range(0.0, 0.18))
			_:
				return Vector2(analog_sway_rng.randf_range(min_offset.x, max_offset.x), max_offset.y - half_size.y * analog_sway_rng.randf_range(0.0, 0.18))

	var center_pull = lerpf(1.0, 0.35, pow(quality, 1.4))
	return center + Vector2(
		analog_sway_rng.randf_range(-half_size.x, half_size.x) * center_pull,
		analog_sway_rng.randf_range(-half_size.y, half_size.y) * center_pull
	)

func _get_analog_stroke_overshoot(frame: Dictionary, quality: float) -> float:
	var frame_size = frame["max"] - frame["min"]
	var frame_radius = max(frame_size.x, frame_size.y)
	var stage_scale = lerpf(current_analog_drift_multiplier, 1.0, quality)
	var overshoot_scale = lerpf(analog_low_accuracy_overshoot_scale, analog_high_accuracy_overshoot_scale, quality)
	var overshoot = frame_radius * overshoot_scale * stage_scale
	return clampf(overshoot, analog_visible_frame_min_padding, analog_max_distance_from_frame)

func _get_stage_stroke_speed_multiplier() -> float:
	match aim_solution_stage:
		5: return stage_5_stroke_speed_multiplier
		4: return stage_4_stroke_speed_multiplier
		3: return stage_3_stroke_speed_multiplier
		2: return stage_2_stroke_speed_multiplier
		_: return stage_1_stroke_speed_multiplier

func _get_frame_exit_distance(point: Vector2, direction: Vector2, frame: Dictionary) -> float:
	var min_offset = frame["min"]
	var max_offset = frame["max"]
	var exit_distance = INF
	if abs(direction.x) > 0.001:
		var x_distance = ((max_offset.x if direction.x > 0.0 else min_offset.x) - point.x) / direction.x
		if x_distance > 0.0:
			exit_distance = min(exit_distance, x_distance)
	if abs(direction.y) > 0.001:
		var y_distance = ((max_offset.y if direction.y > 0.0 else min_offset.y) - point.y) / direction.y
		if y_distance > 0.0:
			exit_distance = min(exit_distance, y_distance)
	if exit_distance == INF:
		return analog_visible_frame_min_padding
	return max(exit_distance, analog_visible_frame_min_padding)

func _is_offset_outside_frame(offset: Vector2, frame: Dictionary) -> bool:
	var min_offset = frame["min"]
	var max_offset = frame["max"]
	return offset.x < min_offset.x or offset.x > max_offset.x or offset.y < min_offset.y or offset.y > max_offset.y

func _is_unit_stable() -> bool:
	return not is_reloading

func _get_range_band(range_m: float) -> String:
	if range_m <= short_range_max:
		return "SHORT"
	if range_m <= medium_range_max:
		return "MEDIUM"
	return "LONG"

func _get_max_accuracy_for_range(range_m: float) -> float:
	var range_max := long_max_hit_chance
	match _get_range_band(range_m):
		"SHORT":
			range_max = short_max_hit_chance
		"MEDIUM":
			range_max = medium_max_hit_chance
	return max(range_max, minimum_max_hit_chance)

func _calculate_displayed_hit_chance(max_accuracy: float) -> float:
	var settle_curve = 1.0 - pow(1.0 - clampf(aim_settle, 0.0, 1.0), accuracy_slowdown_power)
	return max_accuracy * settle_curve

func _update_aim_solution_stage() -> void:
	var next_stage = 1
	if aim_settle >= aim_solution_stage_5_threshold:
		next_stage = 5
	elif aim_settle >= aim_solution_stage_4_threshold:
		next_stage = 4
	elif aim_settle >= aim_solution_stage_3_threshold:
		next_stage = 3
	elif aim_settle >= aim_solution_stage_2_threshold:
		next_stage = 2

	if next_stage != aim_solution_stage:
		aim_solution_stage = next_stage
		aim_stage_bump_timer = 0.12

func _update_aim_camera_stage(delta: float) -> void:
	if aim_zoom_stage >= 5:
		return
	aim_camera_stage_elapsed += delta
	var stage_interval = max(0.01, _get_aim_camera_stage_time(aim_zoom_stage))
	while aim_camera_stage_elapsed >= stage_interval and aim_zoom_stage < 5:
		aim_camera_stage_elapsed -= stage_interval
		aim_zoom_stage += 1
		stage_interval = max(0.01, _get_aim_camera_stage_time(aim_zoom_stage))

func _get_aim_camera_stage_time(stage: int) -> float:
	match stage:
		1: return aim_camera_stage_1_time
		2: return aim_camera_stage_2_time
		3: return aim_camera_stage_3_time
		4: return aim_camera_stage_4_time
		_: return 0.0

func _get_aim_stage_fov() -> float:
	match aim_zoom_stage:
		5: return aim_stage_5_fov
		4: return aim_stage_4_fov
		3: return aim_stage_3_fov
		2: return aim_stage_2_fov
		_: return aim_stage_1_fov

func _get_aim_stage_drift_multiplier() -> float:
	match aim_solution_stage:
		5: return stage_5_drift_multiplier
		4: return stage_4_drift_multiplier
		3: return stage_3_drift_multiplier
		2: return stage_2_drift_multiplier
		_: return stage_1_drift_multiplier

func _disrupt_aim_after_fire() -> void:
	aim_settle = max(0.09, aim_settle - post_fire_solution_penalty)
	_update_aim_solution_stage()
	fire_recovery = post_fire_recovery_time

	var max_accuracy = _get_max_accuracy_for_range(current_target_range)
	hit_chance = _calculate_displayed_hit_chance(max_accuracy)

	if analog_reticle_hud:
		analog_reticle_hud.set_solution(hit_chance, _get_range_band(current_target_range), true)

@export_group("Cinematic Transition")
## How long the camera takes to fly from cockpit to gun.
@export var transition_time: float = 0.5
## How much to slow down time during the transition (0.1 = 10% speed).
@export var slomo_scale: float = 0.1

var is_transitioning: bool = false

func fire_cannon():
	if is_reloading or is_transitioning:
		return

	if combat_view_state == CombatViewState.NORMAL_VIEW:
		_begin_aim_flow()
		return

	if combat_view_state == CombatViewState.GUN_CAM_VIEW:
		_enter_analog_aim_view()
		return

	if combat_view_state != CombatViewState.ANALOG_AIM_VIEW:
		return

	var shot_lock = _build_shot_lock(cinematic_camera)
	_disrupt_aim_after_fire()
	_return_to_fire_cam_then_fire(shot_lock)

func _return_to_fire_cam_then_fire(shot_lock: Dictionary) -> void:
	var fire_camera = _get_fire_camera_marker()
	if not fire_camera:
		return

	is_transitioning = true
	combat_view_state = CombatViewState.FIRING_FROM_FIRE_CAM
	_set_analog_hud_visible(false)
	_stop_analog_heartbeat()

	if view_transition_tween and view_transition_tween.is_running():
		view_transition_tween.kill()

	var start_transform = cinematic_camera.global_transform
	var start_fov = cinematic_camera.fov
	view_transition_tween = create_tween()
	view_transition_tween.tween_method(func(t):
		cinematic_camera.global_transform = start_transform.interpolate_with(fire_camera.global_transform, t)
		cinematic_camera.fov = lerpf(start_fov, fire_camera.fov, t)
	, 0.0, 1.0, analog_to_fire_cam_return_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	view_transition_tween.finished.connect(func():
		is_transitioning = false
		_begin_fire_sequence_from_lock(shot_lock)
	)

func _begin_fire_sequence_from_lock(shot_lock: Dictionary) -> void:
	combat_view_state = CombatViewState.FIRING_FROM_FIRE_CAM
	_set_analog_hud_visible(false)
	_stop_analog_heartbeat()

	target_hit_point = shot_lock["focal_point"]
	impact_side_camera_anchor = shot_lock.get("impact_anchor", null) as Node3D
	_perform_actual_shot(shot_lock["target_point"], shot_lock["will_hit_enemy"])

func _build_shot_lock(source_camera: Camera3D) -> Dictionary:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = source_camera.global_position
	var final_dir = -source_camera.global_transform.basis.z
	query.to = source_camera.global_position + (final_dir * 500.0)
	var result = space_state.intersect_ray(query)

	var will_hit_enemy = false
	var impact_anchor: Node3D = _get_analog_target_node()
	var focal_range = current_target_range if current_target_range > 0 else 100.0
	var focal_point = source_camera.global_position + (final_dir * focal_range)
	var target_point = query.to
	if result and result.collider:
		target_point = result.position
		if _is_enemy_collider(result.collider):
			will_hit_enemy = true
			focal_point = target_point
			if result.collider is Node3D:
				impact_anchor = _get_enemy_aim_root(result.collider as Node3D)

	return {
		"target_point": target_point,
		"focal_point": focal_point,
		"will_hit_enemy": will_hit_enemy,
		"impact_anchor": impact_anchor
	}

## Slomo scale while watching the gun cam/firing.
@export var bullet_slomo: float = 0.2
## Slomo scale for the close-up impact view.
@export var impact_slomo: float = 0.05

func _perform_actual_shot(target_point: Vector3, will_hit_enemy: bool):
	combat_view_state = CombatViewState.FIRING_FROM_FIRE_CAM
	_set_analog_hud_visible(false)
	_stop_analog_heartbeat()

	if combat_bark_ui:
		combat_bark_ui.show_commit()

	# Apply bullet slomo
	Engine.time_scale = bullet_slomo

	if cannon_sound:
		cannon_sound.play()

	# Trigger Smoke
	var smoke = find_child("MuzzleSmoke", true)
	if smoke:
		smoke.restart()

	var dir_smoke = find_child("DirectionalSmoke", true)
	if dir_smoke:
		if dir_smoke.has_method("fire"):
			dir_smoke.fire()

	is_reloading = true
	reload_timer = 0.0
	cinematic_phase = 1 # ENTER Gun Cam Phase
	shot_muzzle_pos = muzzle.global_position
	cinematic_timer = 0.0
	has_missed_shot = false
	shot_resolved = false
	shot_will_hit_enemy = will_hit_enemy
	shot_collision_debug_reported = false
	impact_side_camera_active = false

	# Hold the dedicated firing camera through the visible muzzle/fire moment.
	var fire_camera = _get_fire_camera_marker()
	if fire_camera:
		cinematic_camera.global_transform = fire_camera.global_transform
		cinematic_camera.fov = fire_camera.fov

	# --- CONSISTENT IMPACT CAM ---
	var m_pos = muzzle.global_position
	var t_pos = target_hit_point
	var f_dir = (t_pos - m_pos).normalized()
	var s_dir = f_dir.cross(Vector3.UP).normalized()
	if s_dir.length() < 0.1: s_dir = Vector3.RIGHT

	# Pre-calculate the teleport spot: 2m back, 1m up, 1.5m side
	impact_cam_pos = t_pos - (f_dir * impact_cam_distance) + (s_dir * 1.5) + Vector3(0, 1.0, 0)

	var shell = PROJECTILE.instantiate()
	shell.shooter = self
	shell.is_player_shot = true
	shell.is_destined_for_hit = will_hit_enemy
	shell.speed = projectile_speed
	shell.collision_debug_enabled = projectile_collision_debug_enabled
	shell.collision_debug_mask = projectile_collision_debug_mask
	shell.collision_debug_log_path = projectile_collision_debug_log_path
	shell.collision_debug_path_interval = projectile_collision_debug_path_interval
	shell.collision_debug_resolve_sweep_hits = projectile_collision_debug_resolve_sweep_hits

	shell.has_hit.connect(func(body, hit_pos):
		if shot_resolved:
			return

		target_hit_point = hit_pos
		var is_enemy = _is_enemy_collider(body)
		shot_resolved = true

		if combat_bark_ui:
			combat_bark_ui.show_result(is_enemy, body.name if is_enemy else "")

		if not is_enemy and not has_missed_shot:
			has_missed_shot = true
			_play_near_miss_sound(hit_pos)
			var damage_number_script = preload("res://scripts/damage_number.gd")
			damage_number_script.display_text(hit_pos, "MISS", get_tree().current_scene, Color.ORANGE_RED)
		elif is_enemy:
			if hit_sound:
				hit_sound.global_position = hit_pos
				hit_sound.play()
	)

	get_tree().root.add_child(shell)

	# Spawn at muzzle position
	shell.global_position = muzzle.global_position

	shot_muzzle_pos = shell.global_position
	shell.look_at(target_point, Vector3.UP)
	active_shell = shell

	current_spread = max_spread
	recoil_tween = create_tween()
	visual_barrel_base_pos = visual_barrel.position

	# Recoil opposite to muzzle direction
	var recoil_vector = visual_barrel.transform.basis * (-muzzle.position.normalized() * 0.5)

	recoil_tween.tween_property(visual_barrel, "position", visual_barrel_base_pos + recoil_vector, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	recoil_tween.tween_property(visual_barrel, "position", visual_barrel_base_pos, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func hit():
	if is_dead: return
	armor -= 1
	damage_flash_timer = 2.0
	is_reloading = true
	reload_timer = 0.0

	# If we take a hit during the cinematic, violently abort the cinematic and slam back to cockpit
	cinematic_phase = 0
	combat_view_state = CombatViewState.NORMAL_VIEW
	_set_analog_hud_visible(false)
	_stop_analog_heartbeat()
	cinematic_camera.current = false
	camera.current = true

	for i in range(10):
		var shake_tween = create_tween()
		shake_tween.tween_property(camera, "h_offset", randf_range(-0.5, 0.5), 0.03)
		shake_tween.tween_property(camera, "v_offset", randf_range(-0.5, 0.5), 0.03)
	var reset_tween = create_tween()
	reset_tween.tween_property(camera, "h_offset", 0.0, 0.05).set_delay(0.3)
	reset_tween.tween_property(camera, "v_offset", 0.0, 0.05).set_delay(0.3)

	if armor <= 0:
		is_dead = true
		var death_tween = create_tween()
		death_tween.tween_property(self, "rotation_degrees:z", 85.0, 2.0).set_trans(Tween.TRANS_SINE)
		death_tween.tween_property(self, "position:y", -2.0, 2.0).set_parallel(true)

## How much to speed up time during the bullet's travel phase.
@export var travel_fast_forward: float = 3.5
## Distance from target to drop back into slomo for the impact cam.
@export var impact_slomo_threshold: float = 15.0

func _play_near_miss_sound(miss_position: Vector3):
	if miss_sound and _distance_to_nearest_enemy(miss_position) <= near_miss_sound_distance:
		miss_sound.global_position = miss_position
		miss_sound.play()

func _distance_to_nearest_enemy(position: Vector3) -> float:
	var nearest = INF
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node3D:
			nearest = min(nearest, position.distance_to(node.global_position))
	return nearest

func _update_impact_side_camera(_delta: float) -> void:
	if not is_instance_valid(active_shell):
		cinematic_phase = 3
		cinematic_timer = 0.0
		return

	var bullet_pos = active_shell.global_position
	var side_camera_zone = _get_impact_side_camera_world_position()
	var dist_to_camera_zone = bullet_pos.distance_to(side_camera_zone)
	if not impact_side_camera_active:
		Engine.time_scale = travel_fast_forward
		if dist_to_camera_zone <= impact_side_camera_trigger_distance:
			impact_side_camera_active = true
			_update_impact_side_camera_pose(bullet_pos, side_camera_zone)
	else:
		Engine.time_scale = impact_side_camera_time_scale
		_update_impact_side_camera_pose(bullet_pos, side_camera_zone)

	var passed_target = _has_shell_passed_target(bullet_pos)
	if passed_target:
		_debug_report_predicted_hit_without_collision(bullet_pos)
	if passed_target and not shot_will_hit_enemy:
		_resolve_missed_shot_at_target()

	if shot_resolved or passed_target:
		cinematic_phase = 3
		cinematic_timer = 0.0
		active_shell = null

func _update_legacy_impact_camera(delta: float) -> void:
	cinematic_camera.fov = impactcam_fov

	var drift_speed = 0.5
	cinematic_camera.global_position += Vector3.UP * (drift_speed * delta)
	var right_dir = cinematic_camera.global_transform.basis.x
	cinematic_camera.global_position += right_dir * (drift_speed * delta)

	if not is_instance_valid(active_shell):
		cinematic_phase = 3
		cinematic_timer = 0.0
		return

	var bullet_pos = active_shell.global_position
	cinematic_camera.look_at(bullet_pos, Vector3.UP)

	var dist_to_target = bullet_pos.distance_to(target_hit_point)
	if dist_to_target > impact_slomo_threshold:
		Engine.time_scale = travel_fast_forward
	else:
		Engine.time_scale = impact_slomo

	var passed_target = _has_shell_passed_target(bullet_pos)
	if passed_target:
		_debug_report_predicted_hit_without_collision(bullet_pos)
	if passed_target and not shot_will_hit_enemy:
		_resolve_missed_shot_at_target()

	if shot_resolved or passed_target:
		cinematic_phase = 3
		cinematic_timer = 0.0
		active_shell = null

func _update_impact_side_camera_pose(bullet_pos: Vector3, side_camera_zone: Vector3) -> void:
	cinematic_camera.fov = impact_side_camera_fov
	var blend = clampf(impact_side_camera_position_blend, 0.0, 1.0)
	if blend >= 1.0:
		cinematic_camera.global_position = side_camera_zone
	else:
		cinematic_camera.global_position = cinematic_camera.global_position.lerp(side_camera_zone, blend)
	cinematic_camera.look_at(bullet_pos + Vector3.UP * impact_side_camera_look_at_height_bias, Vector3.UP)

func _get_impact_side_camera_world_position() -> Vector3:
	var anchor = _get_impact_side_camera_anchor()
	if not anchor:
		return impact_cam_pos

	var hit_local = anchor.to_local(target_hit_point)
	var side_offset = impact_side_camera_left_local_offset
	if hit_local.x < 0.0:
		side_offset = impact_side_camera_right_local_offset
	return anchor.to_global(side_offset)

func _get_impact_side_camera_anchor() -> Node3D:
	if impact_side_camera_anchor and is_instance_valid(impact_side_camera_anchor):
		return impact_side_camera_anchor

	var target = _get_analog_target_node()
	if target:
		impact_side_camera_anchor = target
		return impact_side_camera_anchor

	var current_scene = get_tree().current_scene
	if current_scene:
		var zezlan = current_scene.find_child("zezlan", true)
		if zezlan is Node3D:
			impact_side_camera_anchor = zezlan as Node3D
			return impact_side_camera_anchor
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
	if combat_bark_ui:
		combat_bark_ui.show_result(false)
	_play_near_miss_sound(target_hit_point)
	var damage_number_script = preload("res://scripts/damage_number.gd")
	damage_number_script.display_text(target_hit_point, "MISS", get_tree().current_scene, Color.ORANGE_RED)
	shot_resolved = true

func _debug_report_predicted_hit_without_collision(bullet_pos: Vector3) -> void:
	if not projectile_collision_debug_enabled:
		return
	if shot_collision_debug_reported or shot_resolved or not shot_will_hit_enemy:
		return
	shot_collision_debug_reported = true
	print("[SHOT TRACE] predicted_hit=true but shell passed target without collision event target=", _fmt_debug_vec(target_hit_point), " shell=", _fmt_debug_vec(bullet_pos), " muzzle=", _fmt_debug_vec(shot_muzzle_pos), " likely=tunneling/missing collision layer/mask/or generated mesh collider gap")

func _fmt_debug_vec(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]

func _get_impact_resolve_linger_time() -> float:
	if impact_side_camera_enabled and impact_side_camera_active:
		return max(0.0, impact_side_camera_track_after_resolve_time)
	return 0.05

func _update_cinematic(delta: float):
	cinematic_timer += delta

	if cinematic_phase == 1:
		cinematic_camera.fov = _get_fire_camera_fov()
		if cinematic_timer >= 0.1:
			if recoil_tween and recoil_tween.is_running():
				recoil_tween.kill()
				visual_barrel.position = visual_barrel_base_pos

			cinematic_phase = 2
			if not impact_side_camera_enabled:
				cinematic_camera.global_position = impact_cam_pos
			cinematic_timer = 0.0
			return

	if cinematic_phase == 2: # IMPACT CAM VIEW
		if impact_side_camera_enabled:
			_update_impact_side_camera(delta)
		else:
			_update_legacy_impact_camera(delta)
		return

	if cinematic_phase == 3:
		if cinematic_timer >= _get_impact_resolve_linger_time():
			cinematic_phase = 0
			cinematic_timer = 0.0
			return

	if cinematic_phase == 0:
		Engine.time_scale = 1.0 # Normal speed
		if reload_timer >= reload_duration:
			is_reloading = false

		if combat_bark_ui:
			combat_bark_ui.hide_bark()

		cinematic_camera.current = false
		camera.current = true
		combat_view_state = CombatViewState.NORMAL_VIEW
		_set_analog_hud_visible(false)
		_stop_analog_heartbeat()
