extends Node

var root: Node3D = null
var sweep_exclusions_callable: Callable

func configure(config: Dictionary) -> void:
	root = config.get("root", root)
	sweep_exclusions_callable = config.get("sweep_exclusions_callable", Callable())

func intersect_target_ray(source_camera: Camera3D, max_distance: float) -> Dictionary:
	if not root or not source_camera:
		return {}
	var space_state = root.get_world_3d().direct_space_state
	var direction = -source_camera.global_transform.basis.z
	var ray_from = source_camera.global_position
	var ray_to = source_camera.global_position + (direction * max_distance)
	var excluded: Array[RID] = _get_sweep_exclusions()

	for i in range(16):
		if ray_from.distance_to(ray_to) < 0.01:
			return {}
		var query = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		query.exclude = excluded
		var result = space_state.intersect_ray(query)
		if result.is_empty():
			return {}
		if is_world_targeting_noise(result.collider) or is_player_tree_node(result.collider as Node):
			if result.collider is CollisionObject3D:
				excluded.append((result.collider as CollisionObject3D).get_rid())
			ray_from = result.position + (direction * 0.08)
			continue
		if is_enemy_collider(result.collider):
			return result
		return {}
	return {}

func is_world_targeting_noise(collider: Object) -> bool:
	if not collider or not collider is Node:
		return false
	var current = collider as Node
	while current:
		var node_name = current.name.to_lower()
		if node_name == "worldsetup" or node_name == "environmentprops":
			return true
		if node_name == "mechscalegravelroad" or node_name == "grassblades":
			return true
		if node_name == "broadleaftree" or node_name == "pinetree" or node_name == "rock":
			return true
		if node_name == "mechscalebuilding":
			return true
		current = current.get_parent()
	return false

func is_enemy_collider(collider: Object) -> bool:
	if not collider:
		return false
	if collider is Node:
		var node = collider as Node
		if is_enemy_target_node(node):
			return true
		var parent = node.get_parent()
		while parent:
			if is_enemy_target_node(parent):
				return true
			parent = parent.get_parent()
	return false

func is_enemy_target_node(node: Node) -> bool:
	if not node or is_player_tree_node(node):
		return false
	if node.is_in_group("enemy"):
		return true

	var node_name = node.name.to_lower()
	if "enemy" in node_name:
		return true
	if "zezlan" in node_name:
		return true
	if node_name == "enemymech":
		return true
	return false

func is_player_tree_node(node: Node) -> bool:
	var current = node
	while current:
		if current.is_in_group("player"):
			return true
		current = current.get_parent()
	return false

func _get_sweep_exclusions() -> Array[RID]:
	if sweep_exclusions_callable.is_valid():
		return sweep_exclusions_callable.call()
	return []
