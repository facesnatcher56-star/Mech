extends Node3D

var camera: Camera3D = null
@onready var cockpit_mesh = self
const DEFAULT_ANALOG_HEARTBEAT = preload("res://assets/Sounds/heartbeats-61.wav")
const PLAYER_DAMAGE_MODEL = preload("res://scripts/player_damage_model.gd")
const COMBAT_DOSSIER_PRESENTER = preload("res://scripts/combat_dossier_presenter.gd")
const MAIN_CAMERA_CONTROLLER = preload("res://scripts/main_camera_controller.gd")
const ANALOG_HEARTBEAT_CONTROLLER = preload("res://scripts/analog_heartbeat_controller.gd")
const ENEMY_FIRE_CINEMATIC_CONTROLLER = preload("res://scripts/enemy_fire_cinematic_controller.gd")
const PROJECTILE_CINEMATIC_CONTROLLER = preload("res://scripts/projectile_cinematic_controller.gd")
const ANALOG_AIM_SOLUTION_CONTROLLER = preload("res://scripts/analog_aim_solution_controller.gd")
const ANALOG_TARGETING_CONTROLLER = preload("res://scripts/analog_targeting_controller.gd")
const PLAYER_FIRE_CONTROLLER = preload("res://scripts/player_fire_controller.gd")
const RELOAD_STATUS_CONTROLLER = preload("res://scripts/reload_status_controller.gd")
const GROUND_ALIGNMENT_CONTROLLER = preload("res://scripts/ground_alignment_controller.gd")
const PLAYER_HIT_RESPONSE_CONTROLLER = preload("res://scripts/player_hit_response_controller.gd")
const TARGET_QUERY_HELPER = preload("res://scripts/target_query_helper.gd")
const COMBAT_VIEW_FLOW_CONTROLLER = preload("res://scripts/combat_view_flow_controller.gd")

enum CombatViewState { NORMAL_VIEW, GUN_CAM_VIEW, ANALOG_AIM_VIEW, FIRING_FROM_FIRE_CAM }

var is_dead: bool = false

var mouse_sensitivity: float = 0.002
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
@onready var side_cam_mortar_sound = find_child("SideCamMortarSound", true)

var visual_barrel: Node3D

@export var visual_barrel_node: Node3D # Assign in Inspector
var muzzle: Node3D
var hit_sound: AudioStreamPlayer3D = null

# --- THE CINEMATIC DIRECTOR SETTINGS ---
@export_group("Main Camera")
## Current field of view.
@export var main_fov: float = 75.0
## Maximum possible zoom in (Tight view).
@export var min_fov_limit: float = 40.0
## Maximum optical zoom out. Keep this below fisheye territory; extra wide view comes from camera pullback.
@export var max_fov_limit: float = 82.0
@export var zoom_sensitivity: float = 5.0
@export_group("Player HP")
## Total player structure pool. Reaching zero kills the mech.
@export var max_structure_hp: int = 60
## Torso armor. Reaching zero also kills the mech.
@export var max_torso_hp: int = 40
## Left arm armor pool.
@export var max_left_arm_hp: int = 25
## Right arm armor pool.
@export var max_right_arm_hp: int = 25
## Left leg armor pool.
@export var max_left_leg_hp: int = 20
## Right leg armor pool.
@export var max_right_leg_hp: int = 20
## Damage taken per hit on any part.
@export var hit_damage: int = 20

@export_group("Main Camera Orbit")
## World-space offset from the mech origin that the normal-view camera orbits around.
@export var main_camera_orbit_target_offset: Vector3 = Vector3(0.0, 1.35, 0.0)
## Base orbit distance. Leave at 0 to derive it from the placed Camera3D.
@export var main_camera_orbit_distance: float = 0.0
## Lowest normal-view orbit pitch, in radians.
@export var main_camera_min_pitch: float = deg_to_rad(-35.0)
## Highest normal-view orbit pitch, in radians.
@export var main_camera_max_pitch: float = deg_to_rad(55.0)
## How quickly the camera settles onto its orbit position.
@export var main_camera_orbit_blend_speed: float = 12.0

@export_group("Gun Cam")
## FOV used during the gun-cam dolly-in transition.
@export var guncam_fov: float = 75.0

@export_group("Fire Cam")
## How long to hold the fire cam after the shot before tracking the shell.
@export var firecam_duration: float = 0.5
## FOV of the fire cam. Overrides the FireCam_R marker's built-in FOV.
@export var firecam_fov: float = 75.0

@export_group("Projectile")
## Speed applied to player-fired shells, in world units per second.
@export var projectile_speed: float = 150.0

