extends Area3D

## World units per second that the shell travels.
@export var speed: float = 150.0
@export_group("Collision Debug")
## Prints shell path, swept ray hits, Area3D collision hits, and lifetime cleanup.
@export var collision_debug_enabled: bool = false
## Physics mask used by the debug sweep ray. Default 1 matches the shell collider.
@export_flags_3d_physics var collision_debug_mask: int = 1
## Prints every path sample. Leave off unless you need very noisy per-frame shell positions.
@export var collision_debug_log_path: bool = false
## Seconds between path sample logs when collision_debug_log_path is enabled.
@export var collision_debug_path_interval: float = 0.05
## If enabled, a swept ray hit resolves the shell immediately. If disabled, it only reports likely tunneling.
@export var collision_debug_resolve_sweep_hits: bool = false
var sparks_script = preload("res://scripts/impact_sparks.gd")
var shooter: Node3D = null
var is_player_shot: bool = false
var is_destined_for_hit: bool = false

signal has_hit(body, hit_pos)

var _last_position: Vector3 = Vector3.ZERO
var _path_log_timer: float = 0.0
var _hit_resolved: bool = false

func _ready():
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_last_position = global_position
	
	if collision_debug_enabled:
		print("[SHELL TRACE] spawn pos=", _fmt_vec(global_position), " speed=", speed, " mask=", collision_debug_mask, " destined_hit=", is_destined_for_hit)

	$LifeTimer.timeout.connect(func():
		if collision_debug_enabled and not _hit_resolved:
			print("[SHELL TRACE] lifetime expired pos=", _fmt_vec(global_position), " last=", _fmt_vec(_last_position), " no collision signal fired")
		queue_free()
	)

@onready var shell_mesh = get_node_or_null("testshell")
var spin_speed: float = 120.0 # High speed for rifling effect

func _physics_process(delta):
	if _hit_resolved:
		return

	var from_pos = global_position
	var to_pos = from_pos + (-global_transform.basis.z * speed * delta)
	_trace_sweep(from_pos, to_pos, delta)
	global_position = to_pos
	_last_position = to_pos

	if shell_mesh:
		# rotate_object_local ensures it spins around its current longitudinal axis
		shell_mesh.rotate_object_local(Vector3.UP, spin_speed * delta)

func _on_body_entered(body):
	if _hit_resolved:
		return
	if shooter and (body == shooter or shooter.is_ancestor_of(body)):
		if collision_debug_enabled:
			print("[SHELL TRACE] ignored shooter body_entered body=", body.name)
		return

	if collision_debug_enabled:
		print("[SHELL TRACE] AREA HIT body=", _describe_body(body), " pos=", _fmt_vec(global_position), " prev=", _fmt_vec(_last_position))
	else:
		print("[SHELL] Collision with: ", body.name, " Groups: ", body.get_groups())
	var hit_pos = global_position
	_resolve_hit(body, hit_pos, "area")

func _trace_sweep(from_pos: Vector3, to_pos: Vector3, delta: float) -> void:
	if not collision_debug_enabled:
		return

	_path_log_timer += delta
	if collision_debug_log_path and _path_log_timer >= max(0.001, collision_debug_path_interval):
		_path_log_timer = 0.0
		print("[SHELL TRACE] path from=", _fmt_vec(from_pos), " to=", _fmt_vec(to_pos), " speed=", speed)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = collision_debug_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = _get_sweep_exclusions()

	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return

	var body = result.get("collider")
	if not body:
		return

	print("[SHELL TRACE] SWEEP WOULD HIT body=", _describe_body(body), " from=", _fmt_vec(from_pos), " to=", _fmt_vec(to_pos), " hit=", _fmt_vec(result.position), " normal=", _fmt_vec(result.normal), " note=ray crossed collider this frame")
	if collision_debug_resolve_sweep_hits:
		_resolve_hit(body, result.position, "sweep")

func _get_sweep_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = [get_rid()]
	if shooter:
		if shooter is CollisionObject3D:
			exclusions.append((shooter as CollisionObject3D).get_rid())
		for child in shooter.get_children():
			_collect_collision_object_rids(child, exclusions)
	return exclusions

func _collect_collision_object_rids(node: Node, exclusions: Array[RID]) -> void:
	if node is CollisionObject3D:
		exclusions.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_collision_object_rids(child, exclusions)

func _resolve_hit(body, hit_pos: Vector3, source: String) -> void:
	if _hit_resolved:
		return
	_hit_resolved = true
	has_hit.emit(body, hit_pos)

	# 1. Visual Payoff
	if not is_player_shot:
		var sparks = sparks_script.new()
		get_tree().root.add_child(sparks)
		sparks.global_position = hit_pos
	
	# 2. Hit Logic (Recursive search for a 'hit' method)
	var target = body
	while target != null:
		if target.has_method("hit") or target.has_method("part_hit"):
			if collision_debug_enabled:
				print("[SHELL TRACE] resolve source=", source, " target_method_node=", target.name, " hit_pos=", _fmt_vec(hit_pos))
			if target.has_method("hit"):
				target.hit()
			else:
				target.part_hit()
			break
		target = target.get_parent()
	if collision_debug_enabled and target == null:
		print("[SHELL TRACE] resolve source=", source, " no hit()/part_hit() owner found for body=", _describe_body(body))
	
	# 3. Cleanup
	queue_free()

func _describe_body(body) -> String:
	if not body:
		return "none"
	var text = str(body.name)
	if body is Node:
		text += " groups=" + str((body as Node).get_groups())
		var parent = (body as Node).get_parent()
		if parent:
			text += " parent=" + parent.name
	return text

func _fmt_vec(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
