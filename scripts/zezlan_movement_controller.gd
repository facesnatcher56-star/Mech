extends Node3D

const PROJECTILE = preload("res://scenes/projectile.tscn")
const _CANNON_FIRE_STREAM = preload("res://assets/Sounds/artillery-gunfire2.wav")

@export_group("Zezlan Firing")
## Seconds between each shot fired at the player.
@export var fire_interval: float = 12.0
## Delay before the very first shot.
@export var initial_fire_delay: float = 4.0
## Shell travel speed in world units per second.
@export var shell_speed: float = 80.0
## Vertical offset applied to the player aim point (targets the cockpit, not the feet).
@export var aim_height_offset: float = 3.0
## Minimum seconds Zezlan holds aim before firing.
@export var min_aim_time: float = 4.0
## Maximum seconds Zezlan holds aim before firing.
@export var max_aim_time: float = 12.0
## Half-angle of the spread cone in degrees at minimum aim time (panic fire).
@export var max_cone_angle_deg: float = 25.0
## Seconds added to aim window when a leg (body) hit lands during aiming.
@export var aim_extension_body_hit: float = 3.0
## Seconds added to aim window when a torso (gun) hit lands during aiming.
@export var aim_extension_torso_hit: float = 1.5

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

@export_group("Zezlan HP")
## Total enemy structure pool shown in the target dossier.
@export var max_structure_hp: int = 100
## Torso armor pool. Reaching zero destroys Zezlan.
@export var max_torso_hp: int = 60
## Left leg armor pool. Reaching zero marks the leg broken in the UI only.
@export var max_left_leg_hp: int = 40
## Right leg armor pool. Reaching zero marks the leg broken in the UI only.
@export var max_right_leg_hp: int = 40
## Damage applied to total structure and torso on torso hits.
@export var torso_hit_damage: int = 18
## Damage applied to total structure and the matching leg on leg hits.
@export var leg_hit_damage: int = 14
## Damage applied to total structure if an unmapped Zezlan mesh is hit.
@export var fallback_hit_damage: int = 18

var _fire_timer: float = 0.0
var _cycle_active: bool = false
var _is_aiming: bool = false
var _aim_timer: float = 0.0
var _aim_duration: float = 0.0
var target_throttle: float = 0.0
var current_travel_speed: float = 0.0
var current_animation_speed: float = 0.0
var braking_to_stop: bool = false
var animation_player: AnimationPlayer
var structure_hp: int = 100
var torso_hp: int = 60
var left_leg_hp: int = 40
var right_leg_hp: int = 40
var is_destroyed: bool = false
var _smoke_deployed: bool = false
var _broken_parts := {}
var damage_number_script = preload("res://scripts/damage_number.gd")

signal hp_changed(snapshot: Dictionary)

func _ready() -> void:
	add_to_group(collision_group_name)
	_reset_hp_pools()
	_fire_timer = initial_fire_delay
	if build_mesh_collision_on_ready:
		_build_mesh_colliders()

	animation_player = _find_animation_player(self)
	if animation_player and animation_enabled:
		animation_player.speed_scale = 0.0

func _reset_hp_pools() -> void:
	structure_hp = max(0, max_structure_hp)
	torso_hp = max(0, max_torso_hp)
	left_leg_hp = max(0, max_left_leg_hp)
	right_leg_hp = max(0, max_right_leg_hp)
	is_destroyed = false
	_broken_parts.clear()

