extends Node

const WORLD_SEED := 74291
const TREE_COUNT := 42
const ROCK_COUNT := 34
const GRASS_COUNT := 1200
const MAP_HALF_SIZE := 235.0
const CLEAR_PATH_HALF_WIDTH := 18.0
const PLAYER_CLEAR_RADIUS := 28.0
const ENEMY_CLEAR_RADIUS := 22.0

var _rng := RandomNumberGenerator.new()

func _ready():
	_rng.seed = WORLD_SEED
	
	# 1. Procedural Grass Ground
	var floor_mesh = CSGBox3D.new()
	floor_mesh.size = Vector3(500, 1, 500)
	floor_mesh.position = Vector3(0, -2.5, 0)
	floor_mesh.use_collision = true
	
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.4, 0.1) # Grassy green
	floor_mat.roughness = 0.9
	
	var floor_noise = FastNoiseLite.new()
	floor_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	floor_noise.frequency = 0.1
	var floor_tex = NoiseTexture2D.new()
	floor_tex.noise = floor_noise
	floor_tex.as_normal_map = true
	floor_tex.bump_strength = 1.0
	
	floor_mat.normal_enabled = true
	floor_mat.normal_texture = floor_tex
	floor_mat.uv1_triplanar = true 
	floor_mesh.material = floor_mat
	add_child(floor_mesh)

	# 2. Industrial Pillars Removed (Grasslands environment)

	# 3. Clearer Atmosphere (Physical Sky)
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	
	var sky = Sky.new()
	var sky_mat = PhysicalSkyMaterial.new()
	sky_mat.rayleigh_color = Color(0.3, 0.5, 0.8) # Clearer blue-ish sky
	sky_mat.mie_color = Color(0.7, 0.7, 0.7) # Brighter halo
	sky_mat.mie_eccentricity = 0.8
	sky_mat.sun_disk_scale = 10.0
	sky_mat.ground_color = Color(0.1, 0.1, 0.1)
	sky.sky_material = sky_mat
	
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.005 # Much thinner fog
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.9) # Bright fog
	
	env.ssao_enabled = true 
	env.glow_enabled = true 
	env.glow_bloom = 0.2 
	env.glow_blend_mode = 0 # Use 0 for GLOW_BLEND_MODE_ADD
	
	# Tonemapping and Exposure
	env.tonemap_mode = 3 # ACES
	env.tonemap_exposure = 1.2
	
	env_node.environment = env
	add_child(env_node)

	# 4. The Sun (Higher and brighter)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 45, 0) # Higher sun
	sun.light_color = Color(1.0, 1.0, 0.9) # Whiter sun
	sun.light_energy = 2.5 # Much brighter
	sun.shadow_enabled = true
	add_child(sun)

	_create_environment_props()

func _create_environment_props():
	var props = Node3D.new()
	props.name = "EnvironmentProps"
	add_child(props)
	
	var trunk_mat = _make_material(Color(0.27, 0.16, 0.08), 0.92)
	var leaf_mat = _make_material(Color(0.06, 0.24, 0.1), 0.96)
	var leaf_dark_mat = _make_material(Color(0.03, 0.14, 0.07), 0.98)
	var rock_mat = _make_material(Color(0.31, 0.33, 0.32), 0.88)
	var rock_dark_mat = _make_material(Color(0.18, 0.19, 0.18), 0.93)
	var grass_mat = _make_material(Color(0.12, 0.38, 0.12), 1.0)
	
	_scatter_grass(props, grass_mat)
	for i in range(TREE_COUNT):
		_create_tree(props, _pick_prop_position(), trunk_mat, leaf_mat if i % 3 != 0 else leaf_dark_mat)
	for i in range(ROCK_COUNT):
		_create_rock(props, _pick_prop_position(), rock_mat if i % 2 == 0 else rock_dark_mat)

func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _pick_prop_position() -> Vector3:
	for attempt in range(80):
		var position = Vector3(
			_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE),
			-1.95,
			_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE)
		)
		if _is_good_prop_position(position):
			return position
	
	return Vector3(_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE), -1.95, _rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE))

