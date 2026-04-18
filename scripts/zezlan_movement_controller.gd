extends Node3D

@export_group("Zezlan Movement - Input")
## Hold this key to raise the target throttle.
@export var throttle_up_key: Key = KEY_W
## Hold this key to lower the target throttle.
@export var throttle_down_key: Key = KEY_S
## Press this key to set target throttle to zero and use the brake deceleration values.
@export var stop_key: Key = KEY_X
## How quickly W/S changes the target throttle. A value of 0.5 takes two seconds to go from 0 to full throttle.
@export var throttle_change_per_second: float = 0.5

@export_group("Zezlan Movement - Travel Speed")
## Enables or disables physical map travel while keeping the editor tuning values intact.
@export var movement_enabled: bool = true
## Local direction Zezlan moves at positive throttle. Default -Z walks forward toward the player side of the map.
@export var local_travel_direction: Vector3 = Vector3(0.0, 0.0, -1.0)
## If enabled, local_travel_direction follows Zezlan rotation. If disabled, local_travel_direction is treated as a world direction.
@export var use_local_direction: bool = true
## Maximum map travel speed in world units per second at full throttle.
@export var max_travel_speed: float = 4.0
## How quickly travel speed ramps up toward the target speed, in world units per second squared.
@export var travel_acceleration: float = 1.5
## How quickly travel speed coasts down when target throttle is lowered with S.
@export var travel_deceleration: float = 2.0
## How quickly travel speed brakes down after pressing X.
@export var travel_stop_deceleration: float = 6.0

@export_group("Zezlan Movement - Walk Animation")
## Enables or disables playback of the imported walk animation.
@export var animation_enabled: bool = true
## Imported GLB animation name to play. Current Zezlan import contains WalkF.
@export var walk_animation_name: StringName = &"WalkF"
## Maximum AnimationPlayer speed_scale at full throttle.
@export var max_animation_speed_scale: float = 1.0
## How quickly animation speed ramps up toward its target speed_scale.
@export var animation_acceleration: float = 0.75
## How quickly animation speed coasts down when target throttle is lowered with S.
@export var animation_deceleration: float = 1.0
## How quickly animation speed brakes down after pressing X.
@export var animation_stop_deceleration: float = 3.0
## Animation speed_scale below this value is treated as stopped.
@export var animation_stop_threshold: float = 0.02
## Stops the AnimationPlayer when animation speed reaches zero. Disable to freeze on the current pose instead.
@export var stop_animation_when_idle: bool = true

@export_group("Zezlan Collision")
## Builds physics collision from Zezlan's imported MeshInstance3D nodes when the scene starts.
@export var build_mesh_collision_on_ready: bool = true
## Group assigned to Zezlan and generated mesh collider bodies so the aim and hit logic recognize them as targets.
@export var collision_group_name: StringName = &"enemy"
## If disabled, only visible mesh nodes get generated collision.
@export var include_invisible_mesh_collision: bool = false
## Collision layer assigned to generated mesh bodies. Default 1 matches the projectile's default mask.
@export_flags_3d_physics var generated_collision_layer: int = 1
## Collision mask assigned to generated mesh bodies.
@export_flags_3d_physics var generated_collision_mask: int = 1

@export_group("Zezlan Collision Debug")
## Prints Zezlan collision setup details, including generated mesh collider names, layers, masks, and AABBs.
@export var collision_debug_enabled: bool = true
## Prints one line for each generated mesh collider. Disable if the startup log gets too noisy.
@export var collision_debug_log_each_collider: bool = true

var target_throttle: float = 0.0
var current_travel_speed: float = 0.0
var current_animation_speed: float = 0.0
var braking_to_stop: bool = false
var animation_player: AnimationPlayer

func _ready() -> void:
	add_to_group(collision_group_name)
	if build_mesh_collision_on_ready:
		_build_mesh_colliders()

	animation_player = _find_animation_player(self)
	if animation_player and animation_enabled:
		animation_player.speed_scale = 0.0

func _process(delta: float) -> void:
	_update_throttle_input(delta)
	_update_travel(delta)
	_update_animation(delta)

func _update_throttle_input(delta: float) -> void:
	if Input.is_physical_key_pressed(throttle_up_key):
		target_throttle = clampf(target_throttle + throttle_change_per_second * delta, 0.0, 1.0)
		braking_to_stop = false
	if Input.is_physical_key_pressed(throttle_down_key):
		target_throttle = clampf(target_throttle - throttle_change_per_second * delta, 0.0, 1.0)
		braking_to_stop = false

	if Input.is_physical_key_pressed(stop_key):
		target_throttle = 0.0
		braking_to_stop = true

