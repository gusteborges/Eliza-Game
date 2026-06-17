extends CanvasLayer

# ============================================================
#  INVENTARIO UI
#  Abre/fecha com Tab. Popula o grid com PlayerData.itens.
# ============================================================

# Mapa: nome_item → { "icone": Texture2D, "nome_display": String }
# Adicione novos itens aqui conforme forem criados no jogo.
const ITEM_INFO: Dictionary = {
	"chave_hall": {
		"nome_display": "Chave Hall",
		"icone": preload("uid://ckgbwtsdsvjmc")
	},
}

@onready var grid_container   : GridContainer = $PainelRaiz/PainelDireito/VBoxDir/MarginGrid/GridItens
@onready var root_panel       : Control       = $PainelRaiz
@onready var animation_player : AnimationPlayer = $PainelRaiz/PainelEsquerdo/VBoxEsq/SubViewportContainer/SubViewport/elisa_rig3/elisa_rig2/AnimationPlayer
@onready var batimento        : ColorRect     = $PainelRaiz/PainelEsquerdo/VBoxEsq/InfoContainer/MarginECG/Batimento

# Referências dos 9 slots (criados via código em _ready)
var slots: Array = []

# ──────────────────────────────────────────────
# SISTEMA DE SAÚDE / ECG
# ──────────────────────────────────────────────
const ESTADO_NORMAL  = 0
const ESTADO_PERIGO  = 1
const ESTADO_CRITICO = 2

# Parâmetros do shader por estado de saúde
const ECG_ESTADOS := {
	ESTADO_NORMAL: {
		"line_color":  Color(0.05, 1.00, 0.45, 1.0),  # verde neon — sinusal
		"speed":       0.22,  # lento e claro — ~60 BPM
		"cycles":      0.9,   # menos de 1 batimento visível — bem legível
		"arrhythmia":  0.0,
		"glow_spread": 5.5,
	},
	ESTADO_PERIGO: {
		"line_color":  Color(1.00, 0.80, 0.00, 1.0),  # amarelo
		"speed":       0.45,  # mais rápido — ~90 BPM
		"cycles":      1.5,   # 1.5 batimentos visíveis
		"arrhythmia":  0.0,
		"glow_spread": 6.5,
	},
	ESTADO_CRITICO: {
		"line_color":  Color(1.00, 0.10, 0.06, 1.0),  # vermelho
		"speed":       0.90,  # rápido e caótico — ~150 BPM
		"cycles":      2.5,   # 2.5 batimentos caóticos
		"arrhythmia":  0.88,
		"glow_spread": 7.5,
	},
}

var _estado_ecg  := -1  # -1 força update inicial
var _tween_ecg   : Tween = null

# ──────────────────────────────────────────────
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_criar_slots()

	# Força a animação a rodar sempre que o inventário nascer
	if animation_player:
		animation_player.play("IDLE_ELISA")

	# Aplica estado inicial do ECG baseado na vida atual
	await get_tree().process_frame
	_checar_estado_saude(true)

# ──────────────────────────────────────────────
func _process(_delta: float) -> void:
	_checar_estado_saude()

# ──────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		fechar()
	elif event.is_action_pressed("inventory"):
		if visible:
			fechar()
		else:
			mostrar()
# ──────────────────────────────────────────────
func mostrar() -> void:
	show()
	if not get_tree().paused:
		get_tree().paused = true
	_atualizar_grid()

func fechar() -> void:
	hide()
	get_tree().paused = false

# ──────────────────────────────────────────────
#  Cria os 9 slots do grid uma única vez
# ──────────────────────────────────────────────
func _criar_slots() -> void:
	for i in range(9):
		var slot := _novo_slot()
		grid_container.add_child(slot)
		slots.append(slot)

