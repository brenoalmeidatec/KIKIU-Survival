# Arte que falta para as fusões (para o Alisson)

Esta entrega não mexe em nenhum arquivo de arte. O que está no código hoje é desenho por código (halo, miolo branco, cartão de fundo sólido) e o som `evolucao.wav` que já existia. Quando sair a arte abaixo, ela entra sem mudar código: é só trocar a textura.

Estilo: pixel art, mesma paleta do jogo (ouro #f1b10e como destaque), sem contorno preto grosso nas bordas de cenário. Prompts para GPT Astra, em inglês, como o `PACOTE_ALISSON.md` já faz.

## 1. Moldura do cartão de FUSÃO (prioridade alta)

Cartão de 600 x 200 px na tela de 960 x 540, com a palavra FUSÃO! no alto. Hoje é um retângulo escuro. Pede uma moldura de 9 fatias (bordas de 12 px).

Prompt:
> Pixel art UI frame, 9-slice, 600x200 target, dark violet background #0a0814 with a thin gold #f1b10e double border, small rune corners, pixel grain, no text, no characters, transparent outside the border, flat readable style, 16-bit era game HUD.

## 2. Halo de fusão por arma (prioridade média)

Sprite 48 x 48 px, um círculo de brilho com a cor da fusão (cada fusão tem a sua cor em `dados/v2_cartas.json`, campo `cor`). Hoje o código desenha o mesmo halo, só com a cor diferente. Um sprite próprio daria um brilho com padrão (faíscas, anel quebrado), que lê de longe.

Prompt (uma por cor, ou uma base branca que o código tinge):
> Pixel art glow sprite, 48x48, soft radial energy burst with four small sparkle points at the edge, pure white core fading to transparent, no colour (it will be tinted in game), crisp pixel steps, no outline.

## 3. Onda da Ventania Cortante (prioridade média)

Hoje a onda da katana é um arco de 64 x 32 px desenhado por código. A Ventania fica 2,0 vezes mais larga; um sprite de arco com cauda dupla ajudaria a ler que é a fusão.

Prompt:
> Pixel art wind slash arc, 64x32, a crescent of pale cyan air with a double tail trailing to the left, three thin stripes inside, transparent background, no outline, 16-bit style.

## 4. Ícone da fusão no card de SUA BUILD (prioridade baixa)

Ícone 16 x 16 (cabe no mesmo padrão dos ícones de carta, que são mostrados em 2x). Um símbolo de "junção" (duas setas que se encontram) em ouro.

Prompt:
> Pixel art icon, 16x16, two small arrows meeting at a point, gold #f1b10e on transparent background, one-pixel dark outline, clear at 2x scale.

## Som (sem arte)

A fusão já toca `assets/audio/v2/evolucao.wav`. Se você tiver um som mais marcado (um estalo com cauda), é só substituir o arquivo com o mesmo nome. Lembrete: confira a licença e registre em `docs/LICENCAS_AUDIO.md`.
