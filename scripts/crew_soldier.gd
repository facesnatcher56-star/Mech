extends Node3D

const RPG_PROJECTILE  = preload("res://scenes/rpg_projectile.tscn")
const SND_LAUNCH      = preload("res://assets/Sounds/rocket-launch.wav")
const SND_HIT         = preload("res://assets/Sounds/rocket-launchhit.wav")

@export_group("Crew Order")
## Crew display name used on the top-left nameplate.
@export var crew_display_name: String = "PVT. HALE"
## Crew class used on the top-left nameplate.
@export var crew_class: String = "RPG RIFLEMAN"
## Key used to order this crewman to fire the RPG.
@export var order_key: Key = KEY_R
## Name text used to find the Zezlan target.
@export var target_name_filter: String = "zezlan"
## Seconds before another RPG order can be accepted.
@export var rpg_cooldown: float = 8.0

@export_group("Crew Patrol")
## Enables simple autonomous patrol around the player mech.
@export var patrol_enabled: bool = true
## Name of the node this crewman patrols around.
@export var patrol_anchor_name: String = "WIPtestmech"
## Closest distance from the player mech when choosing patrol points.
@export var patrol_min_radius: float = 6.0
## Farthest distance from the player mech when choosing patrol points.
@export var patrol_max_radius: float = 11.0
## Movement speed while patrolling.
@export var patrol_speed: float = 2.2
## How close the crewman needs to get before choosing a new patrol point.
@export var patrol_arrive_distance: float = 0.75
## Seconds between forced patrol-point refreshes.
@export var patrol_repick_time: float = 4.0
## Keeps the crewman's current world height instead of snapping to the mech height.
@export var preserve_world_height: bool = true
## How fast the crewman rotates toward his movement direction, in slerp weight per second. Low = gradual.
@export var turn_speed: float = 2.0

@export_group("Crew RPG")
## Chance from 0 to 1 that an ordered RPG shot is aimed to hit Zezlan.
@export_range(0.0, 1.0, 0.01) var rpg_hit_chance: float = 0.55
## Structure-only damage applied to Zezlan when the RPG hits.
@export var rpg_structure_damage: int = 12
## RPG projectile travel speed in world units per second.
@export var rpg_projectile_speed: float = 85.0
## Random miss distance around Zezlan when the hit roll fails.
@export var rpg_miss_radius: float = 9.0
## Vertical miss variance added to failed RPG shots.
@export var rpg_miss_height: float = 4.0

@export_group("Crew Dialogue")
## Height of the crewman's spoken response label.
@export var crew_label_height: float = 2.15
## Local offset for the player's shouted order label.
@export var order_label_local_offset: Vector3 = Vector3(0.0, 2.65, -0.45)
## How long each floating dialogue line stays visible.
@export var dialogue_duration: float = 1.8
## How quickly floating dialogue fades away at the end.
@export var dialogue_fade_time: float = 0.35

@export_group("Crew Animation")
## AnimationPlayer clip name to play while patrolling.
@export var walk_animation: StringName = &"Walk_Backward_While_Shooting"

var cooldown_timer: float = 0.0
var rng := RandomNumberGenerator.new()
var crew_label: Label3D
var order_label: Label3D
var crew_label_timer: float = 0.0
var order_label_timer: float = 0.0
var patrol_anchor: Node3D = null
var patrol_target: Vector3 = Vector3.ZERO
var patrol_timer: float = 0.0
var patrol_height: float = 0.0
var crew_order_ui: Control = null
var _anim_player: AnimationPlayer = null
var _snd_launch: AudioStreamPlayer3D = null
var _snd_hit: AudioStreamPlayer3D = null

