extends Area3D

@export_file("*.tscn") var caminho_cena_transicao: String

# Arraste o Marker3D do topo da escada para cá no Inspetor!
@export var ponto_de_destino: Marker3D 
@export var trancada: bool = true
@export var chave_necessaria = ""
@export var exige_senha: bool = false

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
		
		# -------------------------
		# 1. PORTA COM SENHA
		# -------------------------
		if exige_senha:
			# Se ainda não resolveu, abre a UI e para o código aqui
			if not Global.porta_hall_aberta:
				SenhaUi.mostrar()
				return 
			# Se já resolveu no Global, a mágica acontece: destranca a porta!
			else:
				trancada = false 

		# -------------------------
		# 2. PORTA COM CHAVE
		# -------------------------
		if trancada:
			if not PlayerData.itens.has(chave_necessaria):
				MensagemTela.mostrar_mensagem("A porta nao abre")
				return
				
			print("Usou:", chave_necessaria)
			trancada = false

		# -------------------------
		# 3. ABRIR PORTA E INICIAR TRANSIÇÃO
		# -------------------------
		if caminho_cena_transicao != "" and ponto_de_destino != null:
			Global.destino_do_teleporte = ponto_de_destino.global_position
			Global.rotacao_do_teleporte = ponto_de_destino.global_rotation
			
			get_tree().change_scene_to_file(caminho_cena_transicao)
		else:
			print("Erro: Falta a cena de transição ou o Marker3D do destino!")
