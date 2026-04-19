extends Node3D

const PROJECTILE = preload("res://scenes/projectile.tscn")

var start_pos: Vector3
var is_staggered: bool = false
var stagger_count: int = 0
var armor: int = 1 # One-hit kill

@onready var body = get_node_or_null("Body")
@onready var left_leg = get_node_or_null("Body/LeftLeg")
@onready var right_leg = get_node_or_null("Body/RightLeg")

func _ready():
	add_to_group("enemy")
	start_pos = position

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
	# Firing disabled
	pass

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
