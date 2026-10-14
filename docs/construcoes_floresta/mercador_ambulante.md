# Mercador Ambulante (mercador_ambulante)

**Status:** protótipo para revisão do Breno. Decisão pendente: integrar ao mercador que já existe (recomendado) ou criar um novo.

**O que é:** a proposta era um mercador que anda pela mata. Mas o mapa médio já tem um mercador (`marcadores`: tipo "mercador", pos [600, 1320], custo 8, forcar 1). Criar um segundo com a mesma função duplica a mecânica.

**Recomendação: integrar, não duplicar.** O mercador existente vira um encontro que muda de lugar a cada partida, sorteado entre 2 pontos da rota, e o estoque cresce um pouco. Não há NPC novo, e a arte do mercador existente serve.

```
  Rota do mapa médio (do santuário ao chefe):
  santuário ── alavanca ── [mercador: ponto A ou B] ── ... ── chefe
                              (sorteado na partida)
```

## O que o jogador faz
- Entra na zona do mercador (raio 200 px, já existente) e a loja abre, como hoje.
- Sem tecla nova. A compra é igual à do mercador atual.

## O que acontece (integração)
- A loja mostra 2 cartas (hoje 1) a 8 almas cada. As almas vêm da partida (XP/10, menos o que já foi gasto: `almas_partida` em mundo.gd).
- Uma carta é de stat ou golpe. Não vende cura (o banquete é do coletável loja_cura, que segue como está).
- Compra é única por visita; a segunda carta só fica disponível se o jogador tiver almas para as duas.

## Números propostos
| Item | Valor |
|---|---|
| Preço | 8 almas por carta |
| Cartas por visita | 2 (hoje 1) |
| Pontos possíveis | 2 (A: pos 600, 1320; B: pos perto de 1180, 1560, validar) |
| Visitas por partida | 1 (no ponto sorteado) |

## Custo e risco
- O custo é a alma (XP) que deixa de virar carta de nível. É o mesmo custo do mercador atual.
- Mais uma carta só vale se o jogador tiver almas. Para a horda, nada muda.

## Recarga e limite
- 1 visita por partida, no ponto sorteado. A loja não some depois de comprar; só o estoque acaba.

## Como a horda reage
- Nada. A loja é fora da luta, como hoje.

## Sinais visuais e sonoros
- Igual ao mercador atual: luz de vela e a tela de loja.
- Marcador no minimapa só depois de entrar na zona.

## Nota de desempenho
- Zero custo novo: é o mesmo objeto e a mesma tela.

## Prompt de arte para o GPT Astra
**Não há arte nova** se a integração for aprovada. Se o Breno preferir um mercador novo, este é o prompt:

**Sprites:** carroça pequena de mercador com toldo, 64 x 48 px, vista 2.5D de cima. 1 quadro.
**Animação:** nenhuma (sem animação, só o toldo parado).
**Paleta:** madeira #6B4A2C, toldo de lona #8A3A2A, detalhes dourados #C9A24A, musgo #3F6B3A.

> Pixel art sprite of a small travelling merchant cart with a canvas awning, seen from a top-down 2.5D view, 64 by 48 pixels: wooden wheels, a red-brown canvas roof and a few gold details, matching the style of a 2.5D dark forest survival game. Use only these colors: wood brown #6B4A2C, canvas red #8A3A2A, gold detail #C9A24A, moss green #3F6B3A. Transparent background. One frame, exact size 64 x 48 pixels. No text, no border, no frame, no shadow outside the sprite.

## Pontos de atenção
- Este é o único ponto onde a ficha diz "não fazer". Se o Breno aprovar a integração, esta ficha vira só uma linha no mapa.
- O segundo ponto (B) não é validado: precisa de teste de alcance em testes/v2_mapas.
