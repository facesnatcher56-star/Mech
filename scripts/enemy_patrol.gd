extends Node3D

@export var speed: float = 1.8
@export var patrol_distance: float = 12.0

const PROJECTILE = preload("res://scenes/projectile.tscn")

var start_pos: Vector3
var direction: float = 1.0
var time_passed: float = 0.0
var is_staggered: bool = false
var stagger_count: int = 0

func _ready():
	start_pos = position
	
	# Automated Return Fire Timer (Every 5 seconds)
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(fire_at_player)
	add_child(timer)

func _physics_process(delta):
	if is_staggered:
		return
		
	position.x += speed * direction * delta
	
	if abs(position.x - start_pos.x) >= patrol_distance:
		direction *= -1.0
		position.x = start_pos.x + (patrol_distance * -direction)
	
	time_passed += delta
	var bob_frequency = 3.5
	var bob_intensity = 0.08
	position.y = start_pos.y + abs(sin(time_passed * bob_frequency)) * bob_intensity

func fire_at_player():
	if is_staggered:
		return
		
	# Find the player in the scene
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
		
	# 1. Instantiate projectile
	var shell = PROJECTILE.instantiate()
	shell.shooter = self
	get_tree().root.add_child(shell)
	
	# 2. Position it at the enemy's center (Elevated to match player head height)
	shell.global_position = global_position + Vector3(0, 2.5, 0)
	
	# 3. Aim it directly at the player cockpit
	var target_pos = player.global_position + Vector3(0, 1.2, 0)
	shell.look_at(target_pos)

func hit():
	stagger_count += 1
	var current_stagger_id = stagger_count
	
	print("ENEMY: Hit received! Staggering... (ID: ", current_stagger_id, ")")
	is_staggered = true
	
	await get_tree().create_timer(1.5).timeout
	
	if current_stagger_id == stagger_count:
		print("ENEMY: Resuming patrol.")
		is_staggered = false
	else:
		print("ENEMY: Stagger extended by fresh hit.")
