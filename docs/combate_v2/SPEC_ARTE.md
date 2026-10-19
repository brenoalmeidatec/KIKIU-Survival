# Especificação das folhas animadas dos golpes da v2

Este arquivo é o contrato entre a arte (folhas em `jogos/hordas/projeto/assets/v2/armas_anim/`) e o código que toca as animações
(`v2/anim_golpes.gd`, ligado em `v2/armas_novas.gd`). Vale para os golpes secundários automáticos: projéteis, meteoros, anéis e nuvens.
As invocações já têm folhas de 8 direções próprias (`assets/v2/armas/*_dir.png`, `v2/andante.gd` e `v2/golem.gd`) e a katana do herói tem o
combo do Blender: nada disso entra aqui.

## Regras de arte
- **Quadros diferentes de verdade.** Cada quadro é desenhado de novo (chama que muda de forma, faísca que nasce e some, anel que abre). Não vale
  repetir o mesmo desenho, só mudar o brilho, nem girar ou esticar a imagem parada de `assets/v2/armas/`. A imagem parada é a **referência**
  de cor, forma e silhueta (a primeira pose do voo pode partir dela).
- Pixel art de verdade: sem suavização (nada de antialias nem filtro bilinear), poucos tons (3 a 5 por material), **contorno escuro de 1 px**
  nos projéteis e na cabeça dos meteoros, **sem pixels soltos** (nenhum pixel isolado sem vizinho da mesma cor, salvo faísca de propósito).
- Paleta e luz das imagens paradas atuais (luz vindo de cima à esquerda). Escala do jogo: o herói tem uns 39 px de altura.
- **Fundo transparente** em todas as folhas (RGBA). O código decide a mistura (os anéis e as nuvens vão para a camada aditiva).
- Sem texto, sem moldura, sem grade, sem número.
- Arte nova em arquivo novo: nada em `assets/v2/armas/` muda.

## Formato
- Um PNG por animação: **tira horizontal**, quadros da esquerda para a direita, cada célula exatamente do tamanho de "quadro", sem espaço
  entre elas. Largura = `n × quadro.x`, altura = `quadro.y`.
- Nome: `<sprite>_<anim>.png` (ex.: `bola_fogo_voo.png`, `bola_fogo_impacto.png`).
- Cada grupo escreve o seu índice `indice_<grupo>.json` na mesma pasta (o código lê todos os `indice_*.json`):

```json
{
  "folhas": {
    "bola_fogo": {
      "armas": ["bola_fogo", "fogo_do_ceu"],
      "anims": {
        "voo": {"arquivo": "bola_fogo_voo.png", "quadro": [26, 18], "n": 4, "fps": 12, "loop": true, "ancora": [19, 9]},
        "impacto": {"arquivo": "bola_fogo_impacto.png", "quadro": [56, 56], "n": 6, "fps": 15, "loop": false, "ancora": [28, 28]}
      }
    }
  }
}
```

- `armas`: os ids dos golpes (de `dados/v2_cartas.json`) que usam a folha.
- `ancora`: o pixel da célula que fica no ponto do jogo (a cabeça do projétil, o centro do impacto, o centro do anel).
- `gira: true` (opcional, na animação de voo): o giro já está nos quadros e o código não gira o sprite (adaga, shuriken, disco).

## Animações por família
| Família | Animações (ordem, quadros, fps) | Âncora |
|---|---|---|
| Projétil que aponta (flecha, lança, dardo, feixe) | `voo` 4q 12 fps loop, ponta para a **direita**, rastro curto para a esquerda; `impacto` 3q 20 fps, 20x20 | voo: a cabeça (3/4 da largura, meio da altura); impacto: centro |
| Projétil que gira (adaga, shuriken, disco) | `voo` 8q 16 fps loop, uma volta completa, `gira: true`; `impacto` 3q 20 fps, 20x20 | centro |
| Bola (bola de fogo, chumbo) | `voo` 4q 12 fps loop, aponta para a direita com chama/poeira atrás; `impacto` 6q 15 fps (explosão que abre e some), 56x56 | voo: a cabeça; impacto: centro |
| Meteoro | `queda` 4q 12 fps loop, aponta para a **direita** com rastro longo (o código gira para baixo); `impacto` 8q 15 fps (clarão, onda, fagulhas), 72x72 nos grandes e 48x48 nos pequenos; `marca` 4q 8 fps, 48x32 achatado (chão queimado/rachado/gelado que esfria; o último quase transparente) | queda: a cabeça; impacto e marca: centro |
| Anel de choque | `expandir` 6q 20 fps: nasce pequeno no centro e chega à borda da célula, afinando e esmaecendo; visto no chão achatado (altura ~62% da largura) | centro |
| Nuvem | `entrada` 3q 10 fps (se forma), `loop` 6q 6 fps (4q se a célula passa de 130 px de largura; o último emenda no primeiro; movimento **dentro** da nuvem: bolhas, flocos, gotas, turbilhão), `saida` 3q 10 fps (dissolve) | centro |

Tamanhos de célula: os da tabela de `docs/animacoes_armas_v2.md` (coluna "Quadro novo"). Anéis e nuvens usam o tamanho da imagem parada.

## Prévia obrigatória
Cada folha ganha um GIF ampliado 4x **sem suavizar** (vizinho mais próximo), tocando na velocidade dos fps, sobre fundo cinza-escuro
(`#2a2a30`), em `docs/combate_v2/previas/<sprite>_<anim>.gif`. O projétil mostra o voo e o impacto em seguida.

## Fonte reprodutível
O script que gera as folhas fica em `jogos/hordas/fonte_arte/armas_anim/gerar_<grupo>.py` (Python 3 + Pillow, sem rede). Rodar de novo dá
as mesmas folhas (semente fixa).
