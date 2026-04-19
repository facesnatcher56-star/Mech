extends Node

const WORLD_SEED := 74291
const TREE_COUNT := 110
const BUILDING_COUNT := 26
const ROCK_COUNT := 40
const GRASS_COUNT := 1700
const CLOUD_COUNT := 14
const MAP_HALF_SIZE := 235.0
const GROUND_Y := 0.0
const MIN_LOS_HALF_WIDTH := 24.0
const PLAYER_CLEAR_RADIUS := 34.0
const ENEMY_CLEAR_RADIUS := 34.0
const CLOUD_ALTITUDE := 95.0
const CLOUD_FIELD_RADIUS := 330.0

var _rng := RandomNumberGenerator.new()
var _mech_width_scale := 8.5
var _mech_height_scale := 7.4
var _player_pos := Vector3(27.0, GROUND_Y, -14.0)
var _enemy_pos := Vector3(35.0, GROUND_Y, 155.0)
var _sun: DirectionalLight3D = null
var _base_sun_energy := 2.5
var _clouds: Array[Node3D] = []

func _process(delta: float) -> void:
	_update_clouds(delta)
	_update_cloud_sun_occlusion()

func _ready():
	_rng.seed = WORLD_SEED
	_capture_reference_scale()

	# 1. Procedural grass ground
	var floor_mesh = CSGBox3D.new()
	floor_mesh.size = Vector3(2000, 1, 2000)
	floor_mesh.position = Vector3(0, -0.5, 0)
	floor_mesh.use_collision = true

	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.19, 0.34, 0.12)
	floor_mat.roughness = 0.95

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

	# 2. Clear atmosphere
	var env_node = WorldEnvironment.new()
	var env = Environment.new()

	var sky = Sky.new()
	var sky_mat = PhysicalSkyMaterial.new()
	sky_mat.rayleigh_color = Color(0.3, 0.5, 0.8)
	sky_mat.mie_color = Color(0.7, 0.7, 0.7)
	sky_mat.mie_eccentricity = 0.8
	sky_mat.sun_disk_scale = 10.0
	sky_mat.ground_color = Color(0.1, 0.1, 0.1)
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.005
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.9)
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_bloom = 0.2
	env.glow_blend_mode = 0
	env.tonemap_mode = 3
	env.tonemap_exposure = 1.2

	env_node.environment = env
	add_child(env_node)

	# 3. The sun
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.rotation_degrees = Vector3(-45, 45, 0)
	_sun.light_color = Color(1.0, 1.0, 0.9)
	_sun.light_energy = _base_sun_energy
	_sun.shadow_enabled = true
	add_child(_sun)

	_create_cloud_layer()
	_create_environment_props()

func _capture_reference_scale() -> void:
	var charlie := _find_marker("REF_Charlie")
	var gamma := _find_marker("REF_Gamma")
	var beta := _find_marker("REF_Beta")
	if charlie and gamma:
		_mech_width_scale = maxf(1.0, charlie.global_position.distance_to(gamma.global_position))
	if beta:
		_mech_height_scale = maxf(2.0, beta.global_position.y - GROUND_Y)

	var player := _find_node3d("WIPtestmech")
	var enemy := _find_node3d("zezlan")
	if player:
		_player_pos = Vector3(player.global_position.x, GROUND_Y, player.global_position.z)
	if enemy:
		_enemy_pos = Vector3(enemy.global_position.x, GROUND_Y, enemy.global_position.z)

func _find_marker(node_name: String) -> Marker3D:
	var node := _find_node3d(node_name)
	return node as Marker3D

func _find_node3d(node_name: String) -> Node3D:
	var scene_root := get_tree().current_scene
	if not scene_root:
		scene_root = get_parent()
	if not scene_root:
		return null
	var direct := scene_root.get_node_or_null(node_name) as Node3D
	if direct:
		return direct
	return scene_root.find_child(node_name, true, false) as Node3D

