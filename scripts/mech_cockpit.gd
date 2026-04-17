extends Node3D

@onready var camera = $Camera3D
@onready var cockpit_mesh = self
const PROJECTILE = preload("res://scenes/projectile.tscn")

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

@export_group("Impact Cam")
## Distance from the target to place the impact camera.
@export var impact_cam_distance: float = 10.0
@export var impactcam_timeout: float = 1.5
@export var impactcam_fov: float = 75.0
@export var impactcam_rotation_speed: float = 0.0 # 0 = No rotation
@export var near_miss_sound_distance: float = 4.0

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
@export var optic_sway_amplitude: float = 0.006
@export var optic_sway_speed: float = 0.55
@export var analog_target_center_height: float = 4.0
@export var analog_low_accuracy_drift_degrees: float = 3.8
@export var analog_high_accuracy_drift_degrees: float = 2.2
@export var analog_low_accuracy_drift_speed: float = 0.425
@export var analog_high_accuracy_drift_speed: float = 1.2
@export var analog_low_accuracy_correction_strength: float = 0.15
@export var analog_high_accuracy_correction_strength: float = 0.38
@export var analog_target_leash_softness: float = 0.62
@export var analog_erratic_pulse_strength: float = 0.78
@export var analog_jitter_layer_strength: float = 0.34
@export var analog_overshoot_allowance: float = 0.82
@export var aim_stage_1_fov: float = 44.0
@export var aim_stage_2_fov: float = 38.0
@export var aim_stage_3_fov: float = 32.0
@export var aim_stage_4_fov: float = 26.0
@export var aim_stage_5_fov: float = 20.0
@export var aim_stage_2_threshold: float = 0.20
@export var aim_stage_3_threshold: float = 0.40
@export var aim_stage_4_threshold: float = 0.60
@export var aim_stage_5_threshold: float = 0.80
@export var aim_zoom_blend_speed: float = 9.0
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

@export_group("Analog Aim Debug")
@export var analog_debug_enabled: bool = true
@export var analog_debug_sample_interval: float = 0.0 # 0.0 = Every Tick
@export var analog_debug_record_each_percent: bool = true
@export var analog_debug_print_samples: bool = true
@export var analog_debug_show_label: bool = true

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
var original_camera_rotation: Vector3
var aim_settle: float = 0.09
var hit_chance: float = 0.0
var fire_recovery: float = 0.0
var aim_zoom_stage: int = 1
var current_analog_drift_multiplier: float = 1.0
var aim_stage_bump_timer: float = 0.0
var smooth_max_accuracy: float = 0.7
var combat_view_state: int = CombatViewState.NORMAL_VIEW
var view_transition_tween: Tween
var analog_debug_file: FileAccess
var analog_debug_elapsed: float = 0.0
var analog_debug_session_time: float = 0.0
var analog_debug_last_on_target: bool = false
var analog_debug_last_stage: int = -1
var analog_debug_last_percent: int = -1
var analog_debug_label: Label

# --- RECOIL TRACKING ---
var recoil_tween: Tween
var visual_barrel_base_pos: Vector3

func _ready():
	add_to_group("player")
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
	get_tree().root.call_deferred("add_child", cinematic_camera) 
	_setup_analog_debug_label()
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
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if is_dead: return

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
		is_on_target = last_ray_result.collider.is_in_group("enemy") or "Enemy" in last_ray_result.collider.name
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
		_update_analog_scope_debug(delta)
	
	if analog_reticle_hud:
		# Range info is handled by the analog HUD now
		pass
		
	if Input.is_action_just_pressed("ui_accept"):
		fire_cannon()

func _update_analog_aim(delta: float) -> void:
	var target_point = _get_analog_target_point()
	if target_point != Vector3.ZERO and cinematic_camera != null:
		current_target_range = cinematic_camera.global_position.distance_to(target_point)
		is_on_target = true
	
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
	
	_update_aim_zoom_stage()
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

