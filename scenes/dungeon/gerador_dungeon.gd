## =====================================================================
##  GERADOR DE DUNGEON — Versão Procedural Pura
##  Arquivo: scenes/dungeon/gerador_dungeon.gd
## =====================================================================
##
##  COMO USAR:
##  1. Instancie dungeon.tscn na sua cena principal
##  2. Configure no Inspector:
##       • max_salas      → quantas salas gerar (ex: 20)
##       • semente        → 0 = aleatória, outro número = mapa fixo
##       • chance_desvio  → 0.0 a 1.0, probabilidade de virar esquerda/direita
##       • modulo_boss    → cena da sala boss (opcional)
##       • modulo_save    → cena da sala save (opcional)
##  3. O gerador descobre AUTOMATICAMENTE todos os .tscn da pasta modulos/
##
##  PARA ADICIONAR NOVAS PEÇAS:
##  Basta salvar um .tscn em scenes/dungeon/modulos/ — ele entra automaticamente.
## =====================================================================

extends Node3D

# ── CONFIGURAÇÃO NO INSPECTOR ─────────────────────────────────────────
@export_group("Geração")
@export var max_salas          : int   = 20
@export var semente            : int   = 0      ## 0 = aleatória a cada vez
@export var usar_semente_fixa  : bool  = false
@export var gerar_ao_iniciar   : bool  = true   ## gera automaticamente no _ready
@export var cena_jogador: PackedScene

@export_group("Teste")
## Quando preenchido, usa APENAS estes módulos (ignora auto-descoberta).
## Útil para testar o sistema com uma única sala antes de habilitar todas.
## Limpe o array para voltar ao modo automático com todos os módulos.
@export var modulos_manuais : Array[PackedScene] = []

@export_group("Variedade")
## Probabilidade de virar esquerda ou direita em vez de seguir em frente (0.0–1.0)
@export_range(0.0, 1.0) var chance_desvio := 0.35
## Probabilidade de escolher um módulo de outra família aleatoriamente
@export_range(0.0, 1.0) var chance_familia_aleatoria := 0.25

@export_group("Salas Especiais")
@export var modulo_boss   : PackedScene = null
@export var modulo_save   : PackedScene = null
@export var modulo_puzzle : PackedScene = null
@export_range(0.0, 1.0) var chance_save   := 0.12
@export_range(0.0, 1.0) var chance_puzzle := 0.08

# ── CAMINHOS ──────────────────────────────────────────────────────────
const PASTA_MODULOS := "res://scenes/dungeon/modulos/"
const SALA_INICIAL  := "res://scenes/dungeon/tipos/sala_inicial.tscn"

# ── ESTADO INTERNO ────────────────────────────────────────────────────
var _rng     := RandomNumberGenerator.new()
var _salas   : Array[Node3D]      = []
var _modulos : Array[PackedScene] = []
var _aabbs_ocupados : Array[AABB] = []

## Grupo que identifica as salas GERADAS proceduralmente.
## _limpar() apaga apenas nós deste grupo — player, luzes e ambiente são preservados.
const GRUPO_SALAS := "dungeon_sala"

## Famílias de módulos — carregadas automaticamente por prefixo do nome do arquivo
var _familias : Dictionary = {
	"basico":  [],
	"tubos":   [],
	"tubos1":  [],
	"var1":    [],
	"var2":    [],
	"especial": [],
}

# ── INICIALIZAÇÃO ─────────────────────────────────────────────────────
func _ready() -> void:
	_descobrir_modulos()
	if gerar_ao_iniciar:
		gerar()
		_spawnar_jogador()
		
func _spawnar_jogador() -> void:
	var ponto_spawn := obter_ponto_spawn()

	# Caso 1: player já está na cena (instanciado diretamente no dungeon.tscn)
	var player_existente := get_node_or_null("Player")
	if player_existente:
		player_existente.global_position = ponto_spawn
		print("[Dungeon] Player reposicionado em: %s" % str(ponto_spawn))
		return

	# Caso 2: spawna via cena_jogador (configurado no Inspector)
	if cena_jogador:
		var jogador = cena_jogador.instantiate()
		add_child(jogador)
		jogador.global_position = ponto_spawn
		print("[Dungeon] Player instanciado em: %s" % str(ponto_spawn))

