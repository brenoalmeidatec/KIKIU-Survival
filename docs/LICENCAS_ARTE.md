# Arte, som e fontes de terceiros: o que pode e como registrar

**Regra (Alisson, 2026-10-12):** nada de arte com direitos autorais. Arte de terceiros de **livre uso** pode e deve ser usada quando economiza esforço e é compatível com o nosso contexto. Isto substitui a regra antiga ("nada de arte de terceiros no Git", #132 e #116).

## O que serve ("livre uso")
Serve a licença que permite, ao mesmo tempo, **uso comercial**, **redistribuição dentro do jogo** (o jogo vai ser publicado) e **modificação** (a gente recorta, reduz, quantiza, gera normal map):
- **CC0 / domínio público / Unlicense**: sem condição.
- **CC BY (3.0 ou 4.0)**: com **crédito** (autor, título, licença, link) na tela de Créditos e neste registro.
- **OGA-BY, MIT, BSD, zlib** (para assets) e **SIL OFL** (fontes): com o texto da licença quando ela pedir.

## O que NÃO serve
- Qualquer coisa com **direitos autorais reservados**: sem licença declarada, "uso pessoal", "só para estudo", capturas ou extrações de outros jogos, filmes e marcas, fan art de propriedade alheia.
- **CC BY-NC** (não comercial) e **CC ND** (sem derivados): a gente vende ou publica o jogo e adapta tudo.
- **Copyleft** (CC BY-SA, GPL, LGPL): só com o OK do Alisson, caso a caso (pode obrigar a abrir os arquivos adaptados).
- **Pago:** só com o OK do Breno (regra do `CLAUDE.md`: nada pago sem ele).
- Licenças que deixam **usar no jogo mas não redistribuir o arquivo avulso** (como animações de serviços que exigem conta): só o **resultado cozido** (sprite já renderizado) vai ao Git, nunca o arquivo-fonte cru.

## Compatível com o nosso contexto
Além da licença, o item tem de combinar com o jogo: pixel art 2.5D a 45 graus, escuro com poças de luz coloridas (`docs/visual_2_5d/`), herói de ~39 px em 960x540, paleta enxuta. O que for diferente a gente adapta no pipeline (recorte, redução com filtro BOX, paleta, contorno de 1 px, normal map pelo gerador); se a adaptação custar mais do que fazer no Blender, não vale.

## Como usar (passo a passo)
1. Ache o arquivo e **confira a licença na página dele no dia** (a licença é por arquivo; pacotes às vezes misturam).
2. Sites que pedem login para baixar (Freesound, Mixamo): quem tem a conta baixa; o Claude não entra em contas.
3. Guarde o arquivo em `jogos/hordas/projeto/assets/` (arte e som) ou `assets/fonte/` (fonte) junto do texto da licença quando ela exigir (`LICENSE.txt` ou `OFL.txt` ao lado).
4. **Registre na tabela abaixo** (todas as colunas) e ponha o crédito na tela de Créditos se a licença pedir.
5. Música e efeitos sonoros também entram no `docs/LICENCAS_AUDIO.md`.
6. Na dúvida, não use e pergunte.

## Registro
| Arquivo(s) no jogo | Onde é usado | Autor | Fonte (link) | Licença | Crédito exigido? | Mudanças nossas | Data |
|---|---|---|---|---|---|---|---|
| `assets/fonte/jersey10/` | títulos da v2 | The Soft Type Project | Google Fonts (Jersey 10) | SIL OFL 1.1 | texto da licença (`OFL.txt`) e Créditos | nenhuma | 2026-10-11 |
| `assets/fonte/PressStart2P.ttf` | números e HUD | CodeMan38 | Google Fonts (Press Start 2P) | SIL OFL 1.1 | Créditos | nenhuma | desde a v1 |
| `assets/audio/musica/*.ogg` | música | Kevin MacLeod (incompetech.com) | incompetech.com | CC BY 4.0 | sim (Créditos e `LICENCAS_AUDIO.md`) | cortes, laço, ganho, OGG | 2026-10-12 |
| ~~`assets/fonte/pixelify_sans/`~~ | removida em 2026-10-12 (o 5 saía como S: "500" lia-se "800"); trocada pela Spleen | The Pixelify Sans Project | Google Fonts (Pixelify Sans) | SIL OFL 1.1 | - | - | 2026-10-11 |
| `assets/fonte/spleen/spleen-8x16.otf` | texto corrido e valores da v2 (`Dados.fonte_texto`), sempre em 16 px | Frederic Cambus | https://github.com/fcambus/spleen (release 2.2.0) | BSD de 2 cláusulas | sim: aviso de copyright e texto da licença (`LICENSE.txt` ao lado; linha na tela de Créditos) | nenhuma | 2026-10-12 |
| `assets/v2/armas/*.png` (37 sprites e 25 normais; lista em `indice.json`) | sprites das armas da v2 (ainda não ligados ao código) | Alisson (arte própria) | gerada no GPT pelo Alisson; folhas-fonte em `jogos/hordas/prototipos/cara_nova/objetos/fonte_armas_*.webp` | própria do autor (sem licença de terceiros) | não | recorte por célula, redução BOX, alfa binário (projéteis e aliados) ou brilho virou alfa (efeitos, fundo preto), quantização sem dithering, normal map (projéteis e aliados) | 2026-10-12 |

(Itens novos entram no fim da tabela.)
