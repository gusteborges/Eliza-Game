## ============================================================
##  FERRAMENTA: Gerador de Módulos da Dungeon
##  Arquivo: scenes/dungeon/ferramentas/gerar_modulos.gd
## ============================================================
##
##  COMO USAR:
##  1. Abra o Godot Editor
##  2. Menu superior: Project → Tools → Execute EditorScript
##     OU: Crie um Node qualquer na cena, cole este script como @tool,
##     adicione um botão no Inspector (@export_tool_button no Godot 4.3+)
##     ou use o menu Tools → Execute EditorScript.
##
##  RESULTADO:
##  Cria automaticamente 68+ cenas .tscn em scenes/dungeon/modulos/
##  Cada cena terá:
##    • O mesh correto do Sewers.dae
##    • O script sala_base.gd
##    • 2 Marker3D padrão (NorthExit e SouthExit) para você ajustar depois
##
##  APÓS RODAR:
##  Abra cada cena criada e reposicione os Marker3D
##  nas bordas exatas das aberturas do corredor.
## ============================================================

@tool
extends EditorScript

# ── CAMINHOS ────────────────────────────────────────────────────────
const CAMINHO_DAE        := "res://assets/third_person_controller_assets/models/Sewer/Models/Sewers.dae"
const CAMINHO_SAIDA      := "res://scenes/dungeon/modulos/"
const CAMINHO_SCRIPT_BASE := "res://scenes/dungeon/sala_base.gd"

# ── CORREÇÃO DE ROTAÇÃO DA MALHA ─────────────────────────────────────
## Se as peças aparecerem deitadas/invertidas no Godot, ajuste aqui.
##
## Problema comum de importação de DAE/FBX do Blender:
##   • Blender usa Z=cima, Godot usa Y=cima
##   • Isso causa peças rotacionadas -90° no eixo X ao importar
##
## COMO DESCOBRIR O VALOR CORRETO:
##   1. Rode o script uma vez (valores zerados)
##   2. Abra uma cena gerada no Godot
##   3. Veja se o chão está no lugar certo
##      - Peças deitadas (chão virado para frente): CORRECAO_ROTACAO_X = -90.0
##      - Peças de cabeça para baixo            : CORRECAO_ROTACAO_X = 180.0
##      - Tudo certo                             : CORRECAO_ROTACAO_X = 0.0
const CORRECAO_ROTACAO_X := 0.0   ## graus — altere se as peças chegarem deitadas
const CORRECAO_ROTACAO_Y := 0.0   ## graus — altere se as peças chegarem giradas no eixo Y
const CORRECAO_ROTACAO_Z := 0.0   ## graus — raramente necessário