func _update_travel(delta: float) -> void:
	var target_speed: float = target_throttle * max(0.0, max_travel_speed)
	var ramp: float = travel_acceleration
	if target_speed < current_travel_speed:
		ramp = travel_stop_deceleration if braking_to_stop else travel_deceleration

	current_travel_speed = move_toward(current_travel_speed, target_speed, max(0.0, ramp) * delta)
	if current_travel_speed <= 0.001 and target_speed <= 0.001:
		current_travel_speed = 0.0
		braking_to_stop = false

	if not movement_enabled or current_travel_speed <= 0.0:
		return

	var travel_direction := _get_travel_direction()
	if travel_direction != Vector3.ZERO:
		global_position += travel_direction * current_travel_speed * delta

func _update_animation(delta: float) -> void:
	if not animation_enabled or animation_player == null:
		return

	var target_speed: float = target_throttle * max(0.0, max_animation_speed_scale)
	var ramp: float = animation_acceleration
	if target_speed < current_animation_speed:
		ramp = animation_stop_deceleration if braking_to_stop else animation_deceleration

	current_animation_speed = move_toward(current_animation_speed, target_speed, max(0.0, ramp) * delta)
	if current_animation_speed <= animation_stop_threshold and target_speed <= animation_stop_threshold:
		current_animation_speed = 0.0
		animation_player.speed_scale = 0.0
		if stop_animation_when_idle and animation_player.is_playing():
			animation_player.stop()
		return

	if not animation_player.has_animation(walk_animation_name):
		return

	animation_player.speed_scale = current_animation_speed
	if not animation_player.is_playing() or animation_player.current_animation != walk_animation_name:
		animation_player.play(walk_animation_name)

func _get_travel_direction() -> Vector3:
	var direction := local_travel_direction
	if use_local_direction:
		direction = global_transform.basis * local_travel_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	return direction.normalized()

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _build_mesh_colliders() -> void:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(self, mesh_instances)
	if collision_debug_enabled:
		print("[ZEZLAN COLLISION] building mesh colliders root=", name, " mesh_count=", mesh_instances.size(), " group=", collision_group_name, " layer=", generated_collision_layer, " mask=", generated_collision_mask)
	for mesh_instance in mesh_instances:
		_add_mesh_collider(mesh_instance)

func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh and (include_invisible_mesh_collision or mesh_instance.visible):
			out.append(mesh_instance)

	for child in node.get_children():
		_collect_mesh_instances(child, out)

func _add_mesh_collider(mesh_instance: MeshInstance3D) -> void:
	var shape := mesh_instance.mesh.create_trimesh_shape()
	if not shape:
		if collision_debug_enabled:
			print("[ZEZLAN COLLISION] skipped mesh=", mesh_instance.name, " reason=create_trimesh_shape returned null")
		return

	var body := StaticBody3D.new()
	body.name = "%s_MeshCollider" % mesh_instance.name
	body.collision_layer = generated_collision_layer
	body.collision_mask = generated_collision_mask
	body.add_to_group(collision_group_name)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "Shape"
	collision_shape.shape = shape
	body.add_child(collision_shape)

	mesh_instance.add_child(body)

	if collision_debug_enabled and collision_debug_log_each_collider:
		var world_aabb = _get_mesh_world_aabb(mesh_instance)
		print("[ZEZLAN COLLISION] collider=", body.name, " mesh=", mesh_instance.name, " world_aabb_pos=", _fmt_vec(world_aabb.position), " world_aabb_size=", _fmt_vec(world_aabb.size), " layer=", body.collision_layer, " mask=", body.collision_mask, " groups=", body.get_groups())

func _get_mesh_world_aabb(mesh_instance: MeshInstance3D) -> AABB:
	var local_aabb := mesh_instance.get_aabb()
	var points = [
		local_aabb.position,
		local_aabb.position + Vector3(local_aabb.size.x, 0.0, 0.0),
		local_aabb.position + Vector3(0.0, local_aabb.size.y, 0.0),
		local_aabb.position + Vector3(0.0, 0.0, local_aabb.size.z),
		local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0.0),
		local_aabb.position + Vector3(local_aabb.size.x, 0.0, local_aabb.size.z),
		local_aabb.position + Vector3(0.0, local_aabb.size.y, local_aabb.size.z),
		local_aabb.position + local_aabb.size
	]
	var world_pos = mesh_instance.global_transform * points[0]
	var world_aabb := AABB(world_pos, Vector3.ZERO)
	for point in points:
		world_aabb = world_aabb.expand(mesh_instance.global_transform * point)
	return world_aabb

func _fmt_vec(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