@export_group("Impact Side Camera")
## Group name on a Marker3D node in the scene for the left/Charlie-side camera spawn.
@export var impact_side_cam_left_group: String = "side_cam_left"
## Group name on a Marker3D node in the scene for the right/Alpha-side camera spawn.
@export var impact_side_cam_right_group: String = "side_cam_right"
## Fallback: Charlie-side camera offset in Zezlan local space (used when no marker assigned).
@export var impact_side_camera_left_local_offset: Vector3 = Vector3(8.5, 0.5, 12.0)
## Fallback: Alpha-side camera offset in Zezlan local space (used when no marker assigned).
@export var impact_side_camera_right_local_offset: Vector3 = Vector3(-8.5, 0.5, 12.0)
## Projectile distance from the side camera zone that activates the side camera. Larger values switch to the tracking view earlier.
@export var impact_side_camera_trigger_distance: float = 40.0
## Field of view used after the side camera activates.
@export var impact_side_camera_fov: float = 60.0
## Engine time scale while the side camera tracks the projectile.
@export var impact_side_camera_time_scale: float = 0.05
## Vertical offset added to the projectile look-at target.
@export var impact_side_camera_look_at_height_bias: float = 0.0
## Per-frame blend toward the side camera position. 1.0 snaps instantly.
@export_range(0.0, 1.0, 0.05) var impact_side_camera_position_blend: float = 1.0
## How long to hold on the side cam after impact before returning to cockpit (game-time seconds).
@export var impact_side_camera_linger_duration: float = 1.5

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
var player_damage_model: Node = null
var dossier_presenter: Node = null
var main_camera_controller: Node = null
var analog_heartbeat_controller: Node = null
var enemy_fire_cinematic_controller: Node = null
var projectile_cinematic_controller: Node = null
var analog_aim_solution_controller: Node = null
var analog_targeting_controller: Node = null
var player_fire_controller: Node = null
var reload_status_controller: Node = null
var ground_alignment_controller: Node = null
var player_hit_response_controller: Node = null
var target_query_helper: Node = null
var combat_view_flow_controller: Node = null

func _ready():
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_build_mesh_colliders()
	_setup_player_damage_model()
	_setup_main_camera_controller()
	_setup_enemy_fire_cinematic_controller()
	_setup_analog_aim_solution_controller()
	_setup_reload_status_controller()
	_setup_ground_alignment_controller()
	_setup_target_query_helper()
	_setup_combat_view_flow_controller()
	_setup_player_hit_response_controller()
	hit_sound = _find_audio_player_3d("HitSound")
	_set_analog_hud_visible(false)

	call_deferred("_setup_big_gun")

	cinematic_camera = Camera3D.new()
	cinematic_camera.current = false
	_setup_analog_targeting_controller()
	_setup_analog_heartbeat_controller()
	get_tree().root.call_deferred("add_child", cinematic_camera)
	_setup_projectile_cinematic_controller()
	_setup_player_fire_controller()
	call_deferred("_setup_dossier_presenter")
	call_deferred("_finalize_combat_view_flow_refs")

func _setup_analog_heartbeat_controller() -> void:
	analog_heartbeat_controller = ANALOG_HEARTBEAT_CONTROLLER.new()
	analog_heartbeat_controller.name = "AnalogHeartbeatController"
	add_child(analog_heartbeat_controller)
	analog_heartbeat_controller.configure(
		cinematic_camera,
		analog_heartbeat_stream,
		analog_heartbeat_volume_db,
		analog_heartbeat_pitch_scale,
		Callable(self, "_should_loop_analog_heartbeat")
	)

func _setup_analog_aim_solution_controller() -> void:
	analog_aim_solution_controller = ANALOG_AIM_SOLUTION_CONTROLLER.new()
	analog_aim_solution_controller.name = "AnalogAimSolutionController"
	add_child(analog_aim_solution_controller)
	analog_aim_solution_controller.configure({
		"aim_settle_speed": aim_settle_speed,
		"post_fire_solution_penalty": post_fire_solution_penalty,
		"post_fire_recovery_time": post_fire_recovery_time,
		"accuracy_slowdown_power": accuracy_slowdown_power,
		"short_range_max": short_range_max,
		"medium_range_max": medium_range_max,
		"minimum_max_hit_chance": minimum_max_hit_chance,
		"short_max_hit_chance": short_max_hit_chance,
		"medium_max_hit_chance": medium_max_hit_chance,
		"long_max_hit_chance": long_max_hit_chance,
		"stage_thresholds": [
			0.0,
			aim_solution_stage_2_threshold,
			aim_solution_stage_3_threshold,
			aim_solution_stage_4_threshold,
			aim_solution_stage_5_threshold
		],
		"camera_stage_times": [
			aim_camera_stage_1_time,
			aim_camera_stage_2_time,
			aim_camera_stage_3_time,
			aim_camera_stage_4_time,
			0.0
		],
		"stage_fovs": [
			aim_stage_1_fov,
			aim_stage_2_fov,
			aim_stage_3_fov,
			aim_stage_4_fov,
			aim_stage_5_fov
		],
		"drift_multipliers": [
			stage_1_drift_multiplier,
			stage_2_drift_multiplier,
			stage_3_drift_multiplier,
			stage_4_drift_multiplier,
			stage_5_drift_multiplier
		],
		"stroke_speed_multipliers": [
			stage_1_stroke_speed_multiplier,
			stage_2_stroke_speed_multiplier,
			stage_3_stroke_speed_multiplier,
			stage_4_stroke_speed_multiplier,
			stage_5_stroke_speed_multiplier
		]
	})

