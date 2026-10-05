extends SceneTree
## Ícones (16x16) das armas exclusivas do Hazaki, desenhados pixel a pixel.
## Roda: godot --headless --path jogos/hordas/projeto -s ../fonte_arte/icones_hazaki.gd
## Saída: assets/gerado/icone_<id>.png (cada letra da grade é uma cor; "." = transparente)

const COR := {
	"k": "0d0b14", "g": "45405c", "s": "9a94b0", "w": "ece8f2",
	"r": "b0342f", "R": "7e2027", "o": "c49a45", "O": "eccb7a", "b": "6e4c32",
	"n": "d9a066", "N": "a0663a", "c": "6f8fc8", "C": "c9e8ff",
	"f": "f0921e", "y": "ffd060",
}

const ICONES := {
	"katana": [
		"..............kk",
		".............kwk",
		"............kwsk",
		"...........kwsk.",
		"..........kwsk..",
		".........kwsk...",
		"........kwsk....",
		".......kwsk.....",
		"......kwsk......",
		"...kokwsk.......",
		"....koosk.......",
		"....kRok........",
		"...kRk..........",
		"..kRk...........",
		".kRk............",
		".kk.............",
	],
	"desert_eagles": [
		"................",
		"kkkkkkkk........",
		"kwsssssgk.......",
		"kgggggggk.......",
		".kgkbbk.........",
		"..k.kbbk........",
		"....kbbk........",
		"....kkkk........",
		"........kkkkkkkk",
		".......kgssssswk",
		".......kgggggggk",
		".........kbbkgk.",
		"........kbbk.k..",
		"........kbbk....",
		"........kkkk....",
		"................",
	],
	"arte_marcial": [
		"................",
		".....kkkkkk.....",
		"....knnnnnnk....",
		"...knnnnnnnnk...",
		"...kNnNnNnNnk...",
		"...knnnnnnnnk...",
		"...kkNnnnnnnk...",
		"..knnknnnnnNk...",
		"..knnnknnnNk....",
		"...kkkkkkkk.....",
		"................",
		"c..cc..c........",
		".c..cc..c.......",
		"..c..cc..c......",
		"................",
		"................",
	],
	"aura_hazaki": [
		".....cccccc.....",
		"...cc......cc...",
		"..c...kkkk...c..",
		".c...kCCCCk...c.",
		".c..kCwwwwCk..c.",
		"c...kCwwwwCk...c",
		"c...kCwwwwCk...c",
		"c....kCCCCk....c",
		".c....kkkk....c.",
		".c...........c..",
		"..c.........c...",
		"...cc......cc...",
		".....cccccc.....",
		"................",
		"..C..........C..",
		"................",
	],
	"poder_elemental": [
		"......kk........",
		".....kyk........",
		"....kyfk..k.....",
		"....kfyfk.kck...",
		"...kfyyfk.kCk...",
		"...kffyffkkCck..",
		"..kfffyyffkCCk..",
		"..kRffffffkcCk..",
		"..kRRffffRk.kck.",
		"...kRRRRRk..kk..",
		"....kkkkk.......",
		"..........kCk...",
		".........kCwCk..",
		"..........kCk...",
		"................",
		"................",
	],
}


func _init() -> void:
	for nome in ICONES:
		var grade: Array = ICONES[nome]
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			var linha: String = grade[y]
			assert(linha.length() == 16, "%s: linha %d tem %d colunas" % [nome, y, linha.length()])
			for x in 16:
				var ch := linha[x]
				if ch != ".":
					img.set_pixel(x, y, Color(COR[ch]))
		img.save_png("res://assets/gerado/icone_%s.png" % nome)
		print("ICONE ", nome)
	quit()
