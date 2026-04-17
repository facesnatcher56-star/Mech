@tool
extends GPUParticles3D

# --- Directional Controls ---
@export_group("Direction & Shape")
@export var shoot_direction: Vector3 = Vector3(0, 0, -1):
	set(val):
		shoot_direction = val
		_update_particles()
@export_range(0, 180) var cone_spread: float = 25.0:
	set(val):
		cone_spread = val
		_update_particles()
@export var initial_velocity: float = 15.0:
	set(val):
		initial_velocity = val
		_update_particles()

# --- Visuals & Linger ---
@export_group("Appearance")
@export var smoke_texture: Texture2D = preload("res://assets/VFX/Smoke/PNG/Black smoke/blackSmoke00.png"):
	set(val):
		smoke_texture = val
		_update_material()
@export_range(0.0, 1.0) var smoke_opacity: float = 0.8:
	set(val):
		smoke_opacity = val
		_update_particles()
## Thickness/Density of the smoke (how much it overlaps).
@export_range(1, 1000) var smoke_density: int = 150:
	set(val):
		smoke_density = val
		amount = val
@export var linger_time: float = 3.0:
	set(val):
		linger_time = val
		lifetime = val
		_update_particles()
@export var smoke_scale: float = 4.0:
	set(val):
		smoke_scale = val
		_update_particles()

# --- Frequency ---
@export_group("Frequency")
@export var is_running: bool = false:
	set(val):
		is_running = val
		one_shot = !val
		emitting = val
		if val: 
			explosiveness = 0.0
		else:
			explosiveness = 1.0
		_update_particles()
@export var particle_amount: int = 50:
	set(val):
		particle_amount = val
		amount = val

# --- Editor Only ---
@export_group("Editor")
@export var show_indicator: bool = true:
	set(val):
		show_indicator = val
		if indicator: indicator.visible = val

var indicator: MeshInstance3D

func _ready():
	if Engine.is_editor_hint():
		_create_indicator()
	
	_update_particles()
	_update_material()

func _process(_delta):
	if Engine.is_editor_hint():
		if is_running and not emitting:
			emitting = true

func _create_indicator():
	if indicator: indicator.queue_free()
	indicator = MeshInstance3D.new()
	var arrow_mesh = ImmediateMesh.new()
	indicator.mesh = arrow_mesh
	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.YELLOW
	indicator.material_override = mat
	add_child(indicator)
	_draw_arrow()

func _draw_arrow():
	if not indicator: return
	var mesh: ImmediateMesh = indicator.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var dir = shoot_direction.normalized() * 2.0
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(dir)
	var side = dir.cross(Vector3.UP).normalized() * 0.3
	if side.length() < 0.01: side = Vector3.RIGHT * 0.3
	mesh.surface_add_vertex(dir)
	mesh.surface_add_vertex(dir * 0.8 + side)
	mesh.surface_add_vertex(dir)
	mesh.surface_add_vertex(dir * 0.8 - side)
	mesh.surface_end()

func _update_particles():
	if not process_material or not (process_material is ParticleProcessMaterial):
		process_material = ParticleProcessMaterial.new()
	
	local_coords = false
	visibility_aabb = AABB(Vector3(-100, -100, -100), Vector3(200, 200, 200))
	
	var mat: ParticleProcessMaterial = process_material
	mat.direction = shoot_direction
	mat.spread = cone_spread
	
	mat.initial_velocity_min = initial_velocity * 0.1
	mat.initial_velocity_max = initial_velocity
	
	mat.gravity = Vector3(0, 0.4, 0)
	mat.damping_min = 4.0
	mat.damping_max = 6.0
	
	mat.scale_min = smoke_scale * 0.5
	mat.scale_max = smoke_scale
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.add_point(0.1, Color(1, 1, 1, smoke_opacity))
	gradient.add_point(0.5, Color(1, 1, 1, smoke_opacity * 0.7))
	gradient.add_point(1.0, Color(1, 1, 1, 0))
	
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex
	
	one_shot = !is_running
	if Engine.is_editor_hint():
		_draw_arrow()

func _update_material():
	if not draw_pass_1 or not (draw_pass_1 is QuadMesh):
		draw_pass_1 = QuadMesh.new()
	var mesh: QuadMesh = draw_pass_1
	var mat = StandardMaterial3D.new()
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = smoke_texture
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mat

func fire():
	if is_running: return
	one_shot = true
	emitting = true
	restart()