func _setup_analog_targeting_controller() -> void:
	analog_targeting_controller = ANALOG_TARGETING_CONTROLLER.new()
	analog_targeting_controller.name = "AnalogTargetingController"
	add_child(analog_targeting_controller)
	analog_targeting_controller.configure({
		"cockpit": self,
		"aim_camera": cinematic_camera,
		"is_enemy_collider_callable": Callable(self, "_is_enemy_collider"),
		"is_enemy_target_node_callable": Callable(self, "_is_enemy_target_node"),
		"target_center_height": analog_target_center_height,
		"low_accuracy_overshoot_scale": analog_low_accuracy_overshoot_scale,
		"high_accuracy_overshoot_scale": analog_high_accuracy_overshoot_scale,
		"low_accuracy_stroke_duration": analog_low_accuracy_stroke_duration,
		"high_accuracy_stroke_duration": analog_high_accuracy_stroke_duration,
		"max_distance_from_frame": analog_max_distance_from_frame,
		"visible_frame_min_padding": analog_visible_frame_min_padding
	})

func _setup_reload_status_controller() -> void:
	reload_status_controller = RELOAD_STATUS_CONTROLLER.new()
	reload_status_controller.name = "ReloadStatusController"
	add_child(reload_status_controller)
	reload_status_controller.configure({
		"max_spread": max_spread,
		"reload_duration": reload_duration,
		"current_spread": current_spread,
		"is_reloading": is_reloading,
		"reload_timer": reload_timer
	})

func _setup_ground_alignment_controller() -> void:
	ground_alignment_controller = GROUND_ALIGNMENT_CONTROLLER.new()
	ground_alignment_controller.name = "GroundAlignmentController"
	add_child(ground_alignment_controller)
	ground_alignment_controller.configure({
		"body": self
	})

func _setup_target_query_helper() -> void:
	target_query_helper = TARGET_QUERY_HELPER.new()
	target_query_helper.name = "TargetQueryHelper"
	add_child(target_query_helper)
	target_query_helper.configure({
		"root": self,
		"sweep_exclusions_callable": Callable(self, "_get_sweep_exclusions")
	})

func _setup_combat_view_flow_controller() -> void:
	combat_view_flow_controller = COMBAT_VIEW_FLOW_CONTROLLER.new()
	combat_view_flow_controller.name = "CombatViewFlowController"
	add_child(combat_view_flow_controller)
	combat_view_flow_controller.configure({"cockpit": self})
	combat_view_flow_controller.analog_hud_visibility_changed.connect(_set_analog_hud_visible)
	combat_view_flow_controller.analog_heartbeat_play_requested.connect(_play_analog_heartbeat)
	combat_view_flow_controller.analog_heartbeat_stop_requested.connect(_stop_analog_heartbeat)
	combat_view_flow_controller.target_dossier_show_requested.connect(_show_target_dossier)
	combat_view_flow_controller.target_dossier_hide_requested.connect(_hide_target_dossier)
	combat_view_flow_controller.targeting_stroke_reset_requested.connect(_reset_analog_targeting_stroke)
	combat_view_flow_controller.targeting_drift_changed.connect(_set_analog_targeting_drift)
	combat_view_flow_controller.fire_sequence_requested.connect(_begin_fire_sequence_from_lock)

func _finalize_combat_view_flow_refs() -> void:
	if enemy_fire_cinematic_controller and enemy_fire_cinematic_controller.has_method("configure_cameras"):
		var scene := get_tree().current_scene
		enemy_fire_cinematic_controller.configure_cameras(
			scene.find_child("FiringSequenceCam", true, false) as Camera3D,
			scene.find_child("ActionCamA", true, false) as Camera3D,
			scene.find_child("ActionCamB", true, false) as Camera3D
		)

	if not combat_view_flow_controller:
		return
	combat_view_flow_controller.set_runtime_refs({
		"gun_cam": find_child("GunCam_R", true) as Camera3D,
		"fire_cam": find_child("FireCam_R", true) as Camera3D,
		"cinematic_camera": cinematic_camera,
		"player_camera": camera,
		"analog_targeting_controller": analog_targeting_controller,
		"analog_aim_solution_controller": analog_aim_solution_controller,
		"enemy_fire_cinematic_controller": enemy_fire_cinematic_controller,
	})