func _setup_analog_debug_label() -> void:
	if not analog_debug_show_label:
		return
	var canvas = get_node_or_null("CanvasLayer")
	if not canvas:
		return
	analog_debug_label = Label.new()
	analog_debug_label.name = "AnalogScopeDebug"
	analog_debug_label.visible = false
	analog_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	analog_debug_label.position = Vector2(16.0, 16.0)
	analog_debug_label.add_theme_font_size_override("font_size", 14)
	analog_debug_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.50, 0.95))
	analog_debug_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	canvas.add_child(analog_debug_label)

func _start_analog_debug_session() -> void:
	if not analog_debug_enabled:
		return
	analog_debug_elapsed = 0.0
	analog_debug_session_time = 0.0
	analog_debug_last_on_target = false
	analog_debug_last_stage = aim_zoom_stage
	analog_debug_last_percent = -1
	analog_debug_file = FileAccess.open("user://analog_scope_debug.csv", FileAccess.WRITE)
	if analog_debug_file:
		analog_debug_file.store_line("event,time_s,stage,hit_percent,percent_bucket,aim_settle,center_on_enemy,collider,center_range_m,target_range_m,off_target_m,off_target_deg,camera_fov")
		analog_debug_file.flush()
		print("Analog scope debug recording to user://analog_scope_debug.csv")
	if analog_debug_label:
		analog_debug_label.visible = true

func _end_analog_debug_session(reason: String) -> void:
	if not analog_debug_enabled:
		return
	if analog_debug_file:
		var sample = _sample_center_crosshair_target()
		_write_analog_debug_row("end_" + reason, sample)
		analog_debug_file.flush()
		analog_debug_file = null
	if analog_debug_label:
		analog_debug_label.visible = false

func _update_analog_scope_debug(delta: float) -> void:
	if not analog_debug_enabled or combat_view_state != CombatViewState.ANALOG_AIM_VIEW:
		return
	analog_debug_session_time += delta
	analog_debug_elapsed += delta
	var sample = _sample_center_crosshair_target()
	_update_analog_debug_label(sample)
	if analog_debug_record_each_percent:
		_record_analog_debug_percent_buckets(sample)
	
	if sample["on_enemy"] != analog_debug_last_on_target:
		analog_debug_last_on_target = sample["on_enemy"]
		_write_analog_debug_row("center_on_target_changed", sample)
		print("SCOPE CENTER ", "ON" if sample["on_enemy"] else "OFF", " TARGET | stage=", aim_zoom_stage, " | hit=", roundi(hit_chance * 100.0), "% | off=", "%.2f" % sample["off_target_m"], "m / ", "%.2f" % sample["off_target_deg"], "deg | collider=", sample["collider"])
	
	if aim_zoom_stage != analog_debug_last_stage:
		analog_debug_last_stage = aim_zoom_stage
		_write_analog_debug_row("stage_changed", sample)
		print("SCOPE STAGE ", aim_zoom_stage, " | hit=", roundi(hit_chance * 100.0), "% | center_on_target=", sample["on_enemy"])
	
	if analog_debug_elapsed >= analog_debug_sample_interval:
		analog_debug_elapsed = 0.0
		_write_analog_debug_row("sample", sample)
		if analog_debug_print_samples:
			print("SCOPE SAMPLE | stage=", aim_zoom_stage, " | hit=", roundi(hit_chance * 100.0), "% | center_on_target=", sample["on_enemy"], " | off=", "%.2f" % sample["off_target_m"], "m / ", "%.2f" % sample["off_target_deg"], "deg | collider=", sample["collider"])

func _record_analog_debug_percent_buckets(sample: Dictionary) -> void:
	var current_percent = clampi(int(floor(hit_chance * 100.0)), 0, 100)
	if analog_debug_last_percent < 0:
		analog_debug_last_percent = current_percent
		_write_analog_debug_row("percent_changed", sample, current_percent)
		return
	if current_percent == analog_debug_last_percent:
		return
	var step = 1 if current_percent > analog_debug_last_percent else -1
	var percent = analog_debug_last_percent + step
	while true:
		_write_analog_debug_row("percent_changed", sample, percent)
		if percent == current_percent:
			break
		percent += step
	analog_debug_last_percent = current_percent