func _create_environment_props() -> void:
	var props = Node3D.new()
	props.name = "EnvironmentProps"
	add_child(props)

	var trunk_mat = _make_material(Color(0.24, 0.14, 0.07), 0.94)
	var trunk_dark_mat = _make_material(Color(0.14, 0.08, 0.045), 0.96)
	var leaf_mat = _make_material(Color(0.05, 0.22, 0.09), 0.98)
	var leaf_dark_mat = _make_material(Color(0.025, 0.12, 0.055), 1.0)
	var leaf_pale_mat = _make_material(Color(0.12, 0.32, 0.11), 0.97)
	var rock_mat = _make_material(Color(0.31, 0.33, 0.32), 0.88)
	var rock_dark_mat = _make_material(Color(0.18, 0.19, 0.18), 0.93)
	var grass_mat = _make_material(Color(0.11, 0.34, 0.12), 1.0)
	var wall_mat = _make_material(Color(0.38, 0.39, 0.36), 0.9)
	var wall_dark_mat = _make_material(Color(0.24, 0.25, 0.24), 0.94)
	var roof_mat = _make_material(Color(0.13, 0.14, 0.14), 0.86)
	var window_mat = _make_material(Color(0.035, 0.055, 0.07), 0.35)
	var gravel_mat = _make_gravel_material()

	_create_gravel_road(props, gravel_mat)
	_scatter_grass(props, grass_mat)
	_create_building_fields(props, wall_mat, wall_dark_mat, roof_mat, window_mat)
	_create_tree_groves(props, trunk_mat, trunk_dark_mat, leaf_mat, leaf_dark_mat, leaf_pale_mat)
	for i in range(ROCK_COUNT):
		_create_rock(props, _pick_prop_position(_rng.randf_range(2.0, 5.5)), rock_mat if i % 2 == 0 else rock_dark_mat)

func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _make_gravel_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.34, 0.31)
	material.roughness = 1.0
	material.uv1_triplanar = true
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.7
	noise.fractal_octaves = 3
	var texture = NoiseTexture2D.new()
	texture.noise = noise
	texture.as_normal_map = true
	texture.bump_strength = 0.55
	material.normal_enabled = true
	material.normal_texture = texture
	return material

func _create_gravel_road(parent: Node3D, gravel_mat: StandardMaterial3D) -> void:
	var path := _enemy_pos - _player_pos
	path.y = 0.0
	var path_length := path.length()
	if path_length <= 0.001:
		return
	var forward := path / path_length
	var road_width := maxf(_mech_width_scale * 3.2, 30.0)
	var extension := maxf(_mech_width_scale * 8.0, 72.0)
	var total_length := path_length + extension * 2.0
	var center := (_player_pos + _enemy_pos) * 0.5
	center.y = GROUND_Y + 0.025

	var road = StaticBody3D.new()
	road.name = "MechScaleGravelRoad"
	road.position = center
	road.rotation.y = atan2(forward.x, forward.z)
	parent.add_child(road)

	_add_box_collision(road, Vector3(road_width * 0.9, 0.08, total_length), Vector3(0.0, -0.035, 0.0))
	_create_ragged_gravel_surface(road, road_width, total_length, gravel_mat)

func _create_ragged_gravel_surface(parent: Node3D, road_width: float, total_length: float, gravel_mat: StandardMaterial3D) -> void:
	var dark_gravel_mat = _make_material(Color(0.23, 0.23, 0.205), 1.0)
	var pale_gravel_mat = _make_material(Color(0.43, 0.42, 0.38), 1.0)
	var dirt_mat = _make_material(Color(0.13, 0.18, 0.10), 1.0)
	var pebble_mat = _make_material(Color(0.24, 0.24, 0.225), 1.0)
	var segment_length := maxf(_mech_width_scale * 2.0, 18.0)
	var segment_count := int(ceil(total_length / segment_length))
	var start_z := -total_length * 0.5
	var wheel_offset := road_width * 0.25
	var rut_width := maxf(1.25, _mech_width_scale * 0.17)

	for i in range(segment_count):
		var z := start_z + (i + 0.5) * segment_length
		var chunk_length := segment_length * _rng.randf_range(0.82, 1.18)
		var center_shift := _rng.randf_range(-road_width * 0.08, road_width * 0.08)
		var chunk_width := road_width * _rng.randf_range(0.76, 1.05)
		var mat := gravel_mat
		if i % 4 == 0:
			mat = pale_gravel_mat
		elif i % 5 == 0:
			mat = dark_gravel_mat
		_add_box_visual(
			parent,
			"UnevenGravelPatch",
			Vector3(chunk_width, _rng.randf_range(0.025, 0.055), chunk_length),
			Vector3(center_shift, _rng.randf_range(0.018, 0.055), z + _rng.randf_range(-2.0, 2.0)),
			mat
		)

		for side in [-1.0, 1.0]:
			if _rng.randf() < 0.86:
				var spill_width := _rng.randf_range(road_width * 0.08, road_width * 0.22)
				var spill_length := chunk_length * _rng.randf_range(0.35, 0.9)
				var spill_x: float = side * (chunk_width * 0.5 + spill_width * _rng.randf_range(0.1, 0.55))
				_add_box_visual(
					parent,
					"SoftGravelSpill",
					Vector3(spill_width, _rng.randf_range(0.012, 0.032), spill_length),
					Vector3(spill_x, _rng.randf_range(0.01, 0.03), z + _rng.randf_range(-segment_length * 0.3, segment_length * 0.3)),
					gravel_mat if _rng.randf() < 0.55 else dirt_mat
				)

		for side in [-1.0, 1.0]:
			_add_box_visual(
				parent,
				"PressedMechRut",
				Vector3(rut_width * _rng.randf_range(0.8, 1.45), 0.018, chunk_length * _rng.randf_range(0.7, 1.1)),
				Vector3(side * (wheel_offset + _rng.randf_range(-1.1, 1.1)), 0.065, z + _rng.randf_range(-1.4, 1.4)),
				dark_gravel_mat
			)

	_create_gravel_pebbles(parent, road_width, total_length, pebble_mat)

