extends CanvasLayer

@onready var entrada = $Panel/LineEdit

func _ready():
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

func mostrar():
	show()
	get_tree().paused = true

	entrada.text = ""
	entrada.grab_focus()

func fechar():
	hide()
	get_tree().paused = false

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		fechar()

func _on_button_pressed():
	print("botao clicado")

	if entrada.text.to_upper() == "CORVO":
		Global.porta_hall_aberta = true
		print("Senha correta!")
		fechar()

	else:
		print("Senha incorreta!")
		entrada.text = ""
		entrada.grab_focus()
