extends Node

func _ready():
	# 1. Generate the Ground
	var floor_mesh = CSGBox3D.new()
	floor_mesh.size = Vector3(500, 1, 500)
	floor_mesh.position = Vector3(0, -2.5, 0) # Top surface sits at Y = -2.0
	floor_mesh.use_collision = true
	
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.15, 0.15) # Dark asphalt
	floor_mesh.material = floor_mat
	add_child(floor_mesh)

	# 2. Generate the Concrete Graveyard (The Pillars)
	for i in range(50):
		var pillar = CSGBox3D.new()
		# Randomize massive dimensions
		var w = randf_range(4.0, 12.0)
		var d = randf_range(4.0, 12.0)
		var h = randf_range(20.0, 80.0)
		pillar.size = Vector3(w, h, d)
		
		# Scatter randomly across the floor, avoiding the exact dead center (spawn area)
		var pos_x = 0.0
		var pos_z = 0.0
		while abs(pos_x) < 20 and abs(pos_z) < 20:
			pos_x = randf_range(-200.0, 200.0)
			pos_z = randf_range(-200.0, 200.0)
			
		pillar.position = Vector3(pos_x, -2.0 + (h / 2.0), pos_z)
		pillar.use_collision = true
		
		var pillar_mat = StandardMaterial3D.new()
		pillar_mat.albedo_color = Color(0.2, 0.2, 0.22) # Brutalist gray concrete
		pillar.material = pillar_mat
		add_child(pillar)

	# 3. Generate the Skybox and Fog
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.3, 0.4)
	sky_mat.sky_horizon_color = Color(0.5, 0.5, 0.5)
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.1)
	sky.sky_material = sky_mat
	
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.05
	env.volumetric_fog_albedo = Color(0.6, 0.6, 0.6)
	
	env_node.environment = env
	add_child(env_node)

	# 4. Generate the Sun
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.shadow_enabled = true
	add_child(sun)