func _create_gravel_pebbles(parent: Node3D, road_width: float, total_length: float, pebble_mat: StandardMaterial3D) -> void:
	var pebble_count := 160
	var pebble_mesh = SphereMesh.new()
	pebble_mesh.radius = 1.0
	pebble_mesh.height = 0.55
	pebble_mesh.radial_segments = 6
	pebble_mesh.rings = 3
	pebble_mesh.material = pebble_mat
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = pebble_mesh
	multimesh.instance_count = pebble_count

	for i in range(pebble_count):
		var lateral_limit := road_width * _rng.randf_range(0.32, 0.62)
		var position = Vector3(
			_rng.randf_range(-lateral_limit, lateral_limit),
			_rng.randf_range(0.055, 0.11),
			_rng.randf_range(-total_length * 0.5, total_length * 0.5)
		)
		var scale = Vector3(
			_rng.randf_range(0.12, 0.42),
			_rng.randf_range(0.035, 0.11),
			_rng.randf_range(0.1, 0.36)
		)
		var basis = Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(scale)
		multimesh.set_instance_transform(i, Transform3D(basis, position))

	var pebbles = MultiMeshInstance3D.new()
	pebbles.name = "LooseRoadPebbles"
	pebbles.multimesh = multimesh
	parent.add_child(pebbles)

func _create_cloud_layer() -> void:
	var cloud_root = Node3D.new()
	cloud_root.name = "MovingCloudLayer"
	add_child(cloud_root)

	var cloud_mat = StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.82, 0.86, 0.88, 0.82)
	cloud_mat.roughness = 1.0
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	var cloud_shadow_mat = StandardMaterial3D.new()
	cloud_shadow_mat.albedo_color = Color(0.7, 0.72, 0.72, 0.22)
	cloud_shadow_mat.roughness = 1.0
	cloud_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(CLOUD_COUNT):
		var lane_bias := _rng.randf_range(-115.0, 115.0)
		var position = Vector3(
			_lane_x_at_z(_rng.randf_range(-120.0, 230.0)) + lane_bias,
			CLOUD_ALTITUDE + _rng.randf_range(-10.0, 18.0),
			_rng.randf_range(-210.0, 260.0)
		)
		var cloud := _create_cloud(cloud_root, position, cloud_mat, cloud_shadow_mat)
		cloud.set_meta("velocity", Vector3(_rng.randf_range(3.8, 8.4), 0.0, _rng.randf_range(-1.5, 2.5)))
		cloud.set_meta("occlusion_radius", _rng.randf_range(34.0, 72.0))
		_clouds.append(cloud)

