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

var start_pos: Vector3
var is_staggered: bool = false
var stagger_count: int = 0
var armor: int = 1 # One-hit kill
var _fire_timer: float = 0.0

@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var body = get_node_or_null("Body")
@onready var left_leg = get_node_or_null("Body/LeftLeg")
@onready var right_leg = get_node_or_null("Body/RightLeg")

func _ready():
	add_to_group("enemy")
	start_pos = position
	_fire_timer = initial_fire_delay

func _process(delta):
	if armor <= 0:
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		fire_at_player()

func _physics_process(delta):
	if armor <= 0: return

	# --- Ground Alignment ---
	var space_state = get_world_3d().direct_space_state
	var ground_query = PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 5.0)
	
	# Fix: Exclude the enemy's own hitboxes from its ground check
	var exclusions: Array[RID] = []
	_collect_collision_object_rids(self, exclusions)
	ground_query.exclude = exclusions
	
	var ground_res = space_state.intersect_ray(ground_query)
	if ground_res:
		global_position.y = ground_res.position.y + 3.625

func _collect_collision_object_rids(node: Node, exclusions: Array[RID]) -> void:
	if node is CollisionObject3D:
		exclusions.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_collision_object_rids(child, exclusions)

func fire_at_player():
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		return

	if player.has_method("begin_enemy_fire_cinematic"):
		player.begin_enemy_fire_cinematic(Callable(self, "_perform_fire"))
	else:
		_perform_fire()

func _perform_fire():
	if not is_instance_valid(player):
		return

	var muzzle_pos := global_position + Vector3.UP * muzzle_height_offset
	var aim_pos    := player.global_position + Vector3.UP * aim_height_offset

	var shell := PROJECTILE.instantiate()
	shell.shooter = self
	shell.speed = projectile_speed
	shell.is_player_shot = false
	get_tree().root.add_child(shell)
	shell.global_position = muzzle_pos
	shell.look_at(aim_pos, Vector3.UP)

	if player.has_method("set_enemy_active_shell"):
		player.set_enemy_active_shell(shell, aim_pos)

func hit():
	# The individual parts will handle their own hits via the projectile
	pass

func part_destroyed(part: Node3D):
	print("Parent mech notified: " + part.part_name + " destroyed!")
	if part.is_vital:
		destroy_completely()

func destroy_completely():
	if armor <= 0: return
	armor = 0
	print("ENEMY DESTROYED!")
	
	var explosion_scene = preload("res://scenes/explosion.tscn")
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position + Vector3(0, 1.0, 0)
	
	# Hide everything
	visible = false
	
	# Cleanup
	get_tree().create_timer(2.0).timeout.connect(queue_free)
