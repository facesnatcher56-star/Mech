extends Node

const AMMO_KEYS = ["STANDARD", "AP", "HE", "INCENDIARY", "SHRAPNEL", "CONCUSSION", "BREACH"]

# -1 means infinite, 0 means locked until earned from rewards
var ammo_counts: Dictionary = {
	"STANDARD": -1,
	"AP": 0,
	"HE": 0,
	"INCENDIARY": 0,
	"SHRAPNEL": 0,
	"CONCUSSION": 0,
	"BREACH": 0,
}

func get_ammo_count(key: String) -> int:
	return int(ammo_counts.get(key, 0))

func has_ammo(key: String) -> bool:
	var count = get_ammo_count(key)
	return count == -1 or count > 0

func consume_ammo(key: String) -> void:
	if key == "STANDARD":
		return
	if ammo_counts.has(key) and ammo_counts[key] > 0:
		ammo_counts[key] -= 1

func add_ammo(key: String, amount: int) -> void:
	if key == "STANDARD":
		return
	if ammo_counts.has(key):
		ammo_counts[key] += amount
	else:
		ammo_counts[key] = amount

func reset_ammo() -> void:
	ammo_counts = {
		"STANDARD": -1,
		"AP": 0,
		"HE": 0,
		"INCENDIARY": 0,
		"SHRAPNEL": 0,
		"CONCUSSION": 0,
		"BREACH": 0,
	}

# ── Player HP ─────────────────────────────────────────────────────────────────

var player_hp: Dictionary = {}

func has_saved_hp() -> bool:
	return not player_hp.is_empty()

func get_player_hp() -> Dictionary:
	return player_hp

func save_player_hp(hp_dict: Dictionary) -> void:
	player_hp = hp_dict

func reset_player_hp() -> void:
	player_hp = {}
