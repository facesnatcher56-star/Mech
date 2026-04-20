extends Node

var body: Node3D = null
var ray_start_offset: Vector3 = Vector3.UP * 2.0
var ray_end_offset: Vector3 = Vector3.DOWN * 5.0
var ground_height_offset: float = 3.625
var fallback_height: float = 3.625
var blend_speed: float = 5.0

func configure(config: Dictionary) -> void:
	body = config.get("body", body)
	ray_start_offset = config.get("ray_start_offset", ray_start_offset)
	ray_end_offset = config.get("ray_end_offset", ray_end_offset)
	ground_height_offset = float(config.get("ground_height_offset", ground_height_offset))
	fallback_height = float(config.get("fallback_height", fallback_height))
	blend_speed = float(config.get("blend_speed", blend_speed))

func update(delta: float) -> void:
	if not body or not is_instance_valid(body):
		return

	var space_state = body.get_world_3d().direct_space_state
	var ground_query = PhysicsRayQueryParameters3D.create(body.global_position + ray_start_offset, body.global_position + ray_end_offset)
	ground_query.exclude = get_sweep_exclusions()

	var ground_res = space_state.intersect_ray(ground_query)
	if ground_res:
		body.global_position.y = lerpf(body.global_position.y, ground_res.position.y + ground_height_offset, delta * blend_speed)
	else:
		body.global_position.y = lerpf(body.global_position.y, fallback_height, delta * blend_speed)

func get_sweep_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if body:
		_collect_collision_object_rids(body, exclusions)
	return exclusions

func _collect_collision_object_rids(node: Node, exclusions: Array[RID]) -> void:
	if node is CollisionObject3D:
		exclusions.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_collision_object_rids(child, exclusions)
