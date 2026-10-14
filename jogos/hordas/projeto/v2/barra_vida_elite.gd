extends Node2D
## Barra de vida pequena, desenhada acima do sprite das elites.

const ALTURA := 4.0
const LARGURA_MIN := 30.0
const LARGURA_MAX := 52.0
const COR_FUNDO := Color(0.035, 0.035, 0.045, 0.96)
const COR_BORDA := Color(0.72, 0.72, 0.78, 0.95)

var fracao := -1.0  # força o primeiro desenho mesmo com a vida cheia
var largura := 36.0
var cor := Color(1.0, 0.25, 0.3)


func sincronizar(monstro) -> void:
	visible = monstro.vivo and monstro.elite and not monstro.morrendo
	if not visible:
		return
	if float(monstro.vida) <= 0.0:
		visible = false
		return
	var vida_max := maxf(float(monstro.vida_max), 1.0)
	var nova_fracao := clampf(float(monstro.vida) / vida_max, 0.0, 1.0)
	var novo_largura := clampf(float(monstro.tipo.get("w", 36.0)) * float(monstro.escala) * 0.9, LARGURA_MIN, LARGURA_MAX)
	var nova_cor: Color = monstro.cor_elite
	var retangulo: Rect2 = monstro.sprite.get_rect()
	var topo_visual := float(monstro.sprite.position.y) + retangulo.position.y * float(monstro.sprite.scale.y)
	position = Vector2(float(monstro.sprite.position.x), topo_visual - 5.0)
	if not is_equal_approx(fracao, nova_fracao) or not is_equal_approx(largura, novo_largura) or cor != nova_cor:
		fracao = nova_fracao
		largura = novo_largura
		cor = nova_cor
		queue_redraw()


func _draw() -> void:
	var x := -largura * 0.5
	draw_rect(Rect2(x - 1.0, -1.0, largura + 2.0, ALTURA + 2.0), COR_FUNDO)
	draw_rect(Rect2(x, 0.0, largura, ALTURA), COR_BORDA)
	draw_rect(Rect2(x + 1.0, 1.0, maxf(largura - 2.0, 0.0), ALTURA - 2.0), COR_FUNDO)
	var preenchido := maxf(largura - 2.0, 0.0) * fracao
	if preenchido > 0.0:
		draw_rect(Rect2(x + 1.0, 1.0, preenchido, ALTURA - 2.0), cor)
