extends Node

var cockpit: Node3D = null
var aim_camera: Camera3D = null
var is_enemy_collider_callable: Callable
var is_enemy_target_node_callable: Callable

var target_center_height: float = 4.0
var low_accuracy_overshoot_scale: float = 2.4
var high_accuracy_overshoot_scale: float = 0.35
var low_accuracy_stroke_duration: float = 0.8
var high_accuracy_stroke_duration: float = 1.875
var max_distance_from_frame: float = 4.0
var visible_frame_min_padding: float = 0.35

var current_drift_multiplier: float = 1.0
var sway_rng := RandomNumberGenerator.new()
var stroke_active: bool = false
var stroke_time: float = 0.0
var stroke_duration: float = 0.35
var stroke_start: Vector2 = Vector2.ZERO
var stroke_end: Vector2 = Vector2.ZERO
var stroke_target: Node3D = null

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", cockpit)
	aim_camera = config.get("aim_camera", aim_camera)
	is_enemy_collider_callable = config.get("is_enemy_collider_callable", Callable())
	is_enemy_target_node_callable = config.get("is_enemy_target_node_callable", Callable())
	target_center_height = float(config.get("target_center_height", target_center_height))
	low_accuracy_overshoot_scale = float(config.get("low_accuracy_overshoot_scale", low_accuracy_overshoot_scale))
	high_accuracy_overshoot_scale = float(config.get("high_accuracy_overshoot_scale", high_accuracy_overshoot_scale))
	low_accuracy_stroke_duration = float(config.get("low_accuracy_stroke_duration", low_accuracy_stroke_duration))
	high_accuracy_stroke_duration = float(config.get("high_accuracy_stroke_duration", high_accuracy_stroke_duration))
	max_distance_from_frame = float(config.get("max_distance_from_frame", max_distance_from_frame))
	visible_frame_min_padding = float(config.get("visible_frame_min_padding", visible_frame_min_padding))
	sway_rng.randomize()

func set_aim_camera(camera: Camera3D) -> void:
	aim_camera = camera

func set_drift_multiplier(multiplier: float) -> void:
	current_drift_multiplier = multiplier

func get_drift_multiplier() -> float:
	return current_drift_multiplier

func reset_stroke() -> void:
	stroke_active = false
	stroke_target = null
	stroke_time = 0.0

func get_target_node() -> Node3D:
	if not cockpit:
		return null

	var fallback: Node3D = null
	var nearest = INF
	var candidates: Array = []
	for node in cockpit.get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and is_instance_valid(node):
			fallback = _consider_target_candidate(node, candidates, fallback, nearest)
			if fallback:
				nearest = cockpit.global_position.distance_to(fallback.global_position)

	var current_scene = cockpit.get_tree().current_scene
	if current_scene:
		_scan_named_targets(current_scene, candidates, fallback, nearest)
		if not candidates.is_empty():
			fallback = candidates[0]
			nearest = cockpit.global_position.distance_to(fallback.global_position)
			for candidate in candidates:
				var dist = cockpit.global_position.distance_to(candidate.global_position)
				if candidate.name == "EnemyMech":
					return candidate
				if dist < nearest:
					nearest = dist
					fallback = candidate
	return fallback

func get_enemy_aim_root(node: Node3D) -> Node3D:
	var root := node
	var parent = root.get_parent()
	while parent is Node3D and _is_enemy_collider(parent):
		root = parent as Node3D
		parent = root.get_parent()
	return root

func get_target_point(last_ray_result: Dictionary) -> Vector3:
	var target = get_target_node()
	if target:
		var torso = target.find_child("Torso", true)
		if torso and torso is Node3D:
			return torso.global_position
		return target.global_position + Vector3.UP * target_center_height

	if cockpit:
		var current_scene = cockpit.get_tree().current_scene
		var charlie = current_scene.find_child("REF_Charlie", true) if current_scene else null
		if charlie:
			return charlie.global_position

	if not last_ray_result.is_empty() and last_ray_result.has("position"):
		return last_ray_result.position
	return Vector3.ZERO

func get_camera_target_point(last_ray_result: Dictionary) -> Vector3:
	if cockpit:
		var current_scene = cockpit.get_tree().current_scene
		var aim_camera_target = current_scene.find_child("AimCameraTarget", true) if current_scene else null
		if aim_camera_target and aim_camera_target is Node3D:
			return aim_camera_target.global_position
	return get_target_point(last_ray_result)