func _sample_center_crosshair_target() -> Dictionary:
	var sample = {
		"on_enemy": false,
		"collider": "none",
		"range": 0.0,
		"off_target_m": 0.0,
		"off_target_deg": 0.0
	}
	if not cinematic_camera:
		return sample
	var target_point = _get_analog_target_point()
	var center_origin = cinematic_camera.global_position
	var center_dir = -cinematic_camera.global_transform.basis.z.normalized()
	if target_point != Vector3.ZERO:
		var to_target = target_point - center_origin
		var along_ray = to_target.dot(center_dir)
		var closest_point = center_origin + center_dir * max(0.0, along_ray)
		sample["off_target_m"] = closest_point.distance_to(target_point)
		if to_target.length() > 0.01:
			sample["off_target_deg"] = rad_to_deg(acos(clampf(center_dir.dot(to_target.normalized()), -1.0, 1.0)))
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = center_origin
	query.to = center_origin + (center_dir * 1000.0)
	var result = space_state.intersect_ray(query)
	if result and result.collider:
		var collider = result.collider
		sample["collider"] = collider.name if collider is Node else str(collider)
		sample["range"] = cinematic_camera.global_position.distance_to(result.position)
		sample["on_enemy"] = _is_enemy_collider(collider)
	return sample

func _is_enemy_collider(collider: Object) -> bool:
	if not collider:
		return false
	if collider is Node:
		var node = collider as Node
		if node.is_in_group("enemy") or "Enemy" in node.name:
			return true
		var parent = node.get_parent()
		while parent:
			if parent.is_in_group("enemy") or "Enemy" in parent.name:
				return true
			parent = parent.get_parent()
	return false

func _write_analog_debug_row(event_name: String, sample: Dictionary, percent_bucket: int = -1) -> void:
	if not analog_debug_file:
		return
	var fov_text = "0.00"
	if cinematic_camera:
		fov_text = "%.2f" % cinematic_camera.fov
	var percent_bucket_text = str(percent_bucket) if percent_bucket >= 0 else ""
	var row = [
		event_name,
		"%.3f" % analog_debug_session_time,
		str(aim_zoom_stage),
		str(roundi(hit_chance * 100.0)),
		percent_bucket_text,
		"%.3f" % aim_settle,
		str(sample["on_enemy"]),
		str(sample["collider"]).replace(",", "_"),
		"%.2f" % sample["range"],
		"%.2f" % current_target_range,
		"%.2f" % sample["off_target_m"],
		"%.2f" % sample["off_target_deg"],
		fov_text
	]
	analog_debug_file.store_line(",".join(row))
	analog_debug_file.flush()

func _update_analog_debug_label(sample: Dictionary) -> void:
	if not analog_debug_label:
		return
	analog_debug_label.text = "SCOPE DBG\nSTAGE %d | HIT %d%% | SETTLE %.2f\nCENTER ON TARGET: %s\nOFF TARGET: %.2fm / %.2fdeg\nCENTER HIT: %s @ %.1fm" % [
		aim_zoom_stage,
		roundi(hit_chance * 100.0),
		aim_settle,
		"YES" if sample["on_enemy"] else "NO",
		sample["off_target_m"],
		sample["off_target_deg"],
		sample["collider"],
		sample["range"]
	]

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
	
	var current_scene = get_tree().current_scene
	var charlie = current_scene.find_child("REF_Charlie", true) if current_scene else null
	var start_pos = gun_camera.global_position
	var target_pos = start_pos
	
	if charlie:
		# Use continuous aim_settle to drive the position for a perfectly smooth transition
		# We map the 0.09-1.0 settle range to 0.0-1.0 progress
		var progress = clampf((aim_settle - 0.09) / 0.91, 0.0, 1.0)
		target_pos = start_pos.lerp(charlie.global_position, progress)
		
		if aim_zoom_stage > 1:
			print("PROBE VIEW Progress: ", progress * 100, "% | Stage: ", aim_zoom_stage)
	
	# Physically move the camera
	cinematic_camera.global_position = cinematic_camera.global_position.lerp(target_pos, aim_zoom_blend_speed * delta)
	
	# Blend the FOV and Drift Multiplier
	cinematic_camera.fov = lerpf(cinematic_camera.fov, _get_aim_stage_fov(), aim_zoom_blend_speed * delta)
	current_analog_drift_multiplier = lerpf(current_analog_drift_multiplier, _get_aim_stage_drift_multiplier(), aim_zoom_blend_speed * delta)
	
	# Point at the drifted target point
	var target_point = _get_analog_target_point()
	if target_point != Vector3.ZERO:
		var drifted_point = _get_drifted_analog_target_point(target_point)
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
	_update_aim_zoom_stage()
	current_analog_drift_multiplier = _get_aim_stage_drift_multiplier()
	_start_analog_debug_session()

