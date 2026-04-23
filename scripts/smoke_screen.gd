extends Node3D

@onready var fog_volume: FogVolume = $FogVolume

var _has_deployed: bool = false

func _ready() -> void:
	# Start invisible
	visible = false
	if fog_volume and fog_volume.material:
		# Optionally start density at 0 if you want a fade-in effect
		var mat = fog_volume.material as FogMaterial
		mat.density = 0.0

## Deploys the smoke by making it visible and fading in the density.
func deploy() -> void:
	if _has_deployed: return
	_has_deployed = true
	visible = true
	
	if fog_volume and fog_volume.material:
		var mat = fog_volume.material as FogMaterial
		mat.density = 0.0 # Ensure start at 0
		
		var tween = create_tween()
		# Phase 1: Rapid bloom (2s)
		tween.tween_property(mat, "density", 2.5, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# Phase 2: Hold (4s)
		tween.tween_interval(4.0)
		# Phase 3: Slow dissipation (4s)
		tween.tween_property(mat, "density", 0.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		# End: cleanup
		tween.finished.connect(func(): visible = false)
