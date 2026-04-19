extends Node3D

const PROJECTILE = preload("res://scenes/projectile.tscn")

@export_group("Enemy Firing")
## Seconds between each shot.
@export var fire_interval: float = 6.0
## World units per second for enemy shells.
@export var projectile_speed: float = 80.0
## Height above the enemy origin to spawn shells (approximates cannon height).
@export var muzzle_height_offset: float = 6.5
## Vertical aim offset applied to the player position so shells arc toward the cockpit.
@export var aim_height_offset: float = 3.0
## Delay before the first shot so the player has time to settle in.
@export var initial_fire_delay: float = 4.0

var is_destroyed: bool = false
var _fire_timer: float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _ready():
	add_to_group("enemy")
	_fire_timer = initial_fire_delay

func _process(delta):
	if is_destroyed:
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		fire_at_player()

func fire_at_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return

	var muzzle_pos := global_position + Vector3.UP * muzzle_height_offset
	var aim_pos    := player.global_position + Vector3.UP * aim_height_offset

	var shell := PROJECTILE.instantiate()
	shell.shooter = self
	shell.speed = projectile_speed
	shell.is_player_shot = false
	get_tree().root.add_child(shell)
	shell.global_position = muzzle_pos
	shell.look_at(aim_pos, Vector3.UP)

	if player.has_method("begin_incoming_cinematic"):
		player.begin_incoming_cinematic(shell)

func fire_cannon():
	fire_at_player()

func hit():
	if is_destroyed:
		return
	is_destroyed = true
	print("ENEMY DESTROYED!")

	var explosion_scene = preload("res://scenes/explosion.tscn")
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position

	visible = false
	get_tree().create_timer(2.0).timeout.connect(queue_free)
