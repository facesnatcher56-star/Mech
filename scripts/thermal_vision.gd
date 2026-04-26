extends CanvasLayer

const SHADER = preload("res://shaders/thermal_vision.gdshader")

var _overlay: ColorRect
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

func toggle() -> void:
	_active = not _active
	_overlay.visible = _active

func is_active() -> bool:
	return _active