func _setup_player_hit_response_controller() -> void:
	player_hit_response_controller = PLAYER_HIT_RESPONSE_CONTROLLER.new()
	player_hit_response_controller.name = "PlayerHitResponseController"
	add_child(player_hit_response_controller)
	player_hit_response_controller.configure({
		"cockpit": self,
		"player_damage_model": player_damage_model,
		"projectile_cinematic_controller": projectile_cinematic_controller,
		"dossier_presenter": dossier_presenter
	})
	player_hit_response_controller.reload_started.connect(_start_weapon_reload)

func _refresh_player_hit_response_controller() -> void:
	if not player_hit_response_controller:
		return
	player_hit_response_controller.refresh_runtime_refs({
		"player_damage_model": player_damage_model,
		"projectile_cinematic_controller": projectile_cinematic_controller,
		"dossier_presenter": dossier_presenter
	})

func _should_loop_analog_heartbeat() -> bool:
	return combat_view_flow_controller and combat_view_flow_controller.combat_view_state == CombatViewState.ANALOG_AIM_VIEW

func _play_analog_heartbeat() -> void:
	if analog_heartbeat_controller and analog_heartbeat_controller.has_method("play"):
		analog_heartbeat_controller.play(analog_heartbeat_stream, analog_heartbeat_volume_db, analog_heartbeat_pitch_scale)

func _stop_analog_heartbeat() -> void:
	if analog_heartbeat_controller and analog_heartbeat_controller.has_method("stop"):
		analog_heartbeat_controller.stop()

func _reset_analog_aim_solution() -> float:
	if analog_aim_solution_controller:
		analog_aim_solution_controller.reset_for_aim()
		return analog_aim_solution_controller.get_stage_drift_multiplier()
	return 1.0

func _reset_analog_targeting_stroke() -> void:
	if analog_targeting_controller:
		analog_targeting_controller.reset_stroke()

func _set_analog_targeting_drift(multiplier: float) -> void:
	if analog_targeting_controller:
		analog_targeting_controller.set_drift_multiplier(multiplier)

func _setup_dossier_presenter() -> void:
	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		return
	dossier_presenter = COMBAT_DOSSIER_PRESENTER.new()
	dossier_presenter.name = "CombatDossierPresenter"
	add_child(dossier_presenter)
	dossier_presenter.configure(self, canvas_layer)
	_refresh_player_fire_controller()
	_refresh_player_hit_response_controller()

func _setup_player_damage_model() -> void:
	player_damage_model = PLAYER_DAMAGE_MODEL.new()
	player_damage_model.name = "PlayerDamageModel"
	add_child(player_damage_model)
	player_damage_model.configure({
		"max_structure_hp": max_structure_hp,
		"max_torso_hp": max_torso_hp,
		"max_left_arm_hp": max_left_arm_hp,
		"max_right_arm_hp": max_right_arm_hp,
		"max_left_leg_hp": max_left_leg_hp,
		"max_right_leg_hp": max_right_leg_hp,
		"hit_damage": hit_damage
	})
	player_damage_model.reset()
	player_damage_model.destroyed.connect(_on_player_destroyed)
	is_dead = player_damage_model.is_dead
	_refresh_player_hit_response_controller()

func _setup_main_camera_controller() -> void:
	main_camera_controller = MAIN_CAMERA_CONTROLLER.new()
	main_camera_controller.name = "MainCameraController"
	add_child(main_camera_controller)
	main_camera_controller.configure({
		"cockpit": self,
		"main_fov": main_fov,
		"min_fov_limit": min_fov_limit,
		"max_fov_limit": max_fov_limit,
		"zoom_sensitivity": zoom_sensitivity,
		"orbit_target_offset": main_camera_orbit_target_offset,
		"orbit_distance": main_camera_orbit_distance,
		"min_pitch": main_camera_min_pitch,
		"max_pitch": main_camera_max_pitch,
		"orbit_blend_speed": main_camera_orbit_blend_speed
	})
	camera = main_camera_controller.bind_initial_camera()

func _setup_enemy_fire_cinematic_controller() -> void:
	enemy_fire_cinematic_controller = ENEMY_FIRE_CINEMATIC_CONTROLLER.new()
	enemy_fire_cinematic_controller.name = "EnemyFireCinematicController"
	var root = get_tree().root.get_child(0)
	root.add_child.call_deferred(enemy_fire_cinematic_controller)