func _novo_slot() -> PanelContainer:
	# Container visual do slot
	var panel := PanelContainer.new()
	
	# DIZ AO SLOT PARA OCUPAR TODO O ESPAÇO DISPONÍVEL NO GRID:
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Mantemos o tamanho mínimo como uma base de segurança
	panel.custom_minimum_size = Vector2(120, 120)

	var style := StyleBoxFlat.new()
	style.bg_color          = Color(0.05, 0.12, 0.13, 0.85)
	style.border_width_left   = 2
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 2
	style.border_color     = Color(0.15, 0.5, 0.55, 0.6)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left  = 6
	panel.add_theme_stylebox_override("panel", style)

	# Ícone do item (TextureRect)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# ISSO IMPEDE O VBOX DE DESALINHAR OS ITENS INTERNOS:
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var icon := TextureRect.new()
	icon.name             = "Icone"
	icon.expand_mode      = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode     = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical   = Control.SIZE_SHRINK_CENTER

	# Label do nome
	var lbl_nome := Label.new()
	lbl_nome.name                    = "LabelNome"
	lbl_nome.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nome.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	lbl_nome.add_theme_font_size_override("font_size", 10)
	lbl_nome.add_theme_color_override("font_color", Color(0.6, 0.9, 0.85))
	lbl_nome.autowrap_mode           = TextServer.AUTOWRAP_WORD_SMART
	# Faz o texto do nome usar o espaço interno corretamente
	lbl_nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL 

	# Label de quantidade (canto inferior direito)
	var lbl_qtd := Label.new()
	lbl_qtd.name                  = "LabelQtd"
	lbl_qtd.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_qtd.vertical_alignment    = VERTICAL_ALIGNMENT_BOTTOM
	lbl_qtd.add_theme_font_size_override("font_size", 12)
	lbl_qtd.add_theme_color_override("font_color", Color(0.0, 1.0, 0.6))
	lbl_qtd.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)

	vbox.add_child(icon)
	vbox.add_child(lbl_nome)
	panel.add_child(vbox)
	panel.add_child(lbl_qtd)

	# Começa vazio e invisível
	_limpar_slot(panel)
	return panel

# ──────────────────────────────────────────────
#  Atualiza os 9 slots com os itens atuais
# ──────────────────────────────────────────────
func _atualizar_grid() -> void:
	# Limpa todos primeiro
	for slot in slots:
		_limpar_slot(slot)

	# Conta quantidades de cada item
	var contagem: Dictionary = {}
	for item in PlayerData.itens:
		contagem[item] = contagem.get(item, 0) + 1

	var idx := 0
	for nome_item in contagem.keys():
		if idx >= slots.size():
			break
		var qtd: int = contagem[nome_item]
		_preencher_slot(slots[idx], nome_item, qtd)
		idx += 1

func _limpar_slot(slot: PanelContainer) -> void:
	var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
	style.border_color = Color(0.15, 0.5, 0.55, 0.6)
	slot.add_theme_stylebox_override("panel", style)

	var icon: TextureRect = slot.find_child("Icone", true, false)
	if icon:
		icon.texture = null

	var lbl_nome: Label = slot.find_child("LabelNome", true, false)
	if lbl_nome:
		lbl_nome.text = ""

	var lbl_qtd: Label = slot.find_child("LabelQtd", true, false)
	if lbl_qtd:
		lbl_qtd.text = ""

func _preencher_slot(slot: PanelContainer, nome_item: String, qtd: int) -> void:
	# Borda cyan brilhante para slot preenchido
	var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
	style.border_color  = Color(0.25, 0.85, 0.8, 1.0)
	style.shadow_color  = Color(0.0, 1.0, 0.75, 0.4)
	style.shadow_size   = 6
	slot.add_theme_stylebox_override("panel", style)

	var info: Dictionary = ItemColetadoUI.ITEM_INFO.get(nome_item, {
		"nome_display": nome_item.capitalize().replace("_", " "),
		"icone": null
	})

	var icon: TextureRect = slot.find_child("Icone", true, false)
	if icon and info.get("icone") != null:
		icon.texture = info["icone"]

	var lbl_nome: Label = slot.find_child("LabelNome", true, false)
	if lbl_nome:
		lbl_nome.text = info.get("nome_display", nome_item)

	var lbl_qtd: Label = slot.find_child("LabelQtd", true, false)
	if lbl_qtd:
		lbl_qtd.text = "x%d" % qtd if qtd > 1 else ""

