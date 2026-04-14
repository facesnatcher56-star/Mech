extends Node3D

func _ready():
	var particles = GPUParticles3D.new()
	
	# 1. Mesh for the sparks (Small white-hot fragments)
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 0.04)
	
	# 2. Glowing Molten Material
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0) # White-hot core
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2) # Intense orange glow
	mat.emission_energy_multiplier = 12.0
	mesh.material = mat
	
	particles.draw_pass_1 = mesh
	
	# 3. Particle Physics (Explosive burst)
	var proc_mat = ParticleProcessMaterial.new()
	proc_mat.direction = Vector3(0, 1, 0) # Shoot upwards
	proc_mat.spread = 180.0 # Radial burst
	proc_mat.initial_velocity_min = 12.0
	proc_mat.initial_velocity_max = 22.0
	proc_mat.gravity = Vector3(0, -30.0, 0) # Strong gravity for heavy metal
	proc_mat.damping_min = 4.0
	proc_mat.damping_max = 8.0
	proc_mat.scale_min = 0.4
	proc_mat.scale_max = 1.0
	
	particles.process_material = proc_mat
	particles.amount = 40
	particles.lifetime = 0.7
	particles.explosiveness = 0.95
	particles.one_shot = true
	particles.emitting = true
	
	add_child(particles)
	
	# 4. Self-destruct once effect is finished
	await get_tree().create_timer(1.5).timeout
	queue_free()