func _create_cloud(parent: Node3D, position: Vector3, cloud_mat: StandardMaterial3D, cloud_shadow_mat: StandardMaterial3D) -> Node3D:
	var cloud = Node3D.new()
	cloud.name = "MovingCloud"
	cloud.position = position
	cloud.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	parent.add_child(cloud)

	var puff_count := _rng.randi_range(5, 9)
	var cloud_width := _rng.randf_range(30.0, 64.0)
	var cloud_depth := _rng.randf_range(12.0, 28.0)
	for i in range(puff_count):
		var puff = MeshInstance3D.new()
		puff.name = "CloudPuff"
		var mesh = SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 1.0
		mesh.radial_segments = 16
		mesh.rings = 8
		mesh.material = cloud_mat
		puff.mesh = mesh
		puff.position = Vector3(
			_rng.randf_range(-cloud_width * 0.45, cloud_width * 0.45),
			_rng.randf_range(-1.2, 2.4),
			_rng.randf_range(-cloud_depth * 0.45, cloud_depth * 0.45)
		)
		puff.scale = Vector3(
			_rng.randf_range(7.0, 16.0),
			_rng.randf_range(1.6, 3.6),
			_rng.randf_range(5.0, 12.0)
		)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		cloud.add_child(puff)

	var shadow_blob = MeshInstance3D.new()
	shadow_blob.name = "CloudShadowCaster"
	var shadow_mesh = BoxMesh.new()
	shadow_mesh.size = Vector3(cloud_width, 2.5, cloud_depth)
	shadow_mesh.material = cloud_shadow_mat
	shadow_blob.mesh = shadow_mesh
	shadow_blob.position.y = -2.2
	shadow_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	cloud.add_child(shadow_blob)
	return cloud

func _update_clouds(delta: float) -> void:
	for cloud in _clouds:
		if not is_instance_valid(cloud):
			continue
		var velocity: Vector3 = cloud.get_meta("velocity", Vector3.ZERO)
		cloud.global_position += velocity * delta
		cloud.rotate_y(delta * 0.01)
		_wrap_cloud_position(cloud)

func _wrap_cloud_position(cloud: Node3D) -> void:
	var pos := cloud.global_position
	if pos.x > CLOUD_FIELD_RADIUS:
		pos.x = -CLOUD_FIELD_RADIUS
	if pos.x < -CLOUD_FIELD_RADIUS:
		pos.x = CLOUD_FIELD_RADIUS
	if pos.z > CLOUD_FIELD_RADIUS:
		pos.z = -CLOUD_FIELD_RADIUS
	if pos.z < -CLOUD_FIELD_RADIUS:
		pos.z = CLOUD_FIELD_RADIUS
	cloud.global_position = pos

func _update_cloud_sun_occlusion() -> void:
	if not _sun:
		return
	var focus := (_player_pos + _enemy_pos) * 0.5
	var strongest_cover := 0.0
	for cloud in _clouds:
		if not is_instance_valid(cloud):
			continue
		var radius := float(cloud.get_meta("occlusion_radius", 48.0))
		var cloud_pos := cloud.global_position
		var distance := Vector2(cloud_pos.x, cloud_pos.z).distance_to(Vector2(focus.x, focus.z))
		var cover := clampf(1.0 - distance / radius, 0.0, 1.0)
		strongest_cover = maxf(strongest_cover, cover)
	var target_energy := lerpf(_base_sun_energy, _base_sun_energy * 0.42, strongest_cover)
	_sun.light_energy = lerpf(_sun.light_energy, target_energy, 0.05)

func _create_building_fields(parent: Node3D, wall_mat: StandardMaterial3D, wall_dark_mat: StandardMaterial3D, roof_mat: StandardMaterial3D, window_mat: StandardMaterial3D) -> void:
	for i in range(BUILDING_COUNT):
		var radius := _rng.randf_range(_mech_width_scale * 1.0, _mech_width_scale * 2.5)
		var position := _pick_side_prop_position(radius, -95.0, 220.0, _get_los_half_width() + 24.0, MAP_HALF_SIZE * 0.72)
		_create_building(parent, position, wall_mat if i % 4 != 0 else wall_dark_mat, roof_mat, window_mat)