func apply_shell_damage(hit_body: Node, hit_pos: Vector3) -> Dictionary:
	if is_destroyed:
		return {
			"applied": false,
			"damage": 0,
			"region": "DESTROYED",
			"part_key": "destroyed",
			"snapshot": get_hp_snapshot()
		}

	var region := _get_hit_region(hit_body)
	var part_key := _region_to_part_key(region)
	var damage := _get_damage_for_region(region)
	var before_part_hp := _get_part_hp(region)

	structure_hp = maxi(0, structure_hp - damage)
	match region:
		"TORSO":
			torso_hp = maxi(0, torso_hp - damage)
			if not _smoke_deployed and torso_hp <= max_torso_hp * 0.5:
				_smoke_deployed = true
				_deploy_smoke_screen()
		"LEFT LEG":
			left_leg_hp = maxi(0, left_leg_hp - damage)
		"RIGHT LEG":
			right_leg_hp = maxi(0, right_leg_hp - damage)

	var part_broken := before_part_hp > 0 and _get_part_hp(region) <= 0 and region != "STRUCTURE"
	if part_broken:
		_broken_parts[region] = true

	if structure_hp <= 0 or torso_hp <= 0:
		_destroy_zezlan()

	damage_number_script.display_text(hit_pos + Vector3.UP * 0.5, "-%d" % damage, get_tree().current_scene, Color(1.0, 0.78, 0.12))
	if part_broken:
		damage_number_script.display_text(hit_pos + Vector3.UP * 1.2, "BROKEN", get_tree().current_scene, Color(1.0, 0.25, 0.1))

	var snapshot := get_hp_snapshot()
	hp_changed.emit(snapshot)
	return {
		"applied": true,
		"damage": damage,
		"region": region,
		"part_key": part_key,
		"part_broken": part_broken,
		"destroyed": is_destroyed,
		"snapshot": snapshot
	}

func get_fire_progress() -> float:
	if is_destroyed:
		return 0.0
	if _is_aiming:
		return 1.0
	return clampf(1.0 - (_fire_timer / maxf(0.001, fire_interval)), 0.0, 1.0)

func get_hp_snapshot() -> Dictionary:
	return {
		"name": "ZEZLAN",
		"structure": {"current": structure_hp, "max": max_structure_hp},
		"parts": {
			"torso": {"label": "TORSO", "current": torso_hp, "max": max_torso_hp, "broken": torso_hp <= 0},
			"left_leg": {"label": "LEFT LEG", "current": left_leg_hp, "max": max_left_leg_hp, "broken": left_leg_hp <= 0},
			"right_leg": {"label": "RIGHT LEG", "current": right_leg_hp, "max": max_right_leg_hp, "broken": right_leg_hp <= 0}
		},
		"reload": {"progress": get_fire_progress(), "label": "CANNON", "aiming": _is_aiming},
		"destroyed": is_destroyed
	}

func apply_rpg_structure_damage(damage: int, hit_pos: Vector3) -> Dictionary:
	if is_destroyed:
		return {
			"applied": false,
			"damage": 0,
			"region": "STRUCTURE",
			"part_key": "structure",
			"destroyed": true,
			"snapshot": get_hp_snapshot()
		}

	var applied_damage: int = maxi(0, damage)
	structure_hp = maxi(0, structure_hp - applied_damage)
	if structure_hp <= 0:
		_destroy_zezlan()

	damage_number_script.display_text(hit_pos + Vector3.UP * 0.75, "-%d RPG" % applied_damage, get_tree().current_scene, Color(1.0, 0.58, 0.16), 28)

	var snapshot := get_hp_snapshot()
	hp_changed.emit(snapshot)
	return {
		"applied": true,
		"damage": applied_damage,
		"region": "STRUCTURE",
		"part_key": "structure",
		"destroyed": is_destroyed,
		"snapshot": snapshot
	}

func _get_hit_region(hit_body: Node) -> String:
	var node := hit_body
	while node:
		var node_name := node.name.to_lower()
		if "torso" in node_name:
			return "TORSO"
		if "footl" in node_name or "kneel" in node_name or "legl" in node_name:
			return "LEFT LEG"
		if "footr" in node_name or "kneer" in node_name or "legr" in node_name:
			return "RIGHT LEG"
		node = node.get_parent()
	return "STRUCTURE"

func _region_to_part_key(region: String) -> String:
	match region:
		"TORSO":
			return "torso"
		"LEFT LEG":
			return "leftleg"
		"RIGHT LEG":
			return "rightleg"
		_:
			return "torso"

func _get_damage_for_region(region: String) -> int:
	var base := 0
	match region:
		"TORSO":
			base = torso_hit_damage
		"LEFT LEG", "RIGHT LEG":
			base = leg_hit_damage
		_:
			base = fallback_hit_damage
	return maxi(1, roundi(base * randf_range(0.8, 1.2)))

func _get_part_hp(region: String) -> int:
	match region:
		"TORSO":
			return torso_hp
		"LEFT LEG":
			return left_leg_hp
		"RIGHT LEG":
			return right_leg_hp
		_:
			return structure_hp

