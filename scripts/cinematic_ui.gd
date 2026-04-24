extends Control

@export_group("Runtime Panel")
## Shows the in-game tuning panel. Leave off for normal play; Inspector values still apply while hidden.
@export var show_runtime_tuner: bool = false

@export_group("AIM TUNING")
## Stroke speed multiplier while solution quality is in stage 1.
@export_range(0.1, 4.0, 0.05) var stage_1_stroke_speed: float = 1.0
## Stroke speed multiplier while solution quality is in stage 2.
@export_range(0.1, 4.0, 0.05) var stage_2_stroke_speed: float = 1.0
## Stroke speed multiplier while solution quality is in stage 3.
@export_range(0.1, 4.0, 0.05) var stage_3_stroke_speed: float = 1.0
## Stroke speed multiplier while solution quality is in stage 4.
@export_range(0.1, 4.0, 0.05) var stage_4_stroke_speed: float = 1.0
## Stroke speed multiplier while solution quality is in stage 5.
@export_range(0.1, 4.0, 0.05) var stage_5_stroke_speed: float = 1.0
## Controls how quickly solution quality and sway control improve. This does not move the zoom camera.
@export_range(0.005, 0.2, 0.001) var aim_build_speed: float = 0.045
## Seconds to hold camera/FOV stage 1 before jumping to stage 2.
@export var camera_stage_1_time: float = 0.35
## Seconds to hold camera/FOV stage 2 before jumping to stage 3.
@export var camera_stage_2_time: float = 0.35
## Seconds to hold camera/FOV stage 3 before jumping to stage 4.
@export var camera_stage_3_time: float = 0.35
## Seconds to hold camera/FOV stage 4 before jumping to stage 5.
@export var camera_stage_4_time: float = 0.35
## Portion of each new camera chunk applied immediately. 0 eases fully, 1 snaps to the chunk.
@export_range(0.0, 1.0, 0.05) var camera_chunk_jump_amount: float = 0.75
## How quickly the camera settles after the immediate chunk jump. Higher values settle faster.
@export_range(0.1, 40.0, 0.1) var camera_chunk_settle_speed: float = 10.0
## Field of view used by camera stage 1.
@export_range(10.0, 90.0, 1.0) var stage_1_fov: float = 44.0
## Field of view used by camera stage 2.
@export_range(10.0, 90.0, 1.0) var stage_2_fov: float = 38.0
## Field of view used by camera stage 3.
@export_range(10.0, 90.0, 1.0) var stage_3_fov: float = 32.0
## Field of view used by camera stage 4.
@export_range(10.0, 90.0, 1.0) var stage_4_fov: float = 26.0
## Field of view used by camera stage 5 at the AimCameraTarget.
@export_range(10.0, 90.0, 1.0) var stage_5_fov: float = 20.0
@export_group("")

var cockpit: Node = null

