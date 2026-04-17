extends Control

@onready var cockpit = get_tree().get_first_node_in_group("player")

func _ready():
	if not cockpit: return
	
	# Gun Cam
	setup_slider("GunCamDuration", "Duration (Gun Cam)", 0.0, 2.0, cockpit.guncam_duration, "How long to watch the gun fire.")
	setup_slider("GunCamFOV", "FOV (Gun Cam)", 10.0, 120.0, cockpit.guncam_fov, "Field of view for the gun camera.")
	
	# Impact Cam
	setup_slider("ImpactCamTimeout", "Timeout (Impact Cam)", 0.5, 5.0, cockpit.impactcam_timeout, "Max time to watch the shell travel.")
	setup_slider("ImpactCamFOV", "FOV (Impact Cam)", 10.0, 120.0, cockpit.impactcam_fov, "Field of view for the impact camera.")
	setup_slider("ImpactCamRotate", "Rotate (Impact Cam)", 0.0, 5.0, cockpit.impactcam_rotation_speed, "How fast the camera spins during flight.")
	
	# Miss/Linger
	setup_slider("LingerDuration", "Linger Duration", 0.0, 5.0, cockpit.linger_duration, "How long to watch the impact point after hit/miss.")

func setup_slider(node_name: String, label_text: String, min_val: float, max_val: float, current_val: float, tooltip: String):
	var container = VBoxContainer.new()
	container.name = node_name
	
	var label = Label.new()
	label.text = label_text
	label.tooltip_text = tooltip
	container.add_child(label)
	
	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.05
	slider.value = current_val
	slider.tooltip_text = tooltip
	
	slider.value_changed.connect(func(val):
		match node_name:
			"GunCamDuration": cockpit.guncam_duration = val
			"GunCamFOV": cockpit.guncam_fov = val
			"ImpactCamTimeout": cockpit.impactcam_timeout = val
			"ImpactCamFOV": cockpit.impactcam_fov = val
			"ImpactCamRotate": cockpit.impactcam_rotation_speed = val
			"LingerDuration": cockpit.linger_duration = val
	)
	
	container.add_child(slider)
	$VBox.add_child(container)
