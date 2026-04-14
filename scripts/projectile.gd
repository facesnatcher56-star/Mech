extends Area3D

var speed: float = 45.0
var sparks_script = preload("res://scripts/impact_sparks.gd")
var shooter: Node3D = null

func _ready():
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	
	var gold_mat = preload("res://materials/gold_shell.tres")
	_apply_gold_recursive(self, gold_mat)
	
	$LifeTimer.timeout.connect(func(): queue_free())

func _apply_gold_recursive(node: Node, mat: Material):
	if node is MeshInstance3D:
		node.set_surface_override_material(0, mat)
		node.visible = true
	for child in node.get_children():
		_apply_gold_recursive(child, mat)

func _physics_process(delta):
	global_translate(-global_transform.basis.z * speed * delta)

func _on_body_entered(body):
	# DEBUG: Log everything we touch
	print("Bullet hit: ", body.name, " Groups: ", body.get_groups())
	
	# Prevent the bullet from hitting the machine that fired it
	if body == shooter or (shooter and body.get_parent() == shooter):
		return
		
	# 1. Visual Payoff
	var sparks = sparks_script.new()
	get_tree().root.add_child(sparks)
	sparks.global_position = global_position
	
	# 2. Hit Logic
	if body.is_in_group("player") or (body.get_parent() and body.get_parent().is_in_group("player")):
		print("WARNING: COCKPIT HIT!")
	
	var target = body
	if not target.has_method("hit") and target.get_parent():
		target = target.get_parent()
		
	if target.has_method("hit"):
		target.hit()
	
	# 3. Cleanup
	queue_free()