func _ready():
	cockpit = _find_cockpit()
	if not cockpit: return
	_apply_aim_tuning_to_cockpit()
	visible = show_runtime_tuner
	mouse_filter = Control.MOUSE_FILTER_STOP if show_runtime_tuner else Control.MOUSE_FILTER_IGNORE
	if not show_runtime_tuner:
		return

	_add_section_header("AIM TUNING")
	setup_slider("Stage1StrokeSpeed", "Stage 1 Stroke Speed", 0.1, 4.0, stage_1_stroke_speed, "Stroke speed multiplier while solution quality is in stage 1.", 0.05)
	setup_slider("Stage2StrokeSpeed", "Stage 2 Stroke Speed", 0.1, 4.0, stage_2_stroke_speed, "Stroke speed multiplier while solution quality is in stage 2.", 0.05)
	setup_slider("Stage3StrokeSpeed", "Stage 3 Stroke Speed", 0.1, 4.0, stage_3_stroke_speed, "Stroke speed multiplier while solution quality is in stage 3.", 0.05)
	setup_slider("Stage4StrokeSpeed", "Stage 4 Stroke Speed", 0.1, 4.0, stage_4_stroke_speed, "Stroke speed multiplier while solution quality is in stage 4.", 0.05)
	setup_slider("Stage5StrokeSpeed", "Stage 5 Stroke Speed", 0.1, 4.0, stage_5_stroke_speed, "Stroke speed multiplier while solution quality is in stage 5.", 0.05)
	setup_slider("AimBuildSpeed", "Aim Build Speed", 0.005, 0.2, aim_build_speed, "Controls solution quality and sway control only. It does not move the zoom camera.", 0.001)
	setup_number_input("CameraStage1Time", "Stage 1 Time", 0.0, 999.0, camera_stage_1_time, "Seconds to hold camera/FOV stage 1 before jumping to stage 2.", 0.01)
	setup_number_input("CameraStage2Time", "Stage 2 Time", 0.0, 999.0, camera_stage_2_time, "Seconds to hold camera/FOV stage 2 before jumping to stage 3.", 0.01)
	setup_number_input("CameraStage3Time", "Stage 3 Time", 0.0, 999.0, camera_stage_3_time, "Seconds to hold camera/FOV stage 3 before jumping to stage 4.", 0.01)
	setup_number_input("CameraStage4Time", "Stage 4 Time", 0.0, 999.0, camera_stage_4_time, "Seconds to hold camera/FOV stage 4 before jumping to stage 5.", 0.01)
	setup_slider("CameraChunkJump", "Camera Chunk Jump", 0.0, 1.0, camera_chunk_jump_amount, "Portion of a new camera chunk applied instantly. 0 eases fully, 1 snaps to the chunk.", 0.05)
	setup_slider("CameraChunkSettle", "Camera Chunk Settle", 0.1, 40.0, camera_chunk_settle_speed, "How fast the camera finishes settling after the instant chunk jump.", 0.1)
	setup_slider("AimStage1FOV", "Stage 1 FOV", 10.0, 90.0, stage_1_fov, "Zoom level for aim stage 1.", 1.0)
	setup_slider("AimStage2FOV", "Stage 2 FOV", 10.0, 90.0, stage_2_fov, "Zoom level for aim stage 2.", 1.0)
	setup_slider("AimStage3FOV", "Stage 3 FOV", 10.0, 90.0, stage_3_fov, "Zoom level for aim stage 3.", 1.0)
	setup_slider("AimStage4FOV", "Stage 4 FOV", 10.0, 90.0, stage_4_fov, "Zoom level for aim stage 4.", 1.0)
	setup_slider("AimStage5FOV", "Stage 5 FOV", 10.0, 90.0, stage_5_fov, "Zoom level for aim stage 5.", 1.0)

	_add_section_header("CAMERA CINEMATICS")

	# Gun Cam
	setup_slider("GunCamDuration", "Duration (Gun Cam)", 0.0, 2.0, cockpit.guncam_duration, "How long to watch the gun fire.")
	setup_slider("GunCamFOV", "FOV (Gun Cam)", 10.0, 120.0, cockpit.guncam_fov, "Field of view for the gun camera.")

	# Impact Cam
	setup_slider("ImpactCamTimeout", "Timeout (Impact Cam)", 0.5, 5.0, cockpit.impactcam_timeout, "Max time to watch the shell travel.")
	setup_slider("ImpactCamFOV", "FOV (Impact Cam)", 10.0, 120.0, cockpit.impactcam_fov, "Field of view for the impact camera.")
	setup_slider("ImpactCamRotate", "Rotate (Impact Cam)", 0.0, 5.0, cockpit.impactcam_rotation_speed, "How fast the camera spins during flight.")

	# Miss/Linger
	setup_slider("LingerDuration", "Linger Duration", 0.0, 5.0, cockpit.linger_duration, "How long to watch the impact point after hit/miss.")

func _find_cockpit() -> Node:
	var node = get_parent()
	while node:
		if not (node is StaticBody3D) and node.has_method("_begin_aim_flow") and node.has_method("_get_aim_stage_fov"):
			return node
		node = node.get_parent()
	
	# Fallback: Find the player cockpit in the scene
	for player_node in get_tree().get_nodes_in_group("player"):
		if player_node.has_method("_begin_aim_flow"):
			return player_node
	return null

func _apply_aim_tuning_to_cockpit() -> void:
	cockpit.stage_1_stroke_speed_multiplier = stage_1_stroke_speed
	cockpit.stage_2_stroke_speed_multiplier = stage_2_stroke_speed
	cockpit.stage_3_stroke_speed_multiplier = stage_3_stroke_speed
	cockpit.stage_4_stroke_speed_multiplier = stage_4_stroke_speed
	cockpit.stage_5_stroke_speed_multiplier = stage_5_stroke_speed
	cockpit.aim_settle_speed = aim_build_speed
	cockpit.aim_camera_stage_1_time = camera_stage_1_time
	cockpit.aim_camera_stage_2_time = camera_stage_2_time
	cockpit.aim_camera_stage_3_time = camera_stage_3_time
	cockpit.aim_camera_stage_4_time = camera_stage_4_time
	cockpit.aim_camera_chunk_jump_amount = camera_chunk_jump_amount
	cockpit.aim_camera_chunk_settle_speed = camera_chunk_settle_speed
	cockpit.aim_stage_1_fov = stage_1_fov
	cockpit.aim_stage_2_fov = stage_2_fov
	cockpit.aim_stage_3_fov = stage_3_fov
	cockpit.aim_stage_4_fov = stage_4_fov
	cockpit.aim_stage_5_fov = stage_5_fov

