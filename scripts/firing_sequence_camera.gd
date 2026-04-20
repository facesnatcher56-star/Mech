extends Camera3D

@export_group("Cinematic Timing")
## Time to hold on this camera before the enemy fires.
@export var pre_fire_hold: float = 2.0
## Time to hold on this camera after the enemy fires before returning to player view.
@export var post_fire_hold: float = 1.0
