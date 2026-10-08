# Port do KIKIU Survival para PS Vita — status

Projeto paralelo, iniciado em 2026-10-06 pelo Claude do Alisson (PC). Alvo: Vita **desbloqueado** (HENkaku/Ensō +
VitaShell), distribuído como `.vpk` homebrew. Não existe caminho oficial: a Sony fechou o programa de desenvolvimento e a loja.

## Por que não dá para levar o projeto atual direto

- **Não existe Godot 4 para Vita.** O renderer *Compatibility* do Godot 4 exige GLES3; o Vita só tem GLES2 (drivers
  não oficiais PVR_PSP2) ou vitaGL. O único port vivo é o [godot-vita](https://github.com/SonicMastr/godot-vita) do
  SonicMastr, base **Godot 3**.
- Portanto o port é um **backport para Godot 3** com adaptação ao hardware: CPU Cortex-A9 444 MHz, 512 MB RAM,
  128 MB VRAM, tela 960×544.
- O que pesa no backport (medido em `jogos/hordas/projeto`, 95 scripts / ~19,4 mil linhas): 217 `await`, 106 lambdas,
  25 cenas `.tscn` formato 3 (o 3.x não lê), online com `@rpc`/ENet, e o shader `escuridao.gd` (usa `uniform vec4 luzes[16]`,
  arrays `const` e `hint_screen_texture` — nada disso existe no GLES2 do 3.x).

## O piloto (`piloto/`)

Antes de converter 19 mil linhas, medir no aparelho se o jogo cabe no Vita. O piloto é um projeto Godot 3 pequeno com
**sprites reais do jogo** (10 inimigos, o João, o chão) e as técnicas que o port vai usar:

- **Horda orientada a dados** (`horda.gd`): nenhum nó por inimigo; arrays paralelos e um único `_draw`.
- **Proteções de desempenho**: lógica completa só perto da tela; longe, 1 quadro a cada `lod_longe` e sem separação;
  separação por grade espacial com teto de 6 vizinhos, recalculada 1 quadro em 3; desenho só do que está na tela, com
  teto `max_desenho`; ordem por Y com baldes (linear, sem `sort_custom`); quem se perde longe renasce no anel em volta.
- **Atlas único** montado na carga (corpos + sombra + sangue): o batching do GLES2 junta tudo. No PC, 300 inimigos =
  ~78 draw calls com atlas contra ~195 sem.
- **Luz compatível com GLES2** (`luz.gd`), dois jeitos: BUFFER (viewport de 1/4 da área, gradientes somados, multiplica a
  cena; aguenta 24 luzes) e SHADER (`escuridao.shader`, 8 luzes em uniforms escalares). Nenhum usa `Light2D` (multi-pass
  no GLES2) nem lê a tela.
- **480×272** = metade exata de 960×544 → escala 2× inteira (o 3.5 não tem stretch inteiro; 640×360 fica 1,5× torto)
  e 1/4 do fill-rate da tela nativa. A rampa também mede 640×360 para comparar.
- **Governador** no modo livre: mira 30 fps; abaixo de 29 corta `max_desenho` e aumenta o LOD; acima de 50 devolve.
- **Sombras**: blob (elipse) por inimigo, no mesmo lote do atlas.

Folha de inimigo do jogo: 3 colunas × N linhas (vistas: 1 ou 5). **A 3ª coluna é a silhueta branca do flash de dano**;
o andar tem só 2 quadros.

### Rampa automática

Ao abrir, o piloto roda sozinho 22 passos (~2 min): N = 50/100/200/300/450/600 × luz SEM/BUFFER/SHADER, mais 4 variantes
com 300 (sem atlas, sem ordem Y, 640×360 com buffer e com shader). Cada passo: 1,5 s de aquecimento + 4 s medindo.
No fim mostra a tabela na tela e grava o CSV em `ux0:data/kikiu_piloto.csv` (e em `user://`). Colunas: fps, quadro
médio/pior (ms), lógica e desenho da horda (ms de CPU), draw calls 2D, inimigos perto/desenhados, memória.

No PC (só para ver se roda e o visual; o fps do PC não diz nada do Vita):
`Godot_v3.5-rc5-vita.exe --path piloto --bench-rapido` (rampa curta, imprime o CSV, salva fotos dos passos com 300).

### Controles (modo livre, depois da rampa)

Analógico: mover · D-pad ↑/↓: ±50 inimigos · △: modo de luz · □: atlas · ○: ordem Y · L: 480×272↔640×360 ·
R: governador · Start: refaz a rampa. O HUD mostra o índice do último botão (confere o mapa do Vita no aparelho:
pelo código do fork, Cross=0, Circle=1, Square=2, Triangle=3, L=6, R=7, Select=10, Start=11, D-pad=12–15).

## Ferramentas (fora do Git)

- Editor: `Godot_v3.5-rc5-vita.exe` (70 178 304 bytes) e template `vita_template_3.5.rc5.tpz` (18 561 647 bytes) do
  release [3.5-rc5-vita1](https://github.com/SonicMastr/godot-vita/releases/tag/3.5-rc5-vita1).
- No PC do Alisson: `E:\Dev\KIKIU-Vita\ferramentas\`, em modo autocontido (`._sc_` ao lado do exe; o template fica
  extraído em `editor_data/templates/3.5.rc5/` com `version.txt` e `vita_release.zip`).
- Exportar: `GODOT_VITA=<caminho do exe> ./exportar.sh` → `build/kikiu_piloto.vpk`. Pegadinhas que o script resolve:
  o exportador ignora o caminho pedido e grava `<título>.vpk` no diretório atual (que o `--path` troca para o projeto);
  o projeto precisa de `vram_compression/import_etc=true` e `import_etc2=true`, senão dá "configuration errors" sem
  detalhe; o LiveArea (`piloto/vita/`, PNG 8 bits com paleta) é obrigatório porque o `template.xml` aponta para
  `bg.png`/`startup.png`.
- Fase 2 possível: a branch `3.x` do fork virou Godot **3.7-dev com vitaGL** (CI até 2026-03, artefatos expirados).
  Só vale compilar (VitaSDK no WSL) se o rc5 ficar no limite. vitaGL exige o `libshacccg.suprx` extraído no Vita.

## Protocolo de teste no Vita

1. Copiar `build/kikiu_piloto.vpk` para o Vita (VitaShell: USB ou FTP com Select) e instalar.
2. Abrir "KIKIU Piloto" e **não tocar em nada** por ~2 min, até a tabela aparecer.
3. Mandar uma foto da tabela **ou** o arquivo `ux0:data/kikiu_piloto.csv`. Se travar ou fechar, anotar em que passo
   estava (o HUD mostra "RAMPA passo N/22").

## Critério de decisão

- **Segue para o backport** se, em 480×272 com luz BUFFER ou SHADER, 300 inimigos ficarem ≥ 30 fps.
- **Fase 2 (vitaGL / 3.7)** se ficar entre 20 e 30 fps.
- **Propor abandonar** se 100 inimigos não segurarem 30 fps.

## Próximo

- [ ] Resultado do piloto no Vita (Alisson).
- [ ] Se seguir: plano do backport por sistema (horda e combate primeiro, depois HUD/cartas/loja, online por último ou
      fora da v1), conversão das cenas, troca do `escuridao.gd` pela luz BUFFER.

## Resultado 1 — Vita real, 3.5-rc5 (2026-10-07) · `medicoes/vita_rc5_2026-10-07.csv`

| N (480×272, atlas) | sem luz | buffer | shader |
|---|---|---|---|
| 50 | 59,5 | 47,9 | 46,6 |
| 100 | 47,5 | 39,2 | 39,9 |
| 200 | 31,9 | 28,5 | 29,1 |
| 300 | 23,8 | 21,7 | 22,7 |
| 450 | 17,9 | 17,0 | 16,5 |
| 600 | 13,2 | 13,6 | 13,1 |

Rodou os 22 passos sem travar; pior quadro sempre perto da média (sem soluço de GC/carga).
**Leitura (regressão sobre os passos):** quadro ≈ 13 ms fixos + **0,20 ms por inimigo na tela**, metade lógica
(0,088 ms por inimigo perto) e metade `_draw` (0,093 ms por inimigo desenhado). Ou seja: **o gargalo é CPU em
GDScript** (~30–45× mais lento que no PC), não a GPU. Cabem ~100 inimigos na tela a 30 fps, ~17 a 60 fps.
- **GPU sobra:** 640×360 não aumentou o custo fixo (15,2 ms contra 14,8); o quadro só piorou porque mais inimigos
  ficam na tela. Luz custa ~2 ms; buffer e shader empatam.
- **Draw call é caro no PVR_PSP2:** sem atlas (241 draw calls contra 77) o custo fixo subiu 7,5 ms (~45 µs por draw call).
  O atlas fica obrigatório.
- `mem_mb` = 0: o template release não conta memória estática (ignorar a coluna).
- Pelo critério, caiu na faixa **20–30 fps → fase 2**. Mas a fase 2 certa não é vitaGL (que ataca driver/GPU, que não
  são o gargalo), e sim tirar o laço quente da horda do GDScript. Plano: **2a** otimizar o GDScript do piloto e medir de
  novo (barato, mesmo template); **2b** se não chegar a ~200 na tela a 30 fps, módulo C++ da horda compilado no template
  (exige montar o build do Vita: VitaSDK no WSL, o mesmo trabalho da 3.7/vitaGL).
- Risco que o piloto ainda não mede: o resto do jogo (armas, projéteis, coletáveis, HUD) também é GDScript por quadro.

## Piloto v2 (2026-10-07) — alinhado com a main de hoje + otimização 2a · aguardando medição no Vita

- **Folhas novas do #103:** monstros com 6 quadros de andar + 1 de flash (7 colunas; bug/spam continuam com 3).
  Fase pela distância andada (um ciclo a cada ~0,7 da altura do bicho). `tipos.gd` agora tem `cols`.
- **#109 (qualidade gráfica):** o perfil `baixa` de `dados/qualidade.json` já é quase o que o Vita precisa
  (`escuro_luzes: 8` = o shader do piloto, sem halo/névoa/sombra projetada/vinheta). No backport, criar um perfil
  `vita` derivado dele em vez de inventar chaves novas.
- **2a aplicada:** movimento todo quadro, direção/vista 1 em 2, separação 1 em 4, grade 1 em 2; sombra assada em cada
  quadro do atlas (1 draw por inimigo); dados por tipo em arrays; chão e sangue só redesenham quando mudam (desenho
  retido do CanvasItem); luzes dos fogos por lista pronta; golpe pela grade.
- **Projéteis** (4 a cada 0,2 s, colisão pela grade): acertam e somem sem matar, para a densidade na tela ficar
  comparável à medição 1 (só o golpe mata, como na v1). Coluna `proj_ms` no CSV.
- Rampa v2: 13 passos (~75 s): N 100–500 × luz SEM/BUFFER, + 300 shader, 300 sem projéteis, 300 em 640×360.
- Pegadinha: o 1º `-e -q` pode sair antes de importar arquivo novo; o `exportar.sh` roda duas vezes.
- **Bug do exportador (0xF0030000 no VitaShell):** `vita-mksfoex.cpp` guarda o TITLE_ID com ponteiro para string
  temporária já liberada; às vezes o `param.sfo` sai com `TITLE_ID = "KIKIU Piloto"` e o VitaShell recusa
  (`VITASHELL_ERROR_INVALID_TITLEID`: 9 caracteres, maiúsculos). É aleatório (a v1 passou por sorte). O `exportar.sh`
  agora roda `conserta_sfo.py`, que regrava TITLE_ID/TITLE/STITLE e falha se não conferir.
- Envio por FTP: se a tela do Vita apagar, o Wi-Fi para e o arquivo chega truncado. Conferir o tamanho na listagem.

## Resultado 2 — Vita real, piloto v2 (2026-10-08) · `medicoes/vita_v2_2026-10-08.csv`

| N (480×272, com projéteis) | sem luz | buffer |
|---|---|---|
| 100 | 59,2 | 48,7 |
| 200 | 44,9 | 39,7 |
| 300 | 36,4 | **30,4** |
| 400 | 29,4 | 25,7 |
| 500 | 24,0 | 22,0 |

**Regressão, v1 → v2:** desenho 0,093 → **0,045 ms** por inimigo (metade: 1 draw por inimigo, sem Dictionary);
lógica 0,088 → 0,064 ms (-27%, menos que o esperado: virou o custo dominante); fixo 13,3 → 10,7 ms.
**Cabem ~185 inimigos na tela a 30 fps** (eram 100) e ~49 a 60 fps. Projéteis custam 0,13–0,26 ms (barato).
GPU continua sobrando (640×360 segue a mesma reta). Pior quadro ~1,2× a média (a grade refeita 1 em 2 alterna o custo).
**Critério:** 300 inimigos com luz a ≥ 30 fps → **passou, no limite** (30,4 com buffer). Viável a 30 fps com orçamento
de ~150–180 na tela; sobra pouco para o resto do jogo em GDScript (armas, efeitos, HUD), que o piloto não tem.

## Fase 2b — template próprio com módulo C++ (noite de 2026-10-08) · aguardando teste no Vita

- **Build:** distro WSL `vita-build` (Ubuntu 24.04), VitaSDK 2026.08 / GCC 15.2, godot-vita `7ca87562` + `modulo/horda_vita`,
  `module_bullet_enabled=no`. Passo a passo e pegadinhas em `compilar/LEIAME.md`. Do zero ~17 min; incremental ~30 s.
- **`HordaVita` (C++):** simulação, grade por contagem + prefixos, separação (teto 8 vizinhos), LOD dos distantes,
  projéteis, golpe, ordem por Y (sort de chaves 64 bits) e desenho de todos os inimigos + projéteis numa triangle
  array (no GLES2 do fork = 1 `glDrawElements`; lotes de 1800 quads cabem no buffer padrão de 128 KB).
  `horda_nativa.gd` mantém a interface da `horda.gd`; sem o módulo (editor do PC) o piloto cai na horda em GDScript.
- **`VitaHW` (C++):** touch frontal e **traseiro** normalizados (o fork só lê o frontal, cru), acelerômetro/giroscópio
  (`SceMotion_stub` linkado pelo SCsub do módulo), clocks reais (confirma 444 MHz) e bateria.
- **Piloto v3:** stick virtual no touch frontal esquerdo, especial no direito, rolamento no traseiro, câmera que inclina
  (Select), som espacial (pan/atenuação por posição, reverb, alargamento Haas, limiter; o Vita só tem saída estéreo,
  então não existe Dolby de verdade), clocks/bateria no HUD, rampa 100–800 inimigos, coluna `main_ms`.
- **Verificado no PC:** build Linux (x11) do mesmo commit com o módulo, rodando o piloto pelo WSLg: lógica da horda
  0,02–0,05 ms com 300–800 inimigos (GDScript no mesmo PC: 0,8–1,7 ms), `_process` inteiro ~0,1 ms, visual certo
  (`medicoes/pc_x11/`).
- **Vita3K:** não roda o driver PVR_PSP2 (até o template oficial para no "OpenGL ES 2.0 Initialization Failed"), então
  não prova a tela. Mas o eboot próprio se comporta igual ao oficial até esse ponto (carrega, resolve imports, inicia
  libc/fios, lê o projeto): o SDK novo não quebra a abertura.
- **Três vpks** (convivem): `kikiu_piloto.vpk` (KIKU00001, template oficial, GDScript), `kikiu_piloto_cpp.vpk`
  (KIKU00002, C++ + hardware), `kikiu_diag.vpk` (KIKU00003, template novo sem módulo: se o C++ não abrir e o diag abrir,
  o problema é o módulo; se nenhum abrir, é o SDK novo).

## O jogo de verdade convertido (noite de 2026-10-08) · `kikiu_vita.vpk` (KIKU00004) aguardando teste no Vita

- **Conversor automático** (`conversor/`): `exportar_jogo.sh` pega a `main` (`git archive`), converte os 88 scripts
  GDScript 4 → 3 (`conversor.py` + `lambdas.py`), monta o projeto Godot 3 (`gerar.py`), confere (`verificar.py`:
  88/88 carregam com os autoloads ativos) e exporta com o template próprio. Rodar de novo a cada atualização da main.
  O que não tem tradução direta está no autoload `G4` (`conversor/g4.gd`). Detalhes do que existe/não existe no 3.5
  em `PLANO_BACKPORT.md`.
- **No PC (Godot 3.5 do fork, GLES2):** tela de título, partida com bot (`--bot --heroi=lucas`), chefe, cartas de
  nível, HUD, loja: 40 s de partida sem nenhum erro, inclusive rodando o `game.pck` exportado. `rodar.py` itera:
  roda N segundos, tira foto (`--g4-foto=N`), agrupa erros.
- **Resolução do jogo: 640×360** (a interface foi desenhada para isso; no Vita escala 1,5× com faixa fina; o piloto
  mostrou que a GPU aguenta). No Vita o `G4` liga o perfil de qualidade `baixa` e um contador de fps no canto.
- **Patches do motor** (`compilar/patches_motor.py`, aplicados pelo `build_vita.sh`): L/R do Vita = JOY_L/JOY_R (4/5);
  posição do "soltar" do touch corrigida. O touch frontal já vira mouse em 960×544 no fork.
- **Ainda não está no Vita:** a horda do jogo continua em GDScript (o `HordaVita` do piloto ainda não está ligado ao
  `inimigos.gd`); o shader da escuridão do horror usa recursos do Godot 4 (fases de horror podem dar erro de shader);
  online desligado (sem conexão).
