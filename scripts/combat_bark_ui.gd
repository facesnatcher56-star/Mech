extends Control

@onready var panel = $Panel
@onready var label = $Panel/Label
@onready var name_label = $Panel/NameLabel

var is_high_priority_active: bool = false

var commit_lines = [
	"Fire.", "Send it.", "Take this.", "Let it fly.",
	"Fire for effect.", "Range is good. Fire.", "Send the round.", "On my mark—fire."
]

var miss_lines = [
	"Damn, missed.", "Off target.", "Shot went wide.", "No hit.",
	"Missed him.", "Adjustment needed.", "We're off.", "That went wide."
]

var hit_generic_lines = [
	"Direct hit.", "Good hit.", "We hit him.", "On target.",
	"That landed.", "Solid hit.", "Target struck.", "We connected."
]

var body_part_lines = {
	"torso": ["Torso hit.", "Center mass hit.", "Direct hit to the body.", "Hit the torso."],
	"leftarm": ["Left arm hit.", "Clipped his left arm.", "Solid hit on the left arm."],
	"rightarm": ["Right arm hit.", "Clipped his right arm.", "Solid hit on the right arm."],
	"leftleg": ["Hit the left leg.", "Left leg hit.", "Damaged the left leg."],
	"rightleg": ["Hit the right leg.", "Right leg hit.", "Damaged the right leg."],
	"head": ["Cockpit area hit.", "Headshot.", "Hit near the optics.", "Targeted the head."]
}

var zezlan_taunts = [
	"Take that, Zezlan!", "You're slowing down, Zezlan.",
	"The Zezlan is hit!", "Finally found you, Zezlan.",
	"Had enough, Zezlan?", "Zezlan's armor is failing!"
]

var smoke_alert_lines = [
	"Zezlan's dumping coolant! He's trying to bleed the block, don't let him reset!",
	"He's purging the manifold! If he clears those lines, he gets his leg back!",
	"Smoke on the deck! I hear his pumps cycling, he's unjamming the breech!",
	"He's blowing the valves! Target is stationary and trying to re-prime his hydraulics!",
	"Coolant flush! Zezlan's down, but he's trying to cycle the pressure—hit him now!"
]

# ── Ammo-type hit barks ───────────────────────────────────────────────────────

var standard_hit_lines = [
	"Solid hit!", "Good impact!", "That punched through!", "Hit confirmed!", "Keep sending it!",
	"That one connected!", "Clean strike!", "Target shook hard!", "Good shell, good hit!",
	"Impact on Zezlan!", "That one rang the dinner bell!", "Armor's peeling like cheap tin!",
	"That leg's got no business still standing!", "Send another and make it official!",
	"That hit had paperwork attached!", "Beautiful shot. Ugly result.",
	"I felt that one from here!", "Whatever that was bolted to, it isn't anymore.",
	"That machine just learned regret.", "Hit it again before it remembers how to stand!"
]

var ap_hit_lines = [
	"AP hit! Armor's cracking!", "That punched deep!", "Clean penetration!",
	"Torso breach forming!", "Armor plate's split!", "That one bit hard!",
	"AP strike confirmed!", "Core armor's weakening!", "Keep AP on the center mass!",
	"That shell found the seam!", "Good punch-through!", "Internal damage likely!",
	"That was a real armor hit!", "Hit the torso again!", "AP did its job!"
]

var he_leg_hit_lines = [
	"HE hit! Structure's buckling!", "Blast walked into the legs!", "Good splash damage!",
	"That shook both sides!", "Leg assembly took it!", "Blast pressure hit the frame!",
	"HE is tearing the lower body!", "Secondary damage confirmed!", "That explosion spread!",
	"Good disable hit!", "Keep HE on the legs!", "Blast cracked the supports!",
	"That rattled the whole chassis!", "Lower structure is softening!", "HE did work!"
]

var he_torso_hit_lines = [
	"HE on the torso!", "Blast washed over the frame!", "Not the deepest hit, but it hurt!",
	"Explosion spread to the legs!", "Torso impact, splash confirmed!",
	"Good blast, not clean penetration!", "HE shook the armor loose!", "That'll loosen something!"
]

var incendiary_hit_lines = [
	"Fire's taking hold!", "Burn on the target!", "Heat damage started!", "That part's cooking!",
	"Good burn, let it work!", "Flame's in the seams!", "Thermal damage confirmed!",
	"Keep pressure while it burns!", "That'll eat through over time!", "Fire's spreading inside!"
]

var concussion_hit_lines = [
	"Concussion hit! Their rhythm's broken!", "That staggered them!", "Good stun effect!",
	"They're off cycle!", "Reload timing disrupted!", "That bought us time!", "Impact shock did it!",
	"Zezlan's aim cycle slipped!", "Good tempo hit!", "Keep them delayed!"
]