func _create_tree_groves(parent: Node3D, trunk_mat: StandardMaterial3D, trunk_dark_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D, leaf_dark_mat: StandardMaterial3D, leaf_pale_mat: StandardMaterial3D) -> void:
	for i in range(TREE_COUNT):
		var radius := _rng.randf_range(2.8, 7.5)
		var position: Vector3
		if i < TREE_COUNT * 0.7:
			position = _pick_side_prop_position(radius, -130.0, 230.0, _get_los_half_width() + 12.0, MAP_HALF_SIZE * 0.9)
		else:
			position = _pick_prop_position(radius)
		var leaf_variant := leaf_mat
		if i % 5 == 0:
			leaf_variant = leaf_dark_mat
		elif i % 7 == 0:
			leaf_variant = leaf_pale_mat
		if i % 3 == 0:
			_create_pine_tree(parent, position, trunk_dark_mat, leaf_variant)
		else:
			_create_broadleaf_tree(parent, position, trunk_mat, leaf_variant)

func _pick_prop_position(radius: float) -> Vector3:
	for attempt in range(120):
		var position = Vector3(
			_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE),
			GROUND_Y,
			_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE)
		)
		if _is_good_prop_position(position, radius):
			return position
	return Vector3(_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE), GROUND_Y, _rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE))

func _pick_side_prop_position(radius: float, min_z: float, max_z: float, min_lateral: float, max_lateral: float) -> Vector3:
	for attempt in range(140):
		var z := _rng.randf_range(min_z, max_z)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := _lane_x_at_z(z) + side * _rng.randf_range(min_lateral, max_lateral)
		var position = Vector3(clampf(x, -MAP_HALF_SIZE, MAP_HALF_SIZE), GROUND_Y, z)
		if _is_good_prop_position(position, radius):
			return position
	return _pick_prop_position(radius)

func _is_good_prop_position(position: Vector3, radius: float) -> bool:
	if abs(position.x) > MAP_HALF_SIZE - radius or abs(position.z) > MAP_HALF_SIZE - radius:
		return false
	if position.distance_to(_player_pos) < maxf(PLAYER_CLEAR_RADIUS, _mech_width_scale * 4.0) + radius:
		return false
	if position.distance_to(_enemy_pos) < maxf(ENEMY_CLEAR_RADIUS, _mech_width_scale * 4.0) + radius:
		return false
	if _is_in_line_of_sight_lane(position, radius):
		return false
	return true

func _get_los_half_width() -> float:
	return maxf(MIN_LOS_HALF_WIDTH, _mech_width_scale * 2.8)

func _lane_x_at_z(z: float) -> float:
	var dz := _enemy_pos.z - _player_pos.z
	if absf(dz) < 0.001:
		return _player_pos.x
	var t := clampf((z - _player_pos.z) / dz, 0.0, 1.0)
	return lerpf(_player_pos.x, _enemy_pos.x, t)

func _is_in_line_of_sight_lane(position: Vector3, radius: float) -> bool:
	var p := Vector2(position.x, position.z)
	var a := Vector2(_player_pos.x, _player_pos.z)
	var b := Vector2(_enemy_pos.x, _enemy_pos.z)
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq <= 0.001:
		return false
	var t_raw := (p - a).dot(ab) / ab_len_sq
	if t_raw < -0.08 or t_raw > 1.08:
		return false
	var closest := a + ab * clampf(t_raw, 0.0, 1.0)
	return p.distance_to(closest) < _get_los_half_width() + radius

func _scatter_grass(parent: Node3D, grass_mat: StandardMaterial3D) -> void:
	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 1.0, 0.025)
	blade_mesh.material = grass_mat

	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade_mesh
	multimesh.instance_count = GRASS_COUNT

	var placed = 0
	var attempts = 0
	while placed < GRASS_COUNT and attempts < GRASS_COUNT * 8:
		attempts += 1
		var height = _rng.randf_range(0.35, 1.35)
		var width = _rng.randf_range(0.7, 1.25)
		var radius := 0.2
		var position = Vector3(
			_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE),
			GROUND_Y + height * 0.5,
			_rng.randf_range(-MAP_HALF_SIZE, MAP_HALF_SIZE)
		)
		if not _is_good_prop_position(position, radius):
			continue

		var basis = Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, width))
		multimesh.set_instance_transform(placed, Transform3D(basis, position))
		placed += 1

	multimesh.visible_instance_count = placed

	var grass = MultiMeshInstance3D.new()
	grass.name = "GrassBlades"
	grass.multimesh = multimesh
	parent.add_child(grass)