func _add_section_header(text: String):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.22, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	$VBox.add_child(label)

func setup_slider(node_name: String, label_text: String, min_val: float, max_val: float, current_val: float, tooltip: String, step_val: float = 0.05):
	var container = VBoxContainer.new()
	container.name = node_name

	var label_row = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.tooltip_text = tooltip
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_row.add_child(label)

	var value_label = Label.new()
	value_label.text = _format_slider_value(current_val, step_val)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 70.0
	label_row.add_child(value_label)
	container.add_child(label_row)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = current_val
	slider.tooltip_text = tooltip

	slider.value_changed.connect(func(val):
		value_label.text = _format_slider_value(val, step_val)
		match node_name:
			"GunCamDuration": cockpit.guncam_duration = val
			"GunCamFOV": cockpit.guncam_fov = val
			"ImpactCamTimeout": cockpit.impactcam_timeout = val
			"ImpactCamFOV": cockpit.impactcam_fov = val
			"ImpactCamRotate": cockpit.impactcam_rotation_speed = val
			"LingerDuration": cockpit.linger_duration = val
			"AimBuildSpeed":
				aim_build_speed = val
				cockpit.aim_settle_speed = val
			"Stage1StrokeSpeed":
				stage_1_stroke_speed = val
				cockpit.stage_1_stroke_speed_multiplier = val
			"Stage2StrokeSpeed":
				stage_2_stroke_speed = val
				cockpit.stage_2_stroke_speed_multiplier = val
			"Stage3StrokeSpeed":
				stage_3_stroke_speed = val
				cockpit.stage_3_stroke_speed_multiplier = val
			"Stage4StrokeSpeed":
				stage_4_stroke_speed = val
				cockpit.stage_4_stroke_speed_multiplier = val
			"Stage5StrokeSpeed":
				stage_5_stroke_speed = val
				cockpit.stage_5_stroke_speed_multiplier = val
			"CameraChunkJump":
				camera_chunk_jump_amount = val
				cockpit.aim_camera_chunk_jump_amount = val
			"CameraChunkSettle":
				camera_chunk_settle_speed = val
				cockpit.aim_camera_chunk_settle_speed = val
			"AimStage1FOV":
				stage_1_fov = val
				cockpit.aim_stage_1_fov = val
			"AimStage2FOV":
				stage_2_fov = val
				cockpit.aim_stage_2_fov = val
			"AimStage3FOV":
				stage_3_fov = val
				cockpit.aim_stage_3_fov = val
			"AimStage4FOV":
				stage_4_fov = val
				cockpit.aim_stage_4_fov = val
			"AimStage5FOV":
				stage_5_fov = val
				cockpit.aim_stage_5_fov = val
	)

	container.add_child(slider)
	$VBox.add_child(container)

func setup_number_input(node_name: String, label_text: String, min_val: float, max_val: float, current_val: float, tooltip: String, step_val: float = 0.01):
	var container = HBoxContainer.new()
	container.name = node_name

	var label = Label.new()
	label.text = label_text
	label.tooltip_text = tooltip
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(label)

	var input = SpinBox.new()
	input.min_value = min_val
	input.max_value = max_val
	input.step = step_val
	input.value = current_val
	input.tooltip_text = tooltip
	input.custom_minimum_size.x = 120.0

	input.value_changed.connect(func(val):
		match node_name:
			"CameraStage1Time":
				camera_stage_1_time = val
				cockpit.aim_camera_stage_1_time = val
			"CameraStage2Time":
				camera_stage_2_time = val
				cockpit.aim_camera_stage_2_time = val
			"CameraStage3Time":
				camera_stage_3_time = val
				cockpit.aim_camera_stage_3_time = val
			"CameraStage4Time":
				camera_stage_4_time = val
				cockpit.aim_camera_stage_4_time = val
	)

	container.add_child(input)
	$VBox.add_child(container)

func _format_slider_value(val: float, step_val: float) -> String:
	if step_val >= 1.0:
		return str(roundi(val))
	if step_val <= 0.001:
		return "%.3f" % val
	return "%.2f" % val