func _destroy_zezlan() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	target_throttle = 0.0
	current_travel_speed = 0.0
	current_animation_speed = 0.0
	movement_enabled = false
	if animation_player:
		animation_player.speed_scale = 0.0
		if stop_animation_when_idle and animation_player.is_playing():
			animation_player.stop()

func _process(delta: float) -> void:
	_update_throttle_input(delta)
	_update_travel(delta)
	_update_animation(delta)
	_update_fire_timer(delta)
	_update_aiming(delta)

func _update_fire_timer(delta: float) -> void:
	if is_destroyed or _is_aiming or _cycle_active:
		return
	if get_tree().get_nodes_in_group("shell_in_flight").size() > 0:
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_start_aiming()

func apply_aim_disruption(region: String) -> void:
	if not _is_aiming:
		return
	match region:
		"TORSO":
			_aim_duration += aim_extension_torso_hit
		"LEFT LEG", "RIGHT LEG":
			_aim_duration += aim_extension_body_hit

func _start_aiming() -> void:
	_is_aiming = true
	_aim_timer = 0.0
	_aim_duration = randf_range(min_aim_time, max_aim_time)

func _update_aiming(delta: float) -> void:
	if not _is_aiming:
		return
	if get_tree().get_nodes_in_group("shell_in_flight").size() > 0:
		return
	_aim_timer += delta
	if _aim_timer >= _aim_duration:
		_is_aiming = false
		_cycle_active = true
		_fire_at_player()

func _fire_at_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(player):
		return

	if player.has_method("begin_enemy_fire_cinematic"):
		player.begin_enemy_fire_cinematic(func(): _launch_shell(player), func(): _cycle_active = false)
	else:
		_launch_shell(player)
		_cycle_active = false

func _launch_shell(player: Node3D) -> void:
	if not is_instance_valid(player):
		return

	var fire_player := get_node_or_null("ZezlanFirePlayer") as AnimationPlayer
	if fire_player and fire_player.has_animation(&"Fire"):
		fire_player.stop()
		fire_player.play(&"Fire")

	var muzzle_pos := _get_muzzle_position()
	var aim_pos    := player.global_position + Vector3.UP * aim_height_offset
	var aim_range     := maxf(0.001, max_aim_time - min_aim_time)
	var t             := clampf((_aim_timer - min_aim_time) / aim_range, 0.0, 1.0)
	var accuracy      := t * t
	var cone_half_rad := deg_to_rad(max_cone_angle_deg * (1.0 - accuracy))
	var distance      := muzzle_pos.distance_to(aim_pos)
	var cone_radius   := tan(cone_half_rad) * distance
	var rand_r        := sqrt(randf()) * cone_radius
	var rand_theta    := randf() * TAU
	aim_pos += Vector3(rand_r * cos(rand_theta), 0.0, rand_r * sin(rand_theta))

	var fire_sfx := AudioStreamPlayer3D.new()
	fire_sfx.stream = _CANNON_FIRE_STREAM
	fire_sfx.max_distance = 300.0
	get_tree().root.add_child(fire_sfx)
	fire_sfx.global_position = muzzle_pos
	fire_sfx.play()
	fire_sfx.finished.connect(fire_sfx.queue_free)

	var shell := PROJECTILE.instantiate()
	shell.shooter = self
	shell.speed = shell_speed
	shell.is_player_shot = false
	get_tree().root.add_child(shell)
	shell.global_position = muzzle_pos
	shell.look_at(aim_pos, Vector3.UP)

	if player.has_method("set_enemy_active_shell"):
		player.set_enemy_active_shell(shell, aim_pos)


func _get_muzzle_position() -> Vector3:
	var muzzle := find_child("EnemyMuzzle", true, false) as Node3D
	if muzzle:
		return muzzle.global_position
	return global_position + Vector3.UP * 6.5

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
		var ap := node as AnimationPlayer
		if ap.has_animation(walk_animation_name):
			return ap
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

func _deploy_smoke_screen() -> void:
	var smoke = get_tree().current_scene.find_child("SmokeScreen", true, false)
	if smoke and smoke.has_method("deploy"):
		smoke.deploy()
	
	var bark_ui = get_tree().current_scene.find_child("CombatBarkUI", true, false)
	if bark_ui and bark_ui.has_method("show_smoke_alert"):
		bark_ui.show_smoke_alert()
