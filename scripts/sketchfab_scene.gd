extends Node3D

@onready var trigger_base: Area3D = $trigger_base

# =========================
# 
# =========================

func _on_trigger_base_body_entered(body : Node3D):
	if  body.is_in_group("Player"):
		print("Player")

func _on_trigger_base_body_exited(body):
	if body.name == "Player":
		print("vazei")
