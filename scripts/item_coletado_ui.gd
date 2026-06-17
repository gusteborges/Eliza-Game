extends CanvasLayer

# ============================================================
#  ITEM COLETADO UI — Aparece em tela cheia ao coletar item.
#  Ao fechar, abre o InventarioUi com o item destacado.
# ============================================================

# Mapeia nome do item → caminho do modelo 3D
const ITEM_MODELOS: Dictionary = {
	"chave_hall": "res://assets/third_person_controller_assets/models/simple_key_-_chave_simples..glb",
}


# Dicionário central de todos os itens — compartilhado com InventarioUi
const ITEM_INFO: Dictionary = {
	"chave_hall": {
		"nome_display": "Chave do Hall",
		"descricao": "Uma chave velha e enferrujada.\nAbre a porta de entrada do hall.",
		"icone": preload("uid://ckgbwtsdsvjmc")
	},
}

@onready var painel       : PanelContainer  = $PainelCentral
@onready var label_nome   : Label           = $PainelCentral/MargemConteudo/VBox/LabelNome
@onready var label_desc   : Label           = $PainelCentral/MargemConteudo/VBox/LabelDescricao
@onready var label_dica   : Label           = $PainelCentral/MargemConteudo/VBox/LabelDica
@onready var modelo_raiz  : Node3D          = $PainelCentral/MargemConteudo/VBox/ModeloContainer/ModeloViewport/ModeloRaiz

var _item_atual   := ""
var _tween_dica: Tween = null
var _modelo_inst: Node3D = null
var _tempo := 0.0

# ──────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

# ──────────────────────────────────────────────
func _process(delta: float) -> void:
	if not visible:
		return
	_tempo += delta
	# Rotação suave do modelo 3D no viewport
	if _modelo_inst != null:
		_modelo_inst.rotation.y += delta * 1.5

# ──────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# is_action_pressed() é o método correto dentro de _unhandled_input
	if event.is_action_pressed("action") \
	or event.is_action_pressed("ui_accept") \
	or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fechar()

# ──────────────────────────────────────────────
func mostrar(nome_item: String) -> void:
	_item_atual = nome_item

	var info: Dictionary = ITEM_INFO.get(nome_item, {
		"nome_display": nome_item.capitalize().replace("_", " "),
		"descricao":    "Um item misterioso.",
		"icone":        null
	})

	label_nome.text = info.get("nome_display", nome_item)
	label_desc.text = info.get("descricao", "")

	# Carrega o modelo 3D no SubViewport
	_carregar_modelo(nome_item)

	show()
	get_tree().paused = true

	# Fade-in do painel
	painel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(painel, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)

	# Piscar dica
	if _tween_dica:
		_tween_dica.kill()
	_tween_dica = create_tween().set_loops()
	_tween_dica.tween_property(label_dica, "modulate:a", 0.25, 0.85)
	_tween_dica.tween_property(label_dica, "modulate:a", 1.0,  0.85)

# ──────────────────────────────────────────────
func _carregar_modelo(nome_item: String) -> void:
	# Remove modelo anterior se existir
	for filho in modelo_raiz.get_children():
		filho.queue_free()
	_modelo_inst = null

	var caminho = ITEM_MODELOS.get(nome_item, "")
	if caminho == "":
		return

	var packed = load(caminho)
	if packed == null:
		return

	_modelo_inst = packed.instantiate()
	modelo_raiz.add_child(_modelo_inst)

	# Centraliza e escala o modelo para caber no viewport
	_modelo_inst.position = Vector3.ZERO
	_modelo_inst.scale = Vector3(2, 1, 2)

# ──────────────────────────────────────────────
func _fechar() -> void:
	if _tween_dica:
		_tween_dica.kill()
		_tween_dica = null

	var tw := create_tween()
	tw.tween_property(painel, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(_apos_fechar)

func _apos_fechar() -> void:
	hide()
	# Limpa o modelo do viewport
	for filho in modelo_raiz.get_children():
		filho.queue_free()
	_modelo_inst = null
	# Não despausa aqui — InventarioUi vai gerenciar a pausa
	InventarioUi.mostrar_com_destaque(_item_atual)
