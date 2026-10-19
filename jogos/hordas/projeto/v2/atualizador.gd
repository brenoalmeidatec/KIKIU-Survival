extends Node
## Aviso de versão nova (#106). Ao abrir o título, pergunta em segundo plano à API pública do GitHub qual é a Release mais
## recente (a tag é "build-AAAA-MM-DD-<sha>", publicada a cada merge na main) e compara com o carimbo embutido (dados/versao.json:
## data e commit, gravados na exportação). Só AVISA: não baixa nem troca nada (o atualizador completo ficou de fora por segurança).
## Silencioso por desenho: sem internet, timeout, resposta estranha ou build "dev" (sem carimbo) não mostram nada nem travam.
## Desligável em Ajustes (opção verificar_versao). `nova_versao(tag, url)` sai uma vez, só se a Release for mais nova.

signal nova_versao(tag: String, url: String)

## Primeiro pergunta ao KIKIU-Releases (repositório público só de versões, #106). Se ele não tiver nenhuma Release (404) ou der
## erro de rede, cai para o KIKIU-Survival: o aviso não fica mudo enquanto o repositório de versões não é publicado.
const API_RELEASES := "https://api.github.com/repos/brenoalmeidatec/KIKIU-Releases/releases/latest"
const API := "https://api.github.com/repos/brenoalmeidatec/KIKIU-Survival/releases/latest"
const PREFIXO_RELEASES := "https://github.com/brenoalmeidatec/KIKIU-Releases/releases"
const PREFIXO_PAGINA := "https://github.com/brenoalmeidatec/KIKIU-Survival/releases"
const TIMEOUT := 5.0

var carimbo := {}  # {"data": "2026-10-07", "commit": "20bf57a"}; vazio = build "dev" (nada a comparar)
var resposta_simulada := ""  # testes: corpo JSON no lugar da rede (vazio = rede de verdade)
var _req: HTTPRequest


func _init() -> void:
	carimbo = ler_carimbo()


## O carimbo gravado na exportação; vazio se não houver (rodando pelo editor).
static func ler_carimbo() -> Dictionary:
	var f := FileAccess.open("res://dados/versao.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary and str(d.get("data", "")) != "" and str(d.get("commit", "")) != "":
		return d
	return {}


## Dispara a consulta. Devolve false (sem fazer nada) se a opção está desligada ou se a build não tem carimbo.
func verificar() -> bool:
	if not bool(Config.v("verificar_versao")) or carimbo.is_empty():
		return false
	if resposta_simulada != "":
		_tratar(resposta_simulada)
		return true
	return _consultar(API_RELEASES, true)


func _consultar(url: String, pode_cair_para_fallback: bool) -> bool:
	_req = HTTPRequest.new()
	_req.timeout = TIMEOUT
	add_child(_req)
	_req.request_completed.connect(_ao_responder.bind(pode_cair_para_fallback))
	var cab := PackedStringArray(["User-Agent: KIKIU-Survival", "Accept: application/vnd.github+json"])
	if _req.request(url, cab) != OK:
		_req.queue_free()
		return false
	return true


func _ao_responder(resultado: int, codigo: int, _cab: PackedStringArray, corpo: PackedByteArray, pode_cair_para_fallback: bool) -> void:
	if is_instance_valid(_req):
		_req.queue_free()
	if resultado == HTTPRequest.RESULT_SUCCESS and codigo == 200:
		_tratar(corpo.get_string_from_utf8())
	elif pode_cair_para_fallback:
		_consultar(API, false)  # sem Release no KIKIU-Releases (ou sem rede): tenta o repositório do jogo


func _tratar(texto: String) -> void:
	var j := JSON.new()
	if j.parse(texto) != OK or not j.data is Dictionary:
		return  # resposta que não é JSON: ignora em silêncio
	var d: Dictionary = j.data
	var tag := str(d.get("tag_name", ""))
	var url := str(d.get("html_url", ""))
	if not aceita_url(url):
		url = PREFIXO_PAGINA  # só abrimos páginas dos nossos repositórios, nunca um endereço vindo da resposta
	if mais_nova(tag, carimbo):
		nova_versao.emit(tag, url)


## A página que o aviso abre: só dos nossos dois repositórios de Release.
static func aceita_url(url: String) -> bool:
	return url.begins_with(PREFIXO_RELEASES) or url.begins_with(PREFIXO_PAGINA)


## `tag` ("build-2026-10-15-abc1234") é mais nova que o carimbo? Data maior, ou a mesma data com outro commit. Tag fora do
## formato, ou carimbo incompleto, nunca avisa.
static func mais_nova(tag: String, carimbo_local: Dictionary) -> bool:
	var rx := RegEx.create_from_string("^build-(\\d{4}-\\d{2}-\\d{2})-([0-9a-f]{4,40})$")
	var m := rx.search(tag)
	if m == null or carimbo_local.is_empty():
		return false
	var data := str(carimbo_local.get("data", ""))
	var commit := str(carimbo_local.get("commit", "")).trim_suffix("+")
	if data == "" or commit == "":
		return false
	var d_tag := m.get_string(1)
	var c_tag := m.get_string(2)
	if d_tag != data:
		return d_tag > data  # AAAA-MM-DD compara como texto
	return not (c_tag.begins_with(commit) or commit.begins_with(c_tag))
