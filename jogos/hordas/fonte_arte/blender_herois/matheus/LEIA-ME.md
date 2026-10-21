# Matheus: aparência própria do personagem (mesmo rig, mesmas animações do Hazaki)

O Matheus é um **personagem** do Salão (`dados/v2_salao.json`, "nomes") e joga com o herói Hazaki (sem campo `heroi`). Esta pasta gera a folha de sprites dele, no
MESMO formato e com as MESMAS animações da folha do Hazaki (parado, andar, rolamento, combo de 3 golpes, escudo, dano e morte, 8 direções, cor + normal).
Nada de regra muda: é só a "aparência" (campo `sprite` do personagem).

```
blender -b -t 6 -P gerar.py                     # ~31 s: quadros/<anim>/<direcao>_<i>_{cor,normal}.png + matheus_rig.blend
blender -b -t 6 -P gerar.py -- --anim=andar     # só uma animação
python ../hazaki/montar_folha.py . matheus      # matheus_final_{albedo,normal}.png + matheus_final.json (+ prévia x4)
python ../hazaki/gifs.py <saida> . matheus hazaki_samurai   # um GIF por animação + comparativo com o sprite que o jogo usava (o do Hazaki)
```

## O que é compartilhado e o que é do Matheus
- `../hazaki/gerar.py` aceita `--perfil=<arquivo.py>`: com ele, o rig, a câmera, a luz, o contorno, a normal e os `anim_*.py` (as poses do Hazaki/katana) são os mesmos, e o
  perfil só troca o modelo e as cores. Sem `--perfil` o Hazaki sai idêntico ao de antes.
- `perfil.py` (esta pasta): `PALETA` (cores do Matheus), `fonte()` (cabelo curto e crespo no lugar das mechas compridas) e `ajustar()` (tira o lenço, põe a camisa escura,
  a tira de couro cruzada com fivela, braçadeiras, antebraço de pele, botas pretas). O resto do corpo é a geometria do estudo do Codex, a mesma do Hazaki.
- `gerar.py` (esta pasta) só chama o do Hazaki com o `--perfil` desta pasta. `montar_folha.py` e `gifs.py` do Hazaki aceitam `[pasta nome]` para montar a folha de outro personagem.

## Referência e decisões
Referência: `../../referencia_herois/matheus.png` (Codex, PR #286): colete azul de gola alta sobre camisa escura, mangas arregaçadas com braçadeiras de couro, pele morena, cabelo
curto e crespo, cinto e tira de couro cruzada, calça azul-marinho, botas pretas, katana de cabo azul.
- **A katana fica na mão** (como no Hazaki): as animações de golpe, estocada e escudo dependem da lâmina na mão. A bainha fica no quadril. Na referência ela está embainhada na cintura;
  embainhar exigiria animações novas de sacar, o que muda as animações (fora do pedido).
- Legível em 32x44: colete azul vivo (o que diferencia do Hazaki vermelho), mangas escuras, pele morena no rosto e antebraços, cabelo escuro e baixo com a testa aparecendo.
- Mesma largura, altura, pé na linha 42 e mesmas colunas da folha do Hazaki (50 colunas x 8 linhas; `colunas` do JSON = as 7 do andar; o resto em `animacoes`).

## No jogo
`prototipos/cara_nova/sprites/matheus{.json,_albedo.png,_normal.png}` (cópia da folha final) e `"sprite": "matheus"` no nome Matheus de `dados/v2_salao.json`.
O salão, o retrato da escolha (quando o personagem não tem rosto) e a partida (mundo e retrato do HUD) usam a folha dele; o Breno (sem `sprite`) continua com a do Hazaki.
Prints reais (janela oculta): `qa/qa_matheus_jogo.gd` (copie para `testes/` de uma cópia do projeto para rodar; não é teste de CI).

GIFs, comparativo e prints: `docs/visual_2_5d/blender_herois/matheus/`.

## Em jogo, 21/10 (integração com a main de 21/10)
`jogos/hordas/projeto/testes/fotos/matheus_gif.tscn` (não roda no CI) grava os quadros reais do jogo com o Matheus (`--ativo=matheus`) ou com o Breno/Hazaki (`--ativo=breno`, o "antes"):
parado, andar, andar na diagonal, combo, E, Q, rolamento, escudo, dano, morte, círculo de colisão e HUD. E e Q do Matheus usam as mesmas colunas da folha que as do Hazaki:
a E (ruptura) segura o quadro de carga e solta o corte (passo 1 do combo), o Q (investida) toca o passo 3 do combo (a estocada, `anim.passo` 2). Nenhuma pose nova foi precisa.
Fotos e GIFs: `docs/visual_2_5d/matheus_em_jogo_2026_10_21/`.
