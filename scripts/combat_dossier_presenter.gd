extends Node

const TARGET_DOSSIER_UI = preload("res://scripts/target_dossier_ui.gd")

var cockpit: Node = null
var canvas_layer: CanvasLayer = null
var target_dossier_ui: Control = null
var self_dossier_ui: Control = null
var enemy_reload_ui: Control = null

func configure(new_cockpit: Node, new_canvas_layer: CanvasLayer) -> void:
	cockpit = new_cockpit
	canvas_layer = new_canvas_layer
	if not canvas_layer:
		return
	_setup_target_dossier_ui()
	_setup_self_dossier_ui()
	_setup_enemy_reload_ui()

func update_self_status(snapshot: Dictionary, reload_progress: float) -> void:
	if not self_dossier_ui:
		return
	var snap := snapshot.duplicate(true)
	snap["reload"] = {"progress": reload_progress, "label": "CANNON"}
	self_dossier_ui.set_snapshot(snap)


func sync_view_visibility(in_normal_view: bool) -> void:
	if self_dossier_ui:
		self_dossier_ui.visible = in_normal_view
	if enemy_reload_ui:
		enemy_reload_ui.visible = in_normal_view

func update_enemy_reload(snap: Dictionary) -> void:
	if enemy_reload_ui:
		enemy_reload_ui.set_snapshot(snap)

func show_target_dossier() -> void:
	if not target_dossier_ui:
		return
	var snapshot := get_current_target_hp_snapshot()
	if snapshot.is_empty():
		target_dossier_ui.hide_dossier()
	else:
		target_dossier_ui.show_dossier(snapshot)

func hide_target_dossier() -> void:
	if target_dossier_ui:
		target_dossier_ui.hide_dossier()

func show_target_no_damage() -> void:
	if target_dossier_ui:
		target_dossier_ui.show_impact_line("NO DAMAGE", "", get_current_target_hp_snapshot())

func show_player_hit(part_key: String, snapshot: Dictionary) -> void:
	if self_dossier_ui:
		self_dossier_ui.show_impact_line("HIT!", part_key, snapshot)

func apply_enemy_damage(body: Node, hit_pos: Vector3) -> Dictionary:
	var damage_model := find_damage_model_node(body)
	if not damage_model or not damage_model.has_method("apply_shell_damage"):
		return {}

	var result: Dictionary = damage_model.apply_shell_damage(body, hit_pos)
	if target_dossier_ui and result.has("snapshot"):
		var damage := int(result.get("damage", 0))
		var region := str(result.get("region", "STRUCTURE"))
		var line := "HIT %s  -%d" % [region, damage]
		if bool(result.get("part_broken", false)):
			line = "%s BROKEN" % region
		if bool(result.get("destroyed", false)):
			line = "TARGET DESTROYED"
		target_dossier_ui.show_impact_line(line, str(result.get("part_key", "")), result["snapshot"])
	return result

func get_current_target_hp_snapshot() -> Dictionary:
	var target := _get_current_target_node()
	var damage_model := find_damage_model_node(target)
	if damage_model and damage_model.has_method("get_hp_snapshot"):
		return damage_model.get_hp_snapshot()
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node:
			damage_model = find_damage_model_node(node)
			if damage_model and damage_model.has_method("get_hp_snapshot"):
				return damage_model.get_hp_snapshot()
	return {}

func find_damage_model_node(start_node: Node) -> Node:
	var node := start_node
	while node:
		if node.has_method("apply_shell_damage") and node.has_method("get_hp_snapshot"):
			return node
		node = node.get_parent()
	return null

func _setup_target_dossier_ui() -> void:
	target_dossier_ui = TARGET_DOSSIER_UI.new()
	target_dossier_ui.name = "TargetDossierUI"
	canvas_layer.add_child(target_dossier_ui)

func _setup_self_dossier_ui() -> void:
	self_dossier_ui = TARGET_DOSSIER_UI.new()
	self_dossier_ui.name = "SelfDossierUI"
	self_dossier_ui.anchor_corner = TARGET_DOSSIER_UI.AnchorCorner.TOP_LEFT
	self_dossier_ui.display_scale = 0.40
	self_dossier_ui.custom_offset_x = -21.0
	self_dossier_ui.custom_offset_y = -21.0
	canvas_layer.add_child(self_dossier_ui)
	self_dossier_ui.show_dossier(_get_player_snapshot())


func _get_current_target_node() -> Node3D:
	if cockpit and cockpit.has_method("_get_analog_target_node"):
		return cockpit._get_analog_target_node()
	return null

func _get_player_snapshot() -> Dictionary:
	if cockpit and cockpit.has_method("get_hp_snapshot"):
		return cockpit.get_hp_snapshot()
	return {}

func _setup_enemy_reload_ui() -> void:
	enemy_reload_ui = TARGET_DOSSIER_UI.new()
	enemy_reload_ui.name = "EnemyReloadUI"
	enemy_reload_ui.minimal_mode = true
	enemy_reload_ui.anchor_corner = TARGET_DOSSIER_UI.AnchorCorner.TOP_RIGHT
	enemy_reload_ui.panel_size = Vector2(210.0, 54.0)
	enemy_reload_ui.display_scale = 1.0
	enemy_reload_ui.custom_offset_x = -4.0
	enemy_reload_ui.custom_offset_y = 4.0
	canvas_layer.add_child(enemy_reload_ui)
	enemy_reload_ui.visible = false
