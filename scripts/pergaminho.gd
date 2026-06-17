extends Area3D

@export_multiline var texto_pergaminho := """
A resposta está nos olhos
daquele que observa.

A terceira lua
aponta o caminho.
"""

var player_near = false

func _ready() -> void:
	# Conecta os sinais de colisão via código
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_near = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_near = false

func _process(_delta):
	# Agora sim ele sabe se o player está perto na hora de apertar o botão!
	if player_near and Input.is_action_just_pressed("action"):
		Pergaminho.mostrar_pergaminho(texto_pergaminho)
