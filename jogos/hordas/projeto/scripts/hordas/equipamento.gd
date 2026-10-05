extends RefCounted
## Equipamentos visuais modulares (seções 6 e 7 do design). Regras e "montador" do visual:
## - cada equipamento (dados/equipamentos.json) ocupa um slot e soma atributos, como um passivo;
## - o personagem é desenhado em CAMADAS (corpo base + uma por equipamento/arma), empilhadas na ordem
##   _config.ordem; um equipamento pode esconder outra camada (o elmo esconde o cabelo);
## - armas com "visual" (armas.json) disputam as mãos pela prioridade; quem perde usa a camada "senao"
##   (ex.: katana vai pra bainha quando as pistolas estão nas mãos).
## Só o personagem com "camadas": true no herois.json tem modelo em camadas (por enquanto, o Hazaki).

const CAMADAS_BASE := ["cabelo"]   # camadas que o personagem sempre tem (podem ser escondidas)


static func dados(id: String) -> Dictionary:
	var d = Dados.json("equipamentos").get(id, {})
	return d if d is Dictionary and not id.begins_with("_") else {}


## Pode oferecer este equipamento agora? Slot livre e (sem dono ou do próprio personagem).
static func permitido(id: String, heroi_id: String, equipados: Dictionary) -> bool:
	var d := dados(id)
	if d.is_empty() or equipados.has(str(d.get("slot", ""))):
		return false
	var dono := str(d.get("characterId", ""))
	return dono == "" or dono == heroi_id


## Soma dos bônus dos equipamentos vestidos (equipados = slot -> id).
static func bonus(equipados: Dictionary) -> Dictionary:
	var s := {}
	for slot in equipados:
		var b: Dictionary = dados(equipados[slot]).get("bonus", {})
		for k in b:
			s[k] = float(s.get(k, 0.0)) + float(b[k])
	return s


## Camadas a desenhar, na ordem (a primeira fica embaixo), pras armas e equipamentos atuais.
static func camadas(armas_ids: Array, equipados: Dictionary) -> Array:
	var ativas: Array = CAMADAS_BASE.duplicate()
	var escondidas := []
	for slot in equipados:
		var d := dados(equipados[slot])
		if d.has("camada"):
			ativas.append(str(d.camada))
		escondidas.append_array(d.get("esconde", []))
	# armas: quem tem mais prioridade pega as mãos primeiro
	var vis := []
	for id in armas_ids:
		var v = Dados.json("armas").get(id, {}).get("visual") if Dados.json("armas").get(id) is Dictionary else null
		if v is Dictionary:
			vis.append(v)
	vis.sort_custom(func(a, b): return float(a.get("prioridade", 0)) > float(b.get("prioridade", 0)))
	var maos := {}
	for v in vis:
		var livres := true
		for m in v.get("maos", []):
			if maos.has(m):
				livres = false
		if livres:
			for m in v.get("maos", []):
				maos[m] = true
			ativas.append(str(v.camada))
		elif v.has("senao"):
			ativas.append(str(v.senao))
	var ordem: Array = Dados.json("equipamentos").get("_config", {}).get("ordem", [])
	var res := ativas.filter(func(c): return not c in escondidas)
	res.sort_custom(func(a, b): return ordem.find(a) < ordem.find(b))
	return res
