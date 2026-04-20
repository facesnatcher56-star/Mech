extends Node

var player: AudioStreamPlayer = null
var loop_condition: Callable

func configure(parent: Node, stream: AudioStream, volume_db: float, pitch_scale: float, new_loop_condition: Callable) -> void:
	loop_condition = new_loop_condition
	player = AudioStreamPlayer.new()
	player.name = "AnalogHeartbeat"
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	parent.add_child(player)
	player.finished.connect(_on_finished)

func play(stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	if not player or not stream:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func stop() -> void:
	if player:
		player.stop()

func _on_finished() -> void:
	if player and loop_condition.is_valid() and bool(loop_condition.call()):
		player.play()
