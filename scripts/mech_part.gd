extends Node3D

@export var part_name: String = "Body Part"
@export var is_vital: bool = false # If true, destroying this kills the whole mech
@export var parent_mech: Node3D

var is_destroyed: bool = false
var spark_timer: Timer
var damage_number_script = preload("res://scripts/damage_number.gd")

func hit():
	if is_destroyed: return
	
	print(part_name + " HIT!")
	damage_number_script.display_text(global_position + Vector3(0, 0.5, 0), "1", get_tree().root)
	destroy_part()

func destroy_part():
	is_destroyed = true
	
	var explosion_scene = preload("res://scenes/small_explosion.tscn")
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position
	
	# Hide the part
	visible = false
	
	# Disable collisions so shells don't hit a dead part
	_disable_collision_recursive(self)
	
	# Start sparking if not vital
	
	# Notify parent mech
	if parent_mech and parent_mech.has_method("part_destroyed"):
		parent_mech.part_destroyed(self)

func start_sparking():
	# Create a persistent spark emitter at the attachment point
	var sparks = GPUParticles3D.new()
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.15
	mat.color = Color(1, 1, 0.5) # Yellow sparks
	
	sparks.process_material = mat
	sparks.amount = 10
	sparks.lifetime = 0.5
	sparks.preprocess = 0.1
	
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	sparks.draw_pass_1 = mesh
	
	add_child(sparks)
	sparks.position = Vector3.ZERO # At the part's origin
	
	# Make it spark "ever so often" instead of constantly
	spark_timer = Timer.new()
	add_child(spark_timer)
	spark_timer.wait_time = randf_range(0.5, 2.0)
	spark_timer.timeout.connect(func():
		sparks.emitting = true
		spark_timer.wait_time = randf_range(1.0, 3.0)
	)
	spark_timer.start()
	sparks.emitting = false
	sparks.one_shot = true # Trigger manually via timer

func _disable_collision_recursive(node: Node):
	if node is CollisionShape3D:
		node.disabled = true
	if node is CollisionObject3D:
		# Also disable the object itself just in case
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)
	for child in node.get_children():
		_disable_collision_recursive(child)
