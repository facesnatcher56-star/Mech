extends Node3D

@onready var fog_volume: FogVolume = $FogVolume

var _has_deployed: bool = false
var _is_active: bool = false
var _tween: Tween = null

func _ready() -> void:
	visible = false
	if fog_volume and fog_volume.material:
		(fog_volume.material as FogMaterial).density = 0.0

func is_active() -> bool:
	return _is_active

func deploy() -> void:
	if _has_deployed:
		return
	_has_deployed = true
	_is_active = true
	visible = true

	if fog_volume and fog_volume.material:
		var mat := fog_volume.material as FogMaterial
		mat.density = 0.0
		_tween = create_tween()
		_tween.tween_property(mat, "density", 2.5, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(4.0)
		_tween.tween_property(mat, "density", 0.0, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.finished.connect(_on_finished)

func dismiss() -> void:
	if not _is_active:
		return
	if _tween and _tween.is_running():
		_tween.kill()
	if fog_volume and fog_volume.material:
		var mat := fog_volume.material as FogMaterial
		_tween = create_tween()
		_tween.tween_property(mat, "density", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_tween.finished.connect(_on_finished)
	else:
		_on_finished()

func _on_finished() -> void:
	visible = false
	_is_active = false
	_has_deployed = false
