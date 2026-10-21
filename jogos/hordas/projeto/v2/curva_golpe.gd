extends RefCounted
## Envelope apenas do corpo; não muda o relógio, alcance ou avanço físico do golpe.
## x: pixels ao longo da mira; y: intensidade da esticada (0..1).
## Chaves: neutro -> -2 px no meio do preparo -> +3 px no acerto -> neutro.
## Smoothstep zera a velocidade nas junções; arredondar só depois de aplicar a direção.


static func corpo(fase: float, acerto: float) -> Vector2:
	var p := clampf(fase, 0.0, 1.0)
	var a := clampf(acerto, 0.001, 0.999)
	var meio := a * 0.5
	if p < meio:
		return Vector2(lerpf(0.0, -2.0, smoothstep(0.0, meio, p)), 0.0)
	if p < a:
		var k := smoothstep(meio, a, p)
		return Vector2(lerpf(-2.0, 3.0, k), k)
	var volta := 1.0 - smoothstep(a, 1.0, p)
	return Vector2(3.0 * volta, volta)
