extends Node

const PROJECTILE = preload("res://scenes/projectile.tscn")
const DAMAGE_NUMBER = preload("res://scripts/damage_number.gd")

var cockpit: Node3D = null
var projectile_cinematic_controller: Node = null
var combat_bark_ui: Node = null
var dossier_presenter: Node = null
var cannon_sound: AudioStreamPlayer3D = null
var hit_sound: AudioStreamPlayer3D = null
var visual_barrel: Node3D = null
var muzzle: Node3D = null

var projectile_speed: float = 150.0
var bullet_slomo: float = 0.2

var intersect_target_ray_callable: Callable
var is_enemy_collider_callable: Callable
var get_target_node_callable: Callable
var get_enemy_aim_root_callable: Callable
var apply_enemy_damage_callable: Callable
var get_fire_camera_callable: Callable
var on_reload_started_callable: Callable

var recoil_tween: Tween
var visual_barrel_base_pos: Vector3

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", cockpit)
	intersect_target_ray_callable = config.get("intersect_target_ray_callable", Callable())
	is_enemy_collider_callable = config.get("is_enemy_collider_callable", Callable())
	get_target_node_callable = config.get("get_target_node_callable", Callable())
	get_enemy_aim_root_callable = config.get("get_enemy_aim_root_callable", Callable())
	apply_enemy_damage_callable = config.get("apply_enemy_damage_callable", Callable())
	get_fire_camera_callable = config.get("get_fire_camera_callable", Callable())
	on_reload_started_callable = config.get("on_reload_started_callable", Callable())
	refresh_runtime_refs(config)

func refresh_runtime_refs(config: Dictionary) -> void:
	projectile_cinematic_controller = config.get("projectile_cinematic_controller", projectile_cinematic_controller)
	combat_bark_ui = config.get("combat_bark_ui", combat_bark_ui)
	dossier_presenter = config.get("dossier_presenter", dossier_presenter)
	cannon_sound = config.get("cannon_sound", cannon_sound)
	hit_sound = config.get("hit_sound", hit_sound)
	visual_barrel = config.get("visual_barrel", visual_barrel)
	muzzle = config.get("muzzle", muzzle)
	projectile_speed = float(config.get("projectile_speed", projectile_speed))
	bullet_slomo = float(config.get("bullet_slomo", bullet_slomo))

func build_shot_lock(source_camera: Camera3D, current_target_range: float) -> Dictionary:
	var final_dir = -source_camera.global_transform.basis.z
	var result = _intersect_target_ray(source_camera, 500.0)

	var will_hit_enemy = false
	var impact_anchor: Node3D = _get_target_node()
	var focal_range = current_target_range if current_target_range > 0 else 100.0
	var focal_point = source_camera.global_position + (final_dir * focal_range)
	var target_point = source_camera.global_position + (final_dir * 500.0)
	if result and result.collider:
		target_point = result.position
		if _is_enemy_collider(result.collider):
			will_hit_enemy = true
			focal_point = target_point
			if result.collider is Node3D:
				impact_anchor = _get_enemy_aim_root(result.collider as Node3D)

	return {
		"target_point": target_point,
		"focal_point": focal_point,
		"will_hit_enemy": will_hit_enemy,
		"impact_anchor": impact_anchor
	}

func perform_actual_shot(target_point: Vector3, will_hit_enemy: bool, focal_point: Vector3, impact_anchor: Node3D) -> void:
	if combat_bark_ui:
		combat_bark_ui.show_commit()

	Engine.time_scale = bullet_slomo

	if cannon_sound:
		cannon_sound.play()

	if cockpit:
		var smoke = cockpit.find_child("MuzzleSmoke", true)
		if smoke:
			smoke.restart()

		var dir_smoke = cockpit.find_child("DirectionalSmoke", true)
		if dir_smoke and dir_smoke.has_method("fire"):
			dir_smoke.fire()

	if on_reload_started_callable.is_valid():
		on_reload_started_callable.call()

	var fire_camera = _get_fire_camera()
	if projectile_cinematic_controller and projectile_cinematic_controller.has_method("begin_fire_cam") and muzzle:
		projectile_cinematic_controller.begin_fire_cam(fire_camera, muzzle.global_position, focal_point, will_hit_enemy, impact_anchor)

	if not cockpit or not muzzle:
		return

	var shell = PROJECTILE.instantiate()
	shell.shooter = cockpit
	shell.is_player_shot = true
	shell.is_destined_for_hit = will_hit_enemy
	shell.speed = projectile_speed
	shell.has_hit.connect(_on_shell_hit)

	cockpit.get_tree().root.add_child(shell)
	shell.global_position = muzzle.global_position
	shell.look_at(target_point, Vector3.UP)

	if projectile_cinematic_controller and projectile_cinematic_controller.has_method("set_active_shell"):
		projectile_cinematic_controller.set_active_shell(shell)

	_apply_recoil()

