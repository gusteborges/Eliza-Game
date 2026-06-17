extends VideoStreamPlayer

@export_file("*.tscn") var caminho_proxima_cena: String

func _ready() -> void:
	loop = false
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)
	play()

func _on_finished() -> void:
	if caminho_proxima_cena != "":
		# Apenas troca de cena! A memória Global já foi preenchida pelo gatilho.
		get_tree().call_deferred("change_scene_to_file", caminho_proxima_cena)
	else:
		print("Erro: O caminho da próxima cena está vazio!")
