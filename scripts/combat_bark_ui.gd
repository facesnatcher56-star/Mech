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
	"Missed him.", "Adjustment needed.", "We’re off.", "That went wide."
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

func _ready():
	visible = false
	modulate.a = 0.0

func show_smoke_alert():
	# Temporarily anchor to top-center
	is_high_priority_active = true
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 40)
	label.text = smoke_alert_lines.pick_random()
	_fade_in()
	
	# Auto-hide after 5 seconds and reset position
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

func show_result(is_hit: bool, body_part_name: String = ""):
	if is_high_priority_active: return
	if not is_hit:
		label.text = miss_lines.pick_random()
	else:
		# 25% chance to use a Zezlan taunt instead of a part-specific bark
		if randf() < 0.25:
			label.text = zezlan_taunts.pick_random()
			return

		var category = _normalize_part_name(body_part_name)
		if category != "" and body_part_lines.has(category):
			label.text = body_part_lines[category].pick_random()
		else:
			label.text = hit_generic_lines.pick_random()

func hide_bark():
	_fade_out()

func _normalize_part_name(part_name: String) -> String:
	var n = part_name.to_lower()
	if "leftarm" in n: return "leftarm"
	if "rightarm" in n: return "rightarm"
	if "leftleg" in n: return "leftleg"
	if "rightleg" in n: return "rightleg"
	if "torso" in n or "body" in n: return "torso"
	if "head" in n or "cockpit" in n or "eye" in n: return "head"
	return ""

func _fade_in():
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.05) # FAST pop up

func _fade_out():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.finished.connect(func(): visible = false)
