extends Area3D

@export var nome_item = "chave_hall"

# Referência ao nó do modelo 3D (pode ser null se não existir na cena)
var modelo: Node3D = null

var player_near = false
var _tempo := 0.0
var _pos_inicial: Vector3

func _ready():
	# Se já foi coletado anteriormente, destrói a chave
	if PlayerData.itens_coletados.has(nome_item):
		queue_free()
		return

	# Tenta pegar o modelo — funciona com ou sem o nó
	modelo = get_node_or_null("ModeloChave")

	_pos_inicial = position

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_near = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_near = false

func _process(delta):
	_tempo += delta

	# Animação flutuante (sobe e desce suavemente)
	var flutua = sin(_tempo * 2.0) * 0.08
	position = _pos_inicial + Vector3(0, flutua, 0)

	# Rotação contínua no eixo Y (apenas se o modelo existir)
	if modelo != null:
		modelo.rotation.y += delta * 1.2

	if player_near and Input.is_action_just_pressed("action"):

		# Evita adicionar item repetido
		if not PlayerData.itens.has(nome_item):
			PlayerData.itens.append(nome_item)

		# Marca como coletado permanentemente
		if not PlayerData.itens_coletados.has(nome_item):
			PlayerData.itens_coletados.append(nome_item)

		print("Pegou:", nome_item)
		queue_free()
		ItemColetadoUI.mostrar(nome_item)
