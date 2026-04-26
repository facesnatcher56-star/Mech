extends CanvasLayer

const SHADER = preload("res://shaders/thermal_vision.gdshader")
const ZEZLAN_LAYER_MASK := 2  # render layer 2 (bit 1)

var _overlay: ColorRect
var _subviewport: SubViewport
var _thermal_cam: Camera3D
var _active: bool = false

func _ready() -> void:
	layer = 10

	# Fullscreen overlay with shader
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.material = ShaderMaterial.new()
	_overlay.material.shader = SHADER
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

	# SubViewport that only renders Zezlan (layer 2)
	_subviewport = SubViewport.new()
	_subviewport.name = "ThermalSubViewport"
	_subviewport.transparent_bg = true
	_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_subviewport.size = Vector2i(get_viewport().get_visible_rect().size)
	get_tree().root.add_child(_subviewport)

	_thermal_cam = Camera3D.new()
	_thermal_cam.cull_mask = ZEZLAN_LAYER_MASK
	_subviewport.add_child(_thermal_cam)

	# Deferred so the scene is fully loaded before we walk Zezlan's tree
	call_deferred("_tag_zezlan_meshes")
	call_deferred("_bind_shader_texture")

func _bind_shader_texture() -> void:
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
	if not _active:
		return

	# Keep thermal cam in sync with whichever camera is active
	var main_cam := get_viewport().get_camera_3d()
	if main_cam and is_instance_valid(main_cam):
		_thermal_cam.global_transform = main_cam.global_transform
		_thermal_cam.fov   = main_cam.fov
		_thermal_cam.near  = main_cam.near
		_thermal_cam.far   = main_cam.far

	# Match viewport size if window was resized
	var vp_size := Vector2i(get_viewport().get_visible_rect().size)
	if _subviewport.size != vp_size:
		_subviewport.size = vp_size

func toggle() -> void:
	_active = not _active
	_overlay.visible = _active
	_subviewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if _active else SubViewport.UPDATE_DISABLED
	)

func is_active() -> bool:
	return _active
