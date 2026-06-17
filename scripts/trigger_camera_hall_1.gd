extends Area3D


@export var target_camera : Camera3D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		target_camera.make_current()
