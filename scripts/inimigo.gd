extends CharacterBody3D

# ── ESTADOS ─────────────────────────────────────────────────────────
enum Estado { IDLE, PERSEGUIR, ATACAR }
var _estado_atual := Estado.IDLE

# ── CONFIGURAÇÃO — editável no Inspector ─────────────────────────────
@export_group("Movimento")
@export var velocidade     := 2.5    ## Velocidade de perseguição em m/s
@export var dist_perseguir := 10.0   ## Distância horizontal para começar a perseguir
@export var dist_ataque    := 1.6    ## Distância horizontal para executar o ataque

@export_group("Combate")
@export var dano_kick       := 20    ## Dano causado por cada kick bem-sucedido
@export var cooldown_ataque := 1.8   ## Segundos de espera entre ataques

@export_group("Referências")
## Caminho para o AnimationPlayer dentro do modelo 3D.
## Para descobrir: abra inimigo.tscn → expanda mixamo_base → copie o caminho.
@export var anim_player_path : NodePath = NodePath("mixamo_base/AnimationPlayer")

@export_group("Animações — nomes exatos conforme o GLB")
## Os nomes exatos aparecem no console ao rodar o jogo (ver diagnóstico abaixo).
@export var anim_idle     := "idle"
@export var anim_caminhar := "walking"
@export var anim_kick     := "kick"

# ── CONSTANTES INTERNAS ──────────────────────────────────────────────
## Gravidade como constante evita chamar ProjectSettings a cada frame
const GRAVIDADE          := 9.8
## Tempo máximo preso no estado ATACANDO antes do reset de segurança
## Corrige o bug silencioso: animação de kick inexistente → _atacando preso em true forever
const TIMEOUT_ATAQUE_MAX := 3.5

# ── VARIÁVEIS DE CONTROLE ────────────────────────────────────────────
var _player       : Node3D          = null
var _anim_player  : AnimationPlayer = null
var _timer_kick   := 0.0   # regressivo — cooldown entre ataques
var _atacando     := false  # verdadeiro enquanto a animação de kick está tocando
var _kick_aplicou := false  # garante no máximo 1 dano por animação de kick
var _timeout_ataque := 0.0  # contador de segurança contra deadlock no estado de ataque

# ===================================================================
#  INICIALIZAÇÃO
# ===================================================================

func _ready() -> void:
	_inicializar_referencias()
	_garantir_formas_de_colisao()
	_conectar_sinais()
	_diagnosticar_animacoes()
	_tocar_anim(anim_idle)

func _inicializar_referencias() -> void:
	# Localiza o player pelo grupo — certifique-se de que o nó Player
	# está registrado no grupo "player" (Nó → Grupos → adicionar "player")
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		push_error("[Inimigo] Player não encontrado! "
				+ "Selecione o nó Player → aba Nó → Grupos → adicione 'player'.")

	# Localiza o AnimationPlayer dentro do modelo 3D
	_anim_player = get_node_or_null(anim_player_path)
	if not _anim_player:
		push_error("[Inimigo] AnimationPlayer não encontrado em '%s'. "
				+ "Ajuste o campo 'Anim Player Path' no Inspector." % str(anim_player_path))

func _garantir_formas_de_colisao() -> void:
	# ─────────────────────────────────────────────────────────────────
	# Bug silencioso corrigido:
	# CollisionShape3D sem shape → inimigo sem colisão → cai pelo chão
	# e desaparece sem qualquer mensagem de erro visível.
	# ─────────────────────────────────────────────────────────────────

	# Colisão do corpo
	var col_corpo := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_corpo and col_corpo.shape == null:
		var capsula        := CapsuleShape3D.new()
		capsula.radius     = 0.35
		capsula.height     = 1.75
		col_corpo.shape    = capsula
		col_corpo.position.y = capsula.height * 0.5  # pés no chão
		push_warning("[Inimigo] CollisionShape3D do corpo estava vazio — "
				+ "cápsula criada automaticamente. Configure no editor para resultados mais precisos.")

	# Colisão da hitbox de ataque
	var col_hitbox := get_node_or_null("Area3D/CollisionShape3D") as CollisionShape3D
	if col_hitbox and col_hitbox.shape == null:
		var esfera       := SphereShape3D.new()
		esfera.radius    = dist_ataque   # raio da hitbox igual ao alcance configurado
		col_hitbox.shape = esfera
		push_warning("[Inimigo] CollisionShape3D da Area3D estava vazio — "
				+ "esfera criada automaticamente.")

func _conectar_sinais() -> void:
	# Conecta via código para não depender do painel de sinais do editor
	if _anim_player and not _anim_player.animation_finished.is_connected(_ao_terminar_animacao):
		_anim_player.animation_finished.connect(_ao_terminar_animacao)

	var area := get_node_or_null("Area3D") as Area3D
	if area and not area.body_entered.is_connected(_ao_entrar_hitbox):
		area.body_entered.connect(_ao_entrar_hitbox)

