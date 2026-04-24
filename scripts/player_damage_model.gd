extends Node

var max_torso_hp: int = 40
var max_left_arm_hp: int = 25
var max_right_arm_hp: int = 25
var max_left_leg_hp: int = 20
var max_right_leg_hp: int = 20
var hit_damage: int = 20

var is_dead: bool = false
var damage_flash_timer: float = 0.0
var torso_hp: int = 0
var left_arm_hp: int = 0
var right_arm_hp: int = 0
var left_leg_hp: int = 0
var right_leg_hp: int = 0

signal damaged(snapshot: Dictionary)
signal destroyed(snapshot: Dictionary)

func configure(config: Dictionary) -> void:
	max_torso_hp = max(0, int(config.get("max_torso_hp", max_torso_hp)))
	max_left_arm_hp = max(0, int(config.get("max_left_arm_hp", max_left_arm_hp)))
	max_right_arm_hp = max(0, int(config.get("max_right_arm_hp", max_right_arm_hp)))
	max_left_leg_hp = max(0, int(config.get("max_left_leg_hp", max_left_leg_hp)))
	max_right_leg_hp = max(0, int(config.get("max_right_leg_hp", max_right_leg_hp)))
	hit_damage = max(0, int(config.get("hit_damage", hit_damage)))

func reset() -> void:
	is_dead = false
	damage_flash_timer = 0.0
	torso_hp = max_torso_hp
	left_arm_hp = max_left_arm_hp
	right_arm_hp = max_right_arm_hp
	left_leg_hp = max_left_leg_hp
	right_leg_hp = max_right_leg_hp

func update(delta: float) -> void:
	if damage_flash_timer > 0.0:
		damage_flash_timer = max(0.0, damage_flash_timer - delta)

func apply_hit(region: String = "BODY") -> Dictionary:
	if is_dead:
		return {
			"applied": false,
			"destroyed": true,
			"snapshot": get_hp_snapshot()
		}

	var is_crit := (region == "WEAK SPOT")
	var actual_damage := maxi(1, roundi(hit_damage * randf_range(0.8, 1.2)))
	
	if is_crit:
		actual_damage *= 2

	torso_hp = maxi(0, torso_hp - actual_damage)
	damage_flash_timer = 2.0

	var legs_destroyed := (left_leg_hp <= 0 and right_leg_hp <= 0)
	if torso_hp <= 0 or legs_destroyed:
		is_dead = true

	var snapshot := get_hp_snapshot()
	damaged.emit(snapshot)
	if is_dead:
		destroyed.emit(snapshot)

	return {
		"applied": true,
		"damage": actual_damage,
		"part_key": "torso",
		"is_crit": is_crit,
		"destroyed": is_dead,
		"snapshot": snapshot
	}

func get_hp_snapshot() -> Dictionary:
	return {
		"name": "PLAYER",
		"parts": {
			"torso":     {"label": "TORSO",   "current": torso_hp,     "max": max_torso_hp,     "broken": torso_hp <= 0},
			"left_arm":  {"label": "L ARM",   "current": left_arm_hp,  "max": max_left_arm_hp,  "broken": left_arm_hp <= 0},
			"right_arm": {"label": "R ARM",   "current": right_arm_hp, "max": max_right_arm_hp, "broken": right_arm_hp <= 0},
			"left_leg":  {"label": "L LEG",   "current": left_leg_hp,  "max": max_left_leg_hp,  "broken": left_leg_hp <= 0},
			"right_leg": {"label": "R LEG",   "current": right_leg_hp, "max": max_right_leg_hp, "broken": right_leg_hp <= 0},
		},
		"destroyed": is_dead
	}