func get_drifted_target_point(target_point: Vector3, delta: float, quality: float, stroke_speed_multiplier: float) -> Vector3:
	var target = get_target_node()
	if not target:
		return target_point

	var frame = _build_target_frame(target, target_point)
	if frame.is_empty():
		return target_point

	if not stroke_active or stroke_time >= stroke_duration or stroke_target != target:
		_begin_correction_stroke(frame, target, quality, stroke_speed_multiplier)

	stroke_time = min(stroke_duration, stroke_time + delta)
	var progress = clampf(stroke_time / max(stroke_duration, 0.001), 0.0, 1.0)
	var eased = progress * progress * (3.0 - 2.0 * progress)
	var offset = stroke_start.lerp(stroke_end, eased)
	return frame["center"] + (frame["right"] * offset.x) + (frame["up"] * offset.y)

func _consider_target_candidate(node: Node3D, candidates: Array, fallback: Node3D, nearest: float) -> Node3D:
	var enemy_root = get_enemy_aim_root(node)
	if not enemy_root or candidates.has(enemy_root):
		return fallback
	candidates.append(enemy_root)
	if enemy_root.name == "EnemyMech":
		return enemy_root
	var dist = cockpit.global_position.distance_to(enemy_root.global_position)
	if dist < nearest:
		return enemy_root
	return fallback

func _scan_named_targets(node: Node, candidates: Array, fallback: Node3D, nearest: float) -> void:
	if node is Node3D and _is_enemy_target_node(node):
		_consider_target_candidate(node as Node3D, candidates, fallback, nearest)
	for child in node.get_children():
		_scan_named_targets(child, candidates, fallback, nearest)

func _build_target_frame(target: Node3D, fallback_point: Vector3) -> Dictionary:
	if not aim_camera or not is_instance_valid(target):
		return {}

	var points: Array = []
	_collect_visible_target_points(target, points)
	if points.is_empty():
		_collect_collision_target_points(target, points)
	if points.is_empty():
		return {}

	var center = Vector3.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	if center == Vector3.ZERO:
		center = fallback_point

	var to_center = center - aim_camera.global_position
	if to_center.length() <= 0.01:
		return {}

	var forward = to_center.normalized()
	var right = forward.cross(Vector3.UP).normalized()
	if right.length() < 0.01:
		right = aim_camera.global_transform.basis.x.normalized()
	var up = right.cross(forward).normalized()

	var min_offset = Vector2(INF, INF)
	var max_offset = Vector2(-INF, -INF)
	for point in points:
		var rel = point - center
		var projected = Vector2(rel.dot(right), rel.dot(up))
		min_offset.x = min(min_offset.x, projected.x)
		min_offset.y = min(min_offset.y, projected.y)
		max_offset.x = max(max_offset.x, projected.x)
		max_offset.y = max(max_offset.y, projected.y)

	var frame_size = max_offset - min_offset
	var padding = max(visible_frame_min_padding, max(frame_size.x, frame_size.y) * 0.06)
	min_offset -= Vector2.ONE * padding
	max_offset += Vector2.ONE * padding

	return {
		"center": center,
		"right": right,
		"up": up,
		"min": min_offset,
		"max": max_offset
	}

func _collect_visible_target_points(node: Node, points: Array) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh:
			_append_aabb_corners(points, mesh_instance.global_transform, mesh_instance.get_aabb())
	elif node is CSGBox3D:
		var csg_box := node as CSGBox3D
		if csg_box.visible:
			_append_aabb_corners(points, csg_box.global_transform, AABB(-csg_box.size * 0.5, csg_box.size))

	for child in node.get_children():
		_collect_visible_target_points(child, points)

func _collect_collision_target_points(node: Node, points: Array) -> void:
	if node is CollisionShape3D:
		var shape_node := node as CollisionShape3D
		if not shape_node.disabled and shape_node.shape:
			var shape_aabb = _get_shape_local_aabb(shape_node.shape)
			if shape_aabb.size != Vector3.ZERO:
				_append_aabb_corners(points, shape_node.global_transform, shape_aabb)

	for child in node.get_children():
		_collect_collision_target_points(child, points)

func _get_shape_local_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var box := shape as BoxShape3D
		return AABB(-box.size * 0.5, box.size)
	if shape is SphereShape3D:
		var sphere := shape as SphereShape3D
		var radius = sphere.radius
		return AABB(Vector3(-radius, -radius, -radius), Vector3.ONE * radius * 2.0)
	if shape is CapsuleShape3D:
		var capsule := shape as CapsuleShape3D
		var radius = capsule.radius
		var height = max(capsule.height, radius * 2.0)
		return AABB(Vector3(-radius, -height * 0.5, -radius), Vector3(radius * 2.0, height, radius * 2.0))
	return AABB()

func _append_aabb_corners(points: Array, xform: Transform3D, aabb: AABB) -> void:
	var origin = aabb.position
	var size = aabb.size
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				points.append(xform * (origin + Vector3(size.x * x, size.y * y, size.z * z)))

