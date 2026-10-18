extends "res://chefes/chefe_base.gd"
## Maltherion, o Rei do Bosque Profanado (chefe principal da Floresta, v3). Ficha em docs/v3/chefes/FICHA_TECNICA.md.
## Três fases: 100-70% (guardião), 70-30% (rei desperto, zonas de raiz e invocações), 30-0% (coração profanado, Coração da Floresta).
## A janela de contra-ataque do Coração fica em "janela" (segundos de recuperação com o chefe parado). Invocações: no máximo
## `max_vivas` por vez (o próprio chefe controla a conta em `pode_invocar`). Valores iniciais, sem ajuste de jogo.
## A arena viva (raízes no chão, passagens, árvores) é do Alisson: este arquivo só cuida do chefe.

const CONFIG := {
	"vida": 5000.0,
	"fase2": 0.7,
	"fase3": 0.3,
	"ataques":
	[
		{"nome": "raizes_gigantes", "clip": "raizes_gigantes", "aviso": 1.4, "recupera": 0.8, "recarga": 3.0, "raio": 3.2, "dano": 5.0, "fase": 1},
		{
			"nome": "invocacao_de_criaturas",
			"clip": "invocacao",
			"aviso": 1.0,
			"recupera": 0.6,
			"recarga": 6.0,
			"raio": 0.0,
			"dano": 0.0,
			"invoca": 2,
			"fase": 1
		},
		{"nome": "garras_sombras", "clip": "garras_sombras", "aviso": 0.9, "recupera": 0.6, "recarga": 2.5, "raio": 2.2, "dano": 4.0, "fase": 1},
		{
			"nome": "tempestade_de_raizes",
			"clip": "tempestade_raizes",
			"aviso": 1.0,
			"recupera": 0.8,
			"recarga": 3.5,
			"raio": 3.0,
			"dano": 4.0,
			"zonas": 3,
			"fase": 2
		},
		{
			"nome": "coracao_da_floresta",
			"clip": "coracao_floresta",
			"aviso": 2.2,
			"recupera": 2.4,
			"recarga": 8.0,
			"raio": 4.2,
			"dano": 8.0,
			"janela": 2.4,
			"fase": 3
		},
	],
}

var max_vivas := 3
var invocadas_vivas := 0


## Invocação: só sai se houver espaço (o Maltherion não invoca sem limite). Devolve quantas saem agora.
func pode_invocar(vivas: int) -> int:
	return clamp(max_vivas - vivas, 0, int(ataque_atual.get("invoca", 0)))


## Clipe de animação do ataque atual (ou o de andar, se não há ataque em curso).
func clip_atual() -> String:
	if ataque_atual.is_empty():
		return "walk" if fase > 1 else "idle"
	return String(ataque_atual.clip)
