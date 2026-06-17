## =====================================================================
##  FERRAMENTA: Estima e atualiza posição dos Marker3Ds de todas as salas
##  Arquivo: scenes/dungeon/ferramentas/estimar_conectores.gd
## =====================================================================
##
##  COMO USAR:
##  1. Menu superior: Project → Tools → Execute EditorScript
##  2. Selecione este arquivo e clique Execute
##
##  O QUE FAZ:
##  Percorre todos os .tscn em scenes/dungeon/modulos/
##  Para cada sala, encontra o MeshInstance3D e estima onde ficam as
##  aberturas usando o AABB (bounding box) da malha.
##  Atualiza NorthExit e SouthExit para as bordas real do mesh.
##
##  RESULTADO:
##  As salas serão conectadas visualmente sem gaps entre elas.
##  Crie ColisaoShape3D logo após (Malha → Mesh → Criar Colisão Simplificada).
## =====================================================================

@tool
extends EditorScript

const PASTA_MODULOS := "res://scenes/dungeon/modulos/"

func _run() -> void:
	print("\n[EstimarConectores] Iniciando estimativa de conectores...\n")

	var dir := DirAccess.open(PASTA_MODULOS)
	if not dir:
		push_error("Pasta não encontrada: " + PASTA_MODULOS)
		return

	var atualizadas := 0
	var erros       := 0

	dir.list_dir_begin()
	var arquivo := dir.get_next()

	while arquivo != "":
		if arquivo.ends_with(".tscn"):
			var caminho := PASTA_MODULOS + arquivo
			if _atualizar_conectores(caminho):
				atualizadas += 1
			else:
				erros += 1
		arquivo = dir.get_next()
	dir.list_dir_end()

	print("\n[EstimarConectores] ========================================")
	print("[EstimarConectores] ✔ Concluído!")
	print("[EstimarConectores]   Salas atualizadas : %d" % atualizadas)
	print("[EstimarConectores]   Erros             : %d" % erros)
	print("[EstimarConectores] ========================================\n")
	print("PRÓXIMO PASSO: Para cada sala, selecione 'Malha' → Mesh → 'Criar Colisão Simplificada'\n")

func _atualizar_conectores(caminho: String) -> bool:
	# Carrega e instancia a cena
	var cena := load(caminho) as PackedScene
	if not cena:
		push_error("Não foi possível carregar: " + caminho)
		return false

	var instancia := cena.instantiate() as Node3D
	if not instancia:
		push_error("Falha ao instanciar: " + caminho)
		return false

	# Encontra o MeshInstance3D
	var malha := instancia.get_node_or_null("Malha") as MeshInstance3D
	if not malha or not malha.mesh:
		push_warning("[EstimarConectores] Sem malha em: " + caminho)
		instancia.queue_free()
		return false

	# Obtém o AABB da malha (bounding box local)
	var aabb : AABB = malha.mesh.get_aabb()
	# Aplica a transform local da malha para obter AABB no espaço do root
	var aabb_global := malha.transform * aabb

	# Centro da malha
	var centro := aabb_global.get_center()

	# Determina a direção principal da malha (maior dimensão = eixo do corredor)
	var tamanho := aabb_global.size
	var eixo_corredor : int   # 0=X, 1=Y, 2=Z
	var tamanho_max := maxf(tamanho.x, maxf(tamanho.y, tamanho.z))

	if tamanho.z >= tamanho.x and tamanho.z >= tamanho.y:
		eixo_corredor = 2  # Z é o eixo principal
	elif tamanho.x >= tamanho.y:
		eixo_corredor = 0  # X é o eixo principal
	else:
		eixo_corredor = 1  # Y é o eixo principal

	# Posições das aberturas (nas extremidades do eixo principal)
	var pos_north : Vector3
	var pos_south : Vector3

	# Altura da abertura: sempre no centro Y do AABB (meio da parede)
	var altura_abertura := centro.y

	match eixo_corredor:
		0:  # corredor no eixo X
			pos_north = Vector3(aabb_global.position.x, altura_abertura, centro.z)
			pos_south = Vector3(aabb_global.end.x,      altura_abertura, centro.z)
		1:  # corredor no eixo Y (improvável mas tratamos)
			pos_north = Vector3(centro.x, aabb_global.position.y, centro.z)
			pos_south = Vector3(centro.x, aabb_global.end.y,      centro.z)
		2:  # corredor no eixo Z (mais comum após importação)
			pos_north = Vector3(centro.x, altura_abertura, aabb_global.position.z)
			pos_south = Vector3(centro.x, altura_abertura, aabb_global.end.z)

	# Encontra o nó Saidas
	var saidas := instancia.get_node_or_null("Saidas")
	if not saidas:
		push_warning("[EstimarConectores] Sem nó 'Saidas' em: " + caminho)
		instancia.queue_free()
		return false

	# Atualiza os Marker3Ds
	var north := saidas.get_node_or_null("NorthExit") as Marker3D
	var south := saidas.get_node_or_null("SouthExit") as Marker3D

	var modificado := false

	if north:
		north.position = pos_north
		# NorthExit aponta para fora no -Z (rotação Y = 0)
		north.rotation = Vector3.ZERO
		modificado = true

	if south:
		south.position = pos_south
		# SouthExit aponta para fora no +Z (rotação Y = 180°)
		south.rotation = Vector3(0.0, PI, 0.0)
		modificado = true

	if not modificado:
		instancia.queue_free()
		return false

	# Salva a cena atualizada
	var nova_cena := PackedScene.new()
	nova_cena.pack(instancia)
	var erro := ResourceSaver.save(nova_cena, caminho)

	instancia.queue_free()

	if erro == OK:
		print("[EstimarConectores] ✔ %-40s N=%s S=%s" % [
			caminho.get_file(),
			"(%.1f,%.1f,%.1f)" % [pos_north.x, pos_north.y, pos_north.z],
			"(%.1f,%.1f,%.1f)" % [pos_south.x, pos_south.y, pos_south.z]
		])
		return true
	else:
		push_error("[EstimarConectores] Erro ao salvar: " + caminho)
		return false
