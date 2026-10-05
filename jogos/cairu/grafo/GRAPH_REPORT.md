# Graph Report - jogo  (2026-10-05)

## Corpus Check
- Corpus is ~41,309 words - fits in a single context window. You may not need a graph.

## Summary
- 1019 nodes · 2812 edges · 41 communities
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 301 edges (avg confidence: 0.64)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- estilo_gba + paleta (estilo_gba.py)
- jogo + menu (jogo.gd)
- visual + controles (visual.gd)
- cairu + extras_testes (capítulo Extras: Sala de testes)
- novos_mapas + laboratorio (novos_mapas.py)
- gerar_audio + violao (gerar_audio.py)
- historia + roteiro (historia.gd)
- rede + mundo (rede.gd)
- mundo + rede (mundo.gd)
- cairu + presidencia (capítulo Capítulo 1: Cairu)
- personagem + mundo (personagem.gd)
- cairu + cap2 (personagem lucas)
- sala204_gba (sala204_gba.py)
- mundo + diretor (_passo())
- mundo + palco_lateral (_atravessar())
- dialogo + jogo (dialogo.gd)
- mundo + animacao (ligado())
- mundo + movel (_entrar())
- base (base.gd)
- animados_mapas + visao_geral (animados_mapas.py)
- reflexo + qw (som())
- cairu + extras_testes (personagem beto)
- cairu + extras_testes (cena h1_chegada)
- animado (animado.gd)
- mundo + pausa (_unhandled_input())
- mapa (mapa.gd)
- figurantes + personagem (figurantes.gd)
- cairu + extras_testes (personagem joao)
- escada (escada.gd)
- minijogo + mangueio (minijogo.gd)
- violao + violao_musica (violao.gd)
- consertar_pc + minijogo (consertar_pc.gd)
- cairu + laboratorio (mapa laboratorio)
- cairu + extras_testes (personagem matheus)
- memoria + minijogo (memoria.gd)
- abas + minijogo (abas.gd)
- cabos + minijogo (cabos.gd)
- digitar + minijogo (digitar.gd)
- impressora + minijogo (impressora.gd)
- virus + minijogo (virus.gd)
- esquiva + minijogo (esquiva.gd)

## God Nodes (most connected - your core abstractions)
1. `capítulo Capítulo 1: Cairu` - 115 edges
2. `capítulo Extras: Sala de testes` - 76 edges
3. `som()` - 55 edges
4. `_passo()` - 49 edges
5. `r()` - 35 edges
6. `ret()` - 30 edges
7. `tocar_cena()` - 30 edges
8. `faixa_sombra()` - 28 edges
9. `_executar()` - 26 edges
10. `ligado()` - 24 edges

## Surprising Connections (you probably didn't know these)
- `cena h4_matheus` --plays_minigame--> `minijogo digitar`  [EXTRACTED]
  capitulos/cairu.json → scripts/minijogo.gd
- `cena h3` --plays_minigame--> `minijogo esquiva`  [EXTRACTED]
  capitulos/cap2.json → scripts/minijogo.gd
- `_tecla()` --calls--> `som()`  [INFERRED]
  minijogos/cabos.gd → scripts/jogo.gd
- `_process()` --calls--> `som()`  [INFERRED]
  minijogos/esquiva.gd → scripts/jogo.gd
- `_tecla()` --calls--> `som()`  [INFERRED]
  minijogos/esquiva.gd → scripts/jogo.gd

## Import Cycles
- None detected.

## Communities (41 total, 0 thin omitted)

### Community 0 - "estilo_gba + paleta (estilo_gba.py)"
Cohesion: 0.08
Nodes (57): main(), ar_cond(), bordas(), capacho(), carregar(), cartazes(), folhas_das_portas(), grama() (+49 more)

### Community 1 - "jogo + menu (jogo.gd)"
Cohesion: 0.07
Nodes (65): pasta_audio_externa(), _juntar_falas(), _arq_slot(), _carregar_opcoes(), _carregar_progresso(), _gravar(), _gravar_slot(), _ler() (+57 more)

### Community 2 - "visual + controles (visual.gd)"
Cohesion: 0.06
Nodes (57): _desenhar_efeitos(), _process(), _ready(), _textura(), sair(), aplicar(), descrever(), nome_botao() (+49 more)

### Community 3 - "cairu + extras_testes (capítulo Extras: Sala de testes)"
Cohesion: 0.05
Nodes (53): capítulo Extras: Sala de testes, cena ar_condicionado_sala, cena arvore, cena banheiro, cena banner, cena bebedouro, cena cantina, cena cardapio (+45 more)

### Community 4 - "novos_mapas + laboratorio (novos_mapas.py)"
Cohesion: 0.12
Nodes (34): armario_mat(), armario_ti(), balcao(), cadeira_escritorio(), cadeira_lucas(), cadeiras_espera(), divisoria(), fundo() (+26 more)

### Community 5 - "gerar_audio + violao (gerar_audio.py)"
Cohesion: 0.08
Nodes (30): acorde(), _agogo(), _caixa(), _chimbal(), compor(), env(), freq(), gravar_wav() (+22 more)

