extends Label3D

var velocity: Vector3 = Vector3(0, 2, 0)
var duration: float = 1.0
var time_passed: float = 0.0

func _ready():
	# Randomize horizontal velocity slightly for variety
	velocity.x = randf_range(-0.5, 0.5)
	velocity.z = randf_range(-0.5, 0.5)
	
	# Visual style
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true # See through walls so numbers are always visible
	fixed_size = true # Keep size consistent regardless of distance
	font_size = 48
	outline_size = 12
	modulate = Color(1, 1, 0) # Yellow for damage

func _process(delta):
	time_passed += delta
	global_position += velocity * delta
	
	# Fade out
	var alpha = 1.0 - (time_passed / duration)
	modulate.a = alpha
	outline_modulate.a = alpha
	
	if time_passed >= duration:
		queue_free()

static func display_text(pos: Vector3, label_text: String, parent: Node, color: Color = Color.YELLOW):
	var label = load("res://scripts/damage_number.gd").new()
	label.text = label_text
	label.modulate = color
	parent.add_child(label)
	label.global_position = pos
	return label