func _descobrir_modulos() -> void:
	_modulos.clear()
	for lista in _familias.values():
		lista.clear()

	# ── Modo manual: usa apenas os módulos definidos no Inspector ─────────
	if not modulos_manuais.is_empty():
		_modulos = modulos_manuais.duplicate()
		# Coloca tudo em "basico" para o seletor de família funcionar
		(_familias["basico"] as Array).append_array(_modulos)
		print("[Dungeon] Modo TESTE — usando %d módulo(s) manuais." % _modulos.size())
		return

	# ── Modo automático: descobre todos os .tscn da pasta ─────────────────
	var dir := DirAccess.open(PASTA_MODULOS)
	if not dir:
		push_error("[Dungeon] Pasta de módulos não encontrada: " + PASTA_MODULOS)
		return

	dir.list_dir_begin()
	var arquivo := dir.get_next()

	while arquivo != "":
		if arquivo.ends_with(".tscn"):
			var caminho := PASTA_MODULOS + arquivo
			var cena    := load(caminho) as PackedScene
			if cena:
				_modulos.append(cena)
				# Classifica por família usando flag — GDScript não suporta for...else
				var encontrou := false
				for prefixo in _familias.keys():
					if arquivo.begins_with("corredor_" + prefixo) \
					or arquivo.begins_with(prefixo):
						(_familias[prefixo] as Array).append(cena)
						encontrou = true
						break
				if not encontrou:
					# Não se encaixou em nenhuma família → vai para especial
					(_familias["especial"] as Array).append(cena)
		arquivo = dir.get_next()
	dir.list_dir_end()

	# Monta resumo das famílias — dict comprehension não é suportado no GDScript
	var info := ""
	for k in _familias.keys():
		info += "%s:%d " % [k, (_familias[k] as Array).size()]
	print("[Dungeon] Módulos carregados: %d | Famílias: %s" % [_modulos.size(), info.strip_edges()])

# ── GERAÇÃO PRINCIPAL ─────────────────────────────────────────────────
func gerar() -> void:
	_limpar()

	if usar_semente_fixa:
		_rng.seed = semente
	else:
		_rng.randomize()
		semente = _rng.seed
	print("[Dungeon] Gerando com semente: %d" % semente)

	if _modulos.is_empty():
		push_error("[Dungeon] Nenhum módulo encontrado em: " + PASTA_MODULOS)
		return

	# ── Sala inicial ──────────────────────────────────────────────────
	var cena_inicial := load(SALA_INICIAL) as PackedScene
	if not cena_inicial:
		push_error("[Dungeon] sala_inicial.tscn não encontrada: " + SALA_INICIAL)
		return

	var sala_atual := _instanciar(cena_inicial, Transform3D.IDENTITY)
	if not sala_atual:
		return
	
	# Adiciona o AABB da sala inicial
	# Forçamos uma atualização de frame para garantir que os nós estejam na árvore e os transforms globais calculados
	await get_tree().process_frame
	_aabbs_ocupados.append(_obter_aabb_global(sala_atual))

	# Escolhe uma família para o bloco inicial e vai trocando ao longo da dungeon
	var familia_atual := _familia_aleatoria()

	# ── Cadeia principal ──────────────────────────────────────────────
	var count_salas := 0
	var tentativas_falhas := 0
	
	while count_salas < max_salas - 1:
		if tentativas_falhas > 50:
			print("[Dungeon] Limite de colisões atingido. Abortando ramificações.")
			break

		# Troca de família eventualmente (variedade visual)
		if _rng.randf() < chance_familia_aleatoria:
			familia_atual = _familia_aleatoria()

		# Escolhe a cena para próxima sala
		var prox_cena := _escolher_modulo(familia_atual)

		# Pega o conector de saída da sala atual
		var conector_saida := _conector_livre(sala_atual)
		if not conector_saida:
			# Sem saída — escolhe outra sala já colocada e continua dela
			var outra := _sala_com_saida_livre()
			if not outra:
				print("[Dungeon] Sem saídas disponíveis após %d salas." % _salas.size())
				break
			sala_atual = outra
			conector_saida = _conector_livre(sala_atual)

		# Calcula o transform de alinhamento e instancia
		var resultado      := _calcular_transform(conector_saida, prox_cena)
		var novo_transform := resultado[0] as Transform3D
		var nome_entrada   := resultado[1] as String
		var nova_sala      := _instanciar(prox_cena, novo_transform)

		if nova_sala:
			# Atualiza transform global forçadamente para cálculo do AABB
			var aabb_nova = _obter_aabb_global(nova_sala)
			
			var colidiu := false
			for aabb_ocupado in _aabbs_ocupados:
				if aabb_ocupado.intersects(aabb_nova):
					colidiu = true
					break
			
			if colidiu:
				nova_sala.queue_free()
				_salas.erase(nova_sala)
				conector_saida.set_meta("usado", true) # Beco sem saída forçado
				tentativas_falhas += 1
				continue

			# Sucesso — consolida a sala
			_aabbs_ocupados.append(aabb_nova)
			conector_saida.set_meta("usado", true)
			
			if not nome_entrada.is_empty():
				var saidas_nova := nova_sala.get_node_or_null("Saidas")
				if saidas_nova:
					var m := saidas_nova.get_node_or_null(nome_entrada) as Marker3D
					if m:
						m.set_meta("usado", true)
			
			sala_atual = nova_sala
			count_salas += 1
			tentativas_falhas = 0

	# ── Sala Boss no beco mais profundo ──────────────────────────────
	if modulo_boss:
		var ultima_com_saida := _sala_com_saida_livre()
		if ultima_com_saida:
			var saida_boss := _conector_livre(ultima_com_saida)
			if saida_boss:
				var resultado_boss := _calcular_transform(saida_boss, modulo_boss)
				var boss_sala := _instanciar(modulo_boss, resultado_boss[0] as Transform3D)
				if boss_sala:
					var aabb_boss = _obter_aabb_global(boss_sala)
					var colidiu := false
					for aabb_ocupado in _aabbs_ocupados:
						if aabb_ocupado.intersects(aabb_boss):
							colidiu = true
							break
					if colidiu:
						boss_sala.queue_free()
						_salas.erase(boss_sala)
					else:
						_aabbs_ocupados.append(aabb_boss)
						saida_boss.set_meta("usado", true)

	print("[Dungeon] ✔ Dungeon gerada: %d salas | Semente: %d" % [_salas.size(), semente])

