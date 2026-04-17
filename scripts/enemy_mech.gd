extends Node3D

const PROJECTILE = preload("res://scenes/projectile.tscn")

var armor: int = 3
var state: String = "PUSHING"
var state_timer: float = 0.0

var move_speed: float = 3.0
@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	add_to_group("enemy")

func _process(delta):
	# AI and Movement disabled as requested
	pass

func fire_cannon():
	# Firing disabled as requested
	pass

func hit():
	if armor <= 0: return
	
	armor = 0 # 1-hit kill
	print("ENEMY DESTROYED!")
	
	var explosion_scene = preload("res://scenes/explosion.tscn")
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position
	
	# Cleanup enemy
	visible = false
	get_tree().create_timer(2.0).timeout.connect(queue_free)