func _ready() -> void:
	rng.randomize()
	patrol_height = global_position.y
	_find_patrol_anchor()
	_pick_patrol_target()
	_find_dialogue_labels()
	_find_crew_order_ui()
	_sync_crew_order_ui(true)
	_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_snd_launch = _make_audio_player("RPGLaunchSound", SND_LAUNCH)
	_snd_hit    = _make_audio_player("RPGHitSound",    SND_HIT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == order_key:
			_try_order_rpg()

func _process(delta: float) -> void:
	if cooldown_timer > 0.0 and get_tree().get_nodes_in_group("shell_in_flight").size() == 0:
		cooldown_timer = max(0.0, cooldown_timer - delta)
	_sync_crew_order_ui(false)
	_update_patrol(delta)
	_update_label_fade(crew_label, "crew_label_timer", delta)
	_update_label_fade(order_label, "order_label_timer", delta)

func _find_dialogue_labels() -> void:
	crew_label = get_node_or_null("CrewDialogue") as Label3D
	order_label = get_node_or_null("OrderDialogue") as Label3D
	if not crew_label:
		crew_label = _make_label("CrewDialogue", Vector3(0.0, crew_label_height, 0.0), Color(0.72, 0.95, 0.68))
	if not order_label:
		order_label = _make_label("OrderDialogue", order_label_local_offset, Color(1.0, 0.82, 0.35))
	crew_label.position.y = crew_label_height
	order_label.position = order_label_local_offset

func _find_patrol_anchor() -> void:
	var current_scene := get_tree().current_scene
	if not current_scene:
		return
	var anchor := current_scene.find_child(patrol_anchor_name, true, false)
	if anchor and anchor is Node3D and anchor != self:
		patrol_anchor = anchor as Node3D

func _update_patrol(delta: float) -> void:
	if not patrol_enabled:
		_set_walk_animation(false)
		return
	if not is_instance_valid(patrol_anchor):
		_find_patrol_anchor()
	if not is_instance_valid(patrol_anchor):
		return

	patrol_timer = max(0.0, patrol_timer - delta)
	var flat_distance := Vector2(global_position.x - patrol_target.x, global_position.z - patrol_target.z).length()
	if patrol_timer <= 0.0 or flat_distance <= patrol_arrive_distance:
		_pick_patrol_target()

	var next_position := global_position.move_toward(patrol_target, max(0.0, patrol_speed) * delta)
	if preserve_world_height:
		next_position.y = patrol_height

	var anchor_pos := patrol_anchor.global_position
	var flat_to_soldier := Vector2(next_position.x - anchor_pos.x, next_position.z - anchor_pos.z)
	var flat_dist := flat_to_soldier.length()
	if flat_dist < patrol_min_radius and flat_dist > 0.001:
		flat_to_soldier = flat_to_soldier.normalized() * patrol_min_radius
		next_position.x = anchor_pos.x + flat_to_soldier.x
		next_position.z = anchor_pos.z + flat_to_soldier.y

	global_position = next_position

	var move_dir := Vector3(patrol_target.x - global_position.x, 0.0, patrol_target.z - global_position.z)
	if move_dir.length_squared() > 0.0025:
		var target_basis := Basis.looking_at(-move_dir.normalized(), Vector3.UP)
		basis = basis.slerp(target_basis, clampf(turn_speed * delta, 0.0, 1.0))

	_set_walk_animation(true)

func _set_walk_animation(walking: bool) -> void:
	if not _anim_player or walk_animation == &"":
		return
	if walking:
		if _anim_player.current_animation != walk_animation:
			_anim_player.play(walk_animation)
	elif _anim_player.is_playing():
		_anim_player.stop()

func _pick_patrol_target() -> void:
	patrol_timer = max(0.1, patrol_repick_time)
	if not is_instance_valid(patrol_anchor):
		patrol_target = global_position
		return
	var min_radius: float = maxf(0.0, patrol_min_radius)
	var max_radius: float = maxf(min_radius, patrol_max_radius)
	var angle := rng.randf_range(0.0, TAU)
	var radius := rng.randf_range(min_radius, max_radius)
	var center := patrol_anchor.global_position
	patrol_target = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	if preserve_world_height:
		patrol_target.y = patrol_height

func _try_order_rpg() -> void:
	if cooldown_timer > 0.0:
		_show_crew_line("RPG reloading.")
		return

	var target := _find_zezlan_target()
	if not target:
		_show_order_line("RPG. Zezlan. Fire.")
		_show_crew_line("No Zezlan target.")
		return

	cooldown_timer = max(0.0, rpg_cooldown)
	_show_order_line("RPG. Zezlan. Fire.")
	_show_crew_line("Copy. Rocket out.")
	_fire_rpg(target)

func _make_audio_player(node_name: String, stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = node_name
	p.stream = stream
	p.unit_size = 60.0
	add_child(p)
	return p

func _fire_rpg(target: Node3D) -> void:
	var muzzle := get_node_or_null("RPGTube/Muzzle") as Node3D
	if not muzzle:
		return

	var will_hit := rng.randf() <= clampf(rpg_hit_chance, 0.0, 1.0)
	var target_point := _get_target_point(target)
	if not will_hit:
		target_point += _get_miss_offset()

	var shell = RPG_PROJECTILE.instantiate()
	shell.shooter = _get_friendly_root()
	shell.is_player_shot = false
	shell.is_destined_for_hit = will_hit
	shell.speed = rpg_projectile_speed
	shell.set("swept_collision_enabled", true)

	var rocket_state := {"resolved": false}
	var target_id := target.get_instance_id()
	shell.has_hit.connect(_on_rpg_shell_hit.bind(rocket_state, target_id, will_hit))

	get_tree().root.add_child(shell)
	shell.global_position = muzzle.global_position
	shell.look_at(target_point, Vector3.UP)

	if _snd_launch:
		_snd_launch.global_position = muzzle.global_position
		_snd_launch.play()

	var travel_time = muzzle.global_position.distance_to(target_point) / max(1.0, rpg_projectile_speed)
	var shell_id := shell.get_instance_id()
	get_tree().create_timer(travel_time + 0.6).timeout.connect(_on_rpg_travel_timeout.bind(rocket_state, shell_id, target_id, target_point, will_hit))

func _on_rpg_travel_timeout(rocket_state: Dictionary, shell_id: int, target_id: int, target_point: Vector3, will_hit: bool) -> void:
	if bool(rocket_state["resolved"]):
		return
	rocket_state["resolved"] = true

	var shell = instance_from_id(shell_id)
	if shell and shell.has_method("_spawn_explosion"):
		shell._spawn_explosion(target_point)
	if shell and shell is Node:
		(shell as Node).queue_free()

	var target := instance_from_id(target_id) as Node3D
	if not target:
		return
	if will_hit:
		_rpg_play_hit_sound(target_point)
		_apply_rpg_damage(target, target_point)
	else:
		_show_crew_line("Missed. Reloading.")
		_update_visible_dossier("RPG MISS", target)

func _on_rpg_shell_hit(body, hit_pos: Vector3, rocket_state: Dictionary, target_id: int, will_hit: bool) -> void:
	if bool(rocket_state["resolved"]):
		return
	rocket_state["resolved"] = true
	var hit_target := instance_from_id(target_id) as Node3D
	if will_hit and hit_target and _is_body_on_target(body, hit_target):
		_rpg_play_hit_sound(hit_pos)
		_apply_rpg_damage(hit_target, hit_pos)
	else:
		_show_crew_line("Missed. Reloading.")
		if hit_target:
			_update_visible_dossier("RPG MISS", hit_target)

func _rpg_play_hit_sound(hit_pos: Vector3) -> void:
	if _snd_launch and _snd_launch.playing:
		_snd_launch.stop()
	if _snd_hit:
		_snd_hit.global_position = hit_pos
		_snd_hit.play()

func _apply_rpg_damage(target: Node3D, hit_pos: Vector3) -> void:
	var damage_model := _find_rpg_damage_model(target)
	if damage_model and damage_model.has_method("apply_rpg_structure_damage"):
		var result: Dictionary = damage_model.apply_rpg_structure_damage(rpg_structure_damage, hit_pos)
		_show_crew_line("Hit confirmed.")
		if result.has("snapshot"):
			_update_visible_dossier("RPG HIT  -%d" % int(result.get("damage", 0)), target, result["snapshot"])
	else:
		_show_crew_line("Hit confirmed.")

func _find_zezlan_target() -> Node3D:
	var target_filter := target_name_filter.to_lower()
	var best: Node3D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node3D:
			var candidate := node as Node3D
			var candidate_name := candidate.name.to_lower()
			if target_filter != "" and not (target_filter in candidate_name) and not candidate.has_method("apply_rpg_structure_damage"):
				continue
			var dist := global_position.distance_to(candidate.global_position)
			if dist < best_dist:
				best = candidate
				best_dist = dist
	return best

func _find_rpg_damage_model(start_node: Node) -> Node:
	var node := start_node
	while node:
		if node.has_method("apply_rpg_structure_damage"):
			return node
		node = node.get_parent()
	return null

func _get_target_point(target: Node3D) -> Vector3:
	var torso = target.find_child("Torso", true, false)
	if torso and torso is Node3D:
		return (torso as Node3D).global_position
	return target.global_position + Vector3.UP * 3.0

func _get_miss_offset() -> Vector3:
	var side := Vector3.RIGHT.rotated(Vector3.UP, rng.randf_range(0.0, TAU)) * rng.randf_range(rpg_miss_radius * 0.65, rpg_miss_radius)
	side.y += rng.randf_range(-rpg_miss_height * 0.35, rpg_miss_height)
	return side

func _is_body_on_target(body: Object, target: Node) -> bool:
	if not body or not target or not body is Node:
		return false
	var node := body as Node
	while node:
		if node == target:
			return true
		node = node.get_parent()
	return false

func _get_friendly_root() -> Node3D:
	return self

func _update_visible_dossier(line: String, target: Node3D, snapshot: Dictionary = {}) -> void:
	var current_scene := get_tree().current_scene
	if not current_scene:
		return
	var dossier = current_scene.find_child("TargetDossierUI", true, false)
	if not dossier or not dossier.visible or not dossier.has_method("show_impact_line"):
		return
	if snapshot.is_empty():
		var damage_model := _find_rpg_damage_model(target)
		if damage_model and damage_model.has_method("get_hp_snapshot"):
			snapshot = damage_model.get_hp_snapshot()
	dossier.show_impact_line(line, "structure", snapshot)

func _find_crew_order_ui() -> void:
	var current_scene := get_tree().current_scene
	if not current_scene:
		return
	var node = current_scene.find_child("CrewOrderUI", true, false)
	if node and node is Control:
		crew_order_ui = node as Control

func _sync_crew_order_ui(sync_identity: bool) -> void:
	if not crew_order_ui:
		_find_crew_order_ui()
	if not crew_order_ui:
		return
	if sync_identity and crew_order_ui.has_method("set_crew_identity"):
		crew_order_ui.set_crew_identity(crew_display_name, crew_class)
	if crew_order_ui.has_method("set_reload"):
		crew_order_ui.set_reload(cooldown_timer, rpg_cooldown)

func _show_crew_line(text: String) -> void:
	if not crew_order_ui:
		_find_crew_order_ui()
	if crew_order_ui and crew_order_ui.has_method("show_response"):
		crew_order_ui.show_response(text)
	if not crew_label:
		return
	crew_label.text = text
	crew_label.visible = true
	crew_label.modulate.a = 1.0
	crew_label_timer = dialogue_duration

func _show_order_line(text: String) -> void:
	if not crew_order_ui:
		_find_crew_order_ui()
	if crew_order_ui and crew_order_ui.has_method("show_order"):
		crew_order_ui.show_order(text)
	if not order_label:
		return
	order_label.text = text
	order_label.visible = true
	order_label.modulate.a = 1.0
	order_label_timer = dialogue_duration

func _update_label_fade(label: Label3D, timer_property: String, delta: float) -> void:
	var timer_value: float = get(timer_property)
	if timer_value <= 0.0:
		if label:
			label.visible = false
		return
	timer_value = max(0.0, timer_value - delta)
	set(timer_property, timer_value)
	if not label:
		return
	var alpha := 1.0
	if dialogue_fade_time > 0.0 and timer_value < dialogue_fade_time:
		alpha = clampf(timer_value / dialogue_fade_time, 0.0, 1.0)
	label.modulate.a = alpha
	label.visible = timer_value > 0.0

func _build_dialogue_labels() -> void:
	crew_label = _make_label("CrewDialogue", Vector3(0.0, crew_label_height, 0.0), Color(0.72, 0.95, 0.68))
	order_label = _make_label("OrderDialogue", order_label_local_offset, Color(1.0, 0.82, 0.35))

func _make_label(label_name: String, local_pos: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.text = ""
	label.position = local_pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 42
	label.outline_size = 8
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.visible = false
	add_child(label)
	return label

func _build_blockout_soldier() -> void:
	if get_node_or_null("Body"):
		return

	var uniform := _make_material(Color(0.19, 0.26, 0.18))
	var armor := _make_material(Color(0.08, 0.09, 0.075))
	var skin := _make_material(Color(0.56, 0.42, 0.30))
	var rpg_mat := _make_material(Color(0.10, 0.11, 0.09))
	var metal := _make_material(Color(0.24, 0.24, 0.21))

	_add_mesh("Body", BoxMesh.new(), Vector3(0, 1.02, 0), Vector3(0.42, 0.72, 0.24), uniform)
	_add_mesh("Head", SphereMesh.new(), Vector3(0, 1.55, 0), Vector3(0.24, 0.24, 0.24), skin)
	_add_mesh("Helmet", SphereMesh.new(), Vector3(0, 1.66, 0), Vector3(0.27, 0.14, 0.27), armor)
	_add_mesh("ArmL", CapsuleMesh.new(), Vector3(-0.34, 1.08, -0.02), Vector3(0.11, 0.48, 0.11), uniform, Vector3(0, 0, 0.45))
	_add_mesh("ArmR", CapsuleMesh.new(), Vector3(0.34, 1.08, -0.02), Vector3(0.11, 0.48, 0.11), uniform, Vector3(0, 0, -0.45))
	_add_mesh("LegL", CapsuleMesh.new(), Vector3(-0.13, 0.43, 0), Vector3(0.12, 0.58, 0.12), uniform)
	_add_mesh("LegR", CapsuleMesh.new(), Vector3(0.13, 0.43, 0), Vector3(0.12, 0.58, 0.12), uniform)
	_add_mesh("BootL", BoxMesh.new(), Vector3(-0.13, 0.08, -0.04), Vector3(0.15, 0.12, 0.25), armor)
	_add_mesh("BootR", BoxMesh.new(), Vector3(0.13, 0.08, -0.04), Vector3(0.15, 0.12, 0.25), armor)

	var tube := Node3D.new()
	tube.name = "RPGTube"
	tube.position = Vector3(0.0, 1.28, -0.24)
	tube.rotation_degrees = Vector3(86.0, 0.0, 90.0)
	add_child(tube)

	var tube_mesh := MeshInstance3D.new()
	tube_mesh.name = "TubeMesh"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.08
	cylinder.bottom_radius = 0.08
	cylinder.height = 0.85
	tube_mesh.mesh = cylinder
	tube_mesh.material_override = rpg_mat
	tube.add_child(tube_mesh)

	var warhead := MeshInstance3D.new()
	warhead.name = "Warhead"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.12
	cone.height = 0.22
	warhead.mesh = cone
	warhead.position = Vector3(0, 0.53, 0)
	warhead.material_override = metal
	tube.add_child(warhead)

	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.58, 0)
	tube.add_child(muzzle)

func _add_mesh(mesh_name: String, mesh: Mesh, pos: Vector3, scale_value: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scale_value
	instance.rotation = rot
	instance.material_override = material
	add_child(instance)
	return instance

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material