func _is_target_aligned() -> bool:
	if not alignment_required:
		return true
	return is_on_target

func _get_analog_target_node() -> Node3D:
	var fallback: Node3D = null
	var nearest = INF
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node):
			if node.name == "EnemyMech":
				return node
			var dist = global_position.distance_to(node.global_position)
			if dist < nearest:
				nearest = dist
				fallback = node
	return fallback

func _get_analog_target_point() -> Vector3:
	var current_scene = get_tree().current_scene
	var charlie = current_scene.find_child("REF_Charlie", true) if current_scene else null
	if charlie:
		return charlie.global_position
	
	var target = _get_analog_target_node()
	if target:
		# Prioritize the Torso node for center-mass anchoring
		var torso = target.find_child("Torso", true)
		if torso and torso is Node3D:
			return torso.global_position
		
		# Fallback to height offset if no torso node is found
		return target.global_position + Vector3.UP * analog_target_center_height
	
	if not last_ray_result.is_empty() and last_ray_result.has("position"):
		return last_ray_result.position
	return Vector3.ZERO

func _get_drifted_analog_target_point(target_point: Vector3) -> Vector3:
	var to_target = target_point - cinematic_camera.global_position
	var distance = to_target.length()
	if distance <= 0.01:
		return target_point
	
	var forward = to_target.normalized()
	var right = forward.cross(Vector3.UP).normalized()
	if right.length() < 0.01:
		right = cinematic_camera.global_transform.basis.x.normalized()
	var up = right.cross(forward).normalized()
	
	var t = Time.get_ticks_msec() * 0.001
	var quality = clampf(aim_settle, 0.0, 1.0)
	
	# --- 1. MECHANICAL WANDER ---
	# Faster frequency at high accuracy = "Faster Corrections"
	var speed_mod = lerpf(analog_low_accuracy_drift_speed, analog_high_accuracy_drift_speed, quality)
	var ph_x = t * speed_mod
	var ph_y = t * speed_mod * 0.82
	
	# Base pattern
	var wander_x = (sin(ph_x * 1.1) * 0.7 + sin(ph_x * 0.43) * 0.3)
	var wander_y = (cos(ph_y * 1.3) * 0.6 + sin(ph_y * 0.57) * 0.4)
	var drift_unit = Vector2(wander_x, wander_y)
	
	# --- 2. DAMPING (Authority) ---
	# Even weaker authority so it doesn't "snap" to center at high quality
	var authority = lerpf(0.005, 0.12, quality)
	drift_unit = drift_unit.lerp(Vector2.ZERO, authority)
	
	# --- 3. DYNAMIC ZONE CALCULATION ---
	# To hit ~4m at 70% (0.7 quality):
	# We use a very steep power curve (4.0) so it stays wide until the extreme end.
	# At 0.7: 0.7^4.0 = 0.24.
	# lerpf(1.5, 1.2, 0.24) = ~1.42m. With stage_mod (1.0), this is very stable.
	var stage_mod = current_analog_drift_multiplier
	var settle_curve = pow(quality, 4.0)
	var dynamic_limit = lerpf(1.5, 1.2, settle_curve) * stage_mod
	
	# Keep a high noise floor so it never feels locked
	var noise_floor = 0.35
	var noise_scalar = lerpf(1.2, noise_floor, quality)
	var noise_x = (sin(t * 3.1) * 0.5 + sin(t * 5.7) * 0.3) * noise_scalar
	var noise_y = (cos(t * 2.7) * 0.4 + sin(t * 6.8) * 0.3) * noise_scalar
	drift_unit.x += noise_x
	drift_unit.y += noise_y
	
	# Final radius uses the dynamic limit
	var final_radius = dynamic_limit * 0.95
	var final_point = target_point + (right * drift_unit.x + up * drift_unit.y) * final_radius
	
	# --- Final Safety Constraint ---
	var target = _get_analog_target_node()
	if target:
		# We still clamp just in case of extreme physics/noise spikes, but it won't "dwell" on the edge
		final_point.x = clamp(final_point.x, target_point.x - dynamic_limit, target_point.x + dynamic_limit)
		final_point.z = clamp(final_point.z, target_point.z - dynamic_limit, target_point.z + dynamic_limit)
		
		var ground_y = target.global_position.y
		var lower_bound = max(ground_y, target_point.y - dynamic_limit)
		final_point.y = clamp(final_point.y, lower_bound, target_point.y + dynamic_limit)
	
	return final_point

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

