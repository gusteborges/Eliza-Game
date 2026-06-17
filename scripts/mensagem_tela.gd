extends CanvasLayer

@onready var label = $ColorRect/Label
@onready var timer = $Timer

func _ready():
	# Começa invisível
	hide() 
	# Conecta o timer para apagar a mensagem quando o tempo acabar
	timer.timeout.connect(_esconder_mensagem)

# Qualquer porta ou item do jogo pode chamar essa função passando o texto que quiser!
func mostrar_mensagem(texto: String):
	label.text = texto
	show() # Fica visível
	timer.start() # Começa a contar os 2 segundos

func _esconder_mensagem():
	hide() # Fica invisível de novo