func _diagnosticar_animacoes() -> void:
	# ─────────────────────────────────────────────────────────────────
	# Lista TODAS as animações do modelo no console.
	# Muito útil para descobrir o nome exato quando as animações
	# não disparam (ex.: "Kick" vs "kick" vs "mixamo_base|kick").
	# ─────────────────────────────────────────────────────────────────
	if not _anim_player:
		return

	print("[Inimigo] === Animações disponíveis no modelo ===")
	for nome_lib in _anim_player.get_animation_library_list():
		var lib := _anim_player.get_animation_library(nome_lib)
		for nome_anim in lib.get_animation_list():
			var nome_completo: String = (str(nome_lib) + "/" + str(nome_anim)) if str(nome_lib) != "" else str(nome_anim)
			print("  · '%s'" % nome_completo)
	print("[Inimigo] =========================================")

	# Alerta imediato sobre nomes errados, sem precisar chegar até o estado ATACAR
	var verificacoes := [
		["idle",     anim_idle],
		["caminhar", anim_caminhar],
		["kick",     anim_kick],
	]
	for par in verificacoes:
		if not _anim_player.has_animation(par[1]):
			push_error("[Inimigo] Animação de '%s' ('%s') NÃO existe. "
					+ "Corrija o campo no Inspector → Animações." % par)

# ===================================================================
#  LOOP PRINCIPAL
# ===================================================================

func _physics_process(delta: float) -> void:
	if not _player:
		return

	_aplicar_gravidade(delta)
	_atualizar_contadores(delta)

	# Usa distância HORIZONTAL para evitar bugs em ambientes com desníveis de chão
	var dist := _distancia_horizontal_ao_player()

	match _estado_atual:
		Estado.IDLE:      _estado_idle(dist)
		Estado.PERSEGUIR: _estado_perseguir(dist)
		Estado.ATACAR:    _estado_atacar(dist)

	move_and_slide()