func _update_aim_zoom_stage() -> void:
	var next_stage = 1
	if aim_settle >= aim_stage_5_threshold:
		next_stage = 5
	elif aim_settle >= aim_stage_4_threshold:
		next_stage = 4
	elif aim_settle >= aim_stage_3_threshold:
		next_stage = 3
	elif aim_settle >= aim_stage_2_threshold:
		next_stage = 2
	
	if next_stage != aim_zoom_stage:
		aim_zoom_stage = next_stage
		aim_stage_bump_timer = 0.12

func _get_aim_stage_fov() -> float:
	match aim_zoom_stage:
		5: return aim_stage_5_fov
		4: return aim_stage_4_fov
		3: return aim_stage_3_fov
		2: return aim_stage_2_fov
		_: return aim_stage_1_fov

func _get_aim_stage_drift_multiplier() -> float:
	match aim_zoom_stage:
		5: return stage_5_drift_multiplier
		4: return stage_4_drift_multiplier
		3: return stage_3_drift_multiplier
		2: return stage_2_drift_multiplier
		_: return stage_1_drift_multiplier

func _apply_optic_sway() -> void:
	if combat_view_state != CombatViewState.ANALOG_AIM_VIEW or is_reloading or is_transitioning:
		return
	
	var t = Time.get_ticks_msec() * 0.001
	var stage_drift = _get_aim_stage_drift_multiplier()
	var settle_drift_trim = lerpf(1.18, 0.82, aim_settle)
	var drift_multiplier = stage_drift * settle_drift_trim
	var drift_amplitude = optic_sway_amplitude * drift_multiplier
	var sway_offset = Vector3(
		(sin(t * optic_sway_speed) + sin(t * optic_sway_speed * 0.37) * 0.45) * drift_amplitude,
		(cos(t * optic_sway_speed * 0.73) + sin(t * optic_sway_speed * 0.51) * 0.35) * drift_amplitude,
		0.0
	)
	if aim_stage_bump_timer > 0.0:
		sway_offset.x += sin(aim_stage_bump_timer * 52.0) * aim_stage_bump * (aim_stage_bump_timer / 0.12)
	cinematic_camera.rotation += sway_offset

func _disrupt_aim_after_fire() -> void:
	aim_settle = max(0.09, aim_settle - post_fire_solution_penalty)
	_update_aim_zoom_stage()
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
	
	_end_analog_debug_session("fire")
	is_transitioning = true
	combat_view_state = CombatViewState.FIRING_FROM_FIRE_CAM
	_set_analog_hud_visible(false)
	
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
	
	target_hit_point = shot_lock["focal_point"]
	_perform_actual_shot(shot_lock["target_point"], shot_lock["will_hit_enemy"])