func _setup_projectile_cinematic_controller() -> void:
	projectile_cinematic_controller = PROJECTILE_CINEMATIC_CONTROLLER.new()
	projectile_cinematic_controller.name = "ProjectileCinematicController"
	add_child(projectile_cinematic_controller)
	projectile_cinematic_controller.configure({
		"cockpit": self,
		"cinematic_camera": cinematic_camera,
		"player_camera": camera,
		"side_cam_mortar_sound": side_cam_mortar_sound,
		"analog_targeting_controller": analog_targeting_controller,
		"firecam_duration": firecam_duration,
		"firecam_fov": firecam_fov,
		"side_cam_left_group": impact_side_cam_left_group,
		"side_cam_right_group": impact_side_cam_right_group,
		"side_camera_left_local_offset": impact_side_camera_left_local_offset,
		"side_camera_right_local_offset": impact_side_camera_right_local_offset,
		"side_camera_trigger_distance": impact_side_camera_trigger_distance,
		"side_camera_fov": impact_side_camera_fov,
		"side_camera_time_scale": impact_side_camera_time_scale,
		"side_camera_look_at_height_bias": impact_side_camera_look_at_height_bias,
		"side_camera_position_blend": impact_side_camera_position_blend,
		"side_camera_linger_duration": impact_side_camera_linger_duration,
		"travel_fast_forward": travel_fast_forward
	})
	projectile_cinematic_controller.shot_missed.connect(_on_projectile_cinematic_miss)
	projectile_cinematic_controller.cinematic_ended.connect(_on_projectile_cinematic_end)
	_refresh_player_hit_response_controller()

func _setup_player_fire_controller() -> void:
	player_fire_controller = PLAYER_FIRE_CONTROLLER.new()
	player_fire_controller.name = "PlayerFireController"
	add_child(player_fire_controller)
	player_fire_controller.configure({
		"cockpit": self,
		"target_query_helper": target_query_helper,
		"analog_targeting_controller": analog_targeting_controller,
		"projectile_cinematic_controller": projectile_cinematic_controller,
		"combat_bark_ui": combat_bark_ui,
		"dossier_presenter": dossier_presenter,
		"cannon_sound": cannon_sound,
		"hit_sound": hit_sound,
		"visual_barrel": visual_barrel,
		"muzzle": muzzle,
		"fire_cam": find_child("FireCam_R", true) as Camera3D,
		"projectile_speed": projectile_speed,
		"bullet_slomo": bullet_slomo
	})
	player_fire_controller.reload_started.connect(_start_weapon_reload)

func _refresh_player_fire_controller() -> void:
	if not player_fire_controller:
		return
	player_fire_controller.refresh_runtime_refs({
		"projectile_cinematic_controller": projectile_cinematic_controller,
		"combat_bark_ui": combat_bark_ui,
		"dossier_presenter": dossier_presenter,
		"cannon_sound": cannon_sound,
		"hit_sound": hit_sound,
		"visual_barrel": visual_barrel,
		"muzzle": muzzle,
		"fire_cam": find_child("FireCam_R", true) as Camera3D,
		"projectile_speed": projectile_speed,
		"bullet_slomo": bullet_slomo
	})

func get_hp_snapshot() -> Dictionary:
	if player_damage_model and player_damage_model.has_method("get_hp_snapshot"):
		return player_damage_model.get_hp_snapshot()
	return {}

func _show_target_dossier() -> void:
	if dossier_presenter and dossier_presenter.has_method("show_target_dossier"):
		dossier_presenter.show_target_dossier()

func _hide_target_dossier() -> void:
	if dossier_presenter and dossier_presenter.has_method("hide_target_dossier"):
		dossier_presenter.hide_target_dossier()

func _get_current_target_hp_snapshot() -> Dictionary:
	if dossier_presenter and dossier_presenter.has_method("get_current_target_hp_snapshot"):
		return dossier_presenter.get_current_target_hp_snapshot()
	return {}

func _find_damage_model_node(start_node: Node) -> Node:
	if dossier_presenter and dossier_presenter.has_method("find_damage_model_node"):
		return dossier_presenter.find_damage_model_node(start_node)
	return null

func _apply_enemy_damage(body: Node, hit_pos: Vector3) -> Dictionary:
	if dossier_presenter and dossier_presenter.has_method("apply_enemy_damage"):
		return dossier_presenter.apply_enemy_damage(body, hit_pos)
	return {}

func _setup_big_gun():
	visual_barrel = find_child("RightArm", true)

	if visual_barrel:
		muzzle = visual_barrel.get_node_or_null("Muzzle")
		if not muzzle:
			push_warning("MechCockpit: Muzzle marker not found under RightArm — projectile spawn will be wrong.")
	_refresh_player_fire_controller()

func _input(event):
	if is_dead: return
	if not _is_player_view_current():
		return

	# Smooth Zoom Input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_begin_aim_flow()
			return
		if main_camera_controller and main_camera_controller.has_method("handle_mouse_button"):
			if main_camera_controller.handle_mouse_button(event):
				return

	if event is InputEventMouseMotion and combat_view_flow_controller.combat_view_state == CombatViewState.NORMAL_VIEW and not is_reloading and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if main_camera_controller and main_camera_controller.has_method("handle_orbit_motion"):
			main_camera_controller.handle_orbit_motion(event.relative, mouse_sensitivity)

var current_target_range: float = 0.0
var is_on_target: bool = false
var last_ray_result: Dictionary = {}