func _is_good_prop_position(position: Vector3) -> bool:
	var player_pos = Vector3(27.0, -1.95, -14.0)
	var enemy_pos = Vector3(25.0, -1.95, 150.0)
	if position.distance_to(player_pos) < PLAYER_CLEAR_RADIUS:
		return false
	if position.distance_to(enemy_pos) < ENEMY_CLEAR_RADIUS:
		return false
	if abs(position.x - 25.0) < CLEAR_PATH_HALF_WIDTH and position.z > -35.0 and position.z < 170.0:
		return false
	return true

func _scatter_grass(parent: Node3D, grass_mat: StandardMaterial3D):
	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 0.58, 0.025)
	blade_mesh.material = grass_mat
	
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade_mesh
	multimesh.instance_count = GRASS_COUNT
	
	var placed = 0
	var attempts = 0
	while placed < GRASS_COUNT and attempts < GRASS_COUNT * 8:
		attempts += 1
		var position = Vector3(
			_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE),
			-1.72,
			_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE)
		)
		if not _is_good_prop_position(position):
			continue
		
		var height = _rng.randf_range(0.55, 1.45)
		var width = _rng.randf_range(0.7, 1.35)
		var basis = Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, width))
		multimesh.set_instance_transform(placed, Transform3D(basis, position))
		placed += 1
	
	multimesh.visible_instance_count = placed
	
	var grass = MultiMeshInstance3D.new()
	grass.name = "GrassBlades"
	grass.multimesh = multimesh
	parent.add_child(grass)

func _create_tree(parent: Node3D, position: Vector3, trunk_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D):
	var tree = StaticBody3D.new()
	tree.name = "Tree"
	tree.position = position
	tree.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	parent.add_child(tree)
	
	var trunk_height = _rng.randf_range(4.0, 7.2)
	var trunk_radius = _rng.randf_range(0.35, 0.62)
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.78
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = trunk_height
	trunk_mesh.radial_segments = 8
	trunk_mesh.material = trunk_mat
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)
	
	var collision = CollisionShape3D.new()
	var collision_shape = CylinderShape3D.new()
	collision_shape.radius = trunk_radius * 1.15
	collision_shape.height = trunk_height
	collision.shape = collision_shape
	collision.position.y = trunk_height * 0.5
	tree.add_child(collision)
	
	var crown_layers = _rng.randi_range(2, 3)
	for layer in range(crown_layers):
		var crown = MeshInstance3D.new()
		var crown_mesh = SphereMesh.new()
		crown_mesh.radius = _rng.randf_range(1.6, 2.35) - (layer * 0.18)
		crown_mesh.height = crown_mesh.radius * _rng.randf_range(1.25, 1.55)
		crown_mesh.radial_segments = 10
		crown_mesh.rings = 5
		crown_mesh.material = leaf_mat
		crown.mesh = crown_mesh
		crown.position = Vector3(
			_rng.randf_range(-0.35, 0.35),
			trunk_height + 0.6 + (layer * 0.95),
			_rng.randf_range(-0.35, 0.35)
		)
		crown.scale = Vector3(_rng.randf_range(1.0, 1.35), 1.0, _rng.randf_range(1.0, 1.35))
		tree.add_child(crown)

func _create_rock(parent: Node3D, position: Vector3, rock_mat: StandardMaterial3D):
	var rock = StaticBody3D.new()
	rock.name = "Rock"
	rock.position = position
	rock.rotation_degrees = Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(0.0, 360.0), _rng.randf_range(-5.0, 5.0))
	parent.add_child(rock)
	
	var radius = _rng.randf_range(0.9, 2.8)
	var rock_scale = Vector3(_rng.randf_range(1.0, 1.9), _rng.randf_range(0.45, 0.9), _rng.randf_range(0.8, 1.55))
	var mesh_instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * _rng.randf_range(0.9, 1.45)
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = rock_mat
	mesh_instance.mesh = mesh
	mesh_instance.position.y = radius * 0.35
	mesh_instance.scale = rock_scale
	rock.add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	var collision_shape = BoxShape3D.new()
	collision_shape.size = Vector3(
		radius * 1.65 * rock_scale.x,
		radius * 0.95 * rock_scale.y,
		radius * 1.65 * rock_scale.z
	)
	collision.shape = collision_shape
	collision.position.y = radius * 0.35
	rock.add_child(collision)
