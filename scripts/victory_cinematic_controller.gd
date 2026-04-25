extends Node

signal cinematic_completed

const VICTORY_IMAGE   := preload("res://assets/VFX/zezlandefeat.png")
const SMOKE_TEX       := preload("res://assets/VFX/Smoke/PNG/Black smoke/blackSmoke00.png")

const BARK_DELAY      := 1.5
const FIRE_DELAY      := 0.3   # fire spawns almost immediately
const FADE_START      := 5.0
const FADE_DURATION   := 2.2
const BLACK_HOLD      := 0.5
const REVEAL_DURATION := 3.0
const ORBIT_SPEED     := 0.22
const ORBIT_HEIGHT    := 4.5
const ORBIT_RADIUS    := 12.0

var camera: Camera3D    = null
var canvas_layer: Node  = null
var bark_ui: Node       = null
var zezlan_node: Node3D = null

var _elapsed: float     = 0.0
var _orbit_angle: float = 0.0
var _orbiting: bool     = false
var _bark_played: bool  = false
var _fire_spawned: bool = false
var _fade_triggered: bool = false
var _fade_rect: ColorRect = null
var _waiting_for_click: bool = false

func configure(p_camera: Camera3D, p_canvas_layer: Node, p_bark_ui: Node) -> void:
	camera       = p_camera
	canvas_layer = p_canvas_layer
	bark_ui      = p_bark_ui

func begin(p_zezlan: Node3D) -> void:
	zezlan_node = p_zezlan
	if not camera or not zezlan_node:
		return

	_elapsed       = 0.0
	_orbiting      = true
	_bark_played   = false
	_fire_spawned  = false
	_fade_triggered = false
	_waiting_for_click = false

	var diff := camera.global_position - zezlan_node.global_position
	_orbit_angle = atan2(diff.x, diff.z)

	if canvas_layer:
		canvas_layer.visible = false

	# Victory image — layer 127, hidden behind black until reveal
	var image_layer := CanvasLayer.new()
	image_layer.layer = 127
	add_child(image_layer)

	var image_rect := TextureRect.new()
	image_rect.texture = VICTORY_IMAGE
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.modulate.a = 0.0
	image_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image_layer.add_child(image_rect)

	# Black overlay — layer 128
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 128
	add_child(fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade_rect)

	set_meta("image_rect", image_rect)
	camera.current = true

func _process(delta: float) -> void:
	if not _orbiting or not is_instance_valid(zezlan_node):
		if _waiting_for_click:
			_elapsed += delta
			if Engine.get_frames_drawn() % 60 == 0:
				print("[DEBUG] Victory: Waiting for click. Time since start: %.2fs" % _elapsed)
		return

	_elapsed += delta

	# Keep orbiting the whole time — through bark, fire, and fade
	_orbit_angle += ORBIT_SPEED * delta
	var orbit_centre := zezlan_node.global_position + Vector3(0.0, 2.5, 0.0)
	camera.global_position = orbit_centre + Vector3(
		sin(_orbit_angle) * ORBIT_RADIUS,
		ORBIT_HEIGHT,
		cos(_orbit_angle) * ORBIT_RADIUS
	)
	camera.look_at(orbit_centre, Vector3.UP)

	if not _fire_spawned and _elapsed >= FIRE_DELAY:
		_fire_spawned = true
		_spawn_fire()

	if not _bark_played and _elapsed >= BARK_DELAY:
		_bark_played = true
		if bark_ui and bark_ui.has_method("show_victory"):
			bark_ui.show_victory()

	if not _fade_triggered and _elapsed >= FADE_START:
		_fade_triggered = true
		_run_fade_sequence()

func _run_fade_sequence() -> void:
	if not _fade_rect:
		return
	var image_rect := get_meta("image_rect") as TextureRect

	var tween := create_tween()
	# Fade to black while camera keeps orbiting
	tween.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	tween.tween_interval(BLACK_HOLD)
	# Reveal victory image and lift black simultaneously
	if image_rect:
		tween.tween_property(image_rect, "modulate:a", 1.0, REVEAL_DURATION)
	tween.parallel().tween_property(_fade_rect, "color:a", 0.0, REVEAL_DURATION)
	# Stop orbiting once the image is fully revealed
	tween.tween_callback(func(): 
		_orbiting = false
		_waiting_for_click = true
	)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print("[DEBUG] Victory: Input detected. waiting_for_click=%s button=%d" % [_waiting_for_click, event.button_index])

	if _waiting_for_click and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("[DEBUG] Victory: Left click received, advancing to post-battle screen.")
			_waiting_for_click = false
			cinematic_completed.emit()

func _spawn_fire() -> void:
	# Fire material — smoke sprite with additive blend tinted orange
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = SMOKE_TEX
	mat.vertex_color_use_as_albedo = true

	# Fire color gradient: bright yellow-white core → orange → deep red → transparent
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.3, 0.9))
	gradient.add_point(0.3, Color(1.0, 0.45, 0.05, 0.85))
	gradient.add_point(0.65, Color(0.7, 0.1, 0.0, 0.6))
	gradient.add_point(1.0, Color(0.1, 0.05, 0.0, 0.0))

	# Spawn emitters at three heights to cover the full mech
	var emitter_configs := [
		# [local_offset, box_extents, amount, scale]
		[Vector3(0.0, 0.8, 1.5),  Vector3(2.8, 0.5, 2.5),  60, Vector3(2.5, 2.5, 1.0)],  # lower legs/feet
		[Vector3(0.0, 3.2, 1.5),  Vector3(2.5, 1.0, 2.2),  80, Vector3(3.0, 3.5, 1.0)],  # mid torso/knees
		[Vector3(0.0, 5.8, 1.5),  Vector3(2.2, 0.8, 2.0),  60, Vector3(2.8, 3.0, 1.0)],  # upper torso
	]

	for cfg in emitter_configs:
		var emitter := CPUParticles3D.new()
		add_child(emitter)
		emitter.global_position = zezlan_node.global_position + cfg[0]

		emitter.emitting              = true
		emitter.amount                = cfg[2]
		emitter.lifetime              = 1.6
		emitter.explosiveness         = 0.0
		emitter.randomness            = 0.6
		emitter.one_shot              = false

		emitter.emission_shape        = CPUParticles3D.EMISSION_SHAPE_BOX
		emitter.emission_box_extents  = cfg[1]

		emitter.direction             = Vector3(0.0, 1.0, 0.0)
		emitter.spread                = 28.0
		emitter.gravity               = Vector3(0.0, 1.5, 0.0)
		emitter.initial_velocity_min  = 1.5
		emitter.initial_velocity_max  = 4.0
		emitter.scale_amount_min      = 0.8
		emitter.scale_amount_max      = 1.6
		emitter.scale                 = cfg[3]

		emitter.color_ramp            = gradient
		var quad := QuadMesh.new()
		quad.material = mat
		emitter.mesh = quad
