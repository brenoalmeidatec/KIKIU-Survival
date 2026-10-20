extends RefCounted
## Registro de picos de quadro (--picos=MS, só medição): no começo de cada _process do mundo mede o quadro anterior inteiro (tempo de
## parede, de um _process ao outro: script + desenho + o que a engine fez no meio) e quanto dele foi script (avancar). O quadro que passa de
## MS ms imprime uma linha `PICO` com as partes do perfil (mundo.perfil) que cresceram nele, quantos recursos e objetos nasceram (um load()
## ou uma textura criada no meio da partida aparecem aqui) e a memória de textura que subiu. No fim, `PICOS_RESUMO` com p50/p95/p99/máx e os
## 10 piores quadros. Uso: godot --path . res://v2/mundo.tscn -- --picos=25 [--medir ...] [--playtest ...]

const MAX_LINHAS := 300  # o log de uma partida inteira não pode virar um romance

var limite_ms := 25.0
var us_script := 0  # o mundo soma aqui o tempo do avancar e do roteiro (o _us_total ele zera na medição)
var _ant_us := -1
var _ant_script := 0
var _ant_perfil := {}
var _ant_rec := 0
var _ant_obj := 0
var _ant_tex := 0.0
var _parede := PackedFloat32Array()
var _script := PackedFloat32Array()
var _piores := []  # [ms, linha]
var _linhas := 0


func _init(ms: float) -> void:
	limite_ms = ms


## Chamar no começo do _process do mundo, antes do avancar: fecha a conta do quadro anterior.
func quadro(m) -> void:
	var agora := Time.get_ticks_usec()
	var rec := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var obj := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var tex := float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	if _ant_us >= 0:
		var parede := (agora - _ant_us) / 1000.0
		var script := (us_script - _ant_script) / 1000.0
		_parede.append(parede)
		_script.append(script)
		if parede > limite_ms:
			var partes := []
			for k in m.perfil:
				var d := (int(m.perfil[k]) - int(_ant_perfil.get(k, 0))) / 1000.0
				if d >= 0.5:
					partes.append("%s %.1f" % [k, d])
			var linha := (
				"PICO q=%d t=%.2f partida=%.1f parede=%.1f script=%.1f fora=%.1f vivos=%d jogo=%s recursos%+d objetos%+d tex%+.1fMB | %s"
				% [
					int(m.quadros),
					float(m.t),
					float(m.tempo_partida),
					parede,
					script,
					parede - script,
					m.monstros.size(),
					str(m.combate.jogo) if m.combate != null else "-",
					rec - _ant_rec,
					obj - _ant_obj,
					(tex - _ant_tex) / 1048576.0,
					", ".join(partes)
				]
			)
			if _linhas < MAX_LINHAS:
				print(linha)
			_linhas += 1
			_piores.append([parede, linha])
			if _piores.size() > 40:
				_piores.sort_custom(func(a, b): return a[0] > b[0])
				_piores.resize(10)
	_ant_us = agora
	_ant_script = us_script
	_ant_perfil = m.perfil.duplicate()
	_ant_rec = rec
	_ant_obj = obj
	_ant_tex = tex


func resumo() -> void:
	if _parede.is_empty():
		return
	print("PICOS_RESUMO quadros=%d acima_de_%.0fms=%d | parede %s | script %s" % [_parede.size(), limite_ms, _linhas, _pcts(_parede), _pcts(_script)])
	var n33 := 0
	var n50 := 0
	var n100 := 0
	for v in _parede:
		n33 += 1 if v > 33.3 else 0
		n50 += 1 if v > 50.0 else 0
		n100 += 1 if v > 100.0 else 0
	print("PICOS_FAIXAS >33ms=%d >50ms=%d >100ms=%d" % [n33, n50, n100])
	_piores.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(10, _piores.size()):
		print("PIOR %d: %s" % [i + 1, _piores[i][1]])


static func _pcts(a: PackedFloat32Array) -> String:
	var s := a.duplicate()
	s.sort()
	var n := s.size()
	return (
		"p50 %.2f p95 %.2f p99 %.2f p999 %.2f max %.1f"
		% [s[n / 2], s[mini(n - 1, n * 95 / 100)], s[mini(n - 1, n * 99 / 100)], s[mini(n - 1, n * 999 / 1000)], s[n - 1]]
	)