# ── MAPEAMENTO DE NOMES ─────────────────────────────────────────────
## Converte nomes técnicos do Blender para nomes legíveis em português.
## Formato: "nome_original" → "nome_novo"
const TABELA_NOMES := {
	# Corredor básico (sem decoração extra)
	"Serwers":        "corredor_basico_00",
	"Serwers_001":    "corredor_basico_01",
	"Serwers_002":    "corredor_basico_02",
	"Serwers_003":    "corredor_basico_03",
	"Serwers_004":    "corredor_basico_04",
	"Serwers_005":    "corredor_basico_05",
	"Serwers_006":    "corredor_basico_06",
	"Serwers_007":    "corredor_basico_07",
	"Serwers_008":    "corredor_basico_08",
	"Serwers_009":    "corredor_basico_09",
	"Serwers_010":    "corredor_basico_10",
	"Serwers_011":    "corredor_basico_11",
	"Serwers_012":    "corredor_basico_12",
	"Serwers_013":    "corredor_basico_13",
	"Serwers_014":    "corredor_basico_14",
	"Serwers_015":    "corredor_basico_15",

	# Corredor com tubos grandes (SerwersP)
	"SerwersP":       "corredor_tubos_00",
	"SerwersP_001":   "corredor_tubos_01",
	"SerwersP_002":   "corredor_tubos_02",
	"SerwersP_003":   "corredor_tubos_03",
	"SerwersP_004":   "corredor_tubos_04",
	"SerwersP_005":   "corredor_tubos_05",
	"SerwersP_006":   "corredor_tubos_06",
	"SerwersP_007":   "corredor_tubos_07",
	"SerwersP_008":   "corredor_tubos_08",
	"SerwersP_009":   "corredor_tubos_09",
	"SerwersP_010":   "corredor_tubos_10",
	"SerwersP_011":   "corredor_tubos_11",
	"SerwersP_012":   "corredor_tubos_12",
	"SerwersP_013":   "corredor_tubos_13",

	# Corredor com tubos tipo 1 (SerwersP1)
	"SerwersP1":      "corredor_tubos1_00",
	"SerwersP1_001":  "corredor_tubos1_01",
	"SerwersP1_002":  "corredor_tubos1_02",
	"SerwersP1_003":  "corredor_tubos1_03",
	"SerwersP1_004":  "corredor_tubos1_04",
	"SerwersP1_005":  "corredor_tubos1_05",
	"SerwersP1_006":  "corredor_tubos1_06",
	"SerwersP1_007":  "corredor_tubos1_07",
	"SerwersP1_008":  "corredor_tubos1_08",
	"SerwersP1_009":  "corredor_tubos1_09",
	"SerwersP1_010":  "corredor_tubos1_10",
	"SerwersP1_011":  "corredor_tubos1_11",
	"SerwersP1_012":  "corredor_tubos1_12",

	# Corredor variante 01 (Serwers01)
	"Serwers01":      "corredor_var1_00",
	"Serwers01_001":  "corredor_var1_01",
	"Serwers01_002":  "corredor_var1_02",
	"Serwers01_003":  "corredor_var1_03",
	"Serwers01_004":  "corredor_var1_04",
	"Serwers01_005":  "corredor_var1_05",
	"Serwers01_006":  "corredor_var1_06",
	"Serwers01_007":  "corredor_var1_07",
	"Serwers01_008":  "corredor_var1_08",
	"Serwers01_009":  "corredor_var1_09",
	"Serwers01_010":  "corredor_var1_10",
	"Serwers01_011":  "corredor_var1_11",

	# Corredor variante 02 (Serwers02)
	"Serwers02":      "corredor_var2_00",
	"Serwers02_001":  "corredor_var2_01",
	"Serwers02_002":  "corredor_var2_02",
	"Serwers02_003":  "corredor_var2_03",
	"Serwers02_004":  "corredor_var2_04",
	"Serwers02_005":  "corredor_var2_05",
	"Serwers02_006":  "corredor_var2_06",
	"Serwers02_007":  "corredor_var2_07",
	"Serwers02_008":  "corredor_var2_08",
	"Serwers02_009":  "corredor_var2_09",
	"Serwers02_010":  "corredor_var2_10",

	# Peças especiais
	"TB":       "juncao_t_invertida",
	"Cylinder": "pilar_central",
}

