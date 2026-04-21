extends Node3D

const PROJECTILE = preload("res://scenes/projectile.tscn")

@export_group("Enemy Firing")
## Seconds between each shot.
@export var fire_interval: float = 6.0
## World units per second for enemy shells.
@export var projectile_speed: float = 80.0
## Height above the enemy origin to spawn shells (approximates cannon height).
@export var muzzle_height_offset: float = 6.5
## Vertical aim offset applied to the player position so shells arc toward the cockpit.
@export var aim_height_offset: float = 3.0
## Delay before the first shot so the player has time to settle in.
@export var initial_fire_delay: float = 4.0

var is_destroyed: bool = false
var _fire_timer: float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	add_to_group("enemy")
	_fire_timer = initial_fire_delay

func _physics_process(delta):
	if is_destroyed:
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_begin_fire_cinematic()

	_align_to_ground()

func _align_to_ground() -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 2.0,
		global_position + Vector3.DOWN * 5.0
	)
	var exclusions: Array[RID] = []
	_collect_collision_rids(self, exclusions)
	query.exclude = exclusions
	var result = space_state.intersect_ray(query)
	if result:
		global_position.y = result.position.y + 3.625

func _collect_collision_rids(node: Node, out: Array[RID]) -> void:
	if node is CollisionObject3D:
		out.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_collision_rids(child, out)

func _begin_fire_cinematic() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	if player.has_method("begin_enemy_fire_cinematic"):
		player.begin_enemy_fire_cinematic(Callable(self, "_spawn_shell"))
	else:
		_spawn_shell()

func _spawn_shell() -> void:
	if not is_instance_valid(player):
		return

	var muzzle_pos: Vector3 = global_position + Vector3.UP * muzzle_height_offset
	var aim_pos: Vector3 = player.global_position + Vector3.UP * aim_height_offset

	var shell := PROJECTILE.instantiate()
	shell.shooter = self
	shell.speed = projectile_speed
	shell.is_player_shot = false
	get_tree().root.add_child(shell)
	shell.global_position = muzzle_pos
	shell.look_at(aim_pos, Vector3.UP)

	if player.has_method("set_enemy_active_shell"):
		player.set_enemy_active_shell(shell, aim_pos)

func part_destroyed(part: Node3D) -> void:
	print("Enemy part destroyed: " + part.part_name)
	if part.is_vital:
		destroy_completely()

func destroy_completely() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	print("ENEMY DESTROYED!")

	var explosion_scene = preload("res://scenes/explosion.tscn")
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position + Vector3(0, 1.0, 0)

	visible = false
	get_tree().create_timer(2.0).timeout.connect(queue_free)