func _process(delta):
	if is_dead: return
	if not is_instance_valid(camera):
		_try_bind_main_camera()

	# Butter-Smooth Blend
	if main_camera_controller and main_camera_controller.has_method("update_fov"):
		main_camera_controller.update_fov(delta, combat_view_flow_controller.is_transitioning)

	if player_damage_model and player_damage_model.has_method("update"):
		player_damage_model.update(delta)
		is_dead = player_damage_model.is_dead

	if ground_alignment_controller:
		ground_alignment_controller.update(delta)

	var reload_progress = _update_reload_status(delta)

	# Push player reload into self dossier every frame
	if dossier_presenter and dossier_presenter.has_method("update_self_status"):
		dossier_presenter.update_self_status(get_hp_snapshot(), reload_progress)

	if dossier_presenter and dossier_presenter.has_method("update_enemy_reload"):
		var enemy_snap := _get_enemy_hp_snapshot()
		if not enemy_snap.is_empty():
			dossier_presenter.update_enemy_reload(enemy_snap)


	if projectile_cinematic_controller and projectile_cinematic_controller.has_method("is_active"):
		if projectile_cinematic_controller.is_active():
			projectile_cinematic_controller.update(delta)

	if enemy_fire_cinematic_controller and enemy_fire_cinematic_controller.has_method("is_active"):
		if enemy_fire_cinematic_controller.is_active():
			enemy_fire_cinematic_controller.update(delta)

	if combat_view_flow_controller.combat_view_state == CombatViewState.NORMAL_VIEW and not combat_view_flow_controller.is_transitioning:
		if main_camera_controller and main_camera_controller.has_method("update_orbit"):
			main_camera_controller.update_orbit(delta, sway_time, base_sway_amount, current_spread)

	# --- Real-time Ranging ---
	var aim_camera = _get_aim_query_camera()
	if aim_camera:
		last_ray_result = _intersect_target_ray(aim_camera, 1000.0)

		if last_ray_result:
			current_target_range = aim_camera.global_position.distance_to(last_ray_result.position)
			is_on_target = _is_enemy_collider(last_ray_result.collider)
		else:
			current_target_range = 0.0
			is_on_target = false
	else:
		last_ray_result = {}
		current_target_range = 0.0
		is_on_target = false

	if combat_view_flow_controller.combat_view_state == CombatViewState.ANALOG_AIM_VIEW:
		_update_analog_aim(delta)

	sway_time += delta
	if combat_view_flow_controller.combat_view_state == CombatViewState.GUN_CAM_VIEW and not combat_view_flow_controller.is_transitioning:
		_sync_plain_gun_camera()
	elif combat_view_flow_controller.combat_view_state == CombatViewState.ANALOG_AIM_VIEW and not combat_view_flow_controller.is_transitioning:
		_update_analog_camera_presentation(delta)

	if analog_reticle_hud:
		# Range info is handled by the analog HUD now
		pass

	if _is_player_view_current() and Input.is_action_just_pressed("ui_accept"):
		fire_cannon()

func _is_player_view_current() -> bool:
	return (camera != null and camera.current) or (cinematic_camera != null and cinematic_camera.current)

func _try_bind_main_camera() -> void:
	if main_camera_controller and main_camera_controller.has_method("try_bind_camera"):
		camera = main_camera_controller.try_bind_camera()
	hit_sound = _find_audio_player_3d("HitSound")

func _find_audio_player_3d(node_name: String) -> AudioStreamPlayer3D:
	if main_camera_controller and main_camera_controller.has_method("find_audio_player_3d"):
		return main_camera_controller.find_audio_player_3d(node_name)
	return null

func _update_analog_aim(delta: float) -> void:
	var target_point = _get_analog_target_point()
	if target_point != Vector3.ZERO and cinematic_camera != null:
		current_target_range = cinematic_camera.global_position.distance_to(target_point)
		is_on_target = not last_ray_result.is_empty() and last_ray_result.has("collider") and _is_enemy_collider(last_ray_result.collider)

	if not analog_aim_solution_controller:
		return

	var display = analog_aim_solution_controller.update(delta, current_target_range)

	if analog_reticle_hud:
		analog_reticle_hud.set_solution(float(display["hit_chance"]), str(display["range_band"]), true)

func _get_aim_query_camera() -> Camera3D:
	if combat_view_flow_controller.combat_view_state != CombatViewState.NORMAL_VIEW and cinematic_camera:
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
	return firecam_fov

func _set_analog_hud_visible(is_visible: bool) -> void:
	if analog_reticle_hud:
		analog_reticle_hud.visible = is_visible
	if dossier_presenter and dossier_presenter.has_method("sync_view_visibility"):
		dossier_presenter.sync_view_visibility(combat_view_flow_controller.combat_view_state == CombatViewState.NORMAL_VIEW)

