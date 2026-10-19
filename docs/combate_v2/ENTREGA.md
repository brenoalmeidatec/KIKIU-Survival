# Animações de combate da v2: entrega

Pedido do Breno (19/10/2026): sistema de animação de combate de verdade, com preparo, execução, impacto, recuperação, hitbox sincronizada e
efeitos, integrado às cartas, sem fingir animação com um PNG parado. Auditoria completa em [AUDITORIA.md](AUDITORIA.md); contrato da arte em
[SPEC_ARTE.md](SPEC_ARTE.md). Arte e animação feitas por agentes Opus 5.5.

## GIFs tirados do jogo (4x, sem suavizar)
Capturados do viewport do mundo por `testes/fotos/golpes_gif.tscn` e montados por `ferramentas/gifs_golpes.py`, a 30 quadros por segundo de jogo.

| Golpe | Tipo | GIF |
|---|---|---|
| Corte da katana | corpo a corpo leve | [corte.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/corte.gif?raw=true) |
| Estocada da katana | corpo a corpo pesado | [estocada.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/estocada.gif?raw=true) |
| Combo inteiro | corte, corte, estocada | [combo.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/combo.gif?raw=true) |
| Bola de Fogo | projétil com explosão | [bola_fogo.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/bola_fogo.gif?raw=true) |
| Adagas Voadoras | projétil que gira | [adagas.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/adagas.gif?raw=true) |
| Onda de Choque | área (anel) | [onda_choque.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/onda_choque.gif?raw=true) |
| Terremoto | área (anel) | [terremoto.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/terremoto.gif?raw=true) |
| Meteoro Flamejante | magia de fogo | [meteoro.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/meteoro.gif?raw=true) |
| Lança de Geada | magia de gelo | [lanca_geada.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/lanca_geada.gif?raw=true) |
| Nuvem Venenosa | área que fica | [nuvem_veneno.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/nuvem_veneno.gif?raw=true) |
| Corvos Famintos | invocação que voa e bica | [corvos.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/corvos.gif?raw=true) |
| Runa Explosiva | armadilha (arma, pulsa, estoura) | [runa.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/runa.gif?raw=true) |
| Raio em Cadeia | magia elétrica | [raio.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/raio.gif?raw=true) |
| Aura de Fogo | área em volta do herói | [aura.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/aura.gif?raw=true) |
| Lâminas Rodopiantes | órbita que gira | [laminas.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/laminas.gif?raw=true) |
| Ventania (evolução da katana) | onda de vento e lanças | [ventania.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/ventania.gif?raw=true) |
| Juízo Final (evolução) | meteoro evoluído | [juizo_final.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/juizo_final.gif?raw=true) |
| Tempestade Primordial (evolução) | projétil evoluído | [tempestade_primordial.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/tempestade_primordial.gif?raw=true) |
| Estrondo (evolução) | anel evoluído | [estrondo.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/estrondo.gif?raw=true) |
| Furacão Glacial (evolução) | nuvem evoluída | [furacao_glacial.gif](https://github.com/brenoalmeidatec/KIKIU-Survival/blob/claude/project-thread-b3o747/docs/combate_v2/gifs/furacao_glacial.gif?raw=true) |

As prévias de cada folha sozinha (sem o jogo em volta) estão em `docs/combate_v2/previas/`.

## 1. A causa original
Os golpes secundários novos (`v2/armas_novas.gd`) desenhavam **uma imagem parada por arma**: o projétil era o PNG girado para o voo, o
meteoro era o PNG deslizando até o chão, e a nuvem e o anel eram o PNG esticado até o raio. Também não havia fases: o tiro nascia já voando e
já com hitbox, o impacto era só o número de dano, e o anel e a nuvem feriam desde o primeiro instante. A katana do herói e as invocações já
tinham quadros de verdade (folhas do Blender e de 8 direções) e não eram a causa. Detalhes em [AUDITORIA.md](AUDITORIA.md).

## 2. Arquivos modificados e criados
Modificados:
- `jogos/hordas/projeto/v2/armas_novas.gd`: as fases (PREPARO e ATIVO), o pool de impactos e marcas, o desenho pelas folhas, o crítico no tiro e o ricochete.
- `jogos/hordas/projeto/v2/armas.gd`: as Lâminas e o Anel de Brasas giram pela folha (antes, o PNG parado girado na órbita); os corvos batem as asas e mergulham para bicar pela folha (antes, o PNG com escala que respira); a aura de fogo ganhou o loop de chamas; a runa e o círculo rúnico armam, pulsam e estouram pela folha; o raio toca o estalo em cada alvo; a onda e a lança da katana (e a Ventania) voam pela folha.
- `jogos/hordas/projeto/v2/heroi.gd`: `fase_golpe()` (pronto, preparo, ativo, recuperação) para ler a fase da katana.
- `jogos/hordas/projeto/v2/roteiro.gd`: `--build=golpes` (os 36 projéteis, anéis, meteoros e nuvens no nível 5, para medir) e `--build=tudo` (esses mais corvos, aura, raio, runa, lâminas e as evoluções desses tipos).
- `docs/LICENCAS_ARTE.md`: o registro da arte nova.

Criados:
- `jogos/hordas/projeto/v2/anim_golpes.gd`: lê os índices das folhas e toca os quadros.
- `jogos/hordas/projeto/assets/v2/armas_anim/`: 138 tiras PNG e 8 índices (`indice_{projeteis,meteoros,aneis,nuvens,evo_projeteis,evo_met_aneis,evo_nuvens,magias}.json`).
- `jogos/hordas/fonte_arte/armas_anim/gerar_{projeteis,meteoros,aneis,nuvens,evo_projeteis,evo_met_aneis,evo_nuvens,magias}.py`: os geradores da arte (rodar de novo dá as mesmas folhas; os de evolução importam os da base).
- `jogos/hordas/projeto/testes/v2_combate_fases.{gd,tscn}`: o teste novo das fases.
- `jogos/hordas/projeto/testes/fotos/golpes_gif.{gd,tscn}` e `ferramentas/gifs_golpes.py`: a captura dos GIFs.
- `jogos/hordas/projeto/v2/medir_fps_golpes.ps1`, `v2/fps_golpes_{antes,depois}.txt` e `v2/fps_tudo_{antes,depois}.txt`: a medição de FPS.
- `docs/combate_v2/`: esta entrega, a auditoria, o SPEC da arte, as prévias e os GIFs.

## 3. Estrutura de nós
**Nenhuma cena do jogo mudou e nenhum nó novo foi criado.** De propósito: o jogo desenha todos os golpes secundários em três nós `Node2D`
que já existiam em `v2/armas.gd` (`no_corpo`, que recebe a luz; `no_nevoa`, sem luz; `no_brilho`, aditivo), com `draw_texture_rect_region`.
Um nó por projétil custaria FPS com centenas de golpes no PC fraco. A ordem de desenho passou a ser:
- `no_corpo`: marcas no chão (por baixo de tudo), lâminas, corvos, projéteis (quadro do voo), meteoros caindo (quadro da queda), aliados, torres e granadas.
- `no_nevoa`: o volume das nuvens e os impactos (sem luz, para o clarão não escurecer no mapa escuro).
- `no_brilho`: a carga na boca do tiro, o halo, o anel e a nuvem pelas folhas (aditivo) e o aviso do meteoro.

As cenas novas são só de teste: `testes/v2_combate_fases.tscn` e `testes/fotos/golpes_gif.tscn` (um `Node` com o script).

## 4. Os scripts
Completos no repositório (não é pseudocódigo):
- [`v2/anim_golpes.gd`](../../jogos/hordas/projeto/v2/anim_golpes.gd): `carregar()`, `de(id)`, `duracao(f)`, `quadro_em(f, t)`, `quadro_frac(f, k)`, `desenhar(...)`.
- [`v2/armas_novas.gd`](../../jogos/hordas/projeto/v2/armas_novas.gd): procure `F_PREPARO`, `vel_anim`, `tocar_fx`, `_preparar_projetil`, `_brilho_projetil_anim`, `_desenhar_anel_anim`, `_desenhar_nuvem_anim` e `_mais_perto_sem`.

**O fluxo de cada golpe** (as 4 partes ficam separadas: o quadro desenhado não decide o dano):
| Golpe | Preparo (sem hitbox) | Ativo (hitbox) | Impacto (só efeito, no evento real) | Recuperação |
|---|---|---|---|---|
| Katana | do clique ao `acerto_em` (o corpo antecipa pela folha do Blender) | o quadro do `acerto_em`, uma vez por golpe | `hit_stop`, tremor, número, empurrão, atordoamento | o resto do golpe e a janela do combo; a esquiva cancela |
| Projétil | 0,1 s na boca do herói, acompanhando ele; anel que fecha e miolo que acende | voa com o loop de voo; cada monstro uma vez; perfura, ricocheteia ou explode pelas regras da arma | a folha `impacto` toca no ponto do acerto (2x maior no crítico) | some no fim do alcance; a recarga corre |
| Anel | 0,12 s: o 1º quadro pulsa crescendo no herói | a onda abre; o quadro mostrado é o que alcançou o raio real; cada monstro uma vez | número e empurrão | os últimos quadros afinam e somem |
| Nuvem | 0,3 s: a folha `entrada` se forma, sem tique de dano | `loop` com os tiques | número | `saida` dissolve no fim da duração |
| Meteoro | o aviso no chão (já existia) com a folha `queda` girada para baixo | a queda: dano em área no instante do pouso | `impacto` (clarão, onda, fagulhas) e `marca` no chão no mesmo instante | a marca esfria e some |
| Runa | 0,5 s: a folha `armar` desenha o glifo, sem gatilho (a regra de 0,5 s já existia) | `loop` pulsando até um monstro pisar | `explosao` no instante do dano, do tamanho da área real | some com a explosão |
| Corvos | nascem em volta do herói batendo as asas (`voo`) | descem e mergulham (`bicada`) quando estão a menos de 14 px do chão; a bicada fere a cada `tique` | faíscas e número | voltam a subir com o `voo` |
| Raio | a escolha dos alvos (sem efeito antes) | o raio em código liga os alvos reais da cadeia | o `impacto` estala em cada alvo atingido | a linha some em 0,2 s |
| Aura | não tem: é contínua | o `loop` de chamas no raio real, os tiques de dano | número | some quando a aura sai |

Os tempos encolhem com a velocidade de ataque das cartas, mas presos entre 0,5x e 2,5x (`VEL_ANIM_MIN` e `VEL_ANIM_MAX`).

## 5. Recursos gráficos que ainda faltam
Feito na segunda leva: corvos e Revoada de Trovões, aura de fogo e Anel de Brasas, runa e Círculo Rúnico, o estalo do raio, a onda, a lança e a Ventania da katana, e as 16 evoluções de projétil, meteoro, anel e nuvem. O que ainda falta:
- **O raio em si** continua desenhado em código (uma linha torta que liga os alvos reais da cadeia, sorteada a cada queda). Decidi não trocar por folha: uma folha de tamanho fixo não liga dois monstros em posições quaisquer, e a linha já muda a cada raio. Ganhou o estalo animado em cada alvo.
- **Corvos em 3 direções** (de frente e de costas, como as outras invocações): a folha nova é só de lado (o código espelha). Para corvos pequenos que voam rápido, o lado lê bem.
- **Redemoinho verde** foi feito como anel que expande; a tabela antiga pedia um loop de 12 fps (giro contínuo). Se o Breno quiser o giro contínuo, falta essa folha.
- **Pagode do Trovão e Fogos de Festival** (torre e granada): já eram desenhados em código com fases próprias (cair, armar, atirar, desmontar; voar, quicar, pavio, explodir). Ficaram assim.
- O herói não tem quadros de "lançar magia" para os golpes secundários: eles saem do corpo dele sem mudar a pose, como antes (os secundários são automáticos e continuam enquanto ele anda e golpeia).

## 6. Como importar e configurar as animações
1. Ponha a tira em `jogos/hordas/projeto/assets/v2/armas_anim/<sprite>_<anim>.png` (quadros lado a lado, todos do mesmo tamanho, fundo transparente).
2. Descreva no índice do grupo (`indice_<grupo>.json`): `armas` (os ids dos golpes) e, por animação, `arquivo`, `quadro`, `n`, `fps`, `loop`, `ancora` e `gira` (opcional).
3. Abra o projeto no Godot 4.4.1 (ou rode `--headless --import`): o filtro *nearest* já é o padrão do projeto, não precisa de configuração no `.import`.
4. Grupo novo: acrescente o nome em `GRUPOS` de `v2/anim_golpes.gd`.
Os nomes de animação que o código procura: projétil `voo` e `impacto`; meteoro `queda`, `impacto` e `marca`; anel `expandir`; nuvem `entrada`, `loop` e `saida`; órbita `voo` (giro); aura `aura`; runa `armar`, `loop` e `explosao`; corvos `voo` e `bicada`; raio `impacto`; onda, lança e Ventania `voo`.

## 7. Como adicionar uma arma nova
1. Em `dados/v2_cartas.json > golpes`, crie a entrada com `id`, `tipo` (`projetil`, `anel`, `nuvem` ou `meteoro`), `nome`, `cor`, `base` (dano, recarga e os números do tipo: `vel`, `alcance`, `quantidade`, `perfura`, `explosao`, `raio`, `duracao`, `tique`, `aviso`...) e os 4 `niveis`.
2. Opcional: `preparo` em `base` troca o tempo padrão do preparo daquela arma (s).
3. Desenhe as folhas (passo 6) com o id da arma em `armas`. Sem folha, a arma funciona igual, com o desenho antigo.
4. Rode `testes/v2_combate_fases.tscn` e `testes/v2_armas_sprites.tscn`.

## 8. Como criar uma carta que muda um ataque
- **Stat do herói** (todas as armas): em `stats` de `v2_cartas.json`, `stat` = `dano`, `vel_ataque`, `area`, `critico`... A soma vai para `h.m_*` (`cartas.gd`), e o jogo recalcula na hora: a velocidade de ataque encolhe recarga e preparo (com o teto de 0,5x a 2,5x), o crítico vale para a katana e para os tiros.
- **Nível de arma**: em `niveis` do golpe, some números da base (ex.: `{"quantidade": 1}` = multigolpe, `{"perfura": 1}`, `{"explosao": 30}`, `{"raio": 15}`, `{"ricochete": 1}`). `armas.definir_golpe` recalcula da base mais os níveis, sem acumular errado.
- **Ricochete** é um número novo do projétil: depois de um acerto, o tiro muda de rumo para o vizinho mais perto (até 110 px) que ele ainda não acertou. Nenhuma carta usa ainda.
- A animação não precisa de folha nova por carta: a folha estica até o raio real e a quantidade de tiros vem dos números.

## 9. Testes que rodaram de verdade
Todos no PC do trabalho, Godot 4.4.1 (`Godot_v4.4.1-stable_win64_console.exe`), headless:
- `testes/v2_combate_fases.tscn` (novo): `falhas=0`. Confere as 83 folhas (tamanho = n x quadro), o tiro em preparo sem dano e acompanhando a boca, o impacto no acerto, um acerto por tiro, a velocidade de ataque 0,2x, 1x e 9x (preparo preso em 0,5x e 2,5x), o alvo que morre no meio do voo, o ricochete, o crítico do tiro, o anel sem dano no preparo e um acerto por monstro, a nuvem sem dano enquanto se forma, o meteoro com dano só na queda e impacto + marca, a katana só ferindo no quadro do acerto, e 36 golpes no nível 5 com 30 monstros por 10 s sem crescer o pool nem criar nó.
- **Todos os 63 testes da v2** (`testes/v2_*.tscn`): `falhas=0` e sem `SCRIPT ERROR`. Rodaram 3 por vez; `v2_status` passou do limite de 150 s com os outros rodando junto e passou sozinho (178 s, `falhas=0`), e `v2_hud` pegou um arquivo no meio de uma edição minha e passou ao rodar de novo. Depois da última mudança (as lâminas) rodei de novo `v2_hud`, `v2_armas_sprites`, `v2_combate_fases`, `v2_hud_golpes` e `v2_status`: todos com `falhas=0`.
- `gdformat -l 160 --check` em `v2`, `testes` e `scripts`: limpo.
- Com janela: `testes/fotos/golpes_gif.tscn` gerou os 20 GIFs acima; olhei os quadros de cada um.
- **Segunda leva** (corvos, runa, raio, aura, lâminas, onda, Ventania e evoluções): `v2_combate_fases` ganhou a checagem das 138 tiras, da runa que não estoura enquanto se arma e estoura armada tocando a folha, do estalo do raio em cada alvo e do volume com corvos, aura, raio, runa e lâminas juntos: `falhas=0`. Os 63 testes da v2 rodaram de novo: 61 com `falhas=0` de primeira, `v2_status` passou sozinho (passa do limite com outros rodando junto) e `v2_partida` falhou 2 de 4 vezes no Lobo Espiritual. Investiguei: o mesmo acontece no código de antes (2 de 12 sementes falham nos dois), porque o lobo às vezes nasce em cima do monstro e não ataca. Não é desta mudança; o teste agora usa uma semente fixa nesse trecho e passou 3 de 3.
- **FPS da segunda leva** (mesmo script com `-Build tudo`: os 36 mais corvos, aura, raio, runa, lâminas e 18 evoluções, 100 monstros): **antes 12,3 fps** (11,5 a 12,4) e **depois 12,5 fps** (11,9 a 13,1). Empate dentro da oscilação: as folhas novas não custaram FPS.
- **FPS** (`v2/medir_fps_golpes.ps1`: perfil Baixo, 100 monstros caçando, os 36 golpes no nível 5, 3 rodadas de 6 s, sem outro Godot rodando, na Intel HD do PC do trabalho): **antes 12,6 fps** (11,9 a 13,4) e **depois 15,2 fps** (14,5 a 15,3). O desenho dos golpes caiu de ~13 ms para ~10 ms por quadro: a folha substitui parte do desenho em código (motivos do anel, rastros). Numa rodada anterior, também limpa, deu 11,7 contra 12,1; a máquina oscila, então o certo é dizer que **não piorou** e provavelmente melhorou um pouco. É um cenário de estresse (36 golpes ao mesmo tempo); uma partida normal tem 4 a 6.

Não testado: ninguém jogou com mouse e teclado de verdade, nem no i5-3470 de casa; o CI do GitHub roda os testes de novo no PR.

## 10. Limitações
- As folhas são de geração própria por código, com 3 a 5 tons por material: mais limpas e gráficas que as imagens paradas pintadas. O Breno precisa aprovar o estilo jogando.
- As nuvens agora têm a folha (contorno e partículas) **e** o volume de fumaça antigo em código; pode ficar carregado em partidas cheias.
- O anel e a nuvem esticam a folha até o raio real: em escala não inteira os pixels ficam de tamanhos um pouco diferentes.
- O preparo de 0,1 s do tiro atrasa o primeiro acerto em 0,1 s (o DPS calculado no card de status não muda: a recarga é a mesma).
- O crítico no tiro sobe o dano médio dos projéteis em ~10% (a chance base da katana é 10% com dano 2x).
- A aura continua com o shader antigo por baixo das chamas da folha, e a runa com o brilho redondo; ficou de propósito, para não perder a leitura do raio da área.
- O corvo de lado tem as asas do alto meio quadradas e a onda da katana é a folha mais simples do lote (o agente que desenhou apontou os dois como os primeiros a refazer).
