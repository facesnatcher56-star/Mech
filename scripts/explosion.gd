extends GPUParticles3D

func _ready():
	emitting = true
	finished.connect(queue_free)
