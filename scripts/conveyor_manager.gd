extends Node3D

@export var chain_count: int = 4
@export var links_per_chain: int = 50
@export var link_spacing: float = 0.4
@export var chain_spacing: float = 1.5
@export var speed: float = 2.0

var chains = []
var log_node: RigidBody3D

func _ready():
	# 1. Setup Camera and Light
	var cam = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(10, 5, 10)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	
	var sun = DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.shadow_enabled = true

	# 2. Build Chains
	var link_mesh = BoxMesh.new()
	link_mesh.size = Vector3(0.3, 0.1, 0.3)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	mat.metallic = 0.8
	mat.roughness = 0.4
	
	# Try to load existing texture if available
	var tex = load("res://assets/textures/Metal/rusty_metal_04_diff_4k.png")
	if tex:
		mat.albedo_texture = tex
	
	for i in range(chain_count):
		var chain_root = Node3D.new()
		add_child(chain_root)
		chain_root.position.x = (i - (chain_count-1)/2.0) * chain_spacing
		
		var links = []
		for j in range(links_per_chain):
			var link = MeshInstance3D.new()
			link.mesh = link_mesh
			link.material_override = mat
			chain_root.add_child(link)
			link.position.z = j * link_spacing - (links_per_chain * link_spacing / 2.0)
			links.append(link)
		chains.append(links)

	# 3. Add Log
	log_node = RigidBody3D.new()
	add_child(log_node)
	log_node.position = Vector3(0, 1.0, 0)
	
	var log_mesh_inst = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.height = 8.0
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 0.6
	log_mesh_inst.mesh = cylinder
	log_mesh_inst.rotation_degrees.z = 90 # Lay it across chains
	log_node.add_child(log_mesh_inst)
	
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.height = 8.0
	shape.radius = 0.6
	col.shape = shape
	col.rotation_degrees.z = 90
	log_node.add_child(col)
	
	# Add floor for safety
	var floor_node = StaticBody3D.new()
	add_child(floor_node)
	var floor_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(20, 0.2, 40)
	floor_mesh.mesh = box
	floor_node.add_child(floor_mesh)
	floor_node.position.y = -0.5

func _process(delta):
	# Move Chain Links
	var total_length = links_per_chain * link_spacing
	var half_length = total_length / 2.0
	
	for chain in chains:
		for link in chain:
			link.position.z += speed * delta
			# Wrap around
			if link.position.z > half_length:
				link.position.z -= total_length
	
	# Move the log if it's on the chains (simplified simulation)
	if log_node:
		log_node.global_position.z += speed * delta
		if log_node.global_position.z > 15:
			log_node.global_position.z = -15