### Community 6 - "historia + roteiro (historia.gd)"
Cohesion: 0.10
Nodes (42): capitulos(), imagem_mapa(), ler_json(), ler_texto(), limpar_cache(), pasta_externa(), proximo_capitulo(), voz() (+34 more)

### Community 7 - "rede + mundo (rede.gd)"
Cohesion: 0.09
Nodes (33): aplicar_estado_rede(), estado_rede(), _acabou(), _bem_vindo(), _cena(), _cheguei(), _escolher(), _estado() (+25 more)

### Community 8 - "mundo + rede (mundo.gd)"
Cohesion: 0.11
Nodes (35): nome(), parar(), _atualizar_remotos(), _celula_livre_perto(), _checar_ao_entrar(), _checar_gatilhos(), _escolher_cena(), _fechar_pausa() (+27 more)

### Community 9 - "cairu + presidencia (capítulo Capítulo 1: Cairu)"
Cohesion: 0.08
Nodes (28): capítulo Capítulo 1: Cairu, cena armario_antigo, cena cadeira_presidente, cena joao_lab, cena mesa_museu1, cena mesa_museu2, cena mesa_museu3, cena mj_abas_ganhou (+20 more)

### Community 10 - "personagem + mundo (personagem.gd)"
Cohesion: 0.16
Nodes (27): _ready(), tocar(), pasta_personagens(), textura(), _carregar_retrato(), _checar_rotinas(), _criar_npc(), _entrar_pela_porta() (+19 more)

### Community 11 - "cairu + cap2 (personagem lucas)"
Cohesion: 0.16
Nodes (23): capítulo Capítulo 2: [título], cena abertura, cena beto_depois, cena espera, cena final, cena h1, cena h2, cena h2_nicao (+15 more)

### Community 12 - "sala204_gba (sala204_gba.py)"
Cohesion: 0.26
Nodes (22): ar_cond(), bolinha(), bordas(), carteira(), estante(), extintor(), finalizar(), fundo() (+14 more)

### Community 13 - "mundo + diretor (_passo())"
Cohesion: 0.16
Nodes (24): _andar_sem_esperar(), _dialogo(), _parceiro(), _passo(), rodar(), rodar_cena(), _fim_de_cena(), animar() (+16 more)

### Community 14 - "mundo + palco_lateral (_atravessar())"
Cohesion: 0.14
Nodes (22): mexer_porta(), porta_para(), porta_perto(), _atravessar(), _limites_do_mapa(), _ponto_de_passagem(), aparecer(), entrar() (+14 more)

### Community 15 - "dialogo + jogo (dialogo.gd)"
Cohesion: 0.16
Nodes (23): quadro(), _avancar(), _capturar_fundo(), _comecar_fala(), _enfase(), _entrar_caixa(), _entrar_corpos(), _escurecer() (+15 more)

### Community 16 - "mundo + animacao (ligado())"
Cohesion: 0.17
Nodes (21): _rampa(), defs(), estouro(), existe(), folha(), linha(), resolver(), bloqueia() (+13 more)

### Community 17 - "mundo + movel (_entrar())"
Cohesion: 0.15
Nodes (17): lista_mapas(), mapa(), _testar_depois(), _process(), solido(), usar_imagem(), _defs_npcs(), _entrar() (+9 more)

### Community 18 - "base (base.gd)"
Cohesion: 0.18
Nodes (15): _atualizar_rodape(), _comecar(), _desenhar(), _iniciar(), _mostrar_intro(), _pode_tentar(), _ready(), _resultado() (+7 more)

### Community 19 - "animados_mapas + visao_geral (animados_mapas.py)"
Cohesion: 0.18
Nodes (9): brilhos(), carregar(), leds(), manchas(), montar(), no_mapa(), papeis_mural(), rgb() (+1 more)

### Community 20 - "reflexo + qw (som())"
Cohesion: 0.16
Nodes (9): _process(), _tecla(), _falhou(), _nova(), _process(), _tecla(), som(), minijogo qw (+1 more)

### Community 21 - "cairu + extras_testes (personagem beto)"
Cohesion: 0.30
Nodes (14): cena beto, cena beto_aposta, cena beto_cismado, cena beto_dedo, cena beto_lucia, cena beto_mangueiro, cena espera_recepcao, cena fabio (+6 more)

### Community 22 - "cairu + extras_testes (cena h1_chegada)"
Cohesion: 0.26
Nodes (14): cena h1_chegada, cena lukako, cena lukako_depois, cena lukako_desenho, cena lukako_ideia, cena lukako_qw, cena mauro_cana, cena mauro_cantada (+6 more)

### Community 23 - "animado (animado.gd)"
Cohesion: 0.23
Nodes (15): _bolhas(), _brilho(), _draw(), _globo(), _led(), _letreiro(), _linha_codigo(), _nuvens() (+7 more)

### Community 24 - "mundo + pausa (_unhandled_input())"
Cohesion: 0.19
Nodes (14): alvo(), mostrar_debug(), _abrir_painel(), _abrir_pausa(), _alvo(), _desocupar_pausa(), _pausa_escolha(), _texto_diario() (+6 more)

