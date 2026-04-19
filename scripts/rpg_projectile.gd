extends "res://scripts/projectile.gd"

const EXPLOSION_SCENE = preload("res://scenes/explosion.tscn")

@export_group("RPG Effects")
## Explosion scene spawned when the RPG resolves against anything.
@export var explosion_scene: PackedScene = EXPLOSION_SCENE
## Time in seconds before the smoke trail is cleaned after impact.
@export var smoke_cleanup_delay: float = 1.4

@onready var smoke_trail: GPUParticles3D = get_node_or_null("SmokeTrail")

func _ready() -> void:
	swept_collision_enabled = true
	super._ready()
	if smoke_trail:
		smoke_trail.emitting = true

func _resolve_hit(body, hit_pos: Vector3, source: String) -> void:
	if _hit_resolved:
		return
	_spawn_explosion(hit_pos)
	_detach_smoke_trail()
	super._resolve_hit(body, hit_pos, source)

func _spawn_explosion(hit_pos: Vector3) -> void:
	if not explosion_scene:
		return
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	if explosion is Node3D:
		(explosion as Node3D).global_position = hit_pos

func _detach_smoke_trail() -> void:
	if not smoke_trail:
		return
	var global_xform := smoke_trail.global_transform
	remove_child(smoke_trail)
	get_tree().root.add_child(smoke_trail)
	smoke_trail.global_transform = global_xform
	smoke_trail.emitting = false
	var trail_id := smoke_trail.get_instance_id()
	smoke_trail = null
	get_tree().create_timer(smoke_cleanup_delay).timeout.connect(_cleanup_smoke_trail.bind(trail_id))

func _cleanup_smoke_trail(trail_id: int) -> void:
	var trail = instance_from_id(trail_id)
	if trail and trail is Node:
		(trail as Node).queue_free()
