## Script base para todas as salas modulares da dungeon.
## Cada cena de sala (.tscn) deve ter este script como root.
##
## Estrutura esperada da cena filha:
##
##   SalaBase  [StaticBody3D]  ← este script
##   ├── Malha          [MeshInstance3D]   ← geometria da sala (importada do DAE)
##   ├── Colisao        [CollisionShape3D] ← forma de colisão da sala
##   ├── Saidas         [Node3D]           ← contêiner de conectores (obrigatório)
##   │   ├── NorthExit  [Marker3D]         ← conector norte
##   │   ├── SouthExit  [Marker3D]         ← conector sul
##   │   ├── EastExit   [Marker3D]         ← conector leste
##   │   └── WestExit   [Marker3D]         ← conector oeste
##   └── SpawnInimigos  [Node3D]           ← opcional: pontos de spawn
##
## Convenção de orientação dos Marker3D:
##   • Posição: borda da abertura da sala (onde a próxima peça encostará)
##   • Rotação: -Z do Marker aponta para FORA da sala (mesma direção do corredor)
##   Isso permite que o gerador alinhe as salas fazendo:
##     global_transform = conector_anterior.global_transform * Transform3D(Basis.IDENTITY.rotated(Vector3.UP, PI), Vector3.ZERO)

class_name SalaBase
extends StaticBody3D

# ── METADADOS DA SALA ────────────────────────────────────────────────
## Tipo semântico da sala — usado pelo gerador para colocar salas especiais
enum TipoSala {
	GENERICA,       ## corredor ou sala sem propósito especial
	INICIAL,        ## sala onde o player começa
	NORMAL,         ## sala de combate / exploração
	SAVE,           ## sala de save point / descanso
	PUZZLE,         ## sala com desafio / quebra-cabeça
	BOSS,           ## sala de chefe
	BECO,           ## corredor sem saída (dead end)
}

@export var tipo : TipoSala = TipoSala.GENERICA

## Peso de aleatoriedade — salas raras têm peso menor (ex.: Boss = 1, Normal = 10)
@export_range(1, 20) var peso_geracao : int = 10

# ── ESTADO INTERNO ──────────────────────────────────────────────────
## Conectores disponíveis nesta sala (preenchido em _ready automaticamente)
var conectores : Array[Marker3D] = []

## Conectores já utilizados pelo gerador (não podem ser reutilizados)
var conectores_usados : Array[Marker3D] = []

## Referência para a sala que gerou esta (para navegação de grafo)
var sala_pai : SalaBase = null

# ── INICIALIZAÇÃO ───────────────────────────────────────────────────
func _ready() -> void:
	_coletar_conectores()

func _coletar_conectores() -> void:
	# Busca o nó Saidas e coleta todos os Marker3D filhos
	var no_saidas := get_node_or_null("Saidas")
	if not no_saidas:
		push_error("[SalaBase] Nó 'Saidas' não encontrado em '%s'. "
				+ "Crie um Node3D chamado 'Saidas' e adicione os Marker3D dentro dele." % name)
		return

	for filho in no_saidas.get_children():
		if filho is Marker3D:
			conectores.append(filho)

	if conectores.is_empty():
		push_warning("[SalaBase] Sala '%s' não tem Marker3D em 'Saidas'. "
				+ "Adicione pelo menos um conector (NorthExit, SouthExit, etc.)." % name)

# ── API PÚBLICA PARA O GERADOR ──────────────────────────────────────

## Retorna os conectores ainda livres (não usados pelo gerador)
func obter_conectores_livres() -> Array[Marker3D]:
	var livres : Array[Marker3D] = []
	for conector in conectores:
		if conector not in conectores_usados:
			livres.append(conector)
	return livres

## Marca um conector como usado
func marcar_conector_usado(conector: Marker3D) -> void:
	if conector not in conectores_usados:
		conectores_usados.append(conector)

## Verifica se ainda há saídas disponíveis
func tem_saidas_livres() -> bool:
	return obter_conectores_livres().size() > 0

## Retorna a direção cardinal (norte/sul/leste/oeste) de um conector
## baseada no nome do Marker3D
static func direcao_do_conector(conector: Marker3D) -> String:
	var nome := conector.name.to_lower()
	if "north" in nome: return "north"
	if "south" in nome: return "south"
	if "east"  in nome: return "east"
	if "west"  in nome: return "west"
	push_warning("[SalaBase] Conector '%s' não segue a convenção de nomes "
			+ "(NorthExit, SouthExit, EastExit, WestExit)." % conector.name)
	return ""

## Retorna a direção oposta (norte↔sul, leste↔oeste)
static func direcao_oposta(direcao: String) -> String:
	match direcao:
		"north": return "south"
		"south": return "north"
		"east":  return "west"
		"west":  return "east"
	return ""

## Retorna o primeiro conector livre na direção especificada
func conector_na_direcao(direcao: String) -> Marker3D:
	for c in obter_conectores_livres():
		if SalaBase.direcao_do_conector(c) == direcao:
			return c
	return null