### Community 25 - "mapa (mapa.gd)"
Cohesion: 0.26
Nodes (12): _bordas(), _chao(), _corredor_cairu(), _criar_folhas(), _draw(), _parede_cairu(), _porta(), _ret() (+4 more)

### Community 26 - "figurantes + personagem (figurantes.gd)"
Cohesion: 0.32
Nodes (13): _andar(), _caminho_livre(), _defs(), _livre(), _mauro(), _ponto_livre(), _sentar(), atualizar() (+5 more)

### Community 27 - "cairu + extras_testes (personagem joao)"
Cohesion: 0.24
Nodes (9): cena joao, cena joao_depois, cena joao_dor, cena joao_filho, cena joao_trabalho, cena teste_joao_banco, cena teste_joao_passando_mal, cena teste_joao_tombo (+1 more)

### Community 28 - "escada (escada.gd)"
Cohesion: 0.35
Nodes (10): _avisar(), _boneco(), _comecar(), _desenhar(), _dizer(), _errou(), _nova_tecla(), _pos_degrau() (+2 more)

### Community 29 - "minijogo + mangueio (minijogo.gd)"
Cohesion: 0.21
Nodes (7): _process(), _marcar(), _ready(), _unhandled_input(), criar(), minijogo mangueio, sinal terminou

### Community 30 - "violao + violao_musica (violao.gd)"
Cohesion: 0.26
Nodes (8): _agora(), _desenhar(), _nota_do_acorde(), _process(), _ready(), _tecla(), tocar_nota(), minijogo violao

### Community 31 - "consertar_pc + minijogo (consertar_pc.gd)"
Cohesion: 0.29
Nodes (9): _comecar(), _desenhar(), _errou(), _icone(), _process(), _proxima(), _quebrar(), _tecla() (+1 more)

### Community 32 - "cairu + laboratorio (mapa laboratorio)"
Cohesion: 0.20
Nodes (9): cena ar_condicionado, cena armario_materiais, cena armario_ti, cena aviso_lab, cena balcao, cena computadores, cena divisoria, cena janelas (+1 more)

### Community 33 - "cairu + extras_testes (personagem matheus)"
Cohesion: 0.47
Nodes (8): cena h4_ganhou, cena h4_matheus, cena h4_perdeu, cena matheus_anime, cena matheus_depois, cena matheus_games, cena matheus_gastar, cena teste_minijogos

### Community 34 - "memoria + minijogo (memoria.gd)"
Cohesion: 0.36
Nodes (6): _comecar(), _mostrar(), _piscar(), _rodada_nova(), _tecla(), minijogo memoria

### Community 35 - "abas + minijogo (abas.gd)"
Cohesion: 0.32
Nodes (4): _flagra(), _process(), _tecla(), minijogo abas

### Community 36 - "cabos + minijogo (cabos.gd)"
Cohesion: 0.29
Nodes (4): _desenhar(), _tecla(), _y(), minijogo cabos

### Community 37 - "digitar + minijogo (digitar.gd)"
Cohesion: 0.32
Nodes (4): _comecar(), _proxima(), _tecla(), minijogo digitar

### Community 38 - "impressora + minijogo (impressora.gd)"
Cohesion: 0.32
Nodes (4): _comecar(), _nova_faixa(), _tecla(), minijogo impressora

### Community 39 - "virus + minijogo (virus.gd)"
Cohesion: 0.29
Nodes (4): _celula(), _desenhar(), _tecla(), minijogo virus

### Community 40 - "esquiva + minijogo (esquiva.gd)"
Cohesion: 0.29
Nodes (3): _process(), _tecla(), minijogo esquiva

## Knowledge Gaps
- **62 isolated node(s):** `sinal terminou`, `sinal fechou`, `sinal terminou`, `sinal opcoes_mudaram`, `sinal escolheu` (+57 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 187 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `tocar_cena()` connect `mundo + rede (mundo.gd)` to `personagem + mundo (personagem.gd)`, `mundo + diretor (_passo())`, `rede + mundo (rede.gd)`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Why does `mapa recepcao` connect `cairu + extras_testes (capítulo Extras: Sala de testes)` to `cairu + cap2 (personagem lucas)`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `mapa corredor` connect `cairu + extras_testes (capítulo Extras: Sala de testes)` to `cairu + laboratorio (mapa laboratorio)`, `cairu + presidencia (capítulo Capítulo 1: Cairu)`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Are the 43 inferred relationships involving `_passo()` (e.g. with `registrar_fala()` and `som()`) actually correct?**
  _`_passo()` has 43 INFERRED edges - model-reasoned connections that need verification._
- **What connects `sinal terminou`, `sinal fechou`, `sinal terminou` to the rest of the system?**
  _62 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `estilo_gba + paleta (estilo_gba.py)` be split into smaller, more focused modules?**
  _Cohesion score 0.08262626262626263 - nodes in this community are weakly interconnected._
- **Should `jogo + menu (jogo.gd)` be split into smaller, more focused modules?**
  _Cohesion score 0.07418788410886742 - nodes in this community are weakly interconnected._