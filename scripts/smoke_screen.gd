extends Node3D

@onready var fog_volume: FogVolume = $FogVolume

func _ready() -> void:
	# Start invisible
	visible = false
	if fog_volume and fog_volume.material:
		# Optionally start density at 0 if you want a fade-in effect
		var mat = fog_volume.material as FogMaterial
		mat.density = 0.0

## Deploys the smoke by making it visible and fading in the density.
func deploy() -> void:
	if visible: return
	visible = true
	
	if fog_volume and fog_volume.material:
		var mat = fog_volume.material as FogMaterial
		var tween = create_tween()
		tween.tween_property(mat, "density", 2.5, 12.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