# ──────────────────────────────────────────────
#  Abre o inventário e destaca o slot do item recém-coletado
# ──────────────────────────────────────────────
func mostrar_com_destaque(nome_item: String) -> void:
	show()
	if not get_tree().paused:
		get_tree().paused = true
	_atualizar_grid()

	# Aguarda 1 frame para os slots existirem antes de destacar
	await get_tree().process_frame
	_destacar_item(nome_item)

func _destacar_item(nome_item: String) -> void:
	# Calcula a contagem para saber qual índice o item ocupa
	var contagem: Dictionary = {}
	for item in PlayerData.itens:
		contagem[item] = contagem.get(item, 0) + 1

	var idx := 0
	for nome in contagem.keys():
		if nome == nome_item:
			if idx < slots.size():
				_pulsar_slot(slots[idx])
			return
		idx += 1

func _pulsar_slot(slot: PanelContainer) -> void:
	# Pulso dourado 3x para chamar atenção
	var tw := create_tween()
	tw.set_loops(3)
	tw.tween_property(slot, "modulate", Color(1.6, 1.4, 0.4, 1.0), 0.18)
	tw.tween_property(slot, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

# ──────────────────────────────────────────────
#  SISTEMA DE SAÚDE — ECG
# ──────────────────────────────────────────────
func _get_estado_saude() -> int:
	if PlayerData.vida_total <= 0:
		return ESTADO_NORMAL
	var pct := float(PlayerData.vida) / float(PlayerData.vida_total)
	if pct > 0.60:
		return ESTADO_NORMAL
	elif pct > 0.30:
		return ESTADO_PERIGO
	else:
		return ESTADO_CRITICO

func _checar_estado_saude(forcar := false) -> void:
	var novo := _get_estado_saude()
	if novo == _estado_ecg and not forcar:
		return
	_estado_ecg = novo
	_aplicar_estado_ecg(novo)

func _aplicar_estado_ecg(estado: int) -> void:
	if not is_instance_valid(batimento):
		return
	var mat := batimento.material as ShaderMaterial
	if mat == null:
		return

	var p: Dictionary = ECG_ESTADOS[estado]

	# Valores atuais (com fallback para os defaults do shader)
	var cor_atual   = mat.get_shader_parameter("line_color")
	var speed_atual = mat.get_shader_parameter("speed")
	var cyc_atual   = mat.get_shader_parameter("cycles")
	var arrit_atual = mat.get_shader_parameter("arrhythmia")
	var glow_atual  = mat.get_shader_parameter("glow_spread")

	if cor_atual   == null: cor_atual   = Color(0.05, 1.0, 0.45, 1.0)
	if speed_atual == null: speed_atual = 0.55
	if cyc_atual   == null: cyc_atual   = 2.0
	if arrit_atual == null: arrit_atual = 0.0
	if glow_atual  == null: glow_atual  = 12.0

	if _tween_ecg:
		_tween_ecg.kill()
	_tween_ecg = create_tween().set_parallel(true)

	var dur_norm := 1.0
	var dur_ritm := 1.6

	_tween_ecg.tween_method(
		func(v): mat.set_shader_parameter("line_color", v),
		cor_atual, p["line_color"], dur_norm
	)
	_tween_ecg.tween_method(
		func(v): mat.set_shader_parameter("speed", v),
		speed_atual, p["speed"], dur_norm
	)
	_tween_ecg.tween_method(
		func(v): mat.set_shader_parameter("cycles", v),
		cyc_atual, p["cycles"], dur_norm
	)
	_tween_ecg.tween_method(
		func(v): mat.set_shader_parameter("arrhythmia", v),
		arrit_atual, p["arrhythmia"], dur_ritm
	)
	_tween_ecg.tween_method(
		func(v): mat.set_shader_parameter("glow_spread", v),
		glow_atual, p["glow_spread"], dur_norm
	)
