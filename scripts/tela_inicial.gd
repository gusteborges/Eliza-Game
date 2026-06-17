extends Node

const CENA_TESTE = "res://scenes/main.tscn"
var carregando = false

func _input(event):
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed() and not event.is_echo() and not carregando:
			iniciar_carregamento()

func iniciar_carregamento():
	carregando = true
	# Pede para o Godot começar a carregar a cena em segundo plano
	ResourceLoader.load_threaded_request(CENA_TESTE)

func _process(delta):
	if carregando:
		# Verifica constantemente o status do carregamento
		var status = ResourceLoader.load_threaded_get_status(CENA_TESTE)
		
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# Quando terminar 100%, troca a cena usando o recurso já carregado
			var cena_carregada = ResourceLoader.load_threaded_get(CENA_TESTE)
			get_tree().change_scene_to_packed(cena_carregada)