func _build_shot_lock(source_camera: Camera3D) -> Dictionary:
	var random_x = randf_range(-current_spread, current_spread)
	var random_y = randf_range(-current_spread, current_spread)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = source_camera.global_position
	var forward_dir = -source_camera.global_transform.basis.z
	var spread_transform = Transform3D().rotated(Vector3.RIGHT, random_x).rotated(Vector3.UP, random_y)
	var final_dir = spread_transform * forward_dir
	query.to = source_camera.global_position + (final_dir * 500.0)
	var result = space_state.intersect_ray(query)
	
	var will_hit_enemy = false
	var focal_range = current_target_range if current_target_range > 0 else 100.0
	var focal_point = source_camera.global_position + (final_dir * focal_range)
	var target_point = query.to
	if result and result.collider:
		target_point = result.position
		if result.collider.is_in_group("enemy") or "Enemy" in result.collider.name:
			will_hit_enemy = true
			focal_point = target_point
	
	return {
		"target_point": target_point,
		"focal_point": focal_point,
		"will_hit_enemy": will_hit_enemy
	}

## Slomo scale while watching the gun cam/firing.
@export var bullet_slomo: float = 0.2
## Slomo scale for the close-up impact view.
@export var impact_slomo: float = 0.05

func _perform_actual_shot(target_point: Vector3, will_hit_enemy: bool):
	combat_view_state = CombatViewState.FIRING_FROM_FIRE_CAM
	_set_analog_hud_visible(false)
	
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
	
	shell.has_hit.connect(func(body, hit_pos):
		if shot_resolved:
			return
		
		target_hit_point = hit_pos 
		var is_enemy = body.is_in_group("enemy") or "Enemy" in body.name or (body.get_parent() and body.get_parent().is_in_group("enemy"))
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
	_end_analog_debug_session("hit_abort")
	_set_analog_hud_visible(false)
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

func _update_cinematic(delta: float):
	cinematic_timer += delta
	
	if cinematic_phase == 1:
		cinematic_camera.fov = _get_fire_camera_fov()
		if cinematic_timer >= 0.1:
			if recoil_tween and recoil_tween.is_running():
				recoil_tween.kill() 
				visual_barrel.position = visual_barrel_base_pos

			cinematic_phase = 2
			cinematic_camera.global_position = impact_cam_pos
			cinematic_timer = 0.0
			return

	if cinematic_phase == 2: # IMPACT CAM VIEW
		cinematic_camera.fov = impactcam_fov
		
		# HERO DRIFT
		var drift_speed = 0.5 
		cinematic_camera.global_position += Vector3.UP * (drift_speed * delta)
		var right_dir = cinematic_camera.global_transform.basis.x
		cinematic_camera.global_position += right_dir * (drift_speed * delta)
		
		if is_instance_valid(active_shell):
			var bullet_pos = active_shell.global_position
			# TRACK THE BULLET for a dynamic fly-by
			cinematic_camera.look_at(bullet_pos, Vector3.UP)
			
			var dist_to_target = bullet_pos.distance_to(target_hit_point)

			if dist_to_target > impact_slomo_threshold:
				Engine.time_scale = travel_fast_forward
			else:
				Engine.time_scale = impact_slomo

			var target_vector = target_hit_point - shot_muzzle_pos
			var shell_vector = bullet_pos - shot_muzzle_pos
			var passed_target = false
			if target_vector.length() > 0.001:
				passed_target = shell_vector.dot(target_vector.normalized()) >= target_vector.length()
			
			if passed_target and not shot_will_hit_enemy:
				if not has_missed_shot:
					has_missed_shot = true
					if combat_bark_ui:
						combat_bark_ui.show_result(false)
					_play_near_miss_sound(target_hit_point)
					var damage_number_script = preload("res://scripts/damage_number.gd")
					damage_number_script.display_text(target_hit_point, "MISS", get_tree().current_scene, Color.ORANGE_RED)
				shot_resolved = true
				active_shell = null

			if shot_resolved or passed_target:
				cinematic_phase = 3
				cinematic_timer = 0.0
				return
		else:
			cinematic_phase = 3
			cinematic_timer = 0.0
			return

	if cinematic_phase == 3:
		if cinematic_timer >= 0.05: 
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
		_end_analog_debug_session("normal_view")
		_set_analog_hud_visible(false)
