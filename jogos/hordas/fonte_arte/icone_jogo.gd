extends SceneTree
## Ícone do K.I.K.I.U: elmo de cavaleiro com marca de caos (crista roxa, visor de brasa), desenhado pixel a pixel em
## 16x16 e ampliado por vizinho mais próximo (sem filtro) para 32, 48 e 256.
## Roda: godot --headless --path jogos/hordas/projeto -s ../fonte_arte/icone_jogo.gd
## Saída: assets/icone/kikiu_<tamanho>.png. O .ico é montado depois, pelo gerar_instalador.sh, com ffmpeg.
## Cada linha de METADE tem 8 colunas (a esquerda); a direita é o espelho, então o elmo sai simétrico.
## "." = transparente; o contorno de 1 px (cor "k") é posto sozinho em volta do desenho, por isso a grade deixa a borda livre.

const COR := {
	"k": "0d0b14", "g": "45405c", "s": "9a94b0", "w": "ece8f2",
	"d": "1c1826", "r": "b0342f", "R": "ff5a3c", "o": "c49a45",
	"p": "a62a8f", "P": "3d1046", "m": "e04aa8",
}

const METADE := [
	"........", "..gggggg", "..gooooo", "..goPPPP",
	"..goPPPm", "..goPPmR", "..goPmRR", "..goPPmR",
	"..goPPPm", "..goPPPP", "...gPPPg", "....gPPg",
	".....gPg", "......g.", "........", "........",
]


func _init() -> void:
	var w := 16
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	for y in w:
		var meia: String = METADE[y]
		assert(meia.length() == 8, "linha %d tem %d colunas (esperava 8)" % [y, meia.length()])
		var linha := meia
		for i in range(7, -1, -1):
			linha += meia[i]
		for x in w:
			var ch: String = linha[x]
			if ch != ".":
				img.set_pixel(x, y, Color(COR[ch]))
	var cheio := []
	for y in w:
		for x in w:
			cheio.append(img.get_pixel(x, y).a > 0.5)
	for y in w:
		for x in w:
			if cheio[y * w + x]:
				continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + v
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < w and cheio[q.y * w + q.x]:
					img.set_pixel(x, y, Color(COR.k))
					break
	DirAccess.make_dir_recursive_absolute("res://assets/icone")
	for t in [16, 32, 48, 64, 128, 256]:
		var out := img.duplicate()
		if t != 16:
			out.resize(t, t, Image.INTERPOLATE_NEAREST)
		out.save_png("res://assets/icone/kikiu_%d.png" % t)
		print("ICONE ", t, "x", t)
	quit()
