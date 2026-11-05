# Corte do Hazaki (Blender)

Efeito do golpe de katana feito por nós no Blender 5.2 (nada de arte de terceiros). Refazer:

```
blender -b -P corte_hazaki.py            # gera corte_hazaki.blend e corte_hazaki_folha.png (16 quadros 128x128, quantizada)
blender -b -P previa.py -- corte_hazaki_folha.png previa_corte.gif   # prévia sobre fundo escuro
```

Depois copie `corte_hazaki_folha.png` para `projeto/assets/v2/efeitos/corte_hazaki.png` (o jogo lê de lá, em `v2/efeitos.gd`).
Render leve: Cycles só com emissão, 12 amostras, ~3 s no total. A folha guarda RGB = calor (0..1) e A = intensidade; o shader do jogo tinge
com a cor do golpe (`dados/v2_combate.json`, `passos[].cor`) e espelha para `lado = -1`.

`gif_jogo.py` monta o GIF antes x depois a partir de `projeto/testes/captura_corte.gd` (captura do jogo, 60 fps fixos).
Só o **corte** usa a folha; a **estocada** continua no shader procedural antigo.

## Variantes guardadas (não usadas no jogo por padrão)
- `corte_hazaki_ciano.py`: só a energia, arco ciano em pixel art grosso (o jogo já tem a folha, opção `variante = "ciano"` em `v2/efeitos.gd`).
- `corte_hazaki_simples.py`: arco fino e afiado com flash branco, 10 quadros. Guardada porque parece magia; o corte da katana segue com `corte_hazaki.py` (katana + linha de anime).

## Folhas do jogo: uma por tamanho, 1 px de arte = 1 px do jogo (`folhas_1px.py`)
O jogo NÃO usa mais `corte_hazaki_folha.png` (128 px) esticada: ela e as folhas de efeito eram desenhadas com escala fracionária (alcance 46 pede 133 px) e pixel
de 2 px na ciano. Agora cada tamanho é renderizado de novo no Blender no tamanho final e o jogo escolhe o mais perto, com escala 1 (`v2/efeitos.gd`).
```
python folhas_1px.py [corte corte_ciano cristal estrela anel espiral]   # ~1 min; chama o Blender 4.5 ou 5.2 (variável BLENDER)
```
- Os scripts do Blender aceitam o tamanho por variável de ambiente: `CORTE_TAM=N` (quadro de N px; o corte ciano passa a sair em 1 px em vez de 64x64 dobrado) e `CORTE_GIROS=1` (a folha sai com 4 linhas: a cena girada 0, 22,5, 45 e 67,5 graus, desenhada pela câmera, sem RotSprite). Sem as variáveis o comportamento é o de antes (o mestre de 128 px).
- A lista de tamanhos fica em `folhas_1px.py` (`TAMANHOS`) e vai para `projeto/dados/v2_folhas_fx.json`, que o jogo lê. Para mudar um tamanho: edite a lista, rode o script e rode `godot --headless --import`.
- Os outros 12 dos 16 ângulos do corte são quartos de volta: o shader troca o UV, exato (o quadro é quadrado e par).
- Memória de vídeo: as 10 folhas do corte somam ~85 MB (RGBA sem compressão; a ciano, ~62 MB, só carrega com o Rastro de katana). Os 3 maiores tamanhos (224, 264, 312) servem o leque do chefe e a cruz do Q; se a memória apertar no i5, cortar o 312 e deixar o leque do chefe travar no 264.

## Corte no estilo do pixelfx em 1 px (`corte_pfx.py`, merge do #611 com o #619)
O rastro largo e as faíscas do pixelfx (do Breno, #619) agora são desenhados ponto a ponto em cada tamanho, por cima da base do Blender que o `folhas_1px.py` grava em `1px/`. Saída: `projeto/assets/v2/efeitos/corte_pfx_e<L>.png` e `corte_pfx_ciano_e<L>.png`, as que o jogo usa. Sem Blender: `python corte_pfx.py` depois de mudar a base ou os tamanhos. O `girar_corte.py` (RotSprite) e as folhas de 128 px (`corte_pfx.png`, `_r1..r3`) saíram do jogo: os 4 ângulos vêm desenhados da câmera do Blender. `corte_pfx_folha.png` e `corte_pfx_ciano_folha.png` aqui ficam como a referência de 128 px do Breno.