# ── EXECUÇÃO ─────────────────────────────────────────────────────────
func _run() -> void:
	print("\n[GerarModulos] ========================================")
	print("[GerarModulos] Iniciando geração de módulos da dungeon")
	print("[GerarModulos] ========================================\n")

	# Garante que a pasta de destino existe
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(CAMINHO_SAIDA)
	)

	# Carrega o DAE como PackedScene
	var dae : PackedScene = load(CAMINHO_DAE)
	if not dae:
		push_error("[GerarModulos] ERRO: Não foi possível carregar '%s'." % CAMINHO_DAE)
		return

	# Carrega o script base
	var script_base : Script = load(CAMINHO_SCRIPT_BASE)
	if not script_base:
		push_error("[GerarModulos] ERRO: Não foi possível carregar '%s'." % CAMINHO_SCRIPT_BASE)
		return

	# Instancia a cena completa do DAE
	var instancia_dae := dae.instantiate()
	var criadas  := 0
	var ignoradas := 0

	for filho in instancia_dae.get_children():
		var nome_original := filho.name

		# Verifica se está no mapeamento
		if nome_original not in TABELA_NOMES:
			ignoradas += 1
			continue

		var nome_novo : String = TABELA_NOMES[nome_original]
		var caminho_destino := CAMINHO_SAIDA + nome_novo + ".tscn"

		# Cria a raiz da nova cena como StaticBody3D
		var raiz := StaticBody3D.new()
		raiz.name = nome_novo
		raiz.set_script(script_base)

		# ── Clona o MeshInstance3D do filho ────────────────────────
		# IMPORTANTE: Preservamos a posição/rotação LOCAL do mesh
		# (relativa ao nó pai). NÃO zeramos porque isso causaria
		# desalinhamento. A raiz StaticBody3D começa em Transform3D.IDENTITY
		# (origem do mundo), e o mesh fica na posição correta dentro dela.
		var malha_fonte : MeshInstance3D = null
		if filho is MeshInstance3D:
			malha_fonte = filho as MeshInstance3D
		else:
			malha_fonte = _encontrar_mesh(filho)

		if malha_fonte:
			var malha : MeshInstance3D = malha_fonte.duplicate()
			malha.name = "Malha"
			# Zera só a posição (o mesh deve ficar centralizado no root)
			# mas MANTÉM a rotação local que veio do DAE.
			# Se as peças ficarem deitadas, ajuste CORRECAO_ROTACAO_X acima.
			malha.position = Vector3.ZERO
			malha.rotation_degrees = Vector3(
				malha.rotation_degrees.x + CORRECAO_ROTACAO_X,
				malha.rotation_degrees.y + CORRECAO_ROTACAO_Y,
				malha.rotation_degrees.z + CORRECAO_ROTACAO_Z
			)
			raiz.add_child(malha)
			malha.owner = raiz
		else:
			push_warning("[GerarModulos] Sem MeshInstance3D em '%s' — cena criada sem malha." % nome_original)

		# ── CollisionShape3D placeholder ───────────────────────────
		var col := CollisionShape3D.new()
		col.name = "Colisao"
		# NOTA: shape será adicionado manualmente no editor
		# Use Malha → selecionar → Mesh → "Criar Colisão Simplificada"
		raiz.add_child(col)
		col.owner = raiz

		# ── Contêiner de Saídas com Marker3Ds padrão ───────────────
		var saidas := Node3D.new()
		saidas.name = "Saidas"
		raiz.add_child(saidas)
		saidas.owner = raiz

		# 2 conectores padrão — ajuste as posições no editor!
		_adicionar_marker(saidas, raiz, "NorthExit", Vector3(0, 0, -4), 0.0)
		_adicionar_marker(saidas, raiz, "SouthExit", Vector3(0, 0,  4), PI)

		# ── Empacota e salva ────────────────────────────────────────
		var nova_cena := PackedScene.new()
		var erro_pack := nova_cena.pack(raiz)
		if erro_pack != OK:
			push_error("[GerarModulos] Erro ao empacotar '%s': %s" % [nome_novo, erro_pack])
			raiz.queue_free()
			continue

		var erro_save := ResourceSaver.save(nova_cena, caminho_destino)
		if erro_save == OK:
			print("[GerarModulos] ✔ %s → %s" % [nome_original.rpad(20), nome_novo])
			criadas += 1
		else:
			push_error("[GerarModulos] Erro ao salvar '%s': código %d" % [caminho_destino, erro_save])

		raiz.queue_free()

	instancia_dae.queue_free()

	print("\n[GerarModulos] ========================================")
	print("[GerarModulos] ✔ Concluído!")
	print("[GerarModulos]   Cenas criadas : %d" % criadas)
	print("[GerarModulos]   Nós ignorados : %d (decoração/props)" % ignoradas)
	print("[GerarModulos]   Destino       : %s" % CAMINHO_SAIDA)
	print("[GerarModulos] ========================================")
	print("\n⚠  PRÓXIMO PASSO OBRIGATÓRIO:")
	print("   Abra cada cena criada e:")
	print("   1. Selecione 'Malha' → menu Mesh → 'Criar Colisão Simplificada'")
	print("   2. Mova NorthExit e SouthExit para as bordas reais das aberturas")
	print("   3. Adicione EastExit / WestExit se a peça tiver mais saídas\n")

# ── AUXILIARES ───────────────────────────────────────────────────────

func _adicionar_marker(pai: Node3D, dono: Node, nome: String, pos: Vector3, rot_y: float) -> void:
	var m := Marker3D.new()
	m.name     = nome
	m.position = pos
	m.rotation = Vector3(0.0, rot_y, 0.0)
	pai.add_child(m)
	m.owner = dono

func _encontrar_mesh(no: Node) -> MeshInstance3D:
	if no is MeshInstance3D:
		return no as MeshInstance3D
	for filho in no.get_children():
		var resultado := _encontrar_mesh(filho)
		if resultado:
			return resultado
	return null