func _create_broadleaf_tree(parent: Node3D, position: Vector3, trunk_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D) -> void:
	var tree = StaticBody3D.new()
	tree.name = "BroadleafTree"
	tree.position = position
	tree.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	parent.add_child(tree)

	var trunk_height := _rng.randf_range(_mech_height_scale * 0.75, _mech_height_scale * 1.35)
	var trunk_radius := _rng.randf_range(_mech_width_scale * 0.06, _mech_width_scale * 0.11)
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.72
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = trunk_height
	trunk_mesh.radial_segments = 9
	trunk_mesh.material = trunk_mat
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	_add_cylinder_collision(tree, trunk_radius * 1.1, trunk_height, Vector3(0.0, trunk_height * 0.5, 0.0))

	var crown_layers = _rng.randi_range(3, 5)
	for layer in range(crown_layers):
		var crown = MeshInstance3D.new()
		var crown_mesh = SphereMesh.new()
		crown_mesh.radius = _rng.randf_range(_mech_width_scale * 0.28, _mech_width_scale * 0.48) - (layer * 0.18)
		crown_mesh.height = crown_mesh.radius * _rng.randf_range(1.2, 1.55)
		crown_mesh.radial_segments = 12
		crown_mesh.rings = 6
		crown_mesh.material = leaf_mat
		crown.mesh = crown_mesh
		crown.position = Vector3(
			_rng.randf_range(-_mech_width_scale * 0.18, _mech_width_scale * 0.18),
			trunk_height + _rng.randf_range(0.25, 1.0) + (layer * _rng.randf_range(0.7, 1.2)),
			_rng.randf_range(-_mech_width_scale * 0.18, _mech_width_scale * 0.18)
		)
		crown.scale = Vector3(_rng.randf_range(1.0, 1.45), 1.0, _rng.randf_range(1.0, 1.45))
		tree.add_child(crown)

func _create_pine_tree(parent: Node3D, position: Vector3, trunk_mat: StandardMaterial3D, leaf_mat: StandardMaterial3D) -> void:
	var tree = StaticBody3D.new()
	tree.name = "PineTree"
	tree.position = position
	tree.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	parent.add_child(tree)

	var trunk_height := _rng.randf_range(_mech_height_scale * 0.85, _mech_height_scale * 1.45)
	var total_height := trunk_height + _rng.randf_range(_mech_height_scale * 0.8, _mech_height_scale * 1.45)
	var trunk_radius := _rng.randf_range(_mech_width_scale * 0.045, _mech_width_scale * 0.085)
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.65
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = trunk_height
	trunk_mesh.radial_segments = 8
	trunk_mesh.material = trunk_mat
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_height * 0.5
	tree.add_child(trunk)

	_add_cylinder_collision(tree, trunk_radius * 1.15, trunk_height, Vector3(0.0, trunk_height * 0.5, 0.0))

	var layer_count := 4
	for layer in range(layer_count):
		var cone = MeshInstance3D.new()
		var cone_mesh = CylinderMesh.new()
		var layer_t := float(layer) / float(layer_count)
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = lerpf(_mech_width_scale * 0.58, _mech_width_scale * 0.24, layer_t)
		cone_mesh.height = _rng.randf_range(_mech_height_scale * 0.62, _mech_height_scale * 0.88)
		cone_mesh.radial_segments = 10
		cone_mesh.material = leaf_mat
		cone.mesh = cone_mesh
		cone.position.y = trunk_height + layer * (_mech_height_scale * 0.45)
		tree.add_child(cone)

	tree.scale.y = _rng.randf_range(0.88, 1.12)
	var top_marker = Marker3D.new()
	top_marker.position.y = total_height
	tree.add_child(top_marker)

