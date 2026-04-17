extends Area3D

var speed: float = 150.0
var sparks_script = preload("res://scripts/impact_sparks.gd")
var shooter: Node3D = null
var is_player_shot: bool = false
var is_destined_for_hit: bool = false

signal has_hit(body, hit_pos)

func _ready():
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	
	$LifeTimer.timeout.connect(func(): queue_free())

@onready var shell_mesh = get_node_or_null("testshell")
var spin_speed: float = 120.0 # High speed for rifling effect

func _physics_process(delta):
	global_translate(-global_transform.basis.z * speed * delta)
	if shell_mesh:
		# rotate_object_local ensures it spins around its current longitudinal axis
		shell_mesh.rotate_object_local(Vector3.UP, spin_speed * delta)

func _on_body_entered(body):
	if shooter and (body == shooter or shooter.is_ancestor_of(body)):
		return

	print("[SHELL] Collision with: ", body.name, " Groups: ", body.get_groups())
	var hit_pos = global_position
	has_hit.emit(body, hit_pos)

	# 1. Visual Payoff
	if not is_player_shot:
		var sparks = sparks_script.new()
		get_tree().root.add_child(sparks)
		sparks.global_position = global_position
	
	# 2. Hit Logic (Recursive search for a 'hit' method)
	var target = body
	while target != null:
		if target.has_method("hit") or target.has_method("part_hit"):
			if target.has_method("hit"):
				target.hit()
			else:
				target.part_hit()
			break
		target = target.get_parent()
	
	# 3. Cleanup
	queue_free()
