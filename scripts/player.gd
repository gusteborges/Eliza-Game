extends CharacterBody3D


@onready var animation_player: AnimationPlayer = $elisa_rig2/AnimationPlayer
@onready var elisa: Node3D = $elisa_rig2/ELISA

# =========================
# CONFIG
# =========================

var walk_speed = 2.0
var run_speed = 4.0
var rotation_speed = 3.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# =========================
# ANIMATION
# =========================

func play_anim(anim_name: String):
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)

# =========================
# READY 
# =========================
func _ready():
	# Verifica se existe um teleporte salvo na memória Global
	if Global.destino_do_teleporte != Vector3.ZERO:
		
		# Move a Regina para a posição salva
		global_position = Global.destino_do_teleporte
		
		# NOVO: Vira a Regina para a rotação salva
		global_rotation = Global.rotacao_do_teleporte
		
		# Limpa as memórias globais
		Global.destino_do_teleporte = Vector3.ZERO
		Global.rotacao_do_teleporte = Vector3.ZERO

# =========================
# PHYSICS
# =========================

func _physics_process(delta):

	# -------------------------
	# GRAVIDADE
	# -------------------------
	if not is_on_floor():
		velocity.y -= gravity * delta

	# -------------------------
	# INPUT
	# -------------------------
	var moving_forward = Input.is_action_pressed("forward")
	var moving_backward = Input.is_action_pressed("backward")
	var rotate_left = Input.is_action_pressed("left")
	var rotate_right = Input.is_action_pressed("right")
	var running = Input.is_action_pressed("run")

	# -------------------------
	# ROTAÇÃO TANQUE 
	# -------------------------
	if rotate_left:
		rotate_y(rotation_speed * delta)
	if rotate_right:
		rotate_y(-rotation_speed * delta)

	# -------------------------
	# VELOCIDADE SECA 
	# -------------------------
	var current_speed = 0.0

	if moving_forward:
		current_speed = run_speed if running else walk_speed
	elif moving_backward:
		# Andar para trás geralmente é mais lento em controles tanque
		current_speed = -(walk_speed * 0.7)

	# -------------------------
	# DIREÇÃO DO PLAYER
	# -------------------------
	var direction = -transform.basis.z.normalized()

	# Aplica a velocidade instantaneamente, sem aceleração
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

# -------------------------
	# ANIMAÇÕES
	# -------------------------
	
	if current_speed != 0:
		# 1. Se estiver andando para frente ou para trás
		if running and moving_forward:
			play_anim("RUNNING_ELISA")
		else:
			play_anim("WALKING_ELISA")
			
	elif rotate_left or rotate_right:
		# 2. Se estiver 100% parada, mas apertou "A" ou "D" para girar
		# Toca a animação de andar no lugar para não ficar estática
		play_anim("WALKING_ELISA") 
		
	else:
		# 3. Se soltou tudo
		play_anim("IDLE_ELISA")

	# -------------------------
	# MOVE
	# -------------------------
	move_and_slide()
