extends Area3D

@export_file("*.tscn") var caminho_cena_transicao: String

# Arraste o Marker3D do topo da escada para cá no Inspetor!
@export var ponto_de_destino: Marker3D 

var player_near : Node3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_near = body

func _on_body_exited(body):
	if body.is_in_group("player"):
		if player_near == body:
			player_near = null

func _process(_delta):
	if player_near != null and Input.is_action_just_pressed("action"):
		if caminho_cena_transicao != "" and ponto_de_destino != null:
			Global.destino_do_teleporte = ponto_de_destino.global_position
			Global.rotacao_do_teleporte = ponto_de_destino.global_rotation
			
			get_tree().change_scene_to_file(caminho_cena_transicao)
		else:
			print("Erro: Falta a cena de transição ou o Marker3D do destino!")
