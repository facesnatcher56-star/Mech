@tool
extends Node3D

const _SMOKE_TEX = preload("res://assets/VFX/Smoke/PNG/Black smoke/blackSmoke00.png")

@export_group("Preview")
## Check this in the editor to fire the effect instantly. Resets itself.
@export var emitting: bool = false:
	set(value):
		emitting = false
		if value and is_inside_tree():
			setup(preview_travel_dir, preview_large)
@export var preview_travel_dir: Vector3 = Vector3(0, 0, 1)
@export var preview_large: bool = false

@export_group("Explosion Sprite")
@export var expl_pixel_size_small: float = 0.018
@export var expl_pixel_size_large: float = 0.035
@export var expl_fps: float = 18.0

@export_group("Debris")
## When non-zero, overrides the travel-derived direction.
@export var debris_direction_override: Vector3 = Vector3.ZERO
@export var debris_mesh_small: Vector3 = Vector3(0.04, 0.025, 0.07)
@export var debris_mesh_large: Vector3 = Vector3(0.08, 0.05, 0.14)
@export var debris_spread: float = 36.0
@export var debris_velocity_min_small: float = 4.0
@export var debris_velocity_max_small: float = 12.0
@export var debris_velocity_min_large: float = 6.0
@export var debris_velocity_max_large: float = 18.0
@export var debris_gravity: float = -22.0
@export var debris_damping_min: float = 4.0
@export var debris_damping_max: float = 9.0
@export var debris_scale_min: float = 0.4
@export var debris_scale_max: float = 1.4
@export var debris_count_small: int = 18
@export var debris_count_large: int = 26
@export var debris_lifetime: float = 1.4

@export_group("Smoke")
@export var smoke_quad_size: float = 1.2
@export var smoke_opacity: float = 0.45
@export var smoke_velocity_min: float = 0.8
@export var smoke_velocity_max: float = 3.0
@export var smoke_spread: float = 28.0
@export var smoke_scale_min: float = 0.5
@export var smoke_scale_max: float = 2.0
@export var smoke_count: int = 5
@export var smoke_lifetime: float = 2.2

@export_group("Lifetime")
@export var vfx_lifetime: float = 3.0

var _sprite: AnimatedSprite3D = null
var _debris: GPUParticles3D = null
var _smoke_ps: GPUParticles3D = null
var _built_large: bool = false

func setup(travel_dir: Vector3, large: bool = false) -> void:
	if _sprite == null or _debris == null or _smoke_ps == null or large != _built_large:
		_rebuild(large)

	_sprite.pixel_size = expl_pixel_size_large if large else expl_pixel_size_small
	_sprite.visible = true
	_sprite.play("explode")

	var dir: Vector3 = debris_direction_override.normalized() if debris_direction_override != Vector3.ZERO else -travel_dir.normalized()
	var proc := _debris.process_material as ParticleProcessMaterial
	proc.direction = dir
	proc.spread = debris_spread
	proc.initial_velocity_min = debris_velocity_min_large if large else debris_velocity_min_small
	proc.initial_velocity_max = debris_velocity_max_large if large else debris_velocity_max_small
	proc.gravity = Vector3(0, debris_gravity, 0)
	proc.damping_min = debris_damping_min
	proc.damping_max = debris_damping_max
	proc.scale_min = debris_scale_min
	proc.scale_max = debris_scale_max
	_debris.amount = debris_count_large if large else debris_count_small
	_debris.lifetime = debris_lifetime
	_debris.emitting = true
	_debris.restart()
	var sproc := _smoke_ps.process_material as ParticleProcessMaterial
	sproc.spread = smoke_spread
	sproc.initial_velocity_min = smoke_velocity_min
	sproc.initial_velocity_max = smoke_velocity_max
	sproc.scale_min = smoke_scale_min
	sproc.scale_max = smoke_scale_max
	_smoke_ps.amount = smoke_count
	_smoke_ps.lifetime = smoke_lifetime
	_smoke_ps.emitting = true
	_smoke_ps.restart()

	if not Engine.is_editor_hint():
		get_tree().create_timer(vfx_lifetime).timeout.connect(queue_free)

func _rebuild(large: bool) -> void:
	for child in get_children():
		child.free()
	_built_large = large
	_sprite = _make_sprite(large)
	add_child(_sprite)
	_debris = _make_debris(large)
	add_child(_debris)
	_smoke_ps = _make_smoke()
	add_child(_smoke_ps)

func _make_sprite(large: bool) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("explode")
	frames.set_animation_speed("explode", expl_fps)
	frames.set_animation_loop("explode", false)
	for i in range(9):
		var tex := load("res://assets/VFX/Smoke/PNG/Explosion/explosion0%d.png" % i) as Texture2D
		if tex:
			frames.add_frame("explode", tex)
	sprite.sprite_frames = frames
	sprite.pixel_size = expl_pixel_size_large if large else expl_pixel_size_small
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.animation = "explode"
	sprite.animation_finished.connect(func(): sprite.visible = false)
	return sprite

func _make_debris(large: bool) -> GPUParticles3D:
	var debris := GPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = debris_mesh_large if large else debris_mesh_small
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9, 0.52, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.36, 0.03)
	mat.emission_energy_multiplier = 8.0
	mesh.material = mat
	debris.draw_pass_1 = mesh
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 0, 1)
	proc.spread = debris_spread
	proc.initial_velocity_min = debris_velocity_min_small
	proc.initial_velocity_max = debris_velocity_max_small
	proc.gravity = Vector3(0, debris_gravity, 0)
	proc.damping_min = debris_damping_min
	proc.damping_max = debris_damping_max
	proc.scale_min = debris_scale_min
	proc.scale_max = debris_scale_max
	debris.process_material = proc
	debris.amount = debris_count_large if large else debris_count_small
	debris.lifetime = debris_lifetime
	debris.explosiveness = 0.92
	debris.one_shot = true
	return debris

func _make_smoke() -> GPUParticles3D:
	var smoke := GPUParticles3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(smoke_quad_size, smoke_quad_size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.22, 0.22, 0.22, smoke_opacity)
	mat.albedo_texture = _SMOKE_TEX
	mesh.material = mat
	smoke.draw_pass_1 = mesh
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 1, 0)
	proc.spread = smoke_spread
	proc.initial_velocity_min = smoke_velocity_min
	proc.initial_velocity_max = smoke_velocity_max
	proc.gravity = Vector3(0, 0.4, 0)
	proc.damping_min = 0.3
	proc.damping_max = 1.0
	proc.scale_min = smoke_scale_min
	proc.scale_max = smoke_scale_max
	smoke.process_material = proc
	smoke.amount = smoke_count
	smoke.lifetime = smoke_lifetime
	smoke.explosiveness = 0.65
	smoke.one_shot = true
	return smoke