func _intersect_target_ray(source_camera: Camera3D, max_distance: float) -> Dictionary:
	if target_query_helper:
		return target_query_helper.intersect_target_ray(source_camera, max_distance)
	return {}

func _is_world_targeting_noise(collider: Object) -> bool:
	if target_query_helper:
		return target_query_helper.is_world_targeting_noise(collider)
	return false

func _is_enemy_collider(collider: Object) -> bool:
	if target_query_helper:
		return target_query_helper.is_enemy_collider(collider)
	return false

func _is_enemy_target_node(node: Node) -> bool:
	if target_query_helper:
		return target_query_helper.is_enemy_target_node(node)
	return false

func _is_player_tree_node(node: Node) -> bool:
	if target_query_helper:
		return target_query_helper.is_player_tree_node(node)
	return false

func _sync_plain_gun_camera() -> void:
	if combat_view_flow_controller:
		combat_view_flow_controller.sync_plain_gun_camera(guncam_fov)

func _update_analog_camera_presentation(delta: float) -> void:
	if combat_view_flow_controller:
		combat_view_flow_controller.update_analog_camera_presentation(
			delta,
			last_ray_result,
			aim_zoom_blend_speed,
			aim_camera_chunk_jump_amount,
			aim_camera_chunk_settle_speed
		)

func begin_enemy_fire_cinematic(fire_callable: Callable) -> void:
	if get_tree().get_nodes_in_group("shell_in_flight").size() > 0:
		return
	if combat_view_flow_controller:
		combat_view_flow_controller.reset_to_normal(CombatViewState.NORMAL_VIEW)

	if enemy_fire_cinematic_controller and enemy_fire_cinematic_controller.has_method("begin"):
		enemy_fire_cinematic_controller.begin(fire_callable, camera, cinematic_camera, is_dead, Callable(self, "_end_cinematic_if_active"))
	else:
		fire_callable.call()

func set_enemy_active_shell(shell: Node3D, impact_pos: Vector3) -> void:
	if enemy_fire_cinematic_controller and enemy_fire_cinematic_controller.has_method("set_active_shell"):
		enemy_fire_cinematic_controller.set_active_shell(shell, impact_pos)

func _end_cinematic_if_active() -> void:
	if projectile_cinematic_controller and projectile_cinematic_controller.has_method("is_active"):
		if projectile_cinematic_controller.is_active():
			projectile_cinematic_controller.end()

func _is_enemy_fire_cinematic_active() -> bool:
	if enemy_fire_cinematic_controller and enemy_fire_cinematic_controller.has_method("is_active"):
		return enemy_fire_cinematic_controller.is_active()
	return false

func _begin_aim_flow() -> void:
	if not is_instance_valid(camera):
		_try_bind_main_camera()
	if combat_view_flow_controller:
		combat_view_flow_controller.begin_aim_flow(is_reloading, CombatViewState.NORMAL_VIEW, CombatViewState.GUN_CAM_VIEW, CombatViewState.ANALOG_AIM_VIEW, transition_time, guncam_fov)

func _enter_analog_aim_view() -> void:
	if combat_view_flow_controller:
		combat_view_flow_controller.enter_analog_aim_view(CombatViewState.ANALOG_AIM_VIEW, last_ray_result)

func _is_target_aligned() -> bool:
	if not alignment_required:
		return true
	return is_on_target

func _get_analog_target_node() -> Node3D:
	if analog_targeting_controller:
		return analog_targeting_controller.get_target_node()
	return null

func _get_enemy_aim_root(node: Node3D) -> Node3D:
	if analog_targeting_controller:
		return analog_targeting_controller.get_enemy_aim_root(node)
	return node

func _get_analog_target_point() -> Vector3:
	if analog_targeting_controller:
		return analog_targeting_controller.get_target_point(last_ray_result)
	return Vector3.ZERO

func _get_analog_camera_target_point() -> Vector3:
	if analog_targeting_controller:
		return analog_targeting_controller.get_camera_target_point(last_ray_result)
	return _get_analog_target_point()

func _get_drifted_analog_target_point(target_point: Vector3, delta: float) -> Vector3:
	var quality = 0.0
	var stroke_speed_multiplier = 1.0
	if analog_aim_solution_controller:
		quality = analog_aim_solution_controller.get_quality()
		stroke_speed_multiplier = analog_aim_solution_controller.get_stage_stroke_speed_multiplier()
	if analog_targeting_controller:
		return analog_targeting_controller.get_drifted_target_point(target_point, delta, quality, stroke_speed_multiplier)
	return target_point

func _is_unit_stable() -> bool:
	return not is_reloading

func _update_reload_status(delta: float) -> float:
	if not reload_status_controller:
		return 1.0
	var state = reload_status_controller.update(delta)
	is_reloading = bool(state["is_reloading"])
	reload_timer = float(state["reload_timer"])
	current_spread = float(state["current_spread"])
	return float(state["reload_progress"])

