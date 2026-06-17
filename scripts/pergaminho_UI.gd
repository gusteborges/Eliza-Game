extends CanvasLayer

@onready var texto = $Control/RichTextLabel

func _ready() -> void:
	hide()

func mostrar_pergaminho(mensagem: String):
	texto.text = mensagem
	show()
	get_tree().paused = true

func fechar():
	hide()
	get_tree().paused = false

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		fechar()