var shrapnel_hit_lines = [
	"Shrapnel hit! Fragments spread!", "Multiple impacts!", "That peppered the frame!",
	"Fragments walked across the armor!", "Good spread pattern!", "Shrapnel tore into the lower body!",
	"That hit more than one section!", "Fragment damage confirmed!", "Good coverage!",
	"That sprayed the chassis!", "Frame's full of holes!", "Lots of small bites!",
	"That chewed the outside up!", "Good scatter hit!", "Fragments found metal!"
]

var breach_hit_lines = [
	"Breach hit! Mark that plate!", "Armor cracked — hit it again!", "That opened a seam!",
	"Breach charge set!", "Next hit there will hurt!", "Good crack in the armor!",
	"That section is exposed!", "Repeat that shot!", "Same spot, send another!",
	"Armor weakness created!", "That plate's compromised!", "Follow-up shot is primed!",
	"Hit that breach before it settles!", "Good setup hit!", "That made a hole. Use it!"
]

var breach_followup_lines = [
	"Breach exploited!", "That follow-up punched through!", "Same spot paid off!",
	"Armor gave way!", "Beautiful follow-up!", "Crack turned into a rupture!"
]

var crit_hit_lines = [
	"Critical hit!", "That hit something important!", "Direct critical!",
	"Major damage confirmed!", "That one went deep!", "Critical damage!",
	"That punched through clean!", "Big hit! Keep pressure!", "Something broke inside!",
	"That was the shot!", "Critical strike confirmed!", "Armor failed!",
	"That tore through!", "Internal damage spike!", "That hurt them bad!"
]

# ── Interface ─────────────────────────────────────────────────────────────────

func _ready():
	visible = false
	modulate.a = 0.0

func show_smoke_alert():
	is_high_priority_active = true
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 40)
	label.text = smoke_alert_lines.pick_random()
	_fade_in()
	get_tree().create_timer(5.0).timeout.connect(func():
		_fade_out()
		await get_tree().create_timer(0.3).timeout
		is_high_priority_active = false
		set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE, 40)
	)

func show_commit():
	if is_high_priority_active: return
	label.text = commit_lines.pick_random()
	_fade_in()

func show_result(is_hit: bool, body_part_name: String = "", ammo_key: String = "", triggered_crack: bool = false, is_crit: bool = false) -> void:
	if is_high_priority_active: return
	if not is_hit:
		label.text = miss_lines.pick_random()
		return

	# Crit barks take highest priority
	if is_crit:
		label.text = crit_hit_lines.pick_random()
		_fade_in()
		return

	# Ammo-specific barks take next priority
	var ammo_bark := _get_ammo_bark(ammo_key, body_part_name, triggered_crack)
	if ammo_bark != "":
		label.text = ammo_bark
		_fade_in()
		return

	# Fallback: 25% Zezlan taunt, otherwise part-specific or generic
	if randf() < 0.25:
		label.text = zezlan_taunts.pick_random()
		return
	var category := _normalize_part_name(body_part_name)
	if category != "" and body_part_lines.has(category):
		label.text = body_part_lines[category].pick_random()
	else:
		label.text = hit_generic_lines.pick_random()

var victory_lines = [
	"Target neutralized.",
	"Zezlan is down. Mission complete.",
	"Enemy destroyed. Good work.",
	"Target eliminated. Stand down.",
	"Zezlan's offline. That's a kill."
]

func show_victory() -> void:
	is_high_priority_active = true
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE, 0)
	label.text = victory_lines.pick_random()
	_fade_in()

func hide_bark():
	_fade_out()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_ammo_bark(ammo_key: String, part_name: String, triggered_crack: bool = false) -> String:
	match ammo_key:
		"STANDARD":
			return standard_hit_lines.pick_random()
		"AP":
			return ap_hit_lines.pick_random()
		"HE":
			var category := _normalize_part_name(part_name)
			if "leg" in category:
				return he_leg_hit_lines.pick_random()
			else:
				return he_torso_hit_lines.pick_random()
		"INCENDIARY":
			return incendiary_hit_lines.pick_random()
		"CONCUSSION":
			return concussion_hit_lines.pick_random()
		"SHRAPNEL":
			return shrapnel_hit_lines.pick_random()
		"BREACH":
			if triggered_crack:
				return breach_followup_lines.pick_random()
			return breach_hit_lines.pick_random()
	return ""

func _normalize_part_name(part_name: String) -> String:
	var n := part_name.to_lower()
	if "leftarm" in n or "left_arm" in n: return "leftarm"
	if "rightarm" in n or "right_arm" in n: return "rightarm"
	if "leftleg" in n or "left_leg" in n: return "leftleg"
	if "rightleg" in n or "right_leg" in n: return "rightleg"
	if "torso" in n or "body" in n: return "torso"
	if "head" in n or "cockpit" in n or "eye" in n: return "head"
	return ""

func _fade_in():
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.05)

func _fade_out():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func(): visible = false)