func _aplicar_gravidade(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta

func _atualizar_contadores(delta: float) -> void:
	# Regride o cooldown de ataque
	if _timer_kick > 0.0:
		_timer_kick -= delta

	# ─────────────────────────────────────────────────────────────────
	# Proteção contra deadlock:
	# Se _atacando ficar preso em true (ex.: animação de kick com nome
	# errado nunca dispara animation_finished), o inimigo travaria para
	# sempre sem atacar nem perseguir. O timeout reseta o estado.
	# ─────────────────────────────────────────────────────────────────
	if _atacando:
		_timeout_ataque += delta
		if _timeout_ataque >= TIMEOUT_ATAQUE_MAX:
			push_warning("[Inimigo] Timeout de ataque! O estado '_atacando' foi resetado. "
					+ "Verifique se a animação '%s' existe e tem o nome correto." % anim_kick)
			_atacando       = false
			_timeout_ataque = 0.0
	else:
		_timeout_ataque = 0.0

# ===================================================================
#  MÁQUINA DE ESTADOS
# ===================================================================

func _estado_idle(dist: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_tocar_anim(anim_idle)

	if dist <= dist_perseguir:
		_mudar_estado(Estado.PERSEGUIR)

func _estado_perseguir(dist: float) -> void:
	# Player saiu do raio de detecção
	if dist > dist_perseguir:
		_mudar_estado(Estado.IDLE)
		return

	# Chegou perto o suficiente para atacar
	if dist <= dist_ataque:
		_mudar_estado(Estado.ATACAR)
		return

	var direcao := _direcao_horizontal_ao_player()
	velocity.x = direcao.x * velocidade
	velocity.z = direcao.z * velocidade

	_olhar_para_player()
	_tocar_anim(anim_caminhar)

func _estado_atacar(dist: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0

	# A animação de kick está em andamento — aguarda ela terminar
	if _atacando:
		_olhar_para_player()  # continua mirando durante o ataque
		return

	# Player fugiu — margem de 1.5× evita oscilação entre ATACAR e PERSEGUIR
	if dist > dist_ataque * 1.5:
		_mudar_estado(Estado.PERSEGUIR)
		return

	# Player ainda próximo e cooldown zerado — ataca!
	_olhar_para_player()
	if _timer_kick <= 0.0:
		_executar_kick()

# ===================================================================
#  SISTEMA DE COMBATE
# ===================================================================

func _executar_kick() -> void:
	# ─────────────────────────────────────────────────────────────────
	# Bug silencioso corrigido:
	# Antes, _atacando era setado como true ANTES de verificar se a
	# animação existe. Se o nome estivesse errado, animation_finished
	# nunca disparava → _atacando ficava true para sempre → IA travada.
	# ─────────────────────────────────────────────────────────────────
	if _anim_player and not _anim_player.has_animation(anim_kick):
		push_error("[Inimigo] Animação de kick '%s' não encontrada! "
				+ "Ajuste o nome no Inspector. Aplicando dano sem animação como fallback." % anim_kick)
		# Fallback: aplica o dano direto sem travar a IA
		_kick_aplicou  = false
		_timer_kick    = cooldown_ataque
		_checar_dano_com_direcao()
		return

	_atacando       = true
	_kick_aplicou   = false
	_timer_kick     = cooldown_ataque
	_timeout_ataque = 0.0
	_tocar_anim(anim_kick)
	print("[Inimigo] ► Kick disparado!")

# Chamado quando um corpo entra na Area3D durante um ataque
func _ao_entrar_hitbox(corpo: Node3D) -> void:
	if corpo == _player and _atacando and not _kick_aplicou:
		_checar_dano_com_direcao()

# Chamado quando qualquer animação termina
func _ao_terminar_animacao(nome_anim: String) -> void:
	if nome_anim != anim_kick:
		return

	# Aplica dano se o corpo a corpo foi válido mas o sinal da hitbox não disparou
	if not _kick_aplicou:
		_checar_dano_com_direcao()

	_atacando       = false
	_timeout_ataque = 0.0
	_tocar_anim(anim_idle)

# Verifica distância horizontal E alinhamento antes de registrar o dano.
# Impede dano "de costas" mesmo se o player estiver no raio da Area3D.
func _checar_dano_com_direcao() -> void:
	if _kick_aplicou:
		return

	# 1. Distância horizontal (ignora diferença de altura)
	var dist := _distancia_horizontal_ao_player()
	if dist > dist_ataque * 1.2:
		print("[Inimigo] Kick falhou — player longe (%.1fm)" % dist)
		return

	# 2. Alinhamento direcional
	#    Após rotate_y(PI), o eixo +Z local aponta para o player.
	#    Produto escalar: 1.0 = frente a frente | 0.0 = 90° | -1.0 = costas
	var dir_ao_player := _direcao_horizontal_ao_player()
	var frente        := global_transform.basis.z.normalized()
	var alinhamento   := frente.dot(dir_ao_player)

	if alinhamento < 0.5:   # aceita desvio de até ~60°
		print("[Inimigo] Kick falhou — não estava de frente (alinhamento: %.2f)" % alinhamento)
		return

	_aplicar_dano()

func _aplicar_dano() -> void:
	if _kick_aplicou:
		return
	_kick_aplicou = true

	# maxi() é a versão com tipo explícito (int) — mais segura que max() genérico
	PlayerData.vida = maxi(0, PlayerData.vida - dano_kick)

	print("[Inimigo] ✔ Kick acertou! Dano: %d | Vida do player: %d/%d" % [
		dano_kick,
		PlayerData.vida,
		PlayerData.vida_total,
	])

	# Ponto de expansão:
	# if PlayerData.vida <= 0:
	#     EventoBus.emit_signal("player_morreu")

# ===================================================================
#  UTILITÁRIOS
# ===================================================================

func _mudar_estado(novo: Estado) -> void:
	if _estado_atual == novo:
		return
	print("[Inimigo] Estado: %s → %s" % [Estado.keys()[_estado_atual], Estado.keys()[novo]])
	_estado_atual = novo

func _tocar_anim(nome: String) -> void:
	if not _anim_player:
		return
	if _anim_player.current_animation == nome:
		return
	if _anim_player.has_animation(nome):
		_anim_player.play(nome)
	else:
		push_warning("[Inimigo] Animação '%s' não encontrada. "
				+ "Verifique o nome no Inspector → Animações." % nome)

func _distancia_horizontal_ao_player() -> float:
	# Usa Vector2 (X e Z) para ignorar diferença de altitude.
	# Evita bugs onde a IA para de atacar em ambientes com desníveis de chão.
	var pos_minha  := Vector2(global_position.x, global_position.z)
	var pos_player := Vector2(_player.global_position.x, _player.global_position.z)
	return pos_minha.distance_to(pos_player)

func _direcao_horizontal_ao_player() -> Vector3:
	var dir := _player.global_position - global_position
	dir.y = 0.0
	# Proteção contra divisão por zero quando player e inimigo estão na mesma posição
	if dir.is_zero_approx():
		return Vector3.ZERO
	return dir.normalized()

func _olhar_para_player() -> void:
	var alvo := Vector3(
		_player.global_position.x,
		global_position.y,
		_player.global_position.z
	)
	# Proteção: look_at() gera erro se o alvo for igual à posição atual
	if alvo.is_equal_approx(global_position):
		return

	look_at(alvo, Vector3.UP)

	# Modelos Mixamo têm o "rosto" no eixo +Z.
	# look_at() aponta o eixo -Z para o alvo → modelo fica de costas.
	# O rotate_y(PI) corrige: gira 180° para que +Z (rosto) fique de frente.
	rotate_y(PI)

# ===================================================================
#  PONTO DE EXPANSÃO — Estrutura para vida, morte e patrulha
# ===================================================================
#
# var vida := 100
#
# func receber_dano(valor: int) -> void:
#     vida = maxi(0, vida - valor)
#     print("[Inimigo] Tomou %d de dano. Vida restante: %d" % [valor, vida])
#     if vida <= 0:
#         _morrer()
#
# func _morrer() -> void:
#     set_physics_process(false)
#     _tocar_anim("morte")
#     await _anim_player.animation_finished
#     queue_free()