# ── LÓGICA DE ALINHAMENTO ─────────────────────────────────────────────

func _calcular_transform(conector_saida: Marker3D, prox_cena: PackedScene) -> Array:
	## Alinha o primeiro conector disponível da nova sala ao conector de saída.
	## Retorna [Transform3D, String] onde String é o nome do conector de ENTRADA usado.
	##
	## IMPORTANTE: O chamador deve marcar o conector de entrada retornado como "usado"
	## para evitar que o gerador o reutilize como saída na iteração seguinte.
	## (Este era o bug que colocava todas as salas no mesmo lugar.)

	# Instancia temporariamente para ler os conectores
	var temp := prox_cena.instantiate() as Node3D
	if not temp:
		return [Transform3D.IDENTITY, ""]
	add_child(temp)
	temp.global_transform = Transform3D.IDENTITY

	var entrada := _primeiro_conector(temp)

	if not entrada:
		# Sem conector — avança 8 unidades na direção de saída
		temp.queue_free()
		var direcao_saida := -conector_saida.global_transform.basis.z.normalized()
		return [Transform3D(Basis.IDENTITY, conector_saida.global_position + direcao_saida * 8.0), ""]

	# Nome do conector de entrada (para marcar como usado após instanciar)
	var nome_entrada : String = entrada.name

	# Posição e Rotação LOCAL do conector de entrada dentro da nova sala
	var pos_entrada_local := entrada.position
	var base_entrada_local := entrada.basis

	# Rotação: A saída global * giro de 180° * inverso da rotação da entrada
	# Isso garante que independentemente de ser um EastExit ou SouthExit, ele vai se alinhar perfeitamente
	var nova_base := conector_saida.global_transform.basis * Basis(Vector3.UP, PI) * base_entrada_local.inverse()

	# Posição: desloca a sala para que o conector de entrada coincida com o de saída
	var nova_pos := conector_saida.global_position - nova_base * pos_entrada_local

	temp.queue_free()
	return [Transform3D(nova_base, nova_pos), nome_entrada]

# ── AUXILIARES ────────────────────────────────────────────────────────

