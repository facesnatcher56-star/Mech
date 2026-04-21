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

signal reload_started()

var projectile_speed: float = 150.0
var bullet_slomo: float = 0.2

var target_query_helper: Node = null
var analog_targeting_controller: Node = null
var fire_cam: Camera3D = null

var recoil_tween: Tween
var visual_barrel_base_pos: Vector3

func configure(config: Dictionary) -> void:
	cockpit = config.get("cockpit", cockpit)
	target_query_helper = config.get("target_query_helper", target_query_helper)
	analog_targeting_controller = config.get("analog_targeting_controller", analog_targeting_controller)
	refresh_runtime_refs(config)

func refresh_runtime_refs(config: Dictionary) -> void:
	projectile_cinematic_controller = config.get("projectile_cinematic_controller", projectile_cinematic_controller)
	combat_bark_ui = config.get("combat_bark_ui", combat_bark_ui)
	dossier_presenter = config.get("dossier_presenter", dossier_presenter)
	cannon_sound = config.get("cannon_sound", cannon_sound)
	hit_sound = config.get("hit_sound", hit_sound)
	visual_barrel = config.get("visual_barrel", visual_barrel)
	muzzle = config.get("muzzle", muzzle)
	fire_cam = config.get("fire_cam", fire_cam) as Camera3D
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

	reload_started.emit()

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

	if is_enemy and damage_result.get("applied", false):
		var region := str(damage_result.get("region", ""))
		var dm: Node = dossier_presenter.find_damage_model_node(body) if dossier_presenter else null
		if dm and dm.has_method("apply_aim_disruption"):
			dm.apply_aim_disruption(region)

	if is_enemy and hit_sound:
		hit_sound.global_position = hit_pos
		hit_sound.play()

	if combat_bark_ui:
		combat_bark_ui.show_result(is_enemy, bark_part_name if is_enemy else "")
		if not is_enemy:
			_show_direct_miss(hit_pos)

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
	if target_query_helper:
		return target_query_helper.intersect_target_ray(source_camera, max_distance)
	return {}

func _is_enemy_collider(collider: Object) -> bool:
	if target_query_helper:
		return target_query_helper.is_enemy_collider(collider)
	return false

func _get_target_node() -> Node3D:
	if analog_targeting_controller:
		return analog_targeting_controller.get_target_node()
	return null

func _get_enemy_aim_root(node: Node3D) -> Node3D:
	if analog_targeting_controller:
		return analog_targeting_controller.get_enemy_aim_root(node)
	return node

func _apply_enemy_damage(body: Node, hit_pos: Vector3) -> Dictionary:
	if dossier_presenter and dossier_presenter.has_method("apply_enemy_damage"):
		return dossier_presenter.apply_enemy_damage(body, hit_pos)
	return {}

func _get_fire_camera() -> Camera3D:
	return fire_cam
