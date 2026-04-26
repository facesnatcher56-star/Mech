extends CanvasLayer

const SHADER = preload("res://shaders/thermal_vision.gdshader")
const ZEZLAN_LAYER_MASK := 2  # render layer 2 (bit 1)

var _overlay: ColorRect
var _subviewport: SubViewport
var _thermal_cam: Camera3D
var _active: bool = false

func _ready() -> void:
	layer = 10

	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.material = ShaderMaterial.new()
	_overlay.material.shader = SHADER
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	# Defer subviewport setup — root is busy during _ready
	call_deferred("_setup_subviewport")

func _setup_subviewport() -> void:
	_subviewport = SubViewport.new()
	_subviewport.name = "ThermalSubViewport"
	_subviewport.transparent_bg = true
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.size = Vector2i(get_viewport().get_visible_rect().size)
	get_tree().root.add_child(_subviewport)

	_thermal_cam = Camera3D.new()
	_thermal_cam.cull_mask = ZEZLAN_LAYER_MASK
	_subviewport.add_child(_thermal_cam)

	_tag_zezlan_meshes()

	# Tag any projectile that enters the scene from now on
	get_tree().node_added.connect(func(node: Node) -> void:
		if node.name == "TracerShell":
			_tag_recursive.call_deferred(node)
	)

	(_overlay.material as ShaderMaterial).set_shader_parameter(
		"zezlan_texture", _subviewport.get_texture()
	)

func _tag_zezlan_meshes() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		_tag_recursive(node)

func _tag_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		node.layers = node.layers | ZEZLAN_LAYER_MASK
	for child in node.get_children():
		_tag_recursive(child)

func _process(_delta: float) -> void:
	if not _active or not is_instance_valid(_thermal_cam):
		return

	var main_cam := get_viewport().get_camera_3d()
	if main_cam and is_instance_valid(main_cam):
		_thermal_cam.global_transform = main_cam.global_transform
		_thermal_cam.fov  = main_cam.fov
		_thermal_cam.near = main_cam.near
		_thermal_cam.far  = main_cam.far

	var vp_size := Vector2i(get_viewport().get_visible_rect().size)
	if _subviewport.size != vp_size:
		_subviewport.size = vp_size

func toggle() -> void:
	_active = not _active
	_overlay.visible = _active

func is_active() -> bool:
	return _active