func _on_shell_hit(body: Node, hit_pos: Vector3) -> void:
	if projectile_cinematic_controller and projectile_cinematic_controller.has_method("is_shot_resolved") and projectile_cinematic_controller.is_shot_resolved():
		return

	if projectile_cinematic_controller and projectile_cinematic_controller.has_method("mark_shell_hit"):
		projectile_cinematic_controller.mark_shell_hit(hit_pos)

	var is_enemy = _is_enemy_collider(body)
	var damage_result: Dictionary = {}
	var bark_part_name := ""
	if is_enemy:
		bark_part_name = body.name
		damage_result = _apply_enemy_damage(body, hit_pos)
		if not damage_result.is_empty() and str(damage_result.get("part_key", "")) != "":
			bark_part_name = str(damage_result.get("part_key", ""))

	if combat_bark_ui:
		combat_bark_ui.show_result(is_enemy, bark_part_name if is_enemy else "")
		if not is_enemy:
			_show_direct_miss(hit_pos)
	elif is_enemy and hit_sound:
		hit_sound.global_position = hit_pos
		hit_sound.play()

func _show_direct_miss(hit_pos: Vector3) -> void:
	var should_show_miss := true
	if projectile_cinematic_controller and projectile_cinematic_controller.has_method("mark_direct_miss"):
		should_show_miss = projectile_cinematic_controller.mark_direct_miss(hit_pos)
	if not should_show_miss:
		return
	if dossier_presenter and dossier_presenter.has_method("show_target_no_damage"):
		dossier_presenter.show_target_no_damage()
	if cockpit:
		DAMAGE_NUMBER.display_text(hit_pos, "MISS", cockpit.get_tree().current_scene, Color.ORANGE_RED)

func _apply_recoil() -> void:
	if not cockpit or not visual_barrel or not muzzle:
		return
	recoil_tween = cockpit.create_tween()
	visual_barrel_base_pos = visual_barrel.position
	var recoil_vector = visual_barrel.transform.basis * (-muzzle.position.normalized() * 0.5)
	recoil_tween.tween_property(visual_barrel, "position", visual_barrel_base_pos + recoil_vector, 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	recoil_tween.tween_property(visual_barrel, "position", visual_barrel_base_pos, 0.18).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _intersect_target_ray(source_camera: Camera3D, max_distance: float) -> Dictionary:
	if intersect_target_ray_callable.is_valid():
		return intersect_target_ray_callable.call(source_camera, max_distance)
	return {}

func _is_enemy_collider(collider: Object) -> bool:
	if is_enemy_collider_callable.is_valid():
		return bool(is_enemy_collider_callable.call(collider))
	return false

func _get_target_node() -> Node3D:
	if get_target_node_callable.is_valid():
		return get_target_node_callable.call()
	return null

func _get_enemy_aim_root(node: Node3D) -> Node3D:
	if get_enemy_aim_root_callable.is_valid():
		return get_enemy_aim_root_callable.call(node)
	return node

func _apply_enemy_damage(body: Node, hit_pos: Vector3) -> Dictionary:
	if apply_enemy_damage_callable.is_valid():
		return apply_enemy_damage_callable.call(body, hit_pos)
	return {}

func _get_fire_camera() -> Camera3D:
	if get_fire_camera_callable.is_valid():
		return get_fire_camera_callable.call()
	return null