func _instanciar(cena: PackedScene, transform: Transform3D) -> Node3D:
	var no := cena.instantiate() as Node3D
	if not no:
		push_warning("[Dungeon] Falha ao instanciar cena.")
		return null
	add_child(no)
	no.global_transform = transform
	# Marca como sala gerada — permite que _limpar() apague APENAS salas,
	# sem afetar Player, luzes ou WorldEnvironment que estejam na cena.
	no.add_to_group(GRUPO_SALAS)
	_salas.append(no)
	return no

func _conector_livre(sala: Node3D) -> Marker3D:
	## Retorna o primeiro Marker3D ainda não marcado como "usado" dentro de Saidas.
	var saidas := sala.get_node_or_null("Saidas")
	if not saidas:
		return null
	for filho in saidas.get_children():
		if filho is Marker3D and not filho.get_meta("usado", false):
			return filho as Marker3D
	return null

func _primeiro_conector(sala: Node3D) -> Marker3D:
	## Retorna qualquer Marker3D de Saidas (para cálculo de alinhamento).
	var saidas := sala.get_node_or_null("Saidas")
	if not saidas:
		return null
	for filho in saidas.get_children():
		if filho is Marker3D:
			return filho as Marker3D
	return null

func _sala_com_saida_livre() -> Node3D:
	## Retorna a última sala da lista que ainda tem conectores livres.
	var i := _salas.size() - 1
	while i >= 0:
		if _conector_livre(_salas[i]):
			return _salas[i]
		i -= 1
	return null

func _obter_aabb_global(sala: Node3D) -> AABB:
	## Calcula a caixa delimitadora da sala inteira no espaço global
	var aabb := AABB()
	var primeiro := true
	var fila := [sala]
	
	while not fila.is_empty():
		var no = fila.pop_front()
		if no is MeshInstance3D:
			var local_aabb = no.get_aabb()
			# Transformamos o AABB local pela posição global da malha
			var global_transform = no.global_transform
			var box_global = global_transform * local_aabb
			if primeiro:
				aabb = box_global
				primeiro = false
			else:
				aabb = aabb.merge(box_global)
		fila.append_array(no.get_children())
		
	# Se a sala não tem malha, cria um volume pequeno no centro
	if primeiro:
		aabb = AABB(sala.global_position - Vector3(1,1,1), Vector3(2,2,2))
	else:
		# Reduz um pouco as margens da caixa para não colidir com paredes adjacentes
		var margem := 0.25
		aabb.position += Vector3(margem, margem, margem)
		aabb.size -= Vector3(margem*2, margem*2, margem*2)
		
	return aabb

func _escolher_modulo(familia: String) -> PackedScene:
	## Escolhe um módulo da família especificada, com chance de sala especial.
	var chance := _rng.randf()
	if modulo_save and chance < chance_save:
		return modulo_save
	if modulo_puzzle and chance < chance_save + chance_puzzle:
		return modulo_puzzle

	var lista := _familias.get(familia, []) as Array
	if lista.is_empty():
		lista = _modulos
	return lista[_rng.randi() % lista.size()] as PackedScene

func _familia_aleatoria() -> String:
	var chaves := _familias.keys()
	# Evita escolher "especial" como família principal
	var principais := chaves.filter(func(k): return k != "especial")
	if principais.is_empty():
		return "basico"
	return principais[_rng.randi() % principais.size()]

func _limpar() -> void:
	## Remove APENAS as salas geradas (grupo "dungeon_sala").
	## Player, luzes e WorldEnvironment são preservados.
	for filho in get_children():
		if filho.is_in_group(GRUPO_SALAS):
			filho.queue_free()
	_salas.clear()
	_aabbs_ocupados.clear()

# ── API PÚBLICA ───────────────────────────────────────────────────────

## Regera com nova semente aleatória
func regerar() -> void:
	usar_semente_fixa = false
	gerar()

## Regera com a mesma semente (mesmo mapa)
func regerar_mesma_semente() -> void:
	usar_semente_fixa = true
	gerar()

## Retorna a posição do PontoSpawnJogador da sala inicial
func obter_ponto_spawn() -> Vector3:
	if _salas.is_empty():
		return Vector3.ZERO
	var spawn := _salas[0].get_node_or_null("PontoSpawnJogador") as Marker3D
	return spawn.global_position if spawn else _salas[0].global_position
