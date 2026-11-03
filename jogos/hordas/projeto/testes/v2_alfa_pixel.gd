extends Node
# Teste da borda dura em pixel art (um tamanho de pixel só, sem alfa gradual). Cada PNG de pixel art da v2 que tinha 100 a 250 níveis de
# transparência (anéis, nuvens, decalques de chão, o aro dos escudos, o foco do menu e as folhas do pixelfx tocadas em escala 1) fica com no
# máximo DEGRAUS níveis de alfa além do zero, como as folhas do #602. Brilho e luz suave de verdade (tex_brilho, PointLight2D) não são PNG
# nem entram aqui. Quem refaz um destes PNG passa por jogos/hordas/fonte_arte/quantizar_alfa.py (o MANIFESTO de lá lista os mesmos).
# Roda: godot --headless --path jogos/hordas/projeto res://testes/v2_alfa_pixel.tscn  (imprime "v2_alfa_pixel falhas=0")
const DEGRAUS := 6
# pastas (todos os .png dentro, sem os *_normal) e arquivos soltos
const PASTAS := [
	"res://assets/v2/armas",
	"res://assets/v2/armas_anim",
	"res://assets/v2/pixelfx/pickups",
	"res://assets/v2/pixelfx/spawn",
	"res://assets/v2/pixelfx/status",
	"res://assets/v2/pixelfx/ui",
	"res://assets/v2/escudos",
	"res://assets/v2/icones_cartas",
	"res://assets/v2/icones_cartas/16",
]
const ARQUIVOS := [
	"res://assets/v2/mapas/cidade/decalques.png",
	"res://assets/v2/mapas/laboratorio/decalques.png",
	"res://assets/v2/mapas/medio/decalques.png",
	"res://v2/hud/foco_premium.png",
]

var falhas := 0
var conferidos := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		falhas += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	var lista: Array = ARQUIVOS.duplicate()
	for pasta in PASTAS:
		var d := DirAccess.open(pasta)
		ok(d != null, "abre a pasta " + pasta)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".png") and not f.ends_with("_normal.png"):
				lista.append(pasta + "/" + f)
	for caminho in lista:
		var n := _niveis_de_alfa(caminho)
		ok(n >= 0, "carrega " + caminho)
		if n < 0:
			continue
		conferidos += 1
		ok(n <= DEGRAUS, "%s tem %d níveis de alfa (teto %d): borda borrada na pixel art" % [caminho, n, DEGRAUS])
	ok(conferidos >= 60, "conferiu poucos PNG (%d): a lista de pastas quebrou" % conferidos)
	print("  PNG conferidos: ", conferidos)
	print("v2_alfa_pixel falhas=", falhas)
	get_tree().quit(1 if falhas > 0 else 0)


# Quantos valores de alfa diferentes de zero o PNG usa; -1 se não abriu.
func _niveis_de_alfa(caminho: String) -> int:
	var img := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if img == null:
		return -1
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var dados := img.get_data()
	var visto := PackedByteArray()
	visto.resize(256)
	var i := 3
	var fim := dados.size()
	while i < fim:
		visto[dados[i]] = 1
		i += 4
	var n := 0
	for a in range(1, 256):
		n += visto[a]
	return n