func _begin_correction_stroke(frame: Dictionary, target: Node3D, quality: float, stroke_speed_multiplier: float) -> void:
	var crossing = _pick_frame_crossing_point(frame, quality)
	var angle = sway_rng.randf_range(0.0, TAU)
	var direction = Vector2(cos(angle), sin(angle)).normalized()

	if stroke_active and stroke_target == target and _is_offset_outside_frame(stroke_end, frame):
		stroke_start = stroke_end
		direction = (crossing - stroke_start).normalized()
		if direction.length() < 0.01:
			direction = Vector2.RIGHT.rotated(sway_rng.randf_range(0.0, TAU))
	else:
		var start_exit = _get_frame_exit_distance(crossing, -direction, frame)
		stroke_start = crossing - direction * (start_exit + _get_stroke_overshoot(frame, quality))

	var end_exit = _get_frame_exit_distance(crossing, direction, frame)
	stroke_end = crossing + direction * (end_exit + _get_stroke_overshoot(frame, quality))
	var base_duration = lerpf(low_accuracy_stroke_duration, high_accuracy_stroke_duration, quality)
	stroke_duration = base_duration / max(0.05, stroke_speed_multiplier)
	stroke_time = 0.0
	stroke_target = target
	stroke_active = true

func _pick_frame_crossing_point(frame: Dictionary, quality: float) -> Vector2:
	var min_offset = frame["min"]
	var max_offset = frame["max"]
	var center = (min_offset + max_offset) * 0.5
	var half_size = (max_offset - min_offset) * 0.5
	var edge_bias = lerpf(0.78, 0.18, quality)

	if sway_rng.randf() < edge_bias:
		var side = sway_rng.randi_range(0, 3)
		match side:
			0:
				return Vector2(min_offset.x + half_size.x * sway_rng.randf_range(0.0, 0.18), sway_rng.randf_range(min_offset.y, max_offset.y))
			1:
				return Vector2(max_offset.x - half_size.x * sway_rng.randf_range(0.0, 0.18), sway_rng.randf_range(min_offset.y, max_offset.y))
			2:
				return Vector2(sway_rng.randf_range(min_offset.x, max_offset.x), min_offset.y + half_size.y * sway_rng.randf_range(0.0, 0.18))
			_:
				return Vector2(sway_rng.randf_range(min_offset.x, max_offset.x), max_offset.y - half_size.y * sway_rng.randf_range(0.0, 0.18))

	var center_pull = lerpf(1.0, 0.35, pow(quality, 1.4))
	return center + Vector2(
		sway_rng.randf_range(-half_size.x, half_size.x) * center_pull,
		sway_rng.randf_range(-half_size.y, half_size.y) * center_pull
	)

func _get_stroke_overshoot(frame: Dictionary, quality: float) -> float:
	var frame_size = frame["max"] - frame["min"]
	var frame_radius = max(frame_size.x, frame_size.y)
	var stage_scale = lerpf(current_drift_multiplier, 1.0, quality)
	var overshoot_scale = lerpf(low_accuracy_overshoot_scale, high_accuracy_overshoot_scale, quality)
	var overshoot = frame_radius * overshoot_scale * stage_scale
	return clampf(overshoot, visible_frame_min_padding, max_distance_from_frame)

func _get_frame_exit_distance(point: Vector2, direction: Vector2, frame: Dictionary) -> float:
	var min_offset = frame["min"]
	var max_offset = frame["max"]
	var exit_distance = INF
	if abs(direction.x) > 0.001:
		var x_distance = ((max_offset.x if direction.x > 0.0 else min_offset.x) - point.x) / direction.x
		if x_distance > 0.0:
			exit_distance = min(exit_distance, x_distance)
	if abs(direction.y) > 0.001:
		var y_distance = ((max_offset.y if direction.y > 0.0 else min_offset.y) - point.y) / direction.y
		if y_distance > 0.0:
			exit_distance = min(exit_distance, y_distance)
	if exit_distance == INF:
		return visible_frame_min_padding
	return max(exit_distance, visible_frame_min_padding)

func _is_offset_outside_frame(offset: Vector2, frame: Dictionary) -> bool:
	var min_offset = frame["min"]
	var max_offset = frame["max"]
	return offset.x < min_offset.x or offset.x > max_offset.x or offset.y < min_offset.y or offset.y > max_offset.y

func _is_enemy_collider(collider: Object) -> bool:
	if is_enemy_collider_callable.is_valid():
		return bool(is_enemy_collider_callable.call(collider))
	return false

func _is_enemy_target_node(node: Node) -> bool:
	if is_enemy_target_node_callable.is_valid():
		return bool(is_enemy_target_node_callable.call(node))
	return false