func _create_building(parent: Node3D, position: Vector3, wall_mat: StandardMaterial3D, roof_mat: StandardMaterial3D, window_mat: StandardMaterial3D) -> void:
	var building = StaticBody3D.new()
	building.name = "MechScaleBuilding"
	building.position = position
	building.rotation_degrees.y = _rng.randf_range(0.0, 360.0)
	parent.add_child(building)

	var footprint = Vector2(
		_rng.randf_range(_mech_width_scale * 1.65, _mech_width_scale * 4.2),
		_rng.randf_range(_mech_width_scale * 1.45, _mech_width_scale * 3.6)
	)
	var height := _rng.randf_range(_mech_height_scale * 0.9, _mech_height_scale * 3.4)
	if _rng.randf() < 0.35:
		height *= _rng.randf_range(0.55, 0.78)

	_add_box_visual(building, "MainBlock", Vector3(footprint.x, height, footprint.y), Vector3(0.0, height * 0.5, 0.0), wall_mat)
	_add_box_collision(building, Vector3(footprint.x, height, footprint.y), Vector3(0.0, height * 0.5, 0.0))
	_add_box_visual(building, "RoofCap", Vector3(footprint.x * 1.04, 0.35, footprint.y * 1.04), Vector3(0.0, height + 0.18, 0.0), roof_mat)

	var annex_count := _rng.randi_range(0, 2)
	for i in range(annex_count):
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var annex_size = Vector3(
			_rng.randf_range(_mech_width_scale * 0.85, _mech_width_scale * 1.8),
			_rng.randf_range(_mech_height_scale * 0.55, height * 0.82),
			_rng.randf_range(_mech_width_scale * 0.9, _mech_width_scale * 1.8)
		)
		var on_x_axis := _rng.randf() < 0.5
		var annex_pos := Vector3.ZERO
		if on_x_axis:
			annex_pos = Vector3(side * (footprint.x * 0.5 + annex_size.x * 0.5), annex_size.y * 0.5, _rng.randf_range(-footprint.y * 0.25, footprint.y * 0.25))
		else:
			annex_pos = Vector3(_rng.randf_range(-footprint.x * 0.25, footprint.x * 0.25), annex_size.y * 0.5, side * (footprint.y * 0.5 + annex_size.z * 0.5))
		_add_box_visual(building, "Annex", annex_size, annex_pos, wall_mat)
		_add_box_collision(building, annex_size, annex_pos)

	_add_window_bands(building, footprint, height, window_mat)

func _add_window_bands(parent: Node3D, footprint: Vector2, height: float, window_mat: StandardMaterial3D) -> void:
	var floor_step := maxf(_mech_height_scale * 0.42, 2.6)
	var floor_y := floor_step
	while floor_y < height - 1.0:
		var band_height := 0.35
		_add_box_visual(parent, "WindowBandFront", Vector3(footprint.x * 0.68, band_height, 0.08), Vector3(0.0, floor_y, -footprint.y * 0.5 - 0.045), window_mat)
		_add_box_visual(parent, "WindowBandBack", Vector3(footprint.x * 0.68, band_height, 0.08), Vector3(0.0, floor_y, footprint.y * 0.5 + 0.045), window_mat)
		_add_box_visual(parent, "WindowBandLeft", Vector3(0.08, band_height, footprint.y * 0.54), Vector3(-footprint.x * 0.5 - 0.045, floor_y, 0.0), window_mat)
		_add_box_visual(parent, "WindowBandRight", Vector3(0.08, band_height, footprint.y * 0.54), Vector3(footprint.x * 0.5 + 0.045, floor_y, 0.0), window_mat)
		floor_y += floor_step

func _add_box_visual(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = local_position
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_box_collision(parent: Node3D, size: Vector3, local_position: Vector3) -> void:
	var collision = CollisionShape3D.new()
	var collision_shape = BoxShape3D.new()
	collision_shape.size = size
	collision.shape = collision_shape
	collision.position = local_position
	parent.add_child(collision)

func _add_cylinder_collision(parent: Node3D, radius: float, height: float, local_position: Vector3) -> void:
	var collision = CollisionShape3D.new()
	var collision_shape = CylinderShape3D.new()
	collision_shape.radius = radius
	collision_shape.height = height
	collision.shape = collision_shape
	collision.position = local_position
	parent.add_child(collision)

func _create_rock(parent: Node3D, position: Vector3, rock_mat: StandardMaterial3D) -> void:
	var rock = StaticBody3D.new()
	rock.name = "Rock"
	rock.position = position
	rock.rotation_degrees = Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(0.0, 360.0), _rng.randf_range(-5.0, 5.0))
	parent.add_child(rock)

	var radius = _rng.randf_range(0.9, _mech_width_scale * 0.38)
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

	_add_box_collision(rock, Vector3(
		radius * 1.65 * rock_scale.x,
		radius * 0.95 * rock_scale.y,
		radius * 1.65 * rock_scale.z
	), Vector3(0.0, radius * 0.35, 0.0))
