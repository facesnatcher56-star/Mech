extends Label3D

var velocity: Vector3 = Vector3(0, 1.2, 0)
var duration: float = 1.2
var time_passed: float = 0.0

# Shared slot counter — each number in a burst claims the next vertical slot
static var _slot: int = 0
static var _resetting: bool = false
const SLOT_STEP := 1.5    # world units between stacked numbers (must be large at ~166u camera distance with fixed_size)
const SLOT_WINDOW := 0.12 # seconds before slot counter resets

func _ready():
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = true
	font_size = 12
	outline_size = 3
	modulate = Color(1, 1, 0)

func _process(delta):
	time_passed += delta
	global_position += velocity * delta
	var alpha = 1.0 - (time_passed / duration)
	modulate.a = alpha
	outline_modulate.a = alpha
	if time_passed >= duration:
		queue_free()

static func display_text(pos: Vector3, label_text: String, parent: Node, color: Color = Color.YELLOW, size: int = 0):
	var label = load("res://scripts/damage_number.gd").new()
	label.text = label_text
	label.modulate = color
	if size > 0:
		label.font_size = size / 4
		label.outline_size = maxi(1, size / 16)

	# Stack vertically within a burst, then reset for the next shot
	var slot_offset := Vector3.UP * _slot * SLOT_STEP
	_slot += 1
	if not _resetting:
		_resetting = true
		parent.get_tree().create_timer(SLOT_WINDOW).timeout.connect(func():
			_slot = 0
			_resetting = false
		)

	parent.add_child(label)
	label.global_position = pos + slot_offset
	return label