func _disrupt_aim_after_fire() -> void:
	if not analog_aim_solution_controller:
		return
	var display = analog_aim_solution_controller.disrupt_after_fire(current_target_range)

	if analog_reticle_hud:
		analog_reticle_hud.set_solution(float(display["hit_chance"]), str(display["range_band"]), true)

@export_group("Cinematic Transition")
## How long the camera takes to fly from cockpit to gun.
@export var transition_time: float = 0.5
## How much to slow down time during the transition (0.1 = 10% speed).
@export var slomo_scale: float = 0.1

func fire_cannon():
	if is_reloading or combat_view_flow_controller.is_transitioning or _is_enemy_fire_cinematic_active() or get_tree().get_nodes_in_group("shell_in_flight").size() > 0:
		return

	if combat_view_flow_controller.combat_view_state == CombatViewState.NORMAL_VIEW:
		_begin_aim_flow()
		return

	if combat_view_flow_controller.combat_view_state == CombatViewState.GUN_CAM_VIEW:
		_enter_analog_aim_view()
		return

	if combat_view_flow_controller.combat_view_state != CombatViewState.ANALOG_AIM_VIEW:
		return

	var shot_lock = _build_shot_lock(cinematic_camera)
	_disrupt_aim_after_fire()
	_return_to_fire_cam_then_fire(shot_lock)

func _return_to_fire_cam_then_fire(shot_lock: Dictionary) -> void:
	if combat_view_flow_controller:
		combat_view_flow_controller.return_to_fire_cam_then_fire(shot_lock, CombatViewState.FIRING_FROM_FIRE_CAM, analog_to_fire_cam_return_time)

func _begin_fire_sequence_from_lock(shot_lock: Dictionary) -> void:
	_perform_actual_shot(
		shot_lock["target_point"],
		shot_lock["will_hit_enemy"],
		shot_lock["focal_point"],
		shot_lock.get("impact_anchor", null) as Node3D
	)

func _build_shot_lock(source_camera: Camera3D) -> Dictionary:
	_refresh_player_fire_controller()
	if player_fire_controller:
		return player_fire_controller.build_shot_lock(source_camera, current_target_range)
	return {}

## Slomo scale while watching the gun cam/firing.
@export var bullet_slomo: float = 0.2

func _perform_actual_shot(target_point: Vector3, will_hit_enemy: bool, focal_point: Vector3, impact_anchor: Node3D):
	_refresh_player_fire_controller()
	if player_fire_controller:
		player_fire_controller.perform_actual_shot(target_point, will_hit_enemy, focal_point, impact_anchor)

func _start_weapon_reload() -> void:
	if reload_status_controller:
		reload_status_controller.start_reload()
		var state = reload_status_controller.get_state()
		is_reloading = bool(state["is_reloading"])
		reload_timer = float(state["reload_timer"])
		current_spread = float(state["current_spread"])
	else:
		is_reloading = true
		reload_timer = 0.0
		current_spread = max_spread

func hit():
	_refresh_player_hit_response_controller()
	if player_hit_response_controller:
		is_dead = player_hit_response_controller.apply_hit(camera, is_dead)

func _on_player_destroyed(_snapshot: Dictionary) -> void:
	is_dead = true

## How much to speed up time during the bullet's travel phase.
@export var travel_fast_forward: float = 3.5

func _distance_to_nearest_enemy(position: Vector3) -> float:
	var nearest = INF
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node3D:
			nearest = min(nearest, position.distance_to(node.global_position))
	return nearest

func _get_sweep_exclusions() -> Array[RID]:
	if ground_alignment_controller:
		return ground_alignment_controller.get_sweep_exclusions()
	return []

func _on_projectile_cinematic_miss(hit_pos: Vector3) -> void:
	if combat_bark_ui:
		combat_bark_ui.show_result(false)
	if dossier_presenter and dossier_presenter.has_method("show_target_no_damage"):
		dossier_presenter.show_target_no_damage()
	var damage_number_script = preload("res://scripts/damage_number.gd")
	damage_number_script.display_text(hit_pos, "MISS", get_tree().current_scene, Color.ORANGE_RED)

func _on_projectile_cinematic_end() -> void:
	if combat_view_flow_controller:
		combat_view_flow_controller.reset_to_normal(CombatViewState.NORMAL_VIEW)
	if combat_bark_ui:
		combat_bark_ui.hide_bark()

func _build_mesh_colliders() -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, meshes)
	for mesh_instance in meshes:
		var shape := mesh_instance.mesh.create_trimesh_shape()
		if not shape:
			continue
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 1
		body.add_to_group("player")
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		mesh_instance.add_child(body)

func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh and node.visible:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, out)

func _get_enemy_hp_snapshot() -> Dictionary:
	if dossier_presenter and dossier_presenter.has_method("get_current_target_hp_snapshot"):
		return dossier_presenter.get_current_target_hp_snapshot()
	return {}
