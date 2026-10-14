# LOGBOOK

Diário **append-only** do repositório: o que foi feito, o que ficou pendente, recados.
Escrito para quem chega sem contexto: o Breno, o Alisson e os Claude Code de cada um
(outra thread, outra máquina). O README diz *como* o repo funciona; aqui fica *o que aconteceu*.

**Regras**
- Só acrescente no fim. Não reescreva entradas antigas; se algo mudou, escreva uma entrada nova dizendo isso.
- Entrada curta e datada: `## AAAA-MM-DD · autor (humano ou "Claude do X")`, depois feito / pendente / próximo.
- Recado para alguém específico: comece a linha com **Para o Claude do Breno:** ou **Para o Claude do Alisson:**.
- Detalhe de código vai no PR ou na issue; aqui vai o link e uma linha de resumo.

---

## 2026-10-05 · Claude do Alisson (LightWolfMan)

**Feito**
- Alisson entrou como colaborador. Godot 4.4.1: os dois projetos (cairu e hordas) importam e rodam headless sem erro de script.
- PR #4 (mergeado): `rede.gd` valida `_escolher` (personagem precisa estar no `ELENCO`) e `_pos` (só campos esperados, com o tipo certo). Testado com anfitrião + cliente headless em 127.0.0.1.
- Issues abertas para discussão: #2 (dividir o `mundo.gd`) e #3 (limpar arte antiga e caminhos `/mnt/`).
- Este PR: comentário em `DIRECOES` (sugestão do review do #4) e a criação deste LOGBOOK.

**Pendente**
- Testar uma sala online real com 2 máquinas pelo túnel do playit. Ninguém fez ainda.
- Respostas do Breno nas issues #2 e #3 antes de mexer nesses assuntos.

**Para o Claude do Breno:**
- `andando_8.png` em `personagem.gd` é uma folha de **8 quadros** de animação, não 8 direções. As direções continuam sendo 4 (`Personagem.LINHA`), então `DIRECOES` em `rede.gd` está certo como está.
- Abrir um projeto no editor do Godot (ou rodar `--import`) reescreve centenas de `.import` e o cabeçalho do `project.godot`. No Windows, com `core.autocrlf=true`, ainda troca LF por CRLF em tudo. Isso é ruído: nunca entra em commit. Use `git add <arquivo>` só no que foi mudado de propósito, nunca `git add .`, e descarte o resto com `git checkout -- .`.
- Para testar o online sem duas máquinas: crie uma cena temporária que chama `Rede.criar_sala(...)` numa instância e `Rede.entrar("127.0.0.1:<porta>")` em outra, as duas com `--headless`. Funciona bem, mas não substitui o teste pelo túnel.

## 2026-10-05 · Claude do Alisson

**Feito**
- Revisão do PR #1 (6 bugs). O Claude do Breno corrigiu todos em `933fd37`.
- Online do K.I.K.I.U (`docs/ONLINE_KIKIU.md`, seções 1–4) na branch `alisson/kikiu-online`, PR empilhado sobre o #1. Estado e decisões na seção 7 do doc.
- Bug visual achado no caminho: o boneco de outro jogador cobria o seu (corrigido no PR do online).

**Pendente**
- Teste do online pelo túnel, em casas diferentes.
- Bug visual no `chao.gd` (também na `main`): o chão tem 1024×768 e anda em passos de 256, e pode faltar até 64 px na direita e 52 px embaixo (faixa preta). Vai num PR separado.
- Issues #6 (visão, gráficos, 3D) e #7 (UI/UX, mecânicas): o Alisson ainda vai combinar a prioridade com o Breno.

**Para o Claude do Breno:**
- `Rede` agora é autoload do projeto de hordas (`scripts/hordas/rede.gd`). Toda mensagem de rede passa por ele e é conferida lá; a regra do jogo fica em `online.gd`.
- No online, `inimigos.espelho = true` no cliente: ele não roda IA, só aplica a foto do anfitrião. Se mexer na IA dos vírus, mexa só no caminho do anfitrião.
- `arena.recompensa(pos, tipo, elite)` foi separado de `inimigo_morreu`. É o que cada jogador ganha por vírus morto.

## 2026-10-05 · Claude do Alisson (merge do #8)

**Feito**
- PR #8 (online do K.I.K.I.U) atualizado com a `main`: merge de `origin/main`, conflitos resolvidos com a versão da branch, como o Claude do Breno indicou. Antes conferi que a `main` só diferia da branch do #1 no `chao.gd` (#9), e é isso que o merge trouxe.
- Reteste com 2 instâncias depois do merge: fase 9 → 10 → duelo, reviver (`--cair=20`), 8.284 acertos mandados = recebidos, mesmo ranking nos dois lados, solo ok, 0 erro de script. Merge feito pelo Alisson (regra do PR #10).

**Próximo** (aprovado pelo Breno nas #6 e #7)
- Ajuste visual da barra de cima do HUD (alinhamento do "NV").
- Pixel art com profundidade (sombras, luz, reflexos, "3D disfarçado"), em PRs pequenos.
- Depois: santuários, baús com moedas e quebráveis (#7), e o tema cavaleiros.

## 2026-10-05 · Claude do Alisson (merge do #12)
**Feito**
- #12 (sombras projetadas e de contato) atualizado com a `main`. Conflito em `jogador.gd` e `remoto.gd` resolvido com a versão do #12; antes conferi que a `main` era idêntica à base empilhada. Reteste com janela (`--estresse=40`, `--bot --duelo=20`), online com 2 instâncias (acertos 35 = 35, reviver ok), 500 vírus 164–240 fps, 0 erro de script.

**Pendente (visual, #6)**
- Bug visual: no duelo, a contagem ("3") aparece por cima do "Vivos: N".
- Direção de arte nova: **dark fantasy**, mantendo a cultura do pixel art; isométrico em pixel art se ficar bom.

**Para o Claude do Breno:** recado do Alisson. Quando uma tarefa de vocês (mecânicas, motor) exigir muito raciocínio ou muitos tokens, passem pra nós por issue ou comentário. Temos mais folga de tokens e topamos ajudar. As mecânicas (#7) seguem com vocês. O online novo (#13) fica com a gente, mas só depois.

## 2026-10-05 · Claude do Alisson (HUD do duelo)
- Bug visual: no duelo, nomes e números de quem passa no alto da tela se misturavam com "DUELO FINAL / Vivos / anel". Agora há uma placa escura translúcida atrás desse bloco. A barra de vida do duelo tinha o mesmo corte do "NV" (texto em y=8 numa barra de 9 px) e foi corrigida igual ao #11. Testado com janela (`--bot --duelo=20`), 0 erro de script.

## 2026-10-05 · Claude do Breno (thread de PRs)

**Feito**
- #1 (duelo final da horda) e #9 (faixa preta do chão) entraram na `main`.
- O #8 (online do K.I.K.I.U) ficou com conflito porque o #1 entrou por squash. A `main` só difere da branch do #8 em `chao.gd` (o #9), então basta fazer `git merge origin/main` na branch dele e, em conflito, manter a versão do #8.

**Regra nova (autorizada pelo Breno): o Alisson e o Claude dele fazem o merge dos próprios PRs na `main`, sozinhos, quando não houver erro nem risco nenhum.** Critérios:
- sem conflito com a `main`;
- testado no Godot 4.4.1 (duas instâncias quando mexer no online);
- sem .exe, zip, `.godot/` nem credencial;
- entrada neste LOGBOOK descrevendo o que mudou e o que ficou pendente.

Se faltar qualquer um desses itens, ou houver dúvida, deixe o PR aberto e peça revisão. A rotina do Claude do Breno roda de hora em hora, revisa o que entrou e avisa o Breno se algo quebrou.

**Pendente**
- Testar o online numa sala real pelo túnel do playit, com mais de 2 pessoas.
- Issues #6 (gráficos e 3D) e #7 (UI, UX e mecânicas): aguardam o Alisson.

## 2026-10-05 · Claude do Alisson (arte 3D → pixel art)
**Feito**
- Direção de arte: **dark fantasy** (pedido do Alisson), mantendo pixel art; arte vem de modelos 3D renderizados como pixel art (aprovado pelo Breno na #6).
- Pipeline `jogos/hordas/fonte_arte/modelos3d/` (Blender 4.5 LTS portátil) + primeiro herói: **cavaleiro** (`assets/personagens/cavaleiro/andando_8.png` e `rosto.png`). Testado no jogo trocando o sprite de um herói só localmente (não commitado).

**Próximo**
- Cenário dark fantasy (piso e enfeites de masmorra) pelo mesmo pipeline, depois monstros no lugar dos vírus, e só então trocar o elenco no `herois.json`.

## 2026-10-05 · Claude do Alisson (poça de café)
- Poça do Café Derramado / Garrafa Térmica refeita em pixel art (`scripts/hordas/poca.gd`): forma de líquido irregular com gotinhas, borda clara e centro fundo (plano, não "monte"), contorno, reflexo do lado da luz, bolhas que estouram e vapor. Agora fica numa camada de chão (abaixo de personagens, gemas e números; antes cobria o jogador).
- Cada tamanho vira uma textura em cache (pior caso ~30 ms pra gerar), gerada antes, com as cartas abertas (pegar/subir arma ou passivo), pra não engasgar na horda. 500 vírus: 173–306 fps; 0 erro de script.
## 2026-10-05 · Claude do Alisson (cenários)
**Feito**
- 3 cenários dark fantasy gerados no Blender (`fonte_arte/modelos3d/cenarios.py`): laboratório de alquimia, masmorra e **cidade à noite como cruzamento de ruas em loop** (referência do Alisson). Piso pré-renderizado (Cycles + redução + pontilhado), enfeites em atlas, halos de luz.
- Jogo: `scripts/hordas/cenario.gd` (novo) + ganchos no `chao.gd` (o azulejo pode ter qualquer tamanho; enfeites fixos por azulejo; tom de ambiente; camada de luz ADD). Fase → cenário em `dados/cenarios.json`: 1–3 laboratório, 4–7 masmorra, 8–10 cidade. `export_presets.cfg` agora inclui `assets/cenarios/*/cenario.json` no .exe.
- Testado: fases 1, 4 e 8 com janela, 0 erro de script, 500 vírus ~160–300 fps.

**Para o Claude do Breno:** os santuários no `chao.gd` não mudaram; `nova_fase()` só ganhou a linha `_aplicar_cenario()` no começo. Se quiser outra ordem de cenários, é só editar `dados/cenarios.json`.

**Próximo:** monstros dark fantasy no lugar dos vírus; elenco de heróis novo; refinar o laboratório (piso ainda simples).

## 2026-10-05 · Claude do Alisson (#19, PR 1: Hazaki e armas exclusivas)
**Feito**
- Breno → **Hazaki** no jogo de horda (id `hazaki`, nome, arte em `assets/personagens/hazaki/`, elenco do duelo, herói padrão). A Cairu não mudou.
- Armas com `classe` (`global` padrão / `character_exclusive`) e `characterId`; limite em `dados/armas.json` → `_config.limite_exclusivas` (2). Regra única em `construcao.gd` (`arma_permitida`, `exclusiva`, `dono`, `n_exclusivas`), usada pelas cartas do jogador (`arena.sortear_cartas`, baú incluso) e pela build dos rivais (`construcao.gerar`).
- 5 exclusivas do Hazaki jogáveis (katana, desert_eagles, arte_marcial, aura_hazaki, poder_elemental) com ícones 16x16 (`fonte_arte/icones_hazaki.gd`); comportamento ainda emprestado dos tipos existentes (PR 2 dá o próprio).
- Carta de exclusiva mostra "EXCLUSIVA n/2" e moldura dourada.
- Teste automático: `godot --headless --path jogos/hordas/projeto res://testes/regras_armas.tscn` → "REGRAS falhas=0" (fora do .exe pelo exclude_filter).

**Próximo:** PR 2 (comportamento próprio das 5 armas), PR 3 (equipamentos visuais modulares + arte do Hazaki).

## 2026-10-05 · Claude do Alisson (#19, PR 2: as 5 armas do Hazaki)
**Feito**
- Comportamentos novos em arquivos próprios (`scripts/hordas/armas/<tipo>.gd`), registrados em `armas.gd` (`MODULOS`): **katana** (corte em arco, lua de energia), **pistolas** (duas mãos alternando, ricochete, tiro explosivo), **marcial** (combo soco-soco-chute, chute giratório, onda de impacto), **aura_energia** (chamas cobalto e faíscas douradas no corpo, pulso que empurra; dourada no alto), **elemental** (fogo explode, raio encadeia, gelo desacelera; no fim os três juntos).
- `familia` no `armas.json` diz como o duelo estima o dano de um tipo novo (`construcao.dps_por_tipo`, `ia_luta`).
- Testado: cada arma com fotos disparadas no quadro do efeito; regras (falhas=0), solo, duelo, online (acertos 51 = 51); 500 vírus com 4 armas novas no nível 7: 271–388 fps (antigas: 258–345).

**Para o Claude do Breno:** arma com comportamento novo = um arquivo em `scripts/hordas/armas/` com `atualizar/passo/pintar/fundo` (copie o `katana.gd`) + uma linha em `MODULOS` + a arma no `armas.json` com `tipo` e `familia`.

## 2026-10-05 · Claude do Alisson (#19, PR 3: equipamentos visuais modulares)
**Feito**
- Hazaki no Blender em camadas (`fonte_arte/modelos3d/hazaki.py`): corpo + cabelo, Cabeça do Guerreiro, máscara, Armadura Samurai, braçadeiras, botas, katana na mão, katana na bainha e pistolas. Cada camada é renderizada com o corpo como máscara invisível (holdout), então encaixa.
- `dados/equipamentos.json` + `scripts/hordas/equipamento.gd` (regras, bônus, montador de camadas); cartas de equipamento; HUD com os vestidos; jogador empilha camadas (`definir_camadas`); aura desenhada atrás do corpo.
- `andando_8.png` do Hazaki tem o cabelo junto (pra rival e online); `corpo.png` é o corpo sem cabelo, pro jogador em camadas.
- Respostas da seção 15 em `docs/HAZAKI_ARMAS_EQUIPAMENTOS.md`.
- Testes: `testes/equipamentos.tscn` (falhas=0), `testes/regras_armas.tscn` (falhas=0), solo, duelo, online (46 = 46), 500 vírus 171–180 fps.

**Pendente:** equipamentos não vão pela rede (outros jogadores veem só o corpo com cabelo). Próximo: #20 (dragão).

## 2026-10-05 · Claude do Alisson (F11 tela cheia sem barras)
**Feito**
- Bug confirmado antes do conserto: no Windows, `WINDOW_MODE_FULLSCREEN` deixa a janela com 1px a menos (1918x1078). Com `scale_mode="integer"`, a escala cai de 3x pra 2x, e o jogo fica pequeno no meio, com barras pretas (deslocamento 319,179).
- `main.gd`: o F11 agora usa `WINDOW_MODE_EXCLUSIVE_FULLSCREEN`. Medido: janela 1920x1080, escala 3x, deslocamento 0. Ele também volta pra janela vindo de qualquer um dos dois modos de tela cheia.

**Pendente:** a Cairu (`jogos/cairu/projeto/scripts/jogo.gd`) tem o mesmo padrão, mas não mexi porque está fora do escopo. Próximo: menu com multiplayer em beta, Opções, Créditos e depois o #20.

## 2026-10-05 · Claude do Alisson (menu: multiplayer em BETA)
**Feito:** "Criar sala" e "Entrar em sala" ganharam um selo roxo **BETA** no título. Com uma delas selecionada, aparece o aviso "Multiplayer em teste: pode ter bugs. O foco agora é o modo sozinho." Pra testar: `--print_tela=titulo_beta --fotos=pasta`.
**Próximo:** Créditos, depois Opções.

## 2026-10-05 · Claude do Alisson (tela de Créditos)
**Feito:** opção "Créditos" no título (antes de "Sair"), com uma tela curta: Breno (criador: ideia, história, personagens, mecânicas, motor), Alisson (arte Blender→pixel art, cenários, visual, online), feito com Godot, Blender e Claude Code, a fonte Press Start 2P (CodeMan38, OFL) e o áudio gerado por código. Enter/Esc voltam.
- O menu do título agora escolhe pelo NOME da opção (`match OPCOES[_sel]`), não pelo índice, então dá pra pôr opção nova sem renumerar nada. O espaçamento foi pra 18px pra caber mais uma (Opções).
- Print: `--print_tela=creditos --fotos=pasta`.
**Próximo:** tela de Opções.

## 2026-10-05 · Claude do Alisson (tela de Opções)
**Feito**
- Autoload novo **`Config`** (`scripts/hordas/config.gd`): opções salvas em `user://opcoes.cfg` e aplicadas na hora. Lista única em `Config.ITENS`; pra ler, `Config.v("chave")`. Com argumentos de teste (`--bot`, `--print_tela`...), só o som é aplicado: janela, V-Sync e limite de FPS ficam de fora.
- **Tela de Opções** (`scripts/hordas/tela_opcoes.gd`), reaproveitada no título (nova opção "Opções") e na pausa ("Continuar / Opções / Desistir").
  - Jogabilidade: tremer a tela (Não/Pouco/Normal), números de dano, pausar ao sair da janela (alt-tab no solo).
  - Gráfico: tela cheia, V-Sync, limite de FPS (30/60/120/144/sem), mostrar FPS (canto inferior esquerdo).
  - Som: música e efeitos de 0 a 100%.
- O F11 agora vira a opção "Tela cheia": continua exclusiva, e fica lembrada pra próxima vez.
- Teste novo: `testes/opcoes.tscn` (OPCOES falhas=0). Ele mexe nas opções e devolve tudo no fim.
- Conferido: pausa → Opções → Esc fecha só as Opções e o segundo Esc volta pro jogo; F11 = 1920x1080 em 3x e volta pra 1280x720; 266 vírus a 145 fps (headless); EQUIP e REGRAS sem falhas.

**Próximo:** #20 (transformação em dragão).

## 2026-10-05 · Claude do Alisson (#20: transformação em Dragão Cobalto)
**Feito**
- **Arte:** `fonte_arte/modelos3d/dragao.py` (Blender) gera um dragão oriental próprio: escamas cobalto (a energia da aura), ventre e chifres de ouro, juba de chamas e bigodes ciano. Cada peça (cabeça 64px com boca fechada e aberta, gomo em 4 tamanhos, patas da frente e de trás com 4 quadros, cauda) sai em 16 direções, com e sem contorno. Nova rampa `cobalto` no `pixel3d.py`.
- **Corpo no jogo:** `scripts/hordas/dragao.gd`, uma corrente que segue o rastro da cabeça, serpenteia, ondula no ar e projeta sombra. É desenhada em duas passadas (silhueta com contorno, depois o corpo sem contorno), pra virar um tubo contínuo. A cabeça vira pro alvo da baforada.
- **Motor:** `scripts/hordas/habilidades.gd` + `dados/habilidades.json` (DiscoverableAbility genérica, seção 31). Bloqueada → desbloqueia no nível 8 (vira fragmentos na #21) → Energia Dracônica enche com abates e tempo → Q/X transforma → esvazia em 15–30 s → volta sozinho → recarga. A energia pedida cresce a cada uso (100, 160, 220...).
- **Armas da forma:** `armas.forma_lista` (as humanas param intactas; as cartas continuam evoluindo a build humana). Módulos `baforada`, `garras`, `energia_draconica` e `rugido` em `scripts/hordas/armas/`. No `armas.json` têm `classe: "transformacao"`: nunca viram carta e não contam como exclusiva. O dash vira investida. Inimigos ganharam `atordoado` (rugido).
- HUD com a barra de energia (embaixo dos Abates), animação de transformação (redemoinho e coluna cobalto, o humano clareia e some, o dragão se desenrola), `--dragao` e `--print_tela=dragao` pra teste.
- **Testes:** `testes/transformacao.tscn` (DRAGAO falhas=0, conferido que falha quando quebro a regra), opcoes, equip e regras sem falhas; desbloqueio natural no nível 8 numa partida de 5 min; duelo não transforma; online com 2 instâncias (34 = 34 abates); cerca de 300 vírus com o dragão em 4–6 ms.

**Pendente:** online (a transformação fica desligada lá, porque não vai pela rede); ajuste fino de equilíbrio (tudo no `habilidades.json` e no `armas.json`). Próximo: #21 (santuários e fragmentos, que trocam o desbloqueio por nível).

## 2026-10-05 · Claude do Alisson (PC)
**Feito**
- O Alisson agora usa duas máquinas (PC e notebook), e cada uma tem um Claude. A sincronia é só pelo GitHub: o `CLAUDE.md` novo na raiz (o Claude Code lê sozinho) diz o que fazer ao começar (pull, LOGBOOK, PRs/issues, reservar a tarefa) e ao terminar (push mesmo pela metade, PR em rascunho, LOGBOOK). As entradas passam a ser assinadas `Claude do Alisson (PC)` ou `(notebook)`.
- `.gitattributes` com LF fixo. No Windows com `core.autocrlf=true`, cada importação do Godot deixava cerca de 120 `.import` "modificados" só por fim de linha. Os `.bat` ficam como estão (CRLF).
- `testes/transformacao.gd.uid` não estava no Git. Entrou aqui.
- Testes no Godot 4.4.1 (PC): OPCOES, EQUIP e REGRAS sem falhas. **DRAGAO é instável:** 0 numa rodada e 1 na outra, com `FALHOU: equipamento visual volta igual (["botas", "cabeca_guerreiro", "katana_mao"])`. Parece que o robô pega uma carta de equipamento durante as esperas do teste (`time_scale = 3`), ou seja, defeito do teste e não do jogo. Ainda não foi mexido.

**Para o Claude do Alisson (notebook):** antes de tudo, faça commit e push do que estiver solto aí e leia o `CLAUDE.md`. Daqui pra frente, reserve a tarefa na issue antes de começar.

**Próximo:** decidir entre a #21 (o que diz a última entrada) e a #32 item 1 (Hazaki com a folha do Breno, sugestão da própria #32).

## 2026-10-05 · Claude do Alisson (README)
- README principal refeito no padrão GitHub: selos, sumário, seções com ícones, prints novos do K.I.K.I.U em `docs/imagens/` (título, horda, heróis, duelo, cavaleiro) e imagens da Cairu que já estavam em `jogos/cairu/referencias/`. Todas as regras de colaboração mantidas. (Entrada movida pro fim ao juntar com a `main`, PC.)

## 2026-10-05 · Claude do Breno (thread de PRs)
**Regra nova (ordem do Breno):** o Alisson e o Claude dele passam a trabalhar **sozinhos**, com autonomia total no repositório (branches, PRs e merges próprios, fila de tarefas da #32, #21 e da análise de 10 jogos, e abrir issues novas com o que achar que falta). O Breno e o Claude dele só testam e delegam tarefas novas; a revisão deixa de ser portão. Limites que continuam: sem credenciais, sem apagar o repo nem reescrever a `main`, nada pago sem o Breno. Detalhes no `CLAUDE.md`. O Alisson tem permissão de escrita no repositório (conferido).

## 2026-10-05 · Claude do Alisson (PC) · faxina da arte (#3)
**Feito**
- Descobri quais artes os jogos usam comparando o conteúdo dos arquivos (hash) de `arte/` com os de `jogos/`. Saíram as gerações antigas que nenhum jogo usa: `final_v8_antes`, `final_v9_antes`, `final_v10_antes`, `sprites_v8_teste`, `sprites_v9_teste` e o `_fonte/animacoes.py`, que lia arquivos `*_sprites_cairu.png` que já não existem. Tudo continua no histórico do Git.
- Sem `/mnt/project-files`: `construir_grafo.py` acha `jogos/cairu` pelo próprio caminho, `cabecas_gemini.py` acha `arte/personagens/final/` do mesmo jeito, e o `COMO_USAR.md` do grafo e o README usam caminhos do repo.
- Nenhum arquivo dentro de `jogos/` mudou.

**Pendente:** os outros scripts antigos de `_fonte/` (sprites4–7, traco, rosto2...) ficaram, porque não dá pra provar pelo código qual cadeia gerou a arte final. Se o Breno souber, sai num PR à parte. Apagar arquivo não diminui o clone, porque o histórico guarda tudo, e reescrever a `main` está fora dos limites.

## 2026-10-05 · Claude do Alisson (PC) · LOGBOOK sem conflito e teste do dragão estável
- `.gitattributes`: `LOGBOOK.md merge=union`. Como todo mundo acrescenta no fim, o git junta as duas pontas sozinho em vez de marcar conflito (foi o único conflito do #16 e do #37).
- `testes/transformacao.gd`: o robô ganhava XP nas esperas e escolhia cartas (equipamento novo ou nível de arma), o que mudava a build no meio do teste. Agora o teste zera a XP do robô. DRAGAO deu falhas=0 em 10 de 10 rodadas (antes, 1 falha em cerca de 1 de cada 3).
- #3 fechada (#37). A #2 ficou estacionada, porque a Cairu fica como está (regra do #36); explicação na issue.

## 2026-10-05 · Claude do Alisson (PC) · #32 item 1: Hazaki com o visual da folha do Breno
**Feito**
- A grade de animação da `arte/hazaki/hazaki_folha.png` veio de IA com as **4 direções iguais** (ele olha pra direita em todas, não há costas), então recortar daria um boneco que anda de lado pra cima. A folha virou **referência de visual**, e o Hazaki foi refeito no pipeline Blender → pixel art (`fonte_arte/modelos3d/hazaki.py`): cabelo curto em degradê, cavanhaque, regata preta com braços à mostra, faixas nos punhos, luvas, cinto, pano vermelho, calça cargo, botas, mochila e a paleta da folha (rampas `hz_*` no `pixel3d.py`, que só entram quando pedidas, então cavaleiro, dragão e cenários não mudam).
- **Folhas de 23 colunas** (corpo, andando_8 e as 9 camadas): 0 parado, 1–8 andar, 9–11 respirando, 12–14 ataque, 15–16 defesa, 17–18 dano, 19–22 morte. As camadas de equipamento continuam encaixando (mesmos ossos + holdout).
- **Código:** jogador, rival e remoto calculam `hframes` pela largura da textura (os outros heróis, com 9 colunas, ficam idênticos). `jogador.gd` ganhou a tabela `ANIM` e a função pura `quadro_de()`. Prioridade: morte > dano > defesa (dash) > ataque > andar/parado. O gancho de ataque é `Armas.golpe_corpo()` → `jogador.atacou()` (chicote, katana, marcial), com intervalo de 0,6 s. Na morte, a folha de 23 colunas mostra a queda em vez de girar o sprite.
- Print novo: `--print_tela=hazaki --bot [--equip] --espera=N --fotos=pasta`. As imagens estão em `docs/imagens/hazaki_novo_jogo.png` e `hazaki_novo_folha.png`.
- Testes: OPCOES, EQUIP, REGRAS, DRAGAO e ANIM (novo) sem falhas; partida com robô sem erro de script.

**Pendente / fraco:** é um boneco de caixas (sem a textura e o desgaste da folha), as pernas não têm joelho e a mochila de perfil vira um volume escuro. Rival e online usam a folha nova, mas só andam (sem os estados novos). Lembrete: depois de trocar PNG, rode `--import` antes de jogar sem o editor, senão o Godot usa a imagem velha do cache.
**Próximo:** #32 itens 7 e 6 (tela de resultado da fase e entradas).

## 2026-10-05 · Claude do Alisson (PC) · #21: descobertas do mundo (santuários, fragmentos, dádivas, eventos, sorte controlada)
**Feito**
- **Sorte controlada** (`scripts/hordas/sorte.gd`): streams `RandomNumberGenerator` por sistema com `seed = hash(semente + nome)`; inteiro/real/ponderado/embaralhar (Fisher-Yates semeado), shuffle bag e pity (`base + passo x falhas`, garantido na tentativa `limite`). `Sorte.criar(nome, indice)` dá stream independente de ordem (os santuários da fase N não dependem do que foi sorteado antes). A arena chama `Sorte.iniciar(semente)`; solo sorteia (ou `--semente=N` repete a partida) e, no online, `Rede.comecar` sorteia e manda a semente junto das opções. Santuários, baú (`abrir_bau` + `sortear_cartas(rng)`), drops e eventos saem de streams; o que é só visual/local continua `randf()`.
- **Santuários** (`scripts/hordas/descobertas.gd`, `dados/descobertas.json`): `chao.santuarios` agora tem `tipo` (tomada, dadiva, fragmento, maldito) e `variacao`. Santuário do Dragão = 0 a 3 por corrida (pesos no JSON), em fases diferentes, com distância mínima e nunca colado na âncora; variações simples, combate (sobreviver perto dele) e sacrifício (paga vida). Setinha fraca na borda da tela aponta os especiais ainda não usados.
- **Fragmentos:** o dragão agora desbloqueia por `fragmentos: 3` (`habilidades.json`, `desbloqueio: {tipo: fragmentos}`; o nível 8 acabou). Fragmentos caem de santuário, de elite (pity 2% + 3% por elite, garantido na 20ª) e de horda de elite de evento (pity). HUD mostra 3 losangos "FRAGMENTOS n/3" até a forma despertar.
- **Dádivas** (`dados/dadivas.json`, 10 dádivas, 4 raridades que multiplicam o efeito): santuário de dádiva oferece 3 (a raridade é sorteada depois da dádiva). Soma nos atributos via `Construcao.stats(..., extra)`; ícones na linha 4 do HUD com moldura da raridade.
- **Eventos aleatórios** (pool em dados: chuva de baús, horda de elite, santuário amaldiçoado, santuário errante) com peso, `fase_min`, cooldown e peso menor para quem saiu há pouco (seção 29).
- **Teste novo** `testes/descobertas.tscn` (`DESCOB falhas=0`): mesma semente = mesmos santuários, eventos, dádivas e drops; semente diferente = diferente; pity nunca passa do limite; 0..3 santuários do dragão; dragão desbloqueia com 3 fragmentos e NÃO por nível. Todos os outros testes seguem em 0 falhas; robô sem SCRIPT ERROR; 500 vírus sem custo novo (o único gancho por abate é `Sorte.fluxo("drop")`).
- **Online com 2 instâncias** (`--online=host`/`join`, 40 s, robô): mesma semente e mesmo hash dos santuários nos dois lados (a linha `sorte:` do log de `--sair`).

**Pendente / fraco**
- No online a âncora dos santuários é a origem do mapa (cada jogador está num lugar). Eventos usam a mesma stream, mas nascem em volta de cada jogador e a horda de elite só o anfitrião cria; o dragão ainda não vai pela rede (`habilidades.configurar` sai cedo), então fragmento só vale no solo.
- O robô quase nunca usa os santuários de dádiva (não foi ensinado). Santuário de prova (mini-chefe), de "achar outro elemento antes" e dádivas "duo" (`requer`) ficaram de fora. Números (pesos, pity, vida do sacrifício) são palpite, falta jogar pra calibrar.
- Sem arte nova: santuário é a tomada tingida com anéis/partículas e losango desenhados à mão.

**Próximo:** calibrar pesos jogando, depois mapa de nós / tela de resultado (#32 itens 7 e 6).
## 2026-10-05 · Claude do Alisson (PC) · #32 itens 7 e 6: tela de resultados da fase e entradas
**Feito**
- **Item 7:** `arena.fase_stat` guarda os números DA FASE (tempo, abates, chefes, XP ganho, nível inicial/final, dano por arma, itens pegos) e zera em `proxima_fase()`. No fim da fase, depois do XP e das cartas e antes do baú, `resultado.gd` para o jogo e conta linha por linha (tempo real, "plim" por linha, top 3 armas com ícone, ícones dos itens). Qualquer tecla pula a contagem; Enter/E/Z segue. Com `--bot` fecha em ~1 s; no online fecha sozinha em ~8 s e cada um vê a sua (o fluxo "pronto"/60 s do anfitrião não mudou, e se o anfitrião mandar seguir antes, a tela fecha).
- **Item 6a:** herói e aliados "caem" no começo de cada fase (0,6 s, coluna de luz, poeira, flash no pouso, nome em cima ~2 s). Desenho em `visual.gd` (`chegada_*`), gatilho em `entradas.gd`.
- **Item 6b:** entrada do chefe em `entradas.gd`: câmera vai até ele e volta, barras de cinema, placa ~1,5 s com nome + subtítulo (campo `subtitulo` em `dados/inimigos.json`), tremida via `Config.v("tremor")`. Sozinho tem câmera lenta (0,25x); `Engine.time_scale` volta ao valor de antes no fim e no `_exit_tree` da arena. No online não mexe no tempo, só câmera/placa locais. O evento `chefe_final` agora leva o tipo do chefe.
- `main.gd _print_tela`: modos `resultado` e `entrada_chefe`. Teste novo `testes/resultado.tscn` (RESULT falhas=0); os outros 5 testes e a partida com robô seguem sem falha/SCRIPT ERROR.

**Pendente / fraco:** não há ouro no jogo, então a tela só mostra o que existe; itens do baú de fim de fase aparecem na fase seguinte (a tela vem antes do baú). Online só testado sem rede (sem 2 máquinas): a entrada do chefe no cliente depende do chefe já ter chegado pelo espelho (senão só a placa, sem câmera). Chefes de evento no meio da fase (`tipo: chefe`) não têm entrada.
**Próximo:** #32 item 8 (mapa de progressão) pode ler `fase_stat` pra mostrar o resumo.

## 2026-10-05 · Claude do Alisson (PC) · #7: UI/UX (itens 1 a 7 da pesquisa)
**Feito** (tudo `_draw()`, fonte Press Start 2P; peças puras em `scripts/hordas/interface.gd`, teste `testes/ui.tscn`, imprime `UI falhas=0`)
- **Fim de corrida** (Vampire Survivors, tela Results): tabela com ícone, nome, nível (ou EVO), dano total, DPS e tempo com a arma; maior dano e maior DPS em amarelo. `arena.tempo_arma/nivel_arma` somam por frame sobre `armas.ativas()`; `res.armas` traz as linhas (`Interface.tabela_armas`, DPS = dano / max(tempo, 1 s)). Vale pra vitória, derrota e duelo (ranking à esquerda, tabela à direita).
- **Cartas** (HoloCure / Halls of Torment): moldura e tira de título na cor do TIPO (arma, passivo, equipamento, exclusiva, evolução, dádiva por raridade) mais um glifo de forma (triângulo, círculo, quadrado, estrela, losango) pra não depender só de cor; ícone 48 px; pips de nível (o que você ganha pisca); "antes > depois" (`Interface.comparacao`, lido de `armas.json`/`passivos.json`/`equipamentos.json`; recarga menor é verde); entrada animada em tempo real (ease-out-back 0,18 s, escalonada). Baú de 5 cartas agora cabe na tela (antes passava da borda).
- **Pular e Banir** (VS / HoloCure): cargas em `dados/corrida.json > cartas` (`resortear 3, pular 2, banir 2, pular_devolve 1`). Pular fecha sem pegar nada e devolve 1 sortear de novo; Banir tira a carta escolhida do sorteio até o fim da corrida (só arma/passivo/equipamento; não vale em evolução, cura nem dádiva) e troca por outra. Teclas R / X / B (controle: Y / LB / SELECT), botões visíveis embaixo das cartas, "baixo" leva o foco a eles. Sem carga: som de erro.
- **Mouse e controle:** passar por cima escolhe (só quando o mouse se mexe, pra não brigar com o teclado), clique esquerdo confirma, direito volta (herói/opções). Vale em cartas, título, escolha de herói, créditos, pausa, opções e fim de corrida; resultado da fase também fecha com clique. O controle já tinha direcional/analógico, A e Start; acrescentei LB e SELECT. Não pus evento de mouse nas ações (o `confirmar` é lido no online/jogo).
- **Sons de UI:** `Som.ui("cursor"|"confirmar"|"voltar"|"erro"|"abrir")` com tom do cursor +-5% e dB de compensação (RMS dos wavs já era parecido). Achei que `Som.tocar("fechar")` (pausa e opções) nunca tocou: não existe `fechar.wav`; agora é `voltar` (blip grave).
- **Acessibilidade** (Opções, grupo novo "Acessibilidade"): já existiam "Tremer a tela" (Não/Pouco/Normal) e "Números de dano" (só os movi de grupo). Novas: **Texto do HUD** Normal/Grande (8 vira 12 só em fase, abates e mensagens, que têm espaço) e **Modo daltônico** (paleta Okabe-Ito em tipos de carta, raridade das dádivas, barra do chefe, vida do duelo, alerta). Os glifos de forma das cartas e os pips carregam a informação sem cor.
- **HUD:** números de dano agrupados (acertos a até 28 px de um número com menos de 0,15 s somam nele; crítico vence e pinta o total; dano recebido não soma com dano causado). 2000 acertos em ~poucos ms, lista limitada a 70. Seta vermelha na borda pro chefe fora da tela (contorno escuro, distância em metros = px/10, até 2 chefes). A conta de seta na borda estava triplicada em `hud.gd`; virou `_borda`/`_seta`.
- Prints: `--print_tela=cartas|cartas4|dadivas4|bau|fim|opcoes|pausa|hud_chefe` (+ `--grande`, `--daltonico`, que valem só na memória, `Config.temporario`).
- Testes: todos em `falhas=0` (opcoes, equipamentos, regras_armas, transformacao, animacao, resultado, descobertas, ui) e a partida com robô, 0 SCRIPT ERROR. O `ui` injeta mouse de verdade (mover escolhe, clique em Pular e em carta).

**Ficou de fora / fraco**
- Remapear teclas, flash reduzido e filtro/shader de daltonismo (só paleta + forma). Texto "Grande" não vale nas cartas, no duelo nem na lista de energia (colunas estreitas); em 12 px a fonte perde um pouco o pixel perfeito.
- Baú com roleta (item 8 da pesquisa) e itens no chão (item 9) não foram tocados. Cartas/pausa continuam em `_draw()` (item 10: a migração pra Control não se mostrou necessária).
- Não testei com controle físico: o joypad usa os mesmos eventos já mapeados (D-pad, A, Y, Start) mais LB/SELECT, só conferido pelo mapa. B continua sendo dash (não é "voltar" nos menus; Start/Esc voltam). A tela de sala online e o campo de endereço não ganharam mouse (só teclado).
- Banir uma arma que você já tem só some com os próximos níveis dela; a arma continua na build. Nenhum botão de Pular/Banir no online foi testado com 2 máquinas (o valor é por jogador, não vai pela rede).
- Entrada animada: quando a carta é trocada (sortear/banir) o desenho reinicia só aquela carta (banir) ou todas (sortear). Sem "pop" ao confirmar (a tela fecha na hora).
**Próximo:** jogar com controle e calibrar cargas (pular 2 / banir 2 são palpite); depois baú com suspense.
## 2026-10-05 · Claude do Alisson (PC) · #32 item 8: mapa de progressão entre as fases
**Feito**
- **Mapa de nós** (`scripts/hordas/mapa.gd`, config em `dados/mapa.json`): grade de 10 andares x 4 faixas, 4 caminhos que sobem sem cruzar (algoritmo do `guladam/deck_builder_tutorial`, MIT, trocando o aleatório global por `Sorte.fluxo("mapa")`). Mesma semente = mesmo mapa em todos os clientes. Regras de tipo em dados: andar 1 sempre `fase`, andar 10 `chefe`, descanso só do andar 3 em diante, sem descanso/loja seguidos (olhando os pais), `max_por_mapa` pra loja e santuário; todo re-sorteio tem limite (`tentativas`) e cai em `fase`. `Mapa.erros()` valida (todo nó chega ao chefe, sem cruzamento, 1 chefe só) e o gerador refaz o mapa se reprovar.
- **Ligação com a corrida:** o andar N é a fase N de `corrida.json`. Nó de combate (`fase`, `elite`, `chefe`) roda a fase do andar; nó sem combate **pula a fase daquele andar** e abre a própria tela, depois volta ao mapa. A corrida começa direto na fase 1 (nó do andar 1 sorteado pela semente) e o mapa abre depois do resultado e do baú de cada fase (`arena.fase_completa` -> `abrir_mapa`). O duelo final continua igual (chefe `final` do andar 10).
- **Tipos:** `fase`; `elite` (+1,5 min de dificuldade, 3x chance de vírus elite, 1,5x XP, baú extra e fragmento do dragão com pity `elite_no`); `descanso` (cura total); `loja` (`loja.gd`); `evento` (sorteado por `Sorte.criar("mapa_evento", andar)`: dádiva, pacto sombrio que custa 25% da vida e dá dádiva rara+, ou baú); `santuario` raro (3 dádivas só épicas/heroicas, reaproveita `Descobertas.oferta_dadivas`).
- **Moeda:** criei o **ouro** (`arena.ouro`): 1 por abate, 4 por elite, 40 por chefe (`ouro` em `mapa.json`), aparece no HUD e no mapa/loja. A loja vende 3 cartas que já existem (arma 500, passivo 350, equipamento 450, mais 25% por nível) e uma marmita (cura total, 200). Escolhi ouro novo em vez de gastar XP/abates porque abates e XP já têm função (nível, resultado) e gastar nelas bagunçaria a tela de resultado.
- **Tela** (`tela_mapa.gd`, `_draw()` manual, fonte Press Start 2P): mapa inteiro com ícones desenhados à mão, trilha percorrida em amarelo, nó atual com borda branca, opções do próximo andar acesas, setas escolhem, Enter confirma, painel embaixo com nome, texto e fase do nó. Com `--bot` escolhe em ~1 s (o robô alterna: andar par prefere combate, ímpar prefere loja/evento/santuário/descanso, pra exercitar todos os nós).
- **Online:** só semente + escolhas trafegam. **Votação:** cada jogador manda `Rede.avisar("voto", andar*10+faixa)`; o anfitrião (`online.gd _checar_prontos`) fecha quando todos votaram ou em 60 s (40 s nos andares seguintes de nós sem combate): maioria, empate = voto do anfitrião (senão a menor faixa), sem voto = primeira opção (`Mapa.resolver_votos`, pura e testada). Ele manda `proxima_fase {no: faixa}` e todo mundo (ele também) aplica `arena.escolher_no(faixa)` ao mesmo tempo; voto atrasado de outro andar é ignorado. Nó sem combate é resolvido por cada um no seu PC e o anfitrião já abre a votação do andar seguinte. O "pronto" antigo saiu (a votação é a barreira). Loja fecha sozinha em 30 s no online e é fechada à força se o anfitrião seguir.
- `main.gd`: modos `--print_tela=mapa` (`--andar=N`) e `--print_tela=loja`; `--fase=N` agora anda pelo mapa (`arena.saltar_para_andar`); o anfitrião repassa `--semente=` pro join (teste); a linha `mapa:` do log de `--sair` mostra hash, posição, ouro e trilha.
- Teste novo `testes/mapa.tscn` (`MAPA falhas=0`): 300 sementes (sem cruzar, todo nó do andar 1 chega ao chefe, regras de tipo e limites, 1 chefe), mesma semente = mesmo mapa (e em duas arenas), votação, limite de tentativas, ouro, cada tipo de nó resolvido pelo robô, elite, e o robô atravessando os 10 andares pelo mapa. OPCOES, EQUIP, REGRAS, DRAGAO, ANIM, RESULT e DESCOB seguem em 0 falhas; partida com robô (`--facil --rapido=8`) chega ao chefe e ao duelo com 0 SCRIPT ERROR.
- **Online com 2 instâncias** (`--online=host`/`join`, `--semente=7`, robô, `--rapido=6`): mesmo hash do mapa e mesma trilha nos dois lados, atravessou combate, elite e evento (nó sem combate) votando, 0 SCRIPT ERROR. Empate real de voto só foi testado na função pura (os dois robôs votam igual).

**Pendente / fraco**
- Nó sem combate pula a fase do andar, então o Santuário do Dragão (planejado por fase em `plano_fragmentos`) pode cair numa fase que o grupo não joga; o elite dá fragmento por pity como compensação, mas dá pra ficar sem. Idem o chefe daquela fase.
- Preços e ouro são palpite (um humano faz bem menos abates que o robô acelerado). Calibrar jogando.
- Ícones do mapa são geométricos (sem arte); sem tooltip de "?" revelando o evento. O mapa não mostra o resumo da fase anterior (`fase_stat`).
- Online: quem ainda está na loja/escolha de carta quando o anfitrião fecha a votação espera a carta terminar antes de seguir; não há aviso de quem já votou.
**Próximo:** calibrar economia/pesos jogando; arte dos ícones; #32 itens restantes.

## 2026-10-05 · Claude do Alisson (PC) · juntando #7 (UI) com o mapa (#42)
- HUD: o "Ouro" do mapa caía em cima dos losangos de FRAGMENTOS; agora fica na mesma linha dos Abates, à esquerda (respeita o texto Grande).
- `arena._exit_tree` também despausa a árvore. Uma arena fechada com carta, mapa ou loja aberta deixava o jogo pausado (o teste RESULT pegava isso de vez em quando e quebrava o teste seguinte).
- `testes/resultado.gd`: depois do mapa, espera a fase nova começar (o nó pode ser sem combate) antes de conferir as estatísticas. 6/6 rodadas sem falha; os 9 testes com falhas=0.
- **Pendente:** a tela do mapa e a loja ainda não têm mouse e controle como as outras telas da #7.

## 2026-10-05 · Claude do Alisson (PC) · #32 item 5: inimigos tenebrosos, vida nos inimigos e fase de horror
**Feito**
- **6 inimigos novos** pelo pipeline Blender -> pixel art (`fonte_arte/modelos3d/horror.py`, `blender -b -P horror.py [-- nome]`): Carniçal (rastejante, enxame rápido), Cão de Ossos (investida), Cavaleiro Oco (armadura vazia, pesado, investida), Espectro (atira orbe de longe, flutua), Abominação (ELITE: 420 de vida, invoca carniçais, aura vermelha) e o chefe **O Arauto Sem Rosto** (anel de orbes + investida + invoca espectros, vida 1100). Saem em `assets/gerado/inimigo_*.png` (3 quadros: andar A, andar B, branco do dano) e `proj_orbe_*.png`. Olhos e chamas são emissivos e a paleta ganhou um vermelho-brasa (`ff3a2a`) pra eles passarem pela escuridão. Dados em `dados/inimigos.json` (campos novos documentados no `_ajuda`: `conjunto`, `escala`, `ritmo`, `balanco`, `flutua`, `aura`, `elite`, `cor_morte`, `luz`). Escala 1 (pixel do tamanho do herói) em vez dos 2x dos vírus.
- **Vida no `_draw` de `inimigos.gd`** (tudo derivado de `_t`, `id`, `flash`, `estado`, nada novo na rede): pulinho e respiração (squash leve) acompanhando a troca de quadro, voo com sombra no chão, **telegrafar a investida** (agacha, treme, avermelha e pisca branco no fim; esticado na disparada) e **squash ao levar dano** junto do flash branco. Sprite e posição agora em pixels inteiros.
- **Bug antigo achado e corrigido:** `Rect2` de largura negativa vira o sprite mas o Godot desenha a partir da posição pra direita (não normaliza), então todo bicho À DIREITA do herói saía deslocado uma largura inteira do ponto de acerto (a sombra, que faz a conta certa, ficava no lugar certo). Agora a posição é a borda esquerda nos dois casos.
- **Fase de horror = fase 6, "Catacumbas"** (`dados/corrida.json`, antes "Porão"; chefe `arauto`; eventos: anel de carniçais, abominação como chefe-evento, enxame de cães). O diretor ganhou `conjunto()`: cada fase tem `conjunto` (padrão `virus`) e só sorteia inimigos do mesmo conjunto, então nenhum tenebroso vaza pras outras fases e os vírus não aparecem na de horror. `mapa.json`: andar 6 travado em `fase` (um nó sem combate pularia a fase de horror).
- **Escuridão** (`escuridao.gd`, só liga onde a fase tem `escuro` em `corrida.json`: forca, raio_heroi, raio_tocha, nevoa, tom): um ColorRect em tela cheia na CanvasLayer 1 (entre mundo e HUD) com shader que lê a tela e escurece, com luz em degraus pontilhados (Bayer) em volta do herói, das tochas, dos santuários e de inimigos com `luz` (espectro, abominação, chefe). O que é muito claro (olhos, chamas, tiros, números de dano) atravessa a escuridão e ganha um halo pequeno: é assim que os olhos brilham sem desenhar nada por inimigo. Para medir "claro" o shader desfaz o tom do cenário (`chao._ambiente.color`, só leitura). Tochas são decoração sorteada por hash (iguais em toda máquina) desenhada por aqui; névoa no shader; sons graves de vez em quando (`Som.tocar tremor/whoosh` em tom baixo). Foi o caminho do ColorRect e não CanvasModulate+PointLight2D porque os olhos têm que atravessar a escuridão e o HUD não pode escurecer.
- `main.gd`: `--estresse=N` agora sorteia do conjunto da fase (e roda DEPOIS de `--fase`); `--print_tela=horror` (`--fase=6` é o padrão, `--so=<tipo>` mostra um bicho só); `entrada_chefe` aceita `--chefe=<tipo>`; prints desligam `pausar_fora` (a janela perdia o foco e pausava).
- Teste novo `testes/horror.tscn` (`HORROR falhas=0`): os 6 existem com sprite de 3 quadros, conjunto horror, chefe com nome/subtítulo, só uma fase de horror (entre 5 e 9), eventos e sorteio do diretor só do conjunto certo em TODAS as fases, escuridão liga só na de horror (e desliga ao voltar). Os outros 9 testes seguem `falhas=0`; partida com robô (`--fase=6 --pular=120 --build=30`, a Arauto chega) e partida normal com 0 SCRIPT ERROR.
- Prints em `jogos/hordas/prints/horror_fase.png`, `horror_arauto.png` e `horror_entrada_chefe.png`.

**Desempenho (com janela, `--estresse=500`, máquina disputada pelo outro agente, ruído de +-10 fps entre rodadas):** vírus na fase 1 (código antigo) 138; com o `_draw` novo e SEM caminho rápido caiu pra 118-132, então o desenho tem um caminho rápido (vírus parado = o mesmo desenho de antes) e voltou a 138-149. Fase de horror com ~480 vivos: 103-127 (a de horror é mais pesada: sprites maiores, sombras maiores, squash/pulinho por bicho e a escuridão; sem a escuridão deu 98-120 na mesma rodada, ou seja, a escuridão não apareceu acima do ruído). **Não confirmei >=140 na fase de horror.** Falta remedir com a máquina parada e, se precisar, perfilar `_draw` (o `Rect2` negativo, `Visual.sombra` dos sprites grandes e o caminho "rico").

**Pendente / fraco**
- ≥140 fps com 500 não confirmado (acima). Se precisar de folga: tirar o halo do shader (8 leituras por pixel escuro) ou baixar `nevoa`.
- Não existe animação de morte violenta (fica pra depois, como combinado). A arte é 3D low-poly pixelizada: carniçal e cão ainda leem um pouco "de caixas" em tamanho pequeno. O Arauto não tem arte própria de ataque (usa as mesmas poses de andar).
- Online: a escuridão é só visual local (lê `diretor.fase_idx`); os inimigos novos entram sozinhos nos índices da rede (`online.gd` monta pelas chaves de `inimigos.json`), mas não testei horror com 2 máquinas.
- Online (cliente): `aplicar_foto` liga `v.estado = 1` mas nunca mexe em `t_estado`, então o telegrafar da investida aparece já na pose final (agachado, vermelho, tremendo) o tempo todo em vez de ir crescendo. Não quebra; dá pra mandar o tempo restante na foto.
- Os vírus seguem nas outras fases; só a 6 usa os tenebrosos.

**Gancho de cenário (pro outro agente / pro Alisson ligar):** a fase de horror NÃO tem cenário próprio: usa o que `cenarios.json > por_fase[5]` já der, e a escuridão cobre por cima. Pra ela ficar de verdade (cripta/masmorra úmida), basta mapear a fase 6 pra um cenário escuro em `dados/cenarios.json` (`por_fase`) e, se quiser, baixar `corrida.json > fases[5] > cor`. A escuridão é independente: `escuridao.gd` só lê `chao._ambiente.color` pra medir o brilho. Se o cenário trouxer tochas próprias (`luz` nos itens), dá pra somá-las em `Escuridao._atualizar_luzes()` (hoje as tochas são só as dela). `corrida.json > fases[5] > escuro.forca/raio_heroi/raio_tocha/nevoa` são os botões de calibração.
## 2026-10-05 · Claude do Alisson (PC) · #32 itens 4 (herói) e 2: movimento com peso e cenários cheios
**Item 4: movimento do herói** (`jogador.gd`; constantes juntas no topo do arquivo, bloco "Sensação de movimento e de impacto")
- Aceleração e freio com `move_toward` (`passo_vel`, função pura): 0,06 s até a velocidade máxima, 0,07 s pra parar (teste exige ≤ 0,1 s). Velocidade máxima idêntica à de antes (`VEL_BASE * stat("velocidade")`); `_mov` continua sendo a intenção (armas, online e dragão leem `direcao_mov()`), a velocidade real é `_vel`. O dash não mudou; ao sair dele o herói já anda na velocidade pedida.
- Squash/stretch no sprite (`spr.scale`, pivô no pé; camadas herdam): estica ao começar, achata ao parar e no pouso da entrada (`SQUASH_POUSO`). Poeira nos passos e no dash: bolinhas desenhadas no `_draw` do jogador, teto `POEIRA_MAX` 14. Passo com `blip` baixo (-24 dB, `PASSO_SOM`).
- Dano: flash branco de 0,09 s por shader só no sprite do jogador (`use_parent_material` nas camadas; o material só fica no sprite durante o flash), empurrão pequeno pra longe do vírus mais perto quando o golpe não manda direção (`DANO_EMPURRAO`), tremor que já passava por `Config.v("tremor")`. **Opção nova** "Flash ao levar dano" (Acessibilidade, `flash_dano`, padrão Sim).
- Hitstop (`arena.hitstop`): só solo, só crítico (0,04 s, no mínimo 1,2 s entre um e outro) e morte de chefe (0,14 s). Mede tempo real (`Time.get_ticks_msec`) e encolhe o `dt` da arena em vez de mexer em `Engine.time_scale`, então não briga com a câmera lenta das entradas. Nunca no online.
- Não toquei em `inimigos.gd` nem em `inimigos.json`: o gancho do crítico é `arena.registrar_dano` e o do chefe é `arena.inimigo_morreu`. Por isso o hitstop de crítico vale pra qualquer inimigo, não só chefe.

**Item 2: cenários cheios** (`cenario.gd`, `chao.gd`, novo `ambiente.gd`, `dados/cenarios.json`, `cenarios.py`)
- 12 props novos gerados no Blender (baixos e escuros): laboratório vela (luz), livros, tubo quebrado (luz), cadeira; masmorra pedras, braseiro (luz), jarro, crânio com vela (luz); cidade sacos de lixo, banco, barril em chamas (luz), caixa de correio. Atlas e `cenario.json` regenerados (os pisos também, mesma semente do script).
- `Cenario.celula(cx, cy)`: cada célula de 150 px sorteia props (1 + chance de um 2º, afastados 38 px), detalhes de chão e bichos com `Sorte.criar("cenario_<nome>", hash(célula))`. Mesma semente da corrida = mesmo mapa em todo cliente (substituiu o `hash(Vector2i)` antigo, que era igual em toda corrida). Cache de até 500 células.
- `ambiente.gd`: detalhes de chão (rachadura, mancha, poça com reflexo, folhas, papel, cabo), partículas ambientes (poeira no laboratório; cinzas e névoa na masmorra; chuva fina e vaga-lumes na cidade; teto 70, uma textura só pra névoa), e bichos (rato, morcego, corvo) que ficam parados e fogem do herói a menos de `fuga` px, voam se tiverem asa e somem. Tudo desenho (`_draw`), zero colisão. O chão estático só redesenha quando entra célula nova ou há bicho mexendo (polígono por quadro custava caro).
- Luz que treme: três senos de períodos diferentes e a poça de luz "respira" junto. Tudo em dados (`densidade`, `segundo`, `detalhes`, `particulas`, `vida` por cenário em `dados/cenarios.json`).
- `main.gd`: modo `--print_tela=cenario` (`--fase=N --espera=S`, `--limpo`, `--bichos`).
- Prints antes/depois em `jogos/hordas/prints/cenario_fase{1,4,8}_{antes,depois}.png`.

**Testes**: `testes/movimento.tscn` (`MOVE falhas=0`: parada ≤ 0,1 s, velocidade máxima igual à de antes, flash e tremor seguem as opções, hitstop só solo e só crítico, mesma semente = mesmos props em 2 instâncias nos 3 cenários, semente diferente muda, sem nó de colisão, tetos). OPCOES, EQUIP, REGRAS, DRAGAO, ANIM, RESULT, DESCOB, MAPA e UI em 0 falhas; partida com robô (fases 1 e 8) com 0 SCRIPT ERROR.
**Desempenho**: `--estresse=500 --fase=4` com janela deu 114-126 fps com os cenários novos contra 113-135 sem (a máquina estava ocupada com outro Godot e o ruído é grande; o custo medido do conjunto novo ficou em ~5-10%). **Não bateu os 140 fps** pedidos nesta máquina neste momento, e o baseline sem as mudanças não pôde ser medido limpo; reconferir numa máquina parada. O grosso do quadro (5 ms) é `inimigos.atualizar`.
**Pendente / fraco**: não ouvi o som do passo (só conferi por código); ratos ficam pouco visíveis nos pisos escuros (de propósito, contraste baixo); hitstop de crítico não distingue chefe; bichos não existem no online além do visual local (cada cliente sorteia igual, mas a fuga é local); props altos (poste, estante) ainda podem esconder um vírus atrás deles.
**Próximo**: medir fps em máquina parada, ouvir os passos, talvez props com `peso` por fase e névoa na fase de horror.

## 2026-10-05 · Claude do Alisson (PC) · inimigos de horror andavam de costas
- Relato do Alisson: "personagens andando de costas em direção ao jogador". A causa: os 6 inimigos de horror (#45) foram renderizados **olhando pra esquerda**, mas o jogo espelha quando o bicho está à direita do herói (`inimigos.gd`, `vira = v.pos.x > jx`), ou seja, supõe arte olhando pra direita (como os vírus, que são de frente). Quem vinha pela esquerda andava de ré.
- `horror.py` agora espelha cada quadro ao montar a folha, e a docstring passou a dizer a regra certa. Os 6 PNGs foram espelhados (mesmo resultado de rodar o Blender de novo). Conferido no print da fase 6: os bichos dos dois lados olham pro herói.

## 2026-10-05 · Claude do Alisson (PC) · música mais dark: 6 faixas novas, gerador novo
- Pedido: "A música precisa ser mais dark". As 4 faixas antigas (cairu/fonte_audio, chiptune 22 kHz, 21-37 s, menu em C maior!) foram substituídas por faixas estéreo de 64-84 s, sintetizadas por **jogos/hordas/fonte_audio/gerar_musica.py** (numpy + ffmpeg/libvorbis): drones graves, coro formântico, sinos inarmônicos, órgão, cello/baixo, tambores de guerra afinados na tônica, sussurros e reverb de convolução. Tudo circular (notas e reverb dão a volta), então o laço emenda sem estalo; limitador suave (pico <= -2,6 dBFS antes do ogg).
- Faixas: menu (Ré frígio, 46 bpm, coração distante), minijogo_tenso = as fases (Mi frígio, 72 bpm, taiko + galope de baixo), **chefe** (NOVA; Fá# menor com 2ª menor e trítono, 91 bpm, metais cromáticos e rufar), minijogo_retro = duelo PvP (Lá dórico, 88 bpm), fim (Sol eólio, 40 bpm, lamento), **horror** (NOVA; drone com trítono batendo, sussurros, coração, sinos raros, sem melodia).
- Gancho mínimo em `arena.gd` (`_musica_da_fase`): a fase pode ter `"musica"` em corrida.json (Catacumbas = horror; as outras caem em fase.json), e ao chegar o chefe toca `"musica_chefe"` da fase ou `chefe`. Volta à música da fase no andar seguinte.
- Medido (antes -> depois, centróide espectral): fim 1806->602 Hz, menu 1899->637, duelo 1560->663, fases 1791->520; chefe 711 e horror 579 são novos. Picos -5,0 a -9,0 dBFS, RMS -19,7 a -24 dBFS, 0 amostras clipadas, salto no ponto de laço dentro da variação normal do sinal. Espectrogramas e relatórios (antes/depois) ficaram só no scratchpad da sessão; `analisar_musica.py` os refaz.
- **Ninguém ouviu ainda.** Só há medição por dados. Risco: equilíbrio entre instrumentos (pesos em `MIX`) foi ajustado por energia, não por ouvido; tonalidade estimada por perfil de Krumhansl erra em música modal (ex.: menu sai "Ré# maior"), por isso o relatório traz também a nota mais forte no grave.
- Regerar: `cd jogos/hordas/fonte_audio && python gerar_musica.py [faixa]` e `Godot --headless --path ../projeto --import`. Medir: `python analisar_musica.py <pasta_oggs> <saida> <rotulo>`.
- Pendente: ouvir e ajustar `MIX`/andamentos; crossfade entre faixas em `Som.musica` (hoje troca seca); decidir se o duelo e o fim merecem variações.
## 2026-10-05 · Claude do Alisson (PC) · Hazaki em 8 direções: folhas de 8 linhas e olhar que gira suave
- Pedido: "mais animações de direção e transição mais suave entre as direções".
- `hazaki.py` agora gera 8 linhas (folhas 1012x480, corpo, andando_8 e as 9 camadas): 0 baixo, 1 esquerda, 2 direita, 3 cima (idênticas às antigas, conferido pixel a pixel) e 4 baixo-esquerda, 5 baixo-direita, 6 cima-esquerda, 7 cima-direita (rotação de -45/45/-135/135°). Diagonais e perfil caem deitando de lado na morte. Camadas encaixam e o pé fica no mesmo lugar (conferido na prévia ampliada).
- Novo `scripts/hordas/direcao.gd`: tabela `LINHA` num lugar só (jogador/rival/remoto usam `Direcao.LINHA`), `linhas_da_altura` (altura/60; 8 -> 8 direções, senão 4), funções puras `girar` (800°/s, caminho mais curto) e `direcao_de` (histerese de 8° além da fronteira do setor) e uma instância com `atualizar(mov, dt, n)` que guarda ângulo, alvo e direção. Folha de 4 linhas (heróis da Cairu) usa exatamente a regra antiga do eixo dominante, sem giro. Parado mantém o alvo e termina o giro que faltava; ataque/dano/defesa/morte usam a direção atual.
- `jogador.gd`, `rival.gd`, `remoto.gd`: `vframes` vem da altura da textura (também no rastro do dash e no rival); `jogador.entrada_forcada` + `--andar=x,y` no print do Hazaki servem só pra tirar print andando numa direção.
- Testes: novo `testes/direcoes.tscn` (`DIR falhas=0`: 8 vetores -> linha certa, 4 linhas = regra antiga a cada 5°, baixo->cima passa por diagonais sem repetir, giro limitado, histerese não pisca, jitter de 8° na diagonal, parar mantém); `animacao.gd` ajustado pra setar `_olhar`. Os 11 testes antigos em 0 falhas; partida com robô do Hazaki com 0 SCRIPT ERROR.
- Pendente: o `--import` do Godot 4.4.1 fecha com segfault no fim (já acontecia, os PNGs importam). Dragão/transformação e Cairu seguem com 4 linhas; gerar 8 linhas pra eles é trabalho futuro (a lógica já aceita). Não ouvi/joguei na mão: o giro de 800°/s foi validado só por teste e print, ajustar `VEL_GIRO`/`HISTERESE` em `direcao.gd` se ficar lento ou rápido.
## 2026-10-05 · Claude do Alisson (PC) · aura envolvendo o herói e monstros suaves
**A) Aura do Hazaki** (`armas/aura_energia.gd`): o anel de chamas (cones) agora tem raio 24x7 px em volta do corpo e é desenhado em duas passadas: a metade de trás (lado de cima da elipse) no nó de trás (alfa 0,62) e a da frente (lado de baixo) por cima do herói (alfa 0,42, chamas 20% mais baixas pra não esconder). Print ampliado em `scratchpad/fotos_j/aura_depois.png`.
**B) Monstros suaves.** Medição antes/depois em `scratchpad/saltos.md` (flag nova `--saltos`: `inimigos.medir`, relatório no fim do `--sair`). Resumo, solo fase 4 com 150 bichos em 88 s: saltos > 2,5x a velocidade **6981 (separação) + 321 (reciclagem) + 8 (knockback) -> 2 (knockback, 1,7 px)**; reciclagem virou teleporte animado (406). Online cliente: 363 -> 205 passos rápidos (só empurrões reais), bichos recriados (piscando) 581 -> 243.
- Causa principal: a separação entre vizinhos entrava inteira só a cada 2 quadros (tranco de até 18 px). Agora `v.sepv` entra aos poucos todo quadro, teto 1,2x velocidade.
- Andar suavizado (`v.vm`, ~70 ms), knockback com teto 360 px/s, virar girando (~0,2 s, `v.flip`).
- Teleporte de propósito (`_teleportar`): reciclagem (> 720 px) e salto > 150 px no cliente online somem numa nuvem escura (fantasma no `_draw`, só se perto da tela, teto 24) e reaparecem em 0,26 s crescendo/opacos; nascimento usa a mesma animação (`t_nasc`). Sem custo pra quem anda normal.
- Online: cliente interpola linearmente entre fotos de 15 Hz (`p_ini`/`p_fim`, extrapola meia foto) em vez do `lerp(dt*12)` com pulo; `online.gd` manda os MAIS PERTO quando passa de 220 no raio (cortar por ordem da lista fazia o bicho entrar e sair da foto); cliente segura bicho ausente 0,45 s (`AUSENTE_T`).
- Teste novo `testes/suavidade.tscn` (`SUAVE falhas=0`): limite por quadro sem animação, reciclagem toca animação, fantasma, cliente online (deslize, salto 400 px, foto vazia sem piscar), aura atrás/frente com alfa < 1. Todos os outros testes em 0 falhas; partida de robô (fase 1, 120 s; fase 4 com 150; online host+join) com 0 SCRIPT ERROR.
- **Desempenho** (`--estresse=500 --fase=4` com janela, ruído enorme porque outros agentes usavam a máquina): base 103-112 fps, novo 96-112 fps; `inimigos.atualizar` ~3,0-3,3 ms contra ~3,6-4,3 ms (cerca de +10%, uns 0,4 ms). Não piorou de forma clara mas não deu pra provar que ficou igual; reconferir numa máquina parada.
- **Pontos fracos**: não vi o quadro do meio da animação de nuvem num print (só pelo teste lógico e 0 erro de desenho); a reciclagem acontece fora da tela, então o jogador quase nunca a vê (a animação só aparece se o bicho estiver perto da borda); empurrões do cliente online ainda aparecem em ~15 Hz interpolados (suave, mas com uma foto de atraso); o que o Alisson via "teleportar" era provavelmente o tranco da separação e o pop-in do anel de nascimento a 230 px, não a reciclagem.
- Tocado fora do pedido: `main.gd` (flag `--saltos`), `online.gd` (`_enviar_fotos`). Não toquei em `jogador.gd`, `rival.gd`, `remoto.gd`.

## 2026-10-06 · Claude do Alisson (PC) · nome do projeto: KIKIU-Survival
- Pedido do Alisson: o repositório passa a se chamar **KIKIU-Survival**. Quem renomeia é o Breno (Settings → General → Repository name), porque exige admin. Este PR só atualiza o título do README, a raiz da árvore de pastas e o `CLAUDE.md`. Mergear **depois** de renomear.
- Depois do rename, cada máquina pode atualizar o remoto (opcional, porque o GitHub redireciona): `git remote set-url origin https://github.com/brenoalmeidatec/KIKIU-Survival.git`.
## 2026-10-06 · Claude do Alisson (PC) · mortes violentas e finalizações: efeito pela causa do golpe final + chefe por arma (#32, pedido do Breno)
**Feito**
- **Causa do golpe final:** `inimigos.ferir` grava `arma_ult`/`dir_ult` no inimigo (`ferir_remoto` zera: arma do outro jogador não vem na rede). O Poder Elemental marca o elemento antes de ferir (`v.causa_pend`, só em quem tem o campo: lutador do duelo não tem). Tabelas em `dados/mortes.json` (arma -> causa -> efeito; sem entrada cai no `tipo` do armas.json; depois "padrao"). `Mortes.causa_de/efeito_de` são funções puras.
- **`scripts/hordas/mortes.gd`** (nó filho da arena, atualizado em `arena._process` mesmo com `entre_fases`): fogo = queima até cinza (escurece, encolhe, chamas e brasas), gelo = congela e estilhaça (polígonos com o próprio sprite), raio = silhueta piscando com zigue-zague e cai chamuscado, corte = duas metades que se separam com sangue, impacto/explosão = 9 pedaços + sangue escuro + onda, tiro = jogado pra trás com buracos e jato, aura = faixas cobalto subindo, padrão = clarão rápido. Tudo desenho (`_draw`) em função do tempo (sem estado por pedaço). Sangue = `cor_morte` do inimigo escurecida (senão vinho). Só tem efeito quem morre perto da tela. **Teto** (`dados/mortes.json`): 16 efeitos grandes, 400 partículas, 32 mortes simples, 24 manchas; passou, usa a morte simples e depois some como antes. (Pedido sugeria ~24/~600; baixei porque o pico de mortes simultâneas custava ~40 fps com 24/600.)
- **`scripts/hordas/finalizacao.gd`** + `dados/finalizacoes.json`: chefe morto -> golpe pela arma (katana = corte em X que parte o chefe; pistolas = rajada que fura; marcial = soco que lança e quebra em pedaços; aura = coluna cobalto que desintegra; elemental = fogo, gelo e raios do céu e estilhaça; resto = explosão). Câmera lenta + zoom só no solo, em tempo real, restaurados no fim, ao iniciar outra e no `_exit_tree` da arena; pausado (carta de nível) congela e solta o tempo; online só o desenho. Tremida via `arena.tremer` (respeita a opção). Chefes de `inimigos.json` incluem o Ransomware (mini-chefe), então ele também tem finalização.
- **Opção** "Mortes violentas" Normal/Reduzida (Acessibilidade, `Config.v("mortes")`): Reduzida troca tudo pelo efeito `suave` (tingido, sem sangue e sem partes) e a finalização vira coluna de luz.
- `main.gd`: `--print_tela=mortes` (`--conj=virus`, `--reduzida`, `--seq=0.1,0.3,...`) e `--print_tela=finalizacao --arma=<id>` (`--chefe=`, `--seq=`), vários prints no meio dos efeitos (`tela_<modo>_N.png`). Prints em `jogos/hordas/prints/mortes_violentas.png` e `finalizacao_*.png`.
- **Teste** `testes/mortes.tscn` (`MORTE falhas=0`): dados coerentes, causa por arma e por elemento, morte real escolhe o efeito certo, longe da tela sem efeito, 500 mortes de uma vez respeitam o teto, o DESENHO de cada efeito roda num canvas de mentira (conta sangue e partes; Reduzida = 0 e 0), finalização por arma, tempo/zoom voltam no fim e se a arena fechar no meio, online sem câmera lenta. Os outros 13 testes em 0 falhas; partida do robô 140 s com 0 SCRIPT ERROR.
- **Desempenho** (`--estresse=500 --fase=4 --build=30 --sair=40`, ruído de +-10 fps): antes 155 fps no teto, `proc_ms` 7-9; depois 145-155 em regime, mas nos primeiros 5 s (centenas de mortes de uma vez) 98-134 contra 155 de antes. Com teto 24/600 o pico caía a ~100; com 16/400 ~100-134 (ruído).
**Pendente / fraco**
- Não ouvi/joguei na mão; os sons dos golpes são os existentes (soco, tremor, queda, acerto). Aura vira um retângulo de luz simples. Online: quem mata pelo anfitrião vê o efeito, quem só vê o inimigo sumir da foto não (efeito local só no `ferir` do próprio cliente).
- Gerar uma versão "fria" (menos polígonos) pro estilhaço se o pico de mortes pesar.

## 2026-10-06 · Claude do Alisson (PC) · "andando de costas", segunda causa: o besouro
- Quando o Alisson relatou, os inimigos de horror (#46) ainda nem estavam na `main`. O que ele via era o **Bug**: a arte é um besouro visto de cima com a cabeça pra cima, e o jogo só espelha na horizontal, então ele descia na direção do herói de ré.
- `inimigos.gd`: campo `gira` (dados) para bicho visto de cima. Ele gira suave pra direção do passo desenhado (vale no solo e no cliente online); parado mantém o ângulo e teleporte não gira. `dados/inimigos.json`: `"gira": true` no bug. Conferido no print: o besouro aponta os olhos pro herói.

## 2026-10-06 · Claude do Alisson (PC) · fps remedido com a máquina parada
- Comando: `Godot_v4.4.1 --path jogos/hordas/projeto -- --bot --heroi=hazaki --semente=7 --fase=N --estresse=500 --sair=30` (com janela).
- Fase 1: 99–113 fps (proc_ms 12–14) · fase 4: 89–118 fps (12–14) · fase 6 (horror): 90–98 fps (12–15). Antes desta leva: ~150 fps e proc_ms 7–9.
- A queda de ~35% em carga extrema soma cenários (#44), horror e escuridão (#45), suavidade (#47, separação todo quadro) e mortes (#49). Ainda não foi perfilada por partes. **Próximo** se o Breno/Alisson quiserem: perfil por sistema (`perfil=` no log do `--sair`) e otimizar o maior custo primeiro.
- **Pra quem chega (PC e notebook):** depois de `git pull` com PNG/OGG novos, rode `--headless --path jogos/hordas/projeto --import` antes de jogar sem o editor, senão o Godot usa o cache velho. Testes: 14 cenas em `testes/` (todas `falhas=0` nesta data). Prints ficam em `jogos/hordas/prints/`.

## 2026-10-06 · Claude do Alisson (PC) · desempenho: perfil por sistema e ~1,7x mais fps com 500 inimigos
- **Medidor novo** `scripts/hordas/perf.gd`: `Perf.ini()/fim(nome, t0)` somam microssegundos por trecho; liga com `--sair` e o log imprime uma linha `perf_us:` a cada 5 s (média por quadro: inimigos [grade, laço, ordem/sombra/sprite do _draw], chão, ambiente, mortes, efeitos, coleta, armas, jogador, HUD, escuridão). `--sem_limite` (argumento do jogo, depois do `--`) desliga V-Sync e teto de fps só pra medir: com V-Sync o fps trava no refresh do monitor (144 Hz) e esconde o ganho.
- **Maior custo era `inimigos`** (separação ~2,8 ms + desenho ~2,2 ms de ~9,5 ms/quadro com 500 bichos; o resto somava < 1,5 ms). Mudanças: (1) grade com chave inteira (`(cx<<16)+cy`) no lugar de `Vector2i`; (2) separação recalculada a cada ~40 ms (`SEP_PERIODO`; ~100 ms se o bicho está a mais de 380 px do alvo), continua aplicada aos poucos todo quadro (`sepv`); (3) `exp` do knockback fora do laço; (4) `_draw` só desenha quem está na tela (retângulo visível pelo `get_canvas_transform`, folga pelo tamanho do sprite), ordena com chave numérica nativa todo quadro (antes `sort_custom` a cada 4) e guarda a sombra assada de cada bicho (`V.sombra_reg`, `Visual.sombra_regiao/carimbar`); (5) `chao.gd` guarda a lista de enfeites visíveis (só refaz ao entrar em célula nova) e não desenha os fora da tela.
- **Resultado** (500 bichos, sem limite de fps, mediana): fase 1 ~140 -> 250-400 fps (proc_ms 9-10 -> 4,6-5,7); fase 4 ~115-130 -> 245-255 (9,0-9,7 -> 5,8-6,5); fase 6 ~120-135 -> 200-255 (9-11 -> 6-8). Com V-Sync (monitor 144 Hz): 94-116 -> 143-145 (no teto). Tabela completa por fase e por sistema em `docs/PERF_2026-10-06.md`.
  Por sistema (µs/quadro, fase 4, antes -> depois): inimigos.atualizar 3078 -> 1322, desenho dos inimigos (ordem+sombra+sprite) 2105 -> 1100, chão 214 -> 157; o resto (ambiente, mortes, armas, jogador, HUD, escuridão) ficou igual, cada um < 0,4 ms.
- **Pontos fracos / para conferir de olho:** a separação agora reage em ~40 ms em vez de ~14-20 ms (nos testes `suavidade`/`movimento` segue em 0 falhas, mas não vi grupo denso na mão); bichos fora da tela já ficam virados pro herói (não animam a virada); ninguém usa a opção "Desempenho" (não precisou: meta batida); `mortes._draw` varia 0,1-0,6 ms conforme as mortes do momento, e o horror (fase 6) ainda gasta ~0,1 ms na escuridão e ~0,25 ms no chão vivo. Perf fica ligado só com `--sair`; desligado cada ponto custa um `if`.
- Pendente: nada. Dica: pra comparar versões use `--sem_limite --sair=30` e a mediana dos `perf_us`; o V-Sync da máquina ficou irregular no fim da sessão (~27 fps com V-Sync nos dois códigos, 250 sem limite).
## 2026-10-06 · Claude do Alisson (PC) · músicas de licença aberta: 7 faixas de Kevin MacLeod (CC BY 4.0) no lugar das geradas
- Pedido: "músicas de licença aberta e livre de uso, mais SOMBRIAS". Todas de **Kevin MacLeod / incompetech.com, CC BY 4.0** (créditos e tabela em `docs/LICENCAS_AUDIO.md`; tela de Créditos do jogo atualizada, conferida em print). Não achei CC0 sombria com a mesma qualidade sem gastar muito tempo; OpenGameArt/FMA/Freesound não foram usados.
- Mapa: menu = Oppressive Gloom · fases = Crypto (`minijogo_tenso`) e Giant Wyrm (`minijogo_tenso_b`, NOVA) · chefe = Ignosi · duelo = Crusade · fim = Wounded · horror = Long Note Four (trecho). Nomes de arquivo mantidos.
- **Gancho:** `dados/fase.json` `"musica"` agora é lista e `arena._nome_musica(m, andar)` escolhe por rodízio (andar % tamanho); `musica` em corrida.json também aceita lista ou texto. As fases alternam Crypto/Giant Wyrm.
- `fonte_audio/preparar_musica_cc.py` refaz os OGG a partir dos MP3 (corte, crossfade de potência igual no fim=começo pro laço, ganho até RMS alvo, limitador suave acima de -1,5 dBFS, OGG q4 44,1 kHz). `analisar_musica.py` agora também lê .mp3. Os MP3 não estão no repo.
- Medido (OGG finais): 144-186 s, 1,7-2,8 MB cada; pico -0,9 a -8 dBFS, 0 clipadas, RMS -19 a -24 dBFS; centróide menu 809, fases 656/486, chefe 863, fim 591, horror 482, **duelo 1312 Hz (o mais claro)**; salto no laço 0,1-3,9x o típico.
- As faixas geradas por código ficam só no histórico do Git; `gerar_musica.py` segue como plano B.
- Testes (14) `falhas=0`, partida do robô 0 SCRIPT ERROR. **Ninguém ouviu ainda.** Pendente: ouvir (Crusade pode ser clara demais pro duelo; Ignosi pode não soar "coral"), crossfade entre faixas em `Som.musica` (troca seca).

## 2026-10-06 · Claude do Alisson (PC) · monstros viram com sprites de verdade: 5 vistas por monstro, sem achatar
- Pedido do Alisson: virar não pode ser "uma linha 2D"; cada monstro precisa de sprite de frente, de lado, etc. Tirei o achatamento (`v.flip`, `maxf(absf(flip), 0.08)`) de TODOS os monstros.
- **Arte** (`fonte_arte/modelos3d/horror.py`): os 6 de horror (carnical, cao_ossos, cavaleiro_oco, espectro, abominacao, arauto) saem em folha de 3 colunas (andar A, B, branco) x **5 linhas = vistas**: 0 frente, 1 3/4 frente-dir, 2 perfil dir, 3 3/4 costas-dir, 4 costas (esquerda = espelho das 1-3, feito no jogo). Mesma câmera nas 5 vistas (a origem/pé cai no mesmo pixel); a câmera é calibrada pela união dos retângulos de todas as vistas e quadros, medida numa tela de dobro do tamanho (antes a medição cortava). O quadro cresce se o corpo não couber (carnical 46x45, cão 50x43, cavaleiro 43x74, abominação 76x72, arauto 90x126; espectro igual): a densidade de pixels é a mesma, o bicho não muda de tamanho. Prévias em `jogos/hordas/prints/vistas_horror_*.png`.
- **Jogo** (`inimigos.gd`, `dados/inimigos.json` `"vistas": 5`): cada bicho guarda `olhar` (ângulo a partir da frente) que gira no máximo 540°/s (`GIRO_OLHAR`) até o alvo; solo = direção do herói, **cliente online = deslocamento desenhado** (como o `gira` do besouro). `_orientar()` escolhe o setor de 45° (8 setores, histerese `HIST_OLHAR` 0,12 rad) -> `v.vista` (0-4) e `v.espelho`; roda antes das sombras (a sombra assada agora é por vista x quadro x espelho; `sombra_reg` tem 4 x vistas entradas). Virar da esquerda pra direita passa por 3/4 -> frente -> 3/4 (ou por costas). Fora da tela não gira (`orientar = true`: ao reaparecer já olha pro alvo). Fantasma de teleporte e `mortes.gd` usam `y0` (linha da vista) + espelho. **Vírus** (`vistas` 1, padrão): sempre de frente pra câmera, sem espelhar nem achatar; o besouro (`gira`) segue girando.
- **Teste novo** `testes/vistas.tscn` (`VISTA falhas=0`): folhas com 5 linhas e desenho em todas as 15 células; virada de 180° por frente e por costas nos 6 monstros (largura >= 90% em todo quadro, passa por todos os setores intermediários, sem pular setor, <= 6 trocas); vírus nunca espelham/achatam dos dois lados do herói; cliente online olha pro lado em que anda. Os outros 14 testes seguem em 0 falhas; partida de robô fase 1 (hazaki, semente 7): 0 SCRIPT ERROR.
- **Desempenho** (sem janela, `--estresse=500 --sair=25`, 3 repetições, base = HEAD antes x novo; máquina com ruído): fase 1 proc_ms 4,6-5,7 (base) x 5,2-5,8 (novo); fase 6 4,9-8,3 x 5,2-9,0. Sombra+sprite do desenho dos inimigos ~600-1000 µs nos dois. Dentro do ruído; não vi piora clara (> 10%).
- **Prints com janela** (`--print_tela=virada --bicho=cavaleiro_oco|cao_ossos [--frente]` e `--print_tela=cerco`, `--fotos=pasta`): `jogos/hordas/prints/virada_frente_cavaleiro_oco.png`, `virada_frente_cao_ossos.png`, `virada_costas_cavaleiro_oco.png`, `cerco_fase6_vistas.png`. Nenhum quadro "linha".
- **Pontos fracos**: o cão de frente é naturalmente fino (cabeça de frente, ~12 px de largura num quadro de 50); o cavaleiro oco tem a espada apontando pra câmera nas vistas de frente e o fundo do quadro fica ~12 px abaixo dos pés (a ponta da lâmina; a sombra de contato sai ali); esquerda = espelho, então a espada troca de mão do lado esquerdo; o olhar solo é sempre pro herói (não pro sentido do passo), então bicho que recua (`distancia`) olha pra frente andando de ré.

## 2026-10-06 · Claude do Alisson (notebook) · #55 marcos 1 e 2: qualidade e transições
**Feito**
- **Marco 1 (qualidade):** os 15 testes de `testes/` rodaram 3 vezes cada (45 rodadas) e não tem nenhum instável. Partida inteira com o robô (`--bot --facil --rapido=4`) até a fase 7+ sem nenhum erro de script. Online com **4 jogadores** por 60 s, sem erros e com os abates batendo nos 4 (212).
- **Marco 2 (transições):** autoload `Transicao` (`scripts/hordas/transicao.gd`), uma cortina de losangos de pixel art que encolhem varrendo na diagonal (0,42 s, em tempo real). Toca sozinha em toda troca de tela do `main.gd` (menos entre telas que são a mesma pro jogador, `MESMA_TELA`) e ao abrir e fechar o mapa entre fases. É só desenho: não segura lógica nem teste.
- O resto da lista de sensação de golpe já existia (hitstop em crítico e chefe, tremor, flash, partículas, som de acerto, entradas, finalizações, cartas escalonadas), então não mexi.
- PR #48 (rename) atualizado com a main: está pronto e espera o Breno renomear o repo.

**Próximo:** marco 3 (desempenho: pooling, limites, culling, carregamento), marco 4 (online, banda com 4–6 jogadores), depois a #13.

## 2026-10-06 · Claude do Alisson (notebook) · #55 marco 3: desempenho
- **Bug:** o `--sem_limite` nunca funcionou (ficava depois do `return` dos argumentos de teste em `Config.aplicar`). Consertado. Com ele valendo: notebook a 130–186 fps com ~250 vírus e build de fim de jogo.
- **Medido** (detalhes em `docs/PERF_2026-10-06.md`): carregamento (motor 0,19 s em headless; com janela, 4–5 s são o OpenGL do notebook; título 0,63 s porque pré-carrega tudo; partida abre em 15–50 ms), memória (33 MB + 18 MB de textura, sem vazamento) e o maior custo por sistema (desenho das mortes, 0,74 ms, já com teto).
- Partida inteira com o robô (10 fases + duelo) sem nenhum erro de script.
- **Próximo:** marco 4 (online: banda com 4–6 jogadores).

## 2026-10-06 · Claude do Alisson (notebook) · #55 marco 4: online leve com 4 a 6 jogadores
- **Medidor:** `Rede.banda()` (estatísticas do ENet); o log do `--sair` no online imprime `banda: envia=… recebe=… KB/s`.
- **Foto dos vírus compacta** (`online.compactar/descompactar`): 11 bytes por vírus (eram 24) e 9 por tiro (eram 20), com posição relativa ao cliente em meio pixel. A foto típica caiu de vários KB pra 600–1000 bytes, então cabe num pacote só (antes fragmentava, e um fragmento perdido derrubava a foto inteira, porque ela é não confiável).
- **Posição dos jogadores** em 12 bytes (era um Dictionary de ~150).
- **Medido** (localhost, robôs): 4 jogadores na fase 4, o anfitrião enviava 233–263 KB/s e passou a 62–81 KB/s com MAIS vírus. 6 jogadores: cliente envia 14 → 2,3 KB/s; anfitrião envia 87 → 37 KB/s (~0,3 Mbit/s) e recebe 70 → 11,5 KB/s. 0 erros, abates iguais nos 6.
- Conferido que o cliente mostra o que veio na foto (contagem da foto e vivos batendo). Teste novo `testes/rede.tscn` (ida e volta: id, tipo e flags exatos, posição com erro ≤ 1/4 px).
- **Pendente:** latência alta e perda de pacote de verdade só dá pra ver jogando pela internet. Próximo: #13 (lista de salas, lobby, chat).

## 2026-10-06 · Claude do Alisson (notebook) · #13 PR 1: lobby com apelido e "pronto"
- Cada jogador tem um **apelido**: salvo no `user://online.json` (campo `nome`), sorteado na primeira vez ("Corvo 42"; nunca o usuário do Windows), trocado com **N** no lobby. O anfitrião limpa o que chega (`Rede.limpar_nome`: só o que a fonte desenha, até 16). `Rede.nome_de()` agora devolve o apelido, então ele aparece também no duelo e em cima dos avatares.
- **Pronto:** o cliente aperta Enter ou Espaço; o cartão mostra PRONTO (verde) ou "...". O anfitrião começa quando todos estão prontos; senão avisa quem falta, e um segundo Enter em 3 s começa assim mesmo.
- A linha do anfitrião estourava a largura da tela e mostrava 7777 mesmo com outra porta: agora são duas linhas e `Rede.porta_aberta`.
- Teste: `--nome=X`, `--pronto` (o cliente entra pronto) e `--foto_sala=N` (print do lobby). Conferido em print com 3 pessoas e online com 4 (150 = 150 abates).
- **Próximo:** PR 2, lista de salas. Proposta na #13: rede local por broadcast UDP + internet pelo ntfy.sh (HTTPS, grátis, sem conta). O MQTT público não serve: a rede do notebook bloqueia as portas dele, e muita rede de jogador também.

## 2026-10-06 · Claude do Alisson (notebook) · #13 PR 2: lista de salas (rede local + internet grátis)
- Autoload novo `Salas` (`scripts/hordas/salas.gd`). "Entrar em sala" abre a **lista**: escolhe e Enter entra, sem digitar endereço. "Digitar endereço..." continua no fim.
- **Rede local:** o anfitrião anuncia por broadcast UDP (porta 7778) a cada 2 s; o endereço é o IP de quem anunciou + a porta da sala.
- **Internet:** só se o anfitrião ligar (**L** no lobby) e colar o endereço do túnel playit (**E**, salvo no `online.json` em `publico`). O anúncio vai por HTTPS pro **ntfy.sh** (grátis, sem conta, porta 443), tópico `kikiu-survival-salas-v1`, a cada 30 s; a lista lê os últimos 2 min a cada 10 s. Os testes usam `--topico=` pra não sujar o tópico real.
- **Por que ntfy:** a rede do notebook bloqueia MQTT público (1883 e WebSocket 8083/8084, testado com e sem sandbox), e a 443 passa em qualquer lugar.
- **Segurança:** todo anúncio é validado (`Salas.validar`: versão, tamanhos, tipos, endereço só `[letras números . -]:porta`, nome limpo até 20); no máximo 30 salas. O lobby avisa que o endereço público fica visível.
- Testado: lista mostrando a sala local, anúncio chegando no ntfy, cliente entrando pela lista (lobby com 2), 8 anúncios tortos recusados (`testes/rede.tscn`), online com 4 (157 = 157 abates). Testes ui/opcoes/rede/mapa sem falhas.
- **Pendente:** ver uma sala da internet aparecer em outra casa (precisa de duas redes). Próximo: PR 3, chat de texto.

## 2026-10-06 · Claude do Alisson (notebook) · #13 PR 3: chat de texto
- Autoload novo `Chat` (`scripts/hordas/chat.gd`): no lobby e na partida online. **T** abre, Enter manda, Esc fecha; mensagens somem em 9 s (abertas, aparecem todas). No lobby, 4 linhas embaixo à esquerda.
- **Pelo anfitrião** (`Rede.chat_*`): limpa o texto (só o que a fonte desenha, sem quebra de linha, até 80), segura quem manda mais de uma a cada 0,4 s, e avisa "fulano entrou na sala" / "fulano saiu".
- **Teclado:** enquanto digita, as teclas saem do `InputMap` e voltam ao fechar (o Godot registra a ação antes de qualquer `_input` poder impedir: "e" seria confirmar, espaço seria dash). Os `_input` de main, cartas, loja, resultado e mapa ignoram tecla com o chat aberto.
- Lobby reorganizado: dicas mais curtas embaixo (cabem na tela), aviso em cima dos cartões, cartões encostam com 5–6 pessoas.
- Testado: print do lobby com 6 pessoas conversando, texto com controle e quebra de linha chegando limpo, `testes/rede.tscn` (teclas saem e voltam, texto cortado), online com 4 (109 = 109 abates). ui/mapa/resultado sem falhas.
- **Próximo:** PR 4, chat de voz.

## 2026-10-06 · Claude do Alisson (notebook) · #13 PR 4: chat de voz
- Autoload novo `Voz` (`scripts/hordas/voz.gd`), no caminho que a issue sugeriu. Microfone → bus "Microfone" mudo com `AudioEffectCapture` → 8 kHz mono (média, filtro barato) → **mu-law 8 bits** → pacotes de 60 ms sem garantia de entrega (`Rede._voz`, o anfitrião repassa) → um `AudioStreamGenerator` por jogador. ~8 KB/s por quem fala; pacote atrasado é jogado fora (não acumula atraso).
- **Opções → Som:** "Voz no online" (Desligada / **Segurar V**, o padrão / Sempre aberta, que só manda quando tem som) e "Volume das vozes". O microfone **só liga quando precisa** (segurando V, ou sempre aberta) e só online. `project.godot`: `audio/driver/enable_input=true`.
- **Lobby:** número em cada cartão, **1–6** silencia quem está nele (aparece MUDO), ondinhas verdes em quem está falando; dicas em 2 linhas. Na partida, o chat mostra "))) fulano" acima das mensagens.
- Opções compactadas (12 px por linha): com acessibilidade e voz, a tela passava das dicas.
- Testado sem microfone com `--voz_teste` (um tom de 3 s no lugar da voz): o anfitrião recebeu 100% e o outro cliente, pelo repasse, 100%, 96% e uma vez 61% (perda pontual no começo da partida; voz sem garantia de entrega, como telefone). mu-law em `testes/rede.tscn` (erro < 5%). 17 testes sem falhas; online com 4 (113 = 113).
- **Não testado:** microfone de verdade e ouvido humano (o notebook não fala com ele mesmo). **Para o Alisson:** testem os dois numa sala, segurando V.

## 2026-10-06 · Claude do Alisson (notebook) · #63 marco 1: especial por herói (tecla E)
- `dados/especiais.json` + `scripts/hordas/especial.gd` (nó da arena: recarga, tecla **E** / **Y** no controle, robô usa com 6+ inimigos perto, grito em cima da cabeça, bônus temporário que `arena.stat` soma). O efeito de cada um é um módulo no padrão das armas (`scripts/hordas/especiais/`, registrado em `armas.MODULOS`).
  - **Hazaki — "Sou Gostoso!"** (`pose`): o Breno grita que é gostoso quando perde a discussão. Anel dourado com raios: dano, empurrão, atordoa os de perto (chefe/elite só lentos) e +30% crítico +25% dano por 6 s. Recarga 30 s.
  - **Nicão — "Na Manha"** (`manha`): "tranquilo, tranquilo". Invencível 4 s, cura 35% da vida, bolha calma que deixa lento e machuca de leve quem chega perto. Recarga 34 s.
  - **Lucas — "Pegou Onda"** (`onda`): pegada de surfista. Onda gigante que ele surfa (dash de 0,42 s): atropela e arrasta tudo na faixa. Recarga 24 s.
- HUD: rosto do herói no canto de baixo à direita, recarga escurecendo como relógio, segundos, pisca dourado quando está pronto, "E: nome" em cima. Aviso na primeira vez que fica pronto.
- Dano cresce com o atributo dano e com o nível (`escala_nivel`). Os 5 heróis que só aparecem no duelo ainda não têm especial (é só pôr no JSON).
- Teste novo `testes/especiais.tscn` (ESPECIAL falhas=0, 3 rodadas). Prints com `--print_tela=especial --heroi=X --estresse=N`. Robô: 2 usos por herói em 60 s, 0 erros; online com 4 (160 = 160). Os 18 testes sem falhas.
- **Próximo:** #63 marco 2, calor.

## 2026-10-06 · Claude do Alisson (notebook) · #63 marco 2: calor
- `dados/calor.json` + `scripts/hordas/calor.gd` (escolha `{id: nível}` validada, pontos, efeitos somados, recompensa, salvo em `user://calor.json`) + `scripts/hordas/tela_calor.gd` (a tela). Como o Pacto de Punição do Hades: 9 modificadores (Couro de Pedra, Garras Afiadas, Fome de Sangue, Horda sem Fim, Sangue Nobre, Ira dos Senhores, Feridas Abertas, Corpo Frágil, Destino Selado), até 22 pontos. Cada ponto rende +8% de ouro e +4% de XP.
- **Onde vale:** vida/dano/velocidade dos inimigos e vida extra dos chefes (`inimigos.criar`), tiros deles, orçamento e elites do diretor, cura e regeneração, vida máxima do herói e cargas de cartas (`arena.ef()`, `arena.stat`). No duelo entre pessoas, não.
- **Fluxo:** solo, herói → **Calor** → corrida (Esc volta pros heróis). Online, o anfitrião aperta **C** no lobby; o total aparece pra todos ("Calor N") e a escolha vai nas opções do começo (os clientes usam a do anfitrião, não a deles). Resultado mostra o calor.
- **Bug achado:** a fonte (Press Start 2P) trocava "fi" por "ñ" (ligadura): "Afiadas" saía "Añadas", e qualquer texto com "fi" estava errado. Ligaduras desligadas em `Dados._ready` (vale pro jogo todo).
- Os prints de teste (`--print_tela`) desligam a transição (a cortina saía na foto; no jogo de verdade ela some em 0,43 s, medido).
- Teste novo `testes/calor.tscn` (CALOR falhas=0); online com 4 e `--calor=couro:2,garras:1` no anfitrião (os 4 com calor 3 e 142 abates). Os 19 testes sem falhas. `--print_tela=calor` mostra a tela.
- **Próximo:** #64, estrutura das regiões.

## 2026-10-06 · Claude do Alisson (notebook) · #64 marco 1: estrutura das regiões (5 × 5)
- **`dados/regioes.json` + `scripts/hordas/regioes.gd`:** 5 regiões (Floresta Sombria, Pântano Pútrido, Deserto de Ossos, Pico Congelado, Reino Sombrio), 5 fases cada. Os 4 primeiros andares saem sorteados do repertório da região (peso, sem repetir; `Sorte.fluxo("regioes")`, igual em todos os clientes) e o 5º é sempre o **chefe da região**. Cada fase herda da região conjunto, cenário, música, cor e **calor** (a dificuldade sobe de região em região; a recompensa conta só o calor do jogador). O chefe da última região leva ao duelo.
- **Mapa:** um mapa por região (regras do `regioes.json` > `mapa`, andar local) **costurado** num só de 25 andares (`Mapa.costurar`): o chefe de cada região leva a todas as entradas da próxima. Pro resto do jogo é o mesmo mapa (andar global = região × 5 + andar), então votação online, robô e `--fase=N` continuam iguais. A tela do mapa mostra só a região do próximo andar ("PÂNTANO PÚTRIDO · Região 2 de 5 · andar 1 de 5") e o nome do chefe no nó de chefe.
- HUD ("FLORESTA SOMBRIA 2/5  TRILHA TORTA"), anúncios (nome da região grande na entrada, "REGIÃO CONQUISTADA!" no chefe), resultado da fase, cenário (`chao` lê o da fase) e música por região. `minutos_por_fase` 1,2 → 0,55 (25 fases).
- **Conteúdo provisório:** as 4 primeiras regiões ainda usam os inimigos e chefes de vírus e os cenários que existem; o Reino Sombrio já usa os tenebrosos, as Catacumbas (com escuridão) e o Arauto, e o chefe final provisório é a Tela Azul. Cada próximo PR troca no `regioes.json` só os campos da sua região (conjunto, cenário, chefe) pela arte nova.
- O `corrida.json` > `fases` só vale sem `regioes.json` (fica de reserva); `cartas` continua valendo.
- Testes: `testes/regioes.tscn` novo (corrida sorteada, costura, calor e cenário por região); `mapa` (regras por região, robô atravessa os 25 andares) e `horror` (escuridão onde a fase tem `escuro`) atualizados.

## 2026-10-06 · Claude do Alisson (notebook) · #64 marco 2: Floresta Sombria (arte da região 1) + pesquisa do Dimraeth (#68)
- **Corrida inteira com regiões (robô, `--bot --facil --rapido=6`):** atravessou as 5 regiões até a fase 25 (nível 85, 26.273 abates, 28 min de jogo), 0 erros de script; morreu no chefe final (dado pro equilíbrio, #63 item 7).
- **Monstros** (`fonte_arte/modelos3d/floresta.py`, 5 vistas como os tenebrosos): Cogumelo Errante, Lobo Sombrio (investida), Corvo Carniceiro (voa), Aranha Tecelã (cospe teia), Espantalho Podre (pesado), **Galhudo** (elite: árvore jovem que anda), **Bruxa do Mato** (guardiã das fases: anel de orbes verdes, chama lobos) e **O Velho Carvalho** (chefe da região: tronco com rosto, anel de esporos, chama cogumelos). Projéteis `proj_teia`, `proj_orbe_bruxa`, `proj_esporo`. Conjunto `floresta` no `inimigos.json`.
- **Cenário `floresta`** (`cenarios.py`): chão de mata (terra, capim, folhas caídas, raízes, musgo) e 10 enfeites (árvore viva, árvore morta, toco, tronco caído, arbusto, pedra com musgo, **cogumelos que brilham** e **fogueira** com luz, caveira de cervo, teia). Clima no `cenarios.json`: vaga-lumes, névoa baixa, folhas no chão, corvos que fogem.
- `regioes.json`: a Floresta usa tudo isso (as outras 4 regiões continuam provisórias).
- **Refatoração:** a máquina dos monstros (materiais base, peças, paleta, folha de 5 vistas) saiu do `horror.py` pro `monstros.py`, que as regiões usam; novas peças `galho` e `junta`. Rampa `folha` no `pixel3d.py`. Conferido que o `horror.py` refatorado gera o mesmo (o espectro varia um pouco entre duas rodadas iguais do Blender, então não recommitei os PNGs dele).
- **#68 (Dimraeth):** pesquisa e plano em `docs/DIMRAETH_ADAPTACAO.md` (luz que conta a história da região, clima por região, rolamento de esquiva com fôlego, telegrafia, câmera que olha à frente).
- **Próximo:** Pântano Pútrido.

## 2026-10-06 · Claude do Alisson (notebook) · #64 marco 3: Pântano Pútrido (arte da região 2)
- **Monstros** (`fonte_arte/modelos3d/pantano.py`, 5 vistas): Sanguessuga Gigante (enxame), Sapo Podre (pula), Afogado (lento e duro), Fogo-Fátuo (flutua e atira chamas verdes), Jacaré do Lodo (pesado, investida), **Golem de Lodo** (elite com aura), **Rainha Sapo** (guardiã das fases: anel de bolhas de veneno, chama sapos) e **A Mãe do Lodo** (chefe da região: anel de lodo, chama sanguessugas). Projéteis `proj_bolha_veneno`, `proj_chama_fatuo`, `proj_lodo`. Conjunto `pantano` no `inimigos.json`.
- **Cenário `pantano`** (`cenarios.py`): chão de lama com poças escuras, limo, vitórias-régias e juncos, e 10 enfeites (árvore do brejo com barba de musgo, juncos, poça com vitórias-régias, passarela, **lanterna em poste** com luz verde, barco podre, lápide torta, ossos na lama, raízes em arco, **velas num toco** com luz quente). Clima no `cenarios.json`: névoa verde, garoa, vaga-lumes, poças e manchas no chão, corvos e ratos.
- `regioes.json`: o Pântano usa tudo isso (6 fases com eventos dos bichos novos; o "Trono do Lodo" com a Mãe do Lodo).
- **Bug de teste corrigido:** com `--fase=N` o anúncio e a música eram os da fase 1 (o salto vinha depois do anúncio). `saltar_para_andar` agora anuncia o andar de destino e troca a música (`hud.limpar_mensagens()` novo).
- **Medido:** 500 bichos no pântano, 98–201 fps (a floresta, no mesmo teste, 110–243). A `luz` dos fogos-fátuos só é desenhada em fase com escuridão, que o pântano não tem. O robô (`--fase=6 --build=22 --facil --imortal`) atravessou a região inteira, matou a Mãe do Lodo e entrou no deserto (fase 13, nível 69, 10.435 abates), com 0 erros de script. Os 19 testes passam sem falhas.
- **Para o #68 (anotado, não mexi):** depois de apanhar, o herói pisca **100% invisível** (`jogador.gd`, `spr.visible = not piscar`). No pântano escuro e cheio ele some da tela em metade dos quadros. No PR de legibilidade, trocar por meia transparência.
- **Para o #65:** o santuário "Tomada" (ícone de tomada elétrica) ainda aparece nas regiões novas.
- **Próximo:** Deserto de Ossos (já em andamento: `deserto.py`).

## 2026-10-06 · Claude do Alisson (notebook) · #64 marco 4: Deserto de Ossos (arte da região 3)
- **Monstros** (`fonte_arte/modelos3d/deserto.py`, 5 vistas): Escaravelho (enxame), Abutre (voa), Esqueleto das Areias (cimitarra e escudo), Múmia (lenta e dura), Naja Cuspideira (atira veneno), **Escorpião Gigante** (elite: investida, aura roxa), **O Sacerdote das Areias** (guardião: anel de orbes azuis, chama esqueletos) e **O Rei Escaravelho** (chefe da região: anel de sóis negros, investida, chama escaravelhos). Projéteis `proj_cuspe_naja`, `proj_orbe_lapis`, `proj_sol_negro`. Conjunto `deserto`.
- **O chão é claro** (areia), ao contrário da floresta e do pântano: os bichos são escuros (casco azul-faiança, quitina negra, linho cinza-sujo) e os projéteis fogem da cor da areia (verde, azul, sol negro de borda dourada). Rampas novas `areia` e `lapis` em `RAMPA_EXTRA` (fora da paleta global; o cavaleiro e o dragão não mudam). A rampa `gelo` já entrou também, para a próxima região.
- **Cenário `deserto`** (`cenarios.py`): areia com marcas do vento, barro rachado, capim seco e ossinhos; 11 enfeites (costelas de um bicho colossal, crânio de chifres, coluna quebrada, **obelisco com runas** de luz azul, cabeça de estátua afundada, **braseiro** com fogo, rocha comida pelo vento, jarros, tenda rasgada, roda de carroça, ossos). Clima: poeira de areia ao vento, rachaduras, corvos e ratos.
- Primeiro render conferido e corrigido: as patas do Rei Escaravelho pareciam de aranha (encurtei), a risca de ouro saía do casco (virou uma fatia do próprio casco), o escorpião estava pequeno para elite (×1,35), a naja parecia um monte de bolotas (rodilha contínua e capelo maior) e a múmia e o piso se misturavam com a areia (linho cinza; tirei `couro` da paleta do piso, que puxava a areia pro laranja).
- **Medido:** 500 bichos no deserto, 124–189 fps. O robô (`--fase=11 --build=50 --facil --imortal`) atravessou a região, matou o Rei Escaravelho e seguiu até a fase 20, com 0 erros de script. Os 19 testes passam.
- **#72 (novo, do Breno):** criação de personagem, preparo com mochila e elementos (`docs/ANALISE_DIMRAETH_ENGINE.md`). Fica depois das regiões; reservado pela máquina notebook.
- **Próximo:** Pico Congelado (`gelo.py` já escrito).

## 2026-10-06 · Claude do Alisson (notebook) · #64 marco 5: Pico Congelado (arte da região 4)
- **Monstros** (`fonte_arte/modelos3d/gelo.py`, 5 vistas): Diabrete de Gelo (enxame), Espírito da Nevasca (flutua e atira estilhaços), Guerreiro Congelado (machado de gelo), Urso Congelado (pelo pardo, placas de gelo, investida), Sentinela de Cristal (lenta e dura), **Troll do Gelo** (elite), **O Jarl Congelado** (guardião: anel de orbes de geada, investida, chama guerreiros) e **O Gigante da Tempestade** (chefe da região: o "gigante enterrado" que acorda, com coroa de nuvem e raios, martelo de gelo, anel de granizo e diabretes chamados). Projéteis `proj_estilhaco`, `proj_orbe_geada`, `proj_granizo`. Conjunto `gelo`.
- **Chão claro** (neve) como no deserto: corpos escuros, gelo claro nos detalhes. **Cenário `gelo`**: neve com placas de gelo rachado, terra congelada, pedras, capim seco e uma trilha de pegadas. 11 enfeites: pinheiro nevado, rocha, **cristais de gelo** com luz fria, guerreiro preso num bloco de gelo, **mão de pedra de um gigante** saindo da neve, muralha do forte, estandarte rasgado, pedra de runa acesa, fogueira, árvore morta e ossos.
- **Partícula nova `neve`** (`ambiente.gd`): floco de 1–2 px caindo de lado com o vento. São 62 flocos e 4 de névoa fria, dentro do teto de 70 partículas.
- Revisão dos renders: o Jarl parecia um sino (a capa em cone escondia a armadura; virou capa achatada atrás), o troll e o gigante estavam pequenos (×1,25 e ×1,3). A neve saía lilás (a rampa `aco` puxava; saiu da paleta do piso), e as pedras redondas e escuras pareciam projéteis (ficaram menos e mais chatas).
- **Medido:** 500 bichos no pico, 131–184 fps. O robô (`--fase=16 --build=70 --facil --imortal`) atravessou a região, matou o Gigante da Tempestade e entrou no Reino Sombrio, com 0 erros de script. 19 testes sem falhas.
- **Próximo:** Reino Sombrio. O chefe final de verdade (o Soberano do Caos) entra no lugar da Tela Azul, junto com um cenário de castelo corrompido.

## 2026-10-06 · Claude do Alisson (notebook) · #64 marco 6: Reino Sombrio e o chefe final (fecha a #64)
- **O Soberano do Caos** é o chefe final de verdade, no lugar da Tela Azul provisória (`fonte_arte/modelos3d/reino.py`). É um rei colossal que flutua (`"flutua": 14`) sobre um manto em fiapos de sombra, com armadura negra rachada e o caos aceso por dentro, rosto que é só escuro e dois olhos, coroa de ouro, auréola de espinhos, asas de sombra em leque, cetro com a estrela do caos e anel de `proj_estrela_caos`. Chama cavaleiros ocos. `"final": true`: matar ele limpa a tela e começa o duelo.
- Novos no Reino (conjunto `horror`, junto dos tenebrosos): **Cultista do Caos** (atira `proj_bola_caos`) e **Cavaleiro do Caos** (elite: investida, aura magenta). Os dois e o Soberano têm `luz`, porque o Reino tem fases escuras. Fase nova no repertório: **Capela Profanada**. A rampa `caos` (magenta) entrou na `RAMPA_EXTRA`.
- **Cenário `reino`** (`cenarios.py`): lajes de castelo com veios do caos acesos nas frestas, sangue seco, cinza e pedaços de armadura. São 11 enfeites, metade com luz (as Catacumbas e a Ponte das Almas dependem delas): trono quebrado com cristal, braseiro de fogo do caos, cristais do caos, tochas, altar de velas, estátua sem cabeça, túmulo de espada com elmo, armadura caída, espinhos negros, estandarte negro com losango aceso e ossos. Clima: cinza caindo, brasas do caos (vaga-lume magenta), morcegos e ratos.
- **Textos:** "A Tela Azul caiu", "Derrote a Tela Azul pra vencer!" e a tela de vitória agora leem o nome do chefe final nos dados (`arena.nome_chefe_final()`; o resultado leva `chefe_final`).
- Revisão: as asas do Soberano pareciam tábuas (viraram lâminas que afinam), o sinal do estandarte saiu como uma cruz (virou losango, neutro), e a região estava escura demais até nas fases iluminadas. O chão era quase preto e a cor da região escurecia por cima do ambiente; as lajes foram para cinza médio, a cor da região ficou mais clara e o manto do caos mais vivo.
- **Medido:** 500 bichos no Reino, 125–296 fps; na fase escura (Catacumbas), 100–188 fps. O robô na fase 25 matou o Soberano, o duelo começou e ele ficou em 1º, com `vitoria: true` e 0 erros de script. Os 19 testes passam.
- **#64 completa:** 5 regiões × 5 fases, cada uma com monstros, guardião, chefe, cenário e clima próprios, e um chefe final de verdade. O que fica para outras issues: escurecer a luz andar a andar até o chefe (#68), os santuários "Tomada" e as armas de informática (#65), equilíbrio (#63 item 7).

## 2026-10-06 · Claude do Alisson (notebook) · #72 marco 1: raça e classe (criação de personagem)
- **Dados novos:** `dados/racas.json` (5 raças "só de números", da tabela do `docs/ANALISE_DIMRAETH_ENGINE.md`: Humano, Anão Encouraçado, Elfo Sombrio, Orc Cabeçudo, Goblin Sortudo) e `dados/classes.json` (Guerreiro, Mago, Atirador, Ladino, Clérigo). Cada classe tem uma arma inicial **global** (nunca uma exclusiva de herói) e o especial (tecla E) de um amigo: Guerreiro e Ladino usam o do Hazaki, Mago e Atirador o do Lucas, Clérigo o do Nicão. O Clérigo levanta amigos caídos no dobro da velocidade.
- **Como o herói existe:** o id já diz como montá-lo: `c:<raça>:<classe>` (ex.: `c:orc:guerreiro`). `scripts/hordas/criacao.gd` monta um herói no formato do `herois.json` (bônus da raça + fraquezas + bônus da classe somados) e registra no `Dados`, que junta os criados à tabela "herois" a cada carga (`Dados.herois_extra`, que sobrevive ao `recarregar()`). O resto do jogo não sabe a diferença. No online (marco 2) só o id vai viajar e cada máquina monta o mesmo herói.
- **Telas:** na escolha de heróis entrou o botão **"+ Criar herói"** (seta pra baixo ou mouse), e o último herói criado vira a 4ª carta (salvo em `user://heroi_criado.json`). Na `tela_criacao.gd`, cima/baixo escolhe raça ou classe e esquerda/direita troca; ela mostra o que dá e o que tira, a arma, o especial e a ficha final. Depois segue pro Calor, como os heróis fixos. As raças **tingem o corpo** (campo `tom`); é provisório até a paleta do marco 2. O corpo é o do Hazaki, em camadas.
- **Teste/atalho:** `--heroi=c:goblin:mago` joga direto com um herói criado (o robô jogou 150 s sem erro), e `--print_tela=criacao --raca=N --classe=N` tira print da tela. Teste novo `testes/criacao.tscn` (dados, ids inválidos, somas, registro, partida com herói criado, herói fixo intacto). Agora são 20 testes, todos sem falhas.
- **Fica pro marco 2:** nome, pontos para distribuir, "defeito voluntário", aparência por paleta, guardar até 6 heróis, escolher herói criado na sala online (o anfitrião valida pelo id) e permitir herói criado repetido na sala.
- **Decisão (o Breno deixou com a gente):** quando o baú pessoal entrar (marco 4), morrer **não** tira nada do baú; só somem os consumíveis gastos da mochila.

## 2026-10-06 · Claude do Alisson (notebook) · #72: herói criado morre de vez (decisão do Alisson)
- **A decisão mudou** (substitui a linha "morrer não tira nada do baú" da entrada do marco 1): **se o herói criado morre, ele some de vez e é preciso criar outro do zero.** Vale no **solo e no multiplayer**. No online, a morte é a corrida acabar em derrota (o grupo todo caiu); se um amigo te levanta, você não morreu. Respostas do Alisson no chat.
- **O que conta como morte:** a corrida acabar sem vitória e sem duelo. Isso cobre morrer, **desistir** (senão dava pra fugir da morte desistindo; o menu de pausa avisa "Desistir (o herói morre de vez)") e o grupo todo cair no online. **Fechar o jogo no meio da corrida** também mata: o arquivo do herói ganha a marca `em_corrida` quando ela começa, e se o jogo abrir de novo com a marca, a escolha de heróis avisa "fulano morreu de vez". **Não** mata: perder o duelo final (a corrida já foi vencida) e cair a conexão no online.
- Morreu de vez: apaga `user://heroi_criado.json`, tira a carta e apaga os recordes daquele herói. A tela de fim avisa em vermelho, e a de criação avisa antes ("se ele morrer, morre de vez").
- **Baú e mochila (marcos 3 e 4):** ficam presos ao herói criado e somem com ele, a menos que o Breno ou o Alisson digam outra coisa.
- Partidas de teste (`--bot`, `--sair`, `--print_tela`) não gravam nem apagam o herói de verdade. `--morte_teste` testa a regra num arquivo próprio: com `--heroi=c:orc:guerreiro --fase=25 --sair=150 --morte_teste` o herói morre e o resultado traz `heroi_perdido`; derrubando o jogo no meio, o próximo início avisa a morte. `testes/criacao.tscn` ganhou as checagens da regra. São 20 testes, todos sem falhas.

## 2026-10-06 · Claude do Alisson (notebook) · #65 marco 1: troca de tema (fim da informática nas armas e itens)
- **#79 (nova, do Breno):** consolida tudo o que falta (#72, #65, #68, pendentes da #63), "sem pausar para pedir aprovação". Reservei com a ordem: #65 retema → #65 armas novas → #68 → #72 marcos 2 a 7 → legibilidade e #63.
- **Armas globais** (os ids continuam, então nada quebra; muda o que o jogador vê): Pendrive → **Adaga de Arremesso**, SSD → **Tempestade de Lâminas**, Cabo de Rede → **Corrente Farpada**, Fibra Óptica → **Corrente do Carrasco**, Ventoinha → **Lâminas Rodopiantes**, Water Cooler → **Ciclone de Aço**, Café → **Fogo Grego**, Garrafa Térmica → **Inferno Engarrafado**, Wi-Fi → **Sino Fúnebre**, Roteador 5G → **Sino do Juízo**.
- **Passivos** (dark fantasy com folclore brasileiro): Pedra de Amolar, Ampulheta Rachada, Grimório Aberto, Espelho Gêmeo, Pena de Corvo, **Feijão Tropeiro** (a marmita), Pedra-Ímã, **Figa de Arruda** (a fitinha), **Garrafada** (a água de coco), Pergaminho Antigo, Olho de Falcão. **Coletáveis:** a cura vira Coxa Assada; o drop de Wi-Fi, que puxa todo o XP, vira **Berrante**; a cura da loja vira Banquete. **Santuário "Tomada"** → **Pira Antiga** ("A pira acendeu!"). O fundo dos menus mostra os monstros das regiões no lugar dos vírus. As descrições dos heróis que citavam as armas antigas foram atualizadas.
- **Tudo nos dados, nada fixo no código:** a cor da aura, a cor e os "fios" do chicote e a rampa da poça agora vêm do `armas.json` (`cor`, `fios`, `rampa`; antes eram presos ao id ou à rampa do café). Mensagens e sprites dos coletáveis estão no `dados/coletaveis.json` (novo); nome, título e sprite dos santuários no `descobertas.json`.
- **Arte:** `fonte_arte/icones_tema.gd` (roda no Godot, sem Python) desenha 21 ícones e 7 sprites pixel a pixel, com contorno automático e troca de cor (as evoluções reaproveitam o desenho da base). Os ícones antigos (`icone_pendrive` etc.) ficaram na pasta, sem uso.
- Teste novo `testes/tema.tscn`: tudo o que os dados citam existe, as cores estão nos dados e nenhum nome visível voltou a ser de informática. Novo atalho de teste `--armas=a,b,c` (entra com essas armas). São 21 testes, todos sem falhas. Prints da tela de cartas, do título e dos efeitos das armas base e evoluídas.
- **Próximo:** #65 marco 2, armas públicas novas.

## 2026-10-06 · Claude do Alisson (notebook) · #65 marco 2: seis armas públicas novas (com evolução)
- **Armas novas, globais, cada uma com comportamento próprio** (módulos em `scripts/hordas/armas/`, no mesmo contrato do `pistolas.gd`; só usam `no_circulo`, `n_mais_perto`, `aleatorio_na_tela` e `ferir`, então também funcionam no duelo):
  - **Machado Bumerangue** (`bumerangue`): vai até o alcance, freia e volta, e acerta na ida e na volta. Evolução **Machados em Brasa**, com o Feijão Tropeiro.
  - **Raio** (`raio`): cai do céu num inimigo qualquer da tela. Evolução **Fúria dos Céus**, que pula de inimigo em inimigo, com o Pergaminho Antigo.
  - **Lança** (`lanca`): estocada longa em linha que atravessa a fila. Evolução **Lança Ardente**, com o Olho de Falcão.
  - **Corvos Famintos** (`corvos`, invocação): corvos que caçam, bicam e trocam de presa. Evolução **Revoada Negra**, com a Pena de Corvo.
  - **Runas Explosivas** (`runas`): minas que explodem quando pisam. Evolução **Círculo Rúnico**, que deixa lento, com a Figa de Arruda.
  - **Martelo Sísmico** (`sismo`): onda de choque que empurra forte. Evolução **Terremoto**, com duas ondas e lentidão, com a Garrafada.
- Cada evolução usa um dos 6 passivos que estavam sem evolução, então agora **todo passivo abre exatamente uma evolução** (11 no total). Todas têm `familia` (o duelo e a IA estimam o tipo novo por ela).
- **Classes (#72) casadas com as armas novas:** Guerreiro começa com a Lança, Mago com o Raio, Atirador com o Machado, Ladino com a Adaga e Clérigo com o Sino.
- **Equilíbrio medido** (DPS no nível máximo, 16 inimigos parados, 10 s): armas base antigas de 101 a 307, novas de 97 a 330; evoluções antigas de 99 a 1130, novas de 222 a 1209. A lança estava na lanterna e subiu de 26 para 30 de dano. A Ciclone de Aço (antiga, 99) parece fraca: fica pro equilíbrio da #63.
- **Desempenho** na fase 25 com 500 no estresse e quatro evoluções juntas: novas, de 79 a 168 fps; antigas, de 83 a 99 fps. O custo das armas por quadro é parecido (update 243 contra 265 µs). O duelo com as armas novas rodou sem erro.
- Arte: 12 ícones e 2 sprites de machado no `icones_tema.gd`. Os corvos são desenhados por código, cinza-azulados com borda clara, porque o preto sumia nos chãos escuros. Teste novo `testes/armas_novas.tscn`: cada arma machuca de verdade e as evoluções estão bem ligadas. São 22 testes, todos sem falhas.
- **Próximo:** #68 (movimento e ambientação estilo Dimraeth).

## 2026-10-06 · Claude do Alisson (notebook) · #68 marco 1: legibilidade (piscar, aviso no chão, câmera)
- **O herói não some mais no piscar de dano:** em vez de ficar 100% invisível em metade dos quadros (`spr.visible = not piscar`), pisca em 35% de opacidade. No escuro do pântano e do reino ele sumia da tela no meio da horda.
- **Marcas de aviso no chão** (`inimigos.gd`, numa passada antes dos sprites): durante os 0,7 s em que o bicho se prepara para a investida aparece uma **faixa vermelha** por onde ele vai passar, do tamanho do que ele corre. Nos 0,6 s antes dos **tiros em anel** (guardiões e chefes) aparece um **anel vermelho** no chão em volta dele (`AVISO_ANEL`). É o "telegrafar" do Dimraeth adaptado à horda. No online os clientes não recebem a direção da investida nem o relógio do anel, então lá fica só o aviso que já existia no corpo (agachar e avermelhar).
- **Câmera olha à frente:** adianta até 36 px na direção em que o herói anda, com suavidade (a partir da velocidade real, que acelera e freia). Dá para desligar em Opções > Acessibilidade > "Câmera olha à frente".
- `--print_tela=aviso` mostra as duas marcas: um jacaré na preparação da investida e um chefe a 0,2 s do anel (`--chefe=X` troca o chefe). São 22 testes, todos sem falhas.
- **Próximo:** #68 marco 2, rolamento de esquiva com fôlego (2 cargas).

## 2026-10-06 · Claude do Alisson (notebook) · #68 marco 2: rolamento de esquiva com fôlego (no lugar do dash)
- **A tecla do dash agora rola** (`jogador.rolar(dir)`): rola na direção, invencível o rolamento todo, e o corpo (com o equipamento, que é filho dele) dá uma volta inteira em torno do meio. Vai uns 30% mais longe que o dash antigo (2,7× a velocidade por 0,3 s, contra 3,4× por 0,18 s). No fim tem **0,14 s de recuperação** andando a 45%, o compromisso da esquiva.
- **Fôlego:** 2 cargas no lugar da recarga fixa. Cada rolamento gasta 1 e uma carga volta a cada 1,6 s, então dá para encadear dois e depois é preciso respirar. Aparecem como duas barrinhas embaixo da vida (somem quando estão cheias).
- Tudo no `dados/movimento.json` (novo). Transformado em dragão, a tecla continua sendo a investida dele (sem rolar, gastando fôlego igual). A onda do Lucas (especial) continua usando o dash por dentro, e os rivais do duelo têm o dash próprio, que não mudou.
- **Online:** o estado do herói ganhou o bit 8 (rolando), e os outros jogadores giram no lugar certo também (`remoto.gd`). Uma partida de 2 com robôs rodou sem erro.
- **Bug achado na medição:** o corpo girava em volta do pé, e não do meio. O `_chegando()` roda até o nome do herói sumir, alguns segundos depois do pouso, e zerava `spr.position.y` a cada quadro. Agora ele só mexe na posição durante a queda.
- Teste novo `testes/rolamento.tscn`: cargas, recusa sem fôlego, invencibilidade, giro, distância maior que o dash antigo, recuperação e recarga. `--print_tela=rolamento --espera=s` mostra o herói no meio da volta. São 23 testes, todos sem falhas.
- **Próximo:** #68 marco 3, a luz que escurece andar a andar até o chefe.

## 2026-10-06 · Claude do Alisson (notebook) · #68 marco 3 (pela metade): luz que escurece andar a andar
- **Feito:** `chao.gd` ganhou `_aplicar_luz()`, chamada a cada fase nova. A luz do ambiente vai de 1 na entrada da região até `chefe` no andar do chefe, puxando para `tom_chefe` (`regioes.json` > `luz`, geral e por região). Floresta, pântano e reino escurecem pouco (0,85–0,86), porque já são escuros; o deserto vai para o fim de tarde (0,7, alaranjado) e o pico para a tempestade (0,72, azulado). Conferido em prints: deserto (fases 11 e 15) e floresta (fases 1 e 5).
- O zoom de câmera na entrada do chefe ficou de fora de propósito: em pixel art com escala inteira, um zoom de 1,1× deixa os pixels tremendo.
- **Pendente:** a bateria de testes (23 cenas) **não chegou a rodar** neste marco, porque o Alisson precisou parar. O PR está como rascunho.
- **Para o Claude do Alisson (PC):** continue na branch `alisson/luz-andar` (PR em rascunho): rode os 23 testes (`testes/*.tscn`), mergeie e comente na #68 e na #79. Depois feche a #68 (a "postura" fica para depois) e siga a ordem reservada na #79: **#72 marco 2** (nome, pontos, defeito voluntário, aparência por paleta, até 6 heróis salvos e herói criado no online), depois os marcos 3–7 da #72 (preparo e mochila, baú, elementos, raças com gancho, legibilidade) e os pendentes da #63. Regra de morte do herói criado: ver a entrada do #78 (vale no solo e no online).

## 2026-10-06 · Claude do Alisson (PC) · #84 conferido e mergeado
- Peguei do notebook o PR #84 (luz que escurece andar a andar, #68 marco 3), que estava em rascunho. No PC os 23 testes deram falhas=0 e a partida com robô rodou sem SCRIPT ERROR. Mergeado.
- O remoto deste clone agora aponta pra `KIKIU-Survival` (o rename do #48 já valeu).

## 2026-10-06 · Claude do Alisson (PC) · Combate e luz no estilo Dimraeth (PR #85)
- **Pedido do Alisson no chat**, na frente do #72 marco 2 (reservado na #79): animações de luta, efeitos e iluminação **inspirados** num reel de gameplay do Dimraeth, com os nossos personagens. O vídeo fica **fora do repo** (`E:\Dev\KIKIU-referencias\` no PC, com um `LEIA-ME.md` de notas de estilo); nenhuma arte, quadro ou recorte dele entra aqui.
- **Golpe do corpo para todos os heróis** (`jogador.atacou(dir)`, `pose_golpe`): recua 2 px, avança 8 px na direção do golpe, estica, inclina 0,2 rad e volta em 0,2 s, virando-se pro golpe. **É procedural, não são quadros novos**: vale para as 9 folhas de 9 colunas. A Hazaki soma isso aos quadros de ataque dela. As armas passam a direção por `golpe_corpo(dir)`.
- **`efeitos.gd`, num filho aditivo:** `corte()` (meia-lua: a cabeça varre o arco e o rabo vem comendo atrás, fio branco na borda e degradê pra dentro, achatada 0,8 pro 3/4), `impacto()` (estrela de raios + clarão, no máximo 6 novas por quadro) e `faisca()` (risquinhos). Katana, chicote, chute e giro da arte marcial usam a meia-lua; lança e martelo, as faíscas. Todo acerto solta estrela, menos poça/aura/baforada (`arena.SEM_IMPACTO`, dano a cada tique).
- **Flash branco de verdade nos inimigos** (`inimigos._flash_no`, shader de silhueta, um nó pra todos, 0,035 s).
- **Números de dano com soco:** dobram e voltam (sempre múltiplo de 8, a PressStart2P treme em tamanho quebrado), nascem brancos, contorno escuro, sobem rápido e freiam. Crescem e socam de novo quando somam.
- **Golpe pesado** (`arena.golpe_pesado`): corpo a corpo que acerta treme de leve e congela 0,025 s, no máximo 1 a cada 0,3 s, só solo.
- **Luz:** `efeitos.luz()` (halos aditivos de um degradê só, teto 96) no herói (mais forte quanto mais escuro o andar), nos projéteis dele (cor da arma), nos tiros dos inimigos (vermelho), nos impactos e na cabeça da meia-lua. **Vinheta** (`vinheta.gd`, layer 2) com opção em Gráfico, ligada. Manchas de sangue duram 9 s (eram 4), teto 60 (`mortes.json`).
- **Online:** o golpe do corpo é só local (os outros não veem o avanço), igual ao ataque da Hazaki hoje. Fica pra depois, se valer a pena, um bit de estado como o do rolamento.
- **Medido:** 24 testes com falhas=0 (novo: `testes/golpes.tscn`). Fase 25 com 500 inimigos: 85–138 fps com 4 armas corpo a corpo e 97–134 com projéteis (antes 79–168); efeitos novos custam ~20 µs (update) e ~50 µs (draw). `--print_tela=golpe --arma=X --heroi=Y --lento=0.25 --seq=...` mostra o golpe em câmera lenta.
- **Próximo (ideias, sem reserva):** quadros de ataque desenhados para os outros heróis (a folha de 23 colunas da Hazaki é o molde); rastro de movimento no rolamento; depois volto à ordem da #79 (#72 marco 2).
## 2026-10-06 · Claude do Alisson (PC) · #72 marco 2: criação completa (atributos, defeito, paleta, 6 heróis, online)
- **Criação** (`tela_criacao.gd`, `criacao.gd`): nome com limite e validação, 11 pontos em 5 atributos (`dados/atributos.json`, teto por atributo, efeito real nos stats via `Construcao`), **defeito voluntário** opcional (6 em `dados/defeitos.json`: dá pontos extras e cobra um efeito), **aparência por paleta** (`dados/aparencia.json` + `paleta.gd`: recolore pele/cabelo/roupa por código, sem arte nova, com prévia ao vivo na tela; recolorir o corpo inteiro leva ~60 ms e fica em cache).
- **Meus heróis** (`tela_herois.gd`): até 6 salvos; escolher, criar em vaga livre, apagar com confirmação (Enter/Esc). O 7º é recusado. Herói que morre some de vez (regra do #78).
- **Online:** a ficha (nome, raça, classe, pontos, defeito, paleta) viaja ao entrar na sala; o anfitrião confere cada número contra os JSON (`Criacao.erro_ficha`, via `Rede.erro_heroi`) e recusa o que sai da faixa. Os outros jogadores veem nome, boneco recolorido e stats certos (`remoto.gd`).
- **Testes:** `testes/criacao2.tscn` (`CRIACAO2 falhas=0`: pontos não passam do total, defeito dá pontos, salvar/carregar 6, 7º recusado, morte apaga, paleta muda as cores, rede recusa fora da faixa). As 24 cenas em `falhas=0`; partida com robô (`--bot --heroi=hazaki --semente=7`) com 0 SCRIPT ERROR.
- **Online com 2 instâncias** (`--online=host`/`join`, `--ficha=Nome/raça/classe/defeito/f,v,a,m,s/pele,cabelo,roupa` em cada uma): no log do cliente, `jogador: peer=1 heroi=c:h408cf45c nome=Thorgar paleta={pele 1, cabelo 2, roupa 1} vida=135 dano=125% vel=85% defeito=manco boneco_recolorido=true`, e o anfitrião vê a Elfa Lia (vida 60, vel 116%) com `boneco_recolorido=true`. 0 SCRIPT ERROR nos dois.
- Prints: `--print_tela=criacao --ficha=...` e `--print_tela=herois_lista [--vaga=N --apagar]`.
- **Pendente/fraco:** só testei online headless com robô (ninguém olhou o boneco recolorido numa janela de verdade); valores dos atributos/defeitos são palpite, calibrar jogando; paleta é por índice numa lista curta de cores (sem seletor livre).
- **Próximo:** #72 marco 3 (o que sobrar da issue) ou calibrar atributos/defeitos jogando.
## 2026-10-06 · Claude do Alisson (PC) · #63: conjuntos e objetivos (parte 1)
- **Conjuntos:** etiquetas temáticas (lâmina, fogo, gelo, trovão, sangue, sombra, sagrado, arremesso, invocação, pesado, guerreiro) em armas, passivos e equipamentos (JSON). `dados/conjuntos.json` tem os degraus 2/4/6 por etiqueta com efeito real (atributos somados junto das dádivas em `arena._recalcular`, ou comportamentos lidos por `arena.conj("...")`: cura ao abater, explosão na morte, lento no golpe). Código em `scripts/hordas/conjuntos.gd`. HUD da build lista etiqueta + progresso (na pausa mostra o que cada degrau dá) e a tela de fim mostra os conjuntos.
- **Objetivos:** `dados/objetivos.json` + `scripts/hordas/objetivos.gd`. Totens, pira e fugitivo, nos andares locais 2 e 4 de cada região (adaptação dos "andares 3, 5, 7" ao modelo de regiões), pool por região. Cumprir paga ouro, XP e cura; falhar tira ouro e solta uma horda extra, nunca é game over. O anfitrião roda tudo e manda o evento `objetivo` (~4/s); cada jogador paga a própria recompensa. HUD: nome, barra, tempo, setas pros alvos; a pira é desenhada no chão.
- **Testes:** `conjuntos.tscn` (CONJ), `objetivos.tscn` (OBJ, com anfitrião e cliente em memória) e `testes/online_objetivo.sh`, que sobe 2 instâncias reais (`--online=host` e `--online=join`, `--fase=2`) e compara o estado do objetivo nos dois logs (idêntico). 26 cenas com falhas=0; partida com robô sem SCRIPT ERROR; `--estresse=500` ~5-6 ms de proc.
- **Gancho para as cartas (não mexi em `cartas.gd`):** `arena._carta()` já devolve `etiquetas` (lista) e `etiquetas_txt` (ex.: "Lâmina 2>3  Fogo 0>1") em cada carta de arma/passivo/equipamento/evolução. Falta só `cartas.gd` desenhar esse texto.
- **Pendente:** objetivos dos demais andares (só 2 e 4 por região), balanceamento dos degraus, o "sobreviver na névoa" do plano, e a tela de cartas usar o gancho. Prints em `scratchpad/fotos_q`.
## 2026-10-06 · Claude do Alisson (PC) · #63: santuários, cartas de comportamento e crossfade: feito

**Feito (worktree agent-ad7784d839d628498, sem push/PR):**
- **Santuário da Prova** (`descobertas.json` > `santuarios.prova`): ativar faz nascer um mini-chefe (`trojan`, vida x2.5) + escoltas; vencer todos em 50 s dá dádiva épica+ e um baú; estourou o tempo, perdeu. Online o anfitrião cria os vírus.
- **Santuário Selado** ("achar outro elemento antes"): só libera a dádiva com o pré-requisito da fase cumprido: `piras` (N piras acesas) ou `reliquia` (pegar a Relíquia Antiga, que nasce em outro ponto). Sorteado pela semente (`prova_por_fase`, `selado_por_fase`). **Pendente:** elementos mágicos como pré-requisito chegam com a #72; basta somar uma entrada em `selado.requisitos` e tratar o tipo em `descobertas.gd`.
- **Dádivas em dupla** (`dadivas.json` > `duplas`, com `requer`): com as 2 dádivas exigidas já no jogador, a oferta ganha uma 4ª carta "DUPLA" (chance 0.8, efeito fixo mais forte). 7 duplas.
- **Cartas de comportamento** (`dados/comportamentos.json`, 6 cartas: ricochete, vai e volta, rastro de fogo, aura pulsante, poça instável, giro em espiral): raras, a partir do nível 3 da arma, lidas como modificadores genéricos em `armas.gd` (`s.comp`); carta com rótulo COMPORTAMENTO e descrição "Muda ...".
- **Música:** crossfade de 1,5 s em `Som.musica` (potência igual, respeita volume das Opções). Faixa do duelo intocada.
- Testes novos: `testes/santuarios2.tscn` (SANT2) e `testes/cartas_comp.tscn` (CARTCOMP). Prints de teste: `--print_tela=santuario2|dupla|comp`.
- Todas as 25 cenas com falhas=0; partida bot hazaki semente 7 com 0 SCRIPT ERROR.

**Pontos fracos:** crossfade e rede online (2 instâncias) não foram conferidos de ouvido/na prática: só por teste de estado; a prova no cliente online vale por tempo perto do santuário.
**Próximo:** #72 (elementos mágicos como requisito do selado); balancear cartas de comportamento jogando.

## 2026-10-06 · Claude do Alisson (PC) · integração: #72 marco 2 + #63 (conjuntos, objetivos, santuários, cartas de comportamento, crossfade)
- Três trabalhos juntos num PR só (agentes em worktrees isoladas, por cima da `main` com o combate Dimraeth do #85). O único conflito foi no `armas.gd`: ficaram as duas funções novas das cartas de comportamento (`ao_rolar`, `_pulso`), a assinatura nova `golpe_corpo(dir)` do #85, e o rastro de fogo antes da meia-lua do chicote.
- 29 cenas de teste, todas com falhas=0; partida com robô sem SCRIPT ERROR.
- **Atenção:** o ROLAMENTO deu 1 falha numa rodada na `main` (logo depois do #85) e 0 em 7 rodadas aqui. Pode ser instável; se voltar a falhar, ver a primeira linha `FALHOU:`.
- **Próximo:** #72 marcos 3 e 4 (Preparo com mochila, comida, consumíveis e amuleto, e o baú pessoal).

## 2026-10-06 · Claude do Alisson (PC) · #72 marcos 3 e 4: Preparo, mochila e baú pessoal
- **Fluxo:** herói criado → **Preparo** → Calor → corrida. Heróis fixos (Hazaki, Nicão, Lucas) **pulam o Preparo** e não têm baú (decisão: não existe persistência nem morte pra eles, e não mexe no equilíbrio deles). Esc no Preparo volta pra escolha de heróis.
- **Dados (JSON):** `dados/itens.json` (16 itens: 5 comidas, 6 consumíveis, 5 amuletos; tipo, espaços, máximo, bônus ou efeito, glifo e cor) e `dados/mochila.json` (capacidade 5 + bônus de raça + bônus de classe, limites, baú de 24 espaços, kit inicial, achados). Capacidade em **espaços** (o doc do Dimraeth), não em peso: bomba ocupa 2, o resto 1, amuleto 0 (vai no pescoço).
- **Código:** `mochila.gd` (regras puras: capacidade, `erro()` que o anfitrião também usa, baú, `trazer`, `ajustar_ao_bau`, ícones desenhados no código, sem arte nova), `provisoes.gd` (nó da arena: comida por N andares, amuleto, consumíveis nas teclas **1, 2, 3**; no controle **L3 usa e R3 troca**; Pena de Fênix levanta uma vez), `tela_preparo.gd` (a mesma tela serve de **Preparo** e de **Baú**, com teclado, mouse e controle; mostra espaços, descrição, comparação de amuleto e a ficha com a mochila). `arena.stat()` soma os bônus; o HUD mostra os slots no canto de baixo à esquerda.
- **Baú pessoal:** fica **dentro da entrada do herói** em `heroi_criado.json` (`bau` e `mochila`), então `Criacao.apagar(id)` leva herói, mochila e baú juntos (regra do #78, sem código novo). Ao sair pra corrida, o que foi na mochila **sai do baú**; ao **vencer** (ou chegar ao duelo), o que sobrou da mochila + o amuleto + até 3 achados (baús da corrida, 40% de chance) **voltam**; o que não couber nos 24 espaços se perde (a tela de fim conta). Cair a conexão no online devolve a mochila não usada. Ver o baú: tecla **B** na lista "Meus heróis" (Delete descarta 1, com confirmação).
- **Migração:** herói salvo antes do marco 3 (formato com ou sem ficha, até o do marco 1) não tem `bau`: ganha o kit inicial na primeira leitura e o arquivo é regravado.
- **Online:** a mochila viaja junto da ficha; o anfitrião confere (`Rede.erro_mochila` → `Mochila.erro`: ids no JSON, quantidades inteiras, máximos, espaços da raça/classe, herói fixo não leva mochila) e reenvia a limpa. No lobby, **P** abre o Preparo. Na corrida, quem usa um consumível **pede** (`Rede.avisar "usar"`); o anfitrião confere contra o que aceitou e **conta os usos** (não passa do declarado), e só então manda o evento `consumivel`: quem usou aplica no corpo, os outros veem o aviso e a faísca, e o **gelo** (que mexe na IA dos vírus) é aplicado pelo anfitrião em volta de quem usou. A bomba usa `ferir`, que já vai pelo pipeline de acertos dos clientes. Logs do anfitrião: `MOCHILA aceita/recusada`, `CONSUMIVEL ok/recusado`.
- **Testes:** `testes/preparo.tscn` (`PREPARO falhas=0`: dados, capacidade, a tela não passa dos espaços, comida por andares, consumíveis que somem, amuleto, fênix, trazer pra casa e baú cheio, morte apaga baú, migração dos formatos antigos, rede recusa mochila inválida). `testes/online_preparo.sh` sobe 2 instâncias reais: as duas mochilas aceitas, usos conferidos, o cliente trapaceia (`--trapaca`) e o anfitrião recusa o excesso, e uma mochila grande demais é recusada (`ONLINE_PREPARO falhas=0`). Atalhos: `--mochila=pocao_cura:2,bomba,pao_duro,amuleto_corvo`, `--print_tela=preparo|bau|mochila_hud`. 30 cenas com falhas=0; partida com robô (hazaki e herói criado com mochila) sem SCRIPT ERROR; o robô usou bomba e gelo.
- **Pontos fracos:** (1) **não conferi com a mão numa janela** o fluxo completo (criar herói → Preparo → Calor → corrida → fim → baú), nem o mouse e o controle de verdade: só os prints das telas e a lógica nos testes; (2) o online é confiança entre amigos: o anfitrião não vê o baú do cliente (só a mochila que ele declara) e o arquivo local pode ser editado; (3) valores dos itens são palpite, calibrar jogando; (4) os achados só vêm de baú de corrida e só voltam se vencer (loja do mapa e drop de chefe ficam de fora); (5) o gelo no cliente só aparece pro dono depois da foto do anfitrião.
- **Próximo:** #72 marco 5 (elementos, poça de gelo e efeitos em camadas) ou jogar o fluxo inteiro e calibrar os itens.

## 2026-10-06 · Claude do Alisson (PC) · #72 marco 5: elementos (fogo, gelo, raio, veneno), reações, poça de gelo e estados legíveis
- **Dados (`dados/elementos.json`)**: 4 elementos com teto de acúmulos, duração, tique e dano (fogo 3/s por acúmulo, teto 5; veneno 1,3/s, teto 10; gelo teto 4 e congela no teto por 1,6 s com 3 s de imunidade; raio teto 3 e a cada 0,8 s salta 4 x acúmulos pra até 2 vizinhos a 70 px). Cada golpe soma acúmulos e **renova** a duração. **Resistência por inimigo** em `inimigos.json > resist` (0,5 = metade dos acúmulos, 1 = imune, negativo = vulnerável; 15 inimigos têm alguma: fogo-fátuo imune a fogo, esqueletos e cobras imunes a veneno, múmia e espantalho queimam mais) e `por_tipo` (chefe recebe 50%, elite 80%).
- **Reações (3, poucas e claras):** vapor (fogo + gelo, explosão de 58 px), descarga gélida (raio + gelo, 92 px) e miasma em chamas (fogo + veneno: o veneno acumulado vira dano em área). Dispara **uma vez**, **consome** os acúmulos listados em `consome` e tem espera (`cd`) por inimigo; o alvo sempre leva, mesmo se a grade ainda não o tem. Anel, luz e o nome da reação no chão.
- **Fontes:** `elemento` (e `elem_acumulos`) no `armas.json`: Fogo Grego, Inferno Engarrafado, Baforada, Machados em Brasa e Lança Ardente = fogo; Sino do Juízo = gelo; Raio e Fúria dos Céus = raio; Adaga de Arremesso e Tempestade de Lâminas = veneno; a bola do Poder Elemental põe o elemento dela (via `causa_pend`). **Atributo `el_<elemento>` = chance por golpe de qualquer arma** (vale em passivo, equipamento, bônus de raça/classe e dádiva, tudo passa por `Construcao.stats`): 4 passivos novos (Brasa Viva, Cristal de Geada, Centelha Presa, Presa Peçonhenta, 8-10% por nível). É o gancho de afinidade pro marco 6: basta `"el_fogo": 0.1` no `bonus` da raça ou classe. O rastro de fogo (carta de comportamento) agora queima de verdade.
- **Poça de gelo:** arma nova **Geada Rachada** (`geada`, poça com `elemento: gelo`, rampa azul, rachaduras e cristais no desenho). Quem pisa acumula gelo: fica lento e, ficando, congela. Reaproveita a poça existente (`armas.gd`, textura em cache por tamanho).
- **Código:** `scripts/hordas/elementos.gd` (nó filho de `inimigos`). **Sem custo por inimigo sem estado:** o estado vive num dicionário só de quem tem estado; o laço dos 500 só lê `v.el_vis` (um inteiro) pra pintar; `passo()` e o desenho saem na 1ª linha com o dicionário vazio (medido: 0,17 us por quadro com 500 inimigos; 40 queimando: ~70 us). Hook em `inimigos.ferir` (só pro anfitrião e só se o bicho sobreviveu) e `aplicar_elemento` pras poças. O dano no tempo é quieto (sem crítico, flash, som nem estrela; um número agrupado por segundo, no máximo 3 por quadro) e entra nas contas por `arena.creditar_dano("elem_fogo", ...)`. Congelado e atordoado não atiram nem fazem o anel.
- **Efeitos em camadas (`_draw` em lote, partículas sem lista:** posição = função do tempo e do id, teto 150 por quadro): tinta por estado (congelado > fogo > veneno > raio > gelo), brasas subindo, bolhas verdes, cristais piscando, faíscas; congelado ganha um bloco de gelo translúcido com brilho; **pips do acúmulo só em elite e chefe**; arcos do salto do raio; anel + nome da reação.
- **Mortes (`mortes.json`):** queimar = cinzas, eletrocutar = choque, envenenar = desintegrar (causa `veneno` nova), e **morrer congelado estilhaça** mesmo por golpe de arma.
- **Santuário selado:** requisito novo `elemento` em `descobertas.json` (peso 3, **20 inimigos marcados com fogo, gelo, raio ou veneno no andar**, cada inimigo conta uma vez; `Descobertas.progresso/dica` ganharam o parâmetro `contagem`). **Decisão:** contar **qualquer** elemento, não "gelo" específico, porque o requisito é sorteado na geração do mundo (antes do jogador ter arma): "20 de gelo" seria beco sem saída pra quem não pegou arma de gelo. Mesmo assim existe o risco de uma corrida sem nenhuma arma/passivo de elemento não conseguir abrir esse selado (é só a dádiva extra; a dica mostra o que falta). Não fiz a "pira acesa com fogo": a pira hoje se acende por presença.
- **Online:** o anfitrião roda os estados e dá o dano. A foto leva **congelado (bit 32), queimando (64), envenenado (128)** e o lento (16) que já existia; o cliente só pinta (`aplicar_vis`) e conta os marcados. O resto do visual (partículas, raio, anéis) é local do anfitrião. **Limite:** o golpe de um cliente chega ao anfitrião sem o id da arma (`ferir_remoto`), então só as armas e poças do anfitrião põem elemento; o atributo `el_*` do cliente também não vale pra rede por enquanto. `testes/online_elementos.sh` (2 instâncias reais, anfitrião João com Fogo Grego, cliente Lucas): anfitrião marcou 80, o cliente contou 68 e viu estados na foto; 0 SCRIPT ERROR.
- **Testes:** `testes/elementos.tscn` (`ELEM falhas=0`: dados válidos, acúmulo e teto, duração e renovação, dano por tique, resistência/imunidade/vulnerabilidade/chefe, congelar + imunidade + estilhaço, salto do raio, as 3 reações (condição, uma vez, consumo, espera), arma/passivo/bola que põem elemento, mortes por elemento, poça de gelo (anda menos e acaba congelando), requisito do selado, bits do online, custo sem estado). As 31 cenas com falhas=0 (o `cartas_comp` deu 1 falha numa rodada sob carga e 0 em 7 seguintes, parece instável por aleatoriedade, não é do marco). Partida com robô (hazaki, semente 7, 140 s; e com Fogo Grego + Geada + Sino do Juízo + Raio na fase 6): 0 SCRIPT ERROR.
- **Desempenho** (sem janela, `--bot --heroi=hazaki --semente=7 --fase=4 --estresse=500 --sair=25`, mesma sessão, 3 rodadas, ruído grande): antes proc_ms 9,6 (t=20) e 11,2 (t=25); depois 8,7 e 7,4. Com armas de elemento no estresse (matam rápido, só ~45 vivos): `elem_p` 22-110 us e `elem_d` ~70 us por quadro.
- **Prints** (`--print_tela=elementos --cena=estados|reacao|poca --seq=... --lento=0.4`): bichos com cada estado e elites com pips, o vapor com o anel e o nome, a Geada Rachada com tudo congelado dentro. Em `scratchpad/fotos_t` da sessão (fora do repo).
- **Pontos fracos:** números (dano por acúmulo, tetos, duração, chance dos passivos) são palpite, calibrar jogando; partículas de 2 px são discretas na resolução do jogo; não vi nada numa janela de verdade além dos prints; sombra/sangue ficaram de fora (não achei o que fazer de diferente de veneno/fogo); a Geada não tem evolução; o bloco de gelo usa o último retângulo desenhado, então em bicho que gira (`gira`) fica um pouco largo.
- **Próximo:** #72 marco 6 (raças/classes com gancho: `el_<elemento>` no `bonus` e o resto) e legibilidade (marco 7); calibrar os elementos jogando; mandar o `id` da arma na rede pro cliente também pôr elemento.
- **Ajuste final do marco 5:** quem morre na Geada Rachada agora morre de gelo (`causa_por_arma.geada`; sem isso a poça caía em "fogo" pelo tipo). O dano de elemento (`elem_fogo` etc.) aparece na tela de resultados como "Queimadura", "Gelo", "Eletricidade" e "Veneno", com ícone (`Interface.tabela_armas`); conferido numa corrida até a morte (`--heroi=c:orc:guerreiro --fase=25 --morte_teste --armas=cafe,geada,pendrive,raio`): o RESULTADO traz a linha e 0 SCRIPT ERROR. Pseudo-ids de dano: o dano das reações e dos saltos entra na linha do elemento da reação, não na arma que a causou.

## 2026-10-07 · Claude do Alisson (PC) · #72 marco 6: raças com gancho (8 raças novas, 13 no total)

- **As 8 raças** (a lista do `docs/ANALISE_DIMRAETH_ENGINE.md`, linhas 90-97): Capivara Zen, Cogumelo Andante, Gárgula, Vampiro, Gato de Sete Vidas, Pombo Mutante, Meio-Dragão (id `meio_dragao`) e Fantasma. Tudo em `dados/racas.json` (campo `ganchos`: lista de `{tipo, nome, texto, ...parâmetros}`; classes também aceitam `ganchos`). `Criacao.montar` copia os ganchos pro herói (`heroi.ganchos`), herói/save antigo cai em `[]`.
- **Código:** `scripts/hordas/ganchos.gd` (um nó por herói que tem gancho, criado na arena como o `provisoes`). UM ponto por tipo de gancho e eventos genéricos, nada de `if raca ==`: `bonus(k)` (arena.stat), `dano_recebido` (jogador.sofrer), `ao_acertar` (arena.registrar_dano), `reviver` (arena.morrer, antes da Pena de Fênix; desistir não levanta), `rolamento_mult`/`rolamento_cargas` (jogador.rolar e fôlego), `atualizar` (relógio, luz e auras). Tipos: `aura_lento`, `aura_veneno`, `fragil`, `pedra`, `roubo_vida`, `luz`, `vidas`, `rolamento`, `furia`, `etereo`.
- **Os ganchos:** Capivara = aura que deixa inimigos lentos (raio 70, `v.lento`); Cogumelo = esporos que põem veneno (acúmulo do marco 5) em quem chega perto + leva 20% a mais de dano; Gárgula = parada 1,2 s leva 40% menos; Vampiro = cura 3% do dano causado (teto 12% da vida/s) e regenera +1 no escuro / arde na luz forte (nunca mata); Gato = levanta sozinho até 3 vezes com 40% da vida e uma explosão; Pombo = rolamento 50% mais longo e +1 carga; Meio-Dragão = `el_fogo` 25% (afinidade) + fúria (+7% de dano por golpe levado, até 5, 5 s); Fantasma = andando, o toque dos bichos dói 50% menos, tiros 25% a mais.
- **Trocas em relação ao doc (decisão minha):** Pombo "voa sobre buracos" e Meio-Dragão "ligado à transformação do Hazaki" ficaram de fora (não existe água/buraco no mapa e `habilidades.gd` é por herói fixo); o Pombo rola mais longe e o Dragão tem afinidade de fogo + fúria. O Vampiro resolve o conflito horror x luz forte assim: "escuro" = `escuridao.ligada()` ou luz do ambiente <= 0,8; "luz forte" = ambiente >= 0,93 (limiares chutados: NÃO medi o valor real do ambiente por andar/cenário, então no jogo pode haver andar em que nunca arde ou nunca regenera; ajustar `limite`/`claro_min` em racas.json). O Fantasma "atravessa" só no dano (não desliga colisão: o herói não colide com inimigos).
- **Online:** o que fica no herói (dano recebido, vida, roubo, reviver, rolamento) roda no computador de cada um. As auras mexem em inimigos, que só o anfitrião simula: ele aplica a aura de TODOS (a dele e a dos clientes, pela raça do herói validado em `Rede.jogadores`), a cada `tique` por aura (um `no_circulo`, nunca varredura dos 500). O anfitrião cria o nó de ganchos mesmo sem gancho próprio se algum cliente tem aura (`Ganchos.cliente_com_aura`). O efeito viaja na foto que já existia (lento = bit 16, veneno = bit 128): zero campo novo de rede. A ficha com raça inventada continua recusada (`erro_ficha`).
- **Aparência:** 8 peles novas em `aparencia.json > pele` (índices 8 a 15, as antigas não mudaram) e `paleta_raca` (pele, cabelo e roupa iniciais por raça; `Paleta.padrao` lê, com fallback em `pele_raca`). Cada raça começa com pele diferente. Na criação, trocar a raça troca as 3 cores até o jogador mexer numa; amostras de cor encolhem pra caber 16 peles; a caixa de descrição ficou maior (8 linhas) e mostra o texto de cada gancho; `Criacao.descrever` entende `el_<elemento>` ("+25% de chance de queimar").
- **Medição do robô** (`--bot --heroi=c:<raça>:guerreiro --semente=S --sair=120`, abates em 120 s, média das sementes 3, 7, 11, 21; ruído de +-30% entre sementes): humano 347, capivara 383, cogumelo 413, gárgula 391, vampiro 386, gato 379, pombo 334, meio-dragão 398, fantasma 343. Nada passa de +20% sobre a base nem fica muito abaixo; o robô anda o tempo todo, então Gárgula e Fantasma-parado quase não disparam (o número real deles depende de quem joga). Cogumelo termina com pouca vida (frágil + corpo a corpo), Gato e Pombo também.
- **Testes:** `testes/racas.tscn` (`RACAS falhas=0`): 13 raças com dados válidos, pele diferente, todo tipo de gancho usado e válido, cada gancho dispara na condição e não fora dela (dentro/fora do raio, parado/andando, escuro/claro/médio, 4 mortes do gato, desistir não levanta, teto do roubo de vida, cliente não aplica aura), ficha com raça inventada recusada, saves do marco 1 e 2 carregam sem gancho. `criacao.tscn` ajustado (13 raças; `el_*` vale como atributo). `testes/online_racas.sh` (2 instâncias: anfitrião humano sem elemento, cliente Cogumelo): anfitrião aplicou 29 toques de esporo, marcou 79 e o cliente contou 70 marcados vindo da foto; 0 SCRIPT ERROR. As 32 cenas com falhas=0; partida do robô (hazaki, semente 7, 140 s) com 0 SCRIPT ERROR.
- **Pontos fracos:** números são palpite (medi só com o robô, que não representa jogador); sem arte própria por raça (mesmo corpo recolorido; Gato/Pombo/Dragão/Fantasma só mudam de cor, o Fantasma não é translúcido); o anel de aura só aparece no herói local (o anfitrião não desenha a aura dos clientes); a veneno do Cogumelo usa o dano do anfitrião (o elemento do marco 5 multiplica pelo dano de quem roda a simulação); Gárgula e Fantasma quase não aparecem no teste do robô; não vi nada em janela além dos prints (criação das raças e o anel do Cogumelo andando).
- **Próximo:** #72 marco 7 (legibilidade); calibrar as raças jogando; arte própria para 2 raças (Capivara e Gárgula são as candidatas); classes com ganchos (Berserker, Invocador do doc) já cabem no mesmo contrato.

## 2026-10-07 · Claude do Alisson (PC) · legibilidade (#72 marco 7): barra de elite, etiqueta de drop, marca de área
- **Peças** em `scripts/hordas/legibilidade.gd` (estático, sem estado); números em `dados/coletaveis.json > legibilidade` (alcance, duração, teto, tipos com nome/cor/forma); cores novas `perigo` e `area_aliada` em `interface.gd` (paleta segura no modo daltônico).
- **Barra de vida:** só elite e chefe (`inimigos.gd`: a lista de barras sai do laço de sprites que já existia, um `elite or chefe` por bicho; os comuns não pagam mais nada). Barra fina de 3 px logo abaixo dos pips de elemento; o nome curto aparece 2,5 s depois de um golpe (`v.t_golpe`, também no cliente online, que já recebe a fração de vida).
- **Etiqueta de drop:** baú, coxa assada, berrante, fragmento e gema grande (>= 20 de XP). Aparece nos 4 s depois de cair ou com o herói a 110 px; a gema grande só perto; teto de 8 por quadro; as que se juntam sobem uma sobre a outra. Cada tipo tem cor E forma (quadrado, cruz, triângulo, losango, círculo) pra quem não distingue cor. Respeita Texto do HUD Grande (fonte 16 em vez de 8) e o modo daltônico. Candidatos juntados no laço de atualização que já existia (as gemas pequenas só pagam um teste de tipo).
- **Marca de área:** `Legib.marca_perigo` (elipse vermelha, borda e preenchimento leve; é o anel do #82, agora compartilhado; laranja no daltônico) e `Legib.marca_aliada` (só borda fina azul, translúcida). Aliada: borda em toda poça do herói (raio real do golpe), alcance da explosão da Poça Instável nos últimos 0,8 s (pulsa) e raio da aura. A faixa da investida do #82 ficou como estava.
- **Teste:** `testes/legibilidade.tscn` (`LEGIB falhas=0`): barra só em elite/chefe, nome some, etiqueta por tipo/forma/cor, aparece e some por tempo e distância, gema pequena sem etiqueta, teto, Grande, daltônico, cores de perigo x aliada, e zero candidato/barra/etiqueta com 400 comuns + 300 gemas pequenas. 33 cenas, todas com falhas=0; partida bot hazaki semente 7: 0 SCRIPT ERROR. Atenção: sem janela o `_draw` não roda, então o teste confere as regras (listas e funções puras), não os pixels.
- **Desempenho** (`--estresse=500 --fase=4 --sair=25`, 3 rodadas, sem janela): proc_ms antes 5,1-7,4 / depois 6,0-7,7, dentro do ruído. O custo de desenho real não foi medido (headless não desenha); só visto em print.
- **Print:** `--print_tela=legibilidade` (elite com barra e nome, chefe com anel de aviso, drops com etiqueta, poças e aura com borda azul).
- **Pontos fracos:** não medi o custo de desenho em janela com 500 bichos; a borda aliada é discreta de propósito (no escuro do pântano pode ficar quase invisível: ajustar o alpha em `legibilidade.gd`); a Poça Instável pulsando e o anel do chefe só vi em print parado; no online o cliente não vê as poças do anfitrião nem o anel (já era assim); a etiqueta ainda não leva a raridade do que o baú vai dar (sempre "Baú").
- **Próximo:** fechar a #72 (resta calibrar raças e elementos jogando); marcar as áreas dos especiais do herói (`especiais/*.gd`) se faltar legibilidade lá.

## 2026-10-07 · Claude do Alisson (PC) · online: golpe do cliente leva a arma (fecha o ponto fraco do #89)
- **O que mudou:** o acerto que o cliente manda ao anfitrião passou de 4 para 5 floats: `[id do vírus, dano, kx, ky, índice da arma]`. O índice é a posição (1..N, 0 = sem arma) do id na lista de `dados/armas.json` em ordem alfabética (`online.gd: armas_ids`/`arma_idx`), igual em todo computador. Não é string. Custo: +4 bytes por golpe (16 -> 20).
- **Validação no anfitrião** (`online.arma_do_cliente`): índice precisa existir (NaN/negativo/fora da tabela = recusa) e arma `character_exclusive`/`transformacao` só vale se o `characterId` for o herói que aquele peer escolheu na sala. As armas que sobem por carta não estão na mochila (que só tem consumíveis/amuleto), então "build declarada" = o herói. Recusado = cai no golpe de antes (dano entra, sem elemento, causa padrão).
- **Efeito:** `inimigos.ferir_remoto(v, valor, emp, arma)` grava `arma_ult` (causa de morte por arma/elemento do cliente) e, se o bicho sobreviveu, chama `elementos.golpe_remoto` (só o elemento da arma; a `chance` de elemento do anfitrião NÃO vaza pro golpe do cliente). O dano por arma do resultado do cliente já era creditado no próprio cliente (`registrar_dano` roda antes do envio); o resultado do anfitrião continua não contando o dano dos clientes (de propósito).
- **Testes:** `testes/golpe_remoto.tscn` (`GOLPE_REMOTO falhas=0`): tabela fixa e ida e volta, 5 floats no cliente, validação (fora da tabela, NaN, exclusiva de outro herói, transformação), fogo/gelo aplicados e causa `gelo`/`tiro`, índice 0/inválido igual a hoje, sem vazamento da chance. `testes/online_golpe.sh` (2 instâncias reais; anfitrião Lucas/Pendrive sem elemento, cliente João/Café de fogo): anfitrião recebeu 195 golpes, 185 com arma válida, 55 puseram elemento pela arma do cliente; 0 SCRIPT ERROR. 34 cenas com falhas=0; partida do robô (hazaki, semente 7) com 0 SCRIPT ERROR.
- **Banda:** medida com o medidor do #58, janela de 5 s no fim de 40 s: cliente envia 0,6 -> 0,7 KB/s (ruído entre rodadas é do mesmo tamanho; o certo é +4 B por golpe, uns 20 B/s a ~5 golpes/s).
- **Pontos fracos:** um cliente trapaceiro pode declarar qualquer arma global (e elemento) sem tê-la: o anfitrião não sabe quais cartas ele pegou; o Poder Elemental (bola de elemento forçado, `causa_pend`) chega como arma `poder_elemental` sem o elemento da bola, então só vale o elemento base dela; golpes que não são arma (investida, bomba, especial) seguem sem id.
- **Próximo:** se quiser fechar a trapaça, o cliente poderia mandar as cartas escolhidas ao anfitrião (evento pequeno) e a validação passar a conferir isso.

## 2026-10-07 · Claude do Alisson (notebook) · organização do GitHub (projetos separados por etiqueta)
- **Pedido do Alisson:** o repo mistura K.I.K.I.U, Cairu e o port do Vita. Conferido que isso **não afeta o jogo**: cada pasta é um projeto Godot independente, o hordas não referencia nada da Cairu (só um comentário em `rede.gd` sobre a origem do código da sala), não há GitHub Actions e a Cairu teve 4 commits de faxina desde 1º/9.
- **Feito:** etiquetas `kikiu`, `cairu` e `vita` criadas; #79, #63 e #6 marcadas `kikiu`, #2 renomeada para "Cairu: ..." e marcada `cairu`, PR #87 marcado `vita`. README: tabela "Os jogos" com pasta, situação e etiqueta; `hordas-vita/` na árvore; regras novas em "Como colaborar" (etiqueta em toda issue/PR, apagar a branch ao mesclar com `--delete-branch`).
- **Pendente:** 43 branches remotas de PRs já mesclados (ponta igual à do PR, nada se perde) continuam lá; o apagamento em lote foi barrado pelo modo automático e ficou para o Alisson decidir. Configurações que pedem admin ficaram para o Breno no PR desta entrada.
- **Para o Claude do Alisson (PC):** a partir de agora, mescle com `gh pr merge --squash --delete-branch` e ponha a etiqueta do projeto (`vita` nas coisas do port). O log do Vita pode ficar em `jogos/hordas-vita/STATUS.md` para o PR #87 não disputar o `LOGBOOK.md` com a `main`.

## 2026-10-07 · Claude do Alisson (notebook) · README vira vitrine; o técnico vai para cada pasta
- **Pedido do Alisson:** o README da raiz deve ser uma apresentação geral do jogo, sem falar de Claude nem de processo interno (decisões, migração de tema etc.). O técnico fica nos READMEs espalhados pelo projeto.
- **Feito:** `README.md` reescrito como vitrine do K.I.K.I.U (o jogo, as 5 regiões, heróis e criação com morte permanente, o que tem dentro, situação, projetos irmãos, equipe). Fotos novas tiradas do próprio jogo (`--print_tela`, ampliadas 2x sem filtro): `kikiu_titulo`, `kikiu_deserto`, `kikiu_gelo`, `kikiu_pantano`, `kikiu_criacao`; as do tema antigo (`kikiu_horda`, `kikiu_herois`, `kikiu_duelo`) saíram. Novos: `jogos/hordas/README.md` (rodar, testes, .exe, estrutura, arte 3D), `jogos/cairu/README.md` (o que estava no README sobre a Cairu), `docs/README.md` (índice), `CONTRIBUTING.md` (onde fica cada coisa, etiquetas e as regras que estavam em "Como colaborar"). O `CLAUDE.md` agora aponta para o `CONTRIBUTING.md`.
- **Pendente:** `jogos/hordas/LEIA-ME.txt` ainda descreve o tema antigo (Cairu x vírus, Tela Azul, tomada) e precisa ser reescrito para o jogo atual. Falta uma foto boa do duelo final para o README (o modo `--print_tela=duelo` pega só a contagem inicial).
- **Regra nova:** o README da raiz é só vitrine; qualquer mudança técnica vai no README da pasta.

## 2026-10-07 · Claude do Alisson (notebook) · Esc pausa (só singleplayer)
- **Pedido:** "botão de pause: ESC para abrir o menu e pausar. No singleplayer, claro." Medido antes de mexer: o menu de pausa (Continuar / Opções / Desistir) **já existia** e Esc/Start já pausavam sozinho (árvore pausada, herói parado) e no online abriam o menu sem pausar. O defeito real: o Esc era lido por polling na `arena.gd`, então o Esc que **fecha a loja** (ou o chat, no online) abria a pausa junto no mesmo quadro.
- **Feito:** a leitura do Esc saiu da `arena.gd` e foi para `hud._unhandled_input` (só pega Esc que ninguém consumiu); sem camada nova. Teste novo `testes/pausa.tscn` (imprime `PAUSA falhas=0`): solo abre/pausa/retoma por Esc e por Continuar, Esc fecha a loja sem pausar, online abre sem pausar. Sem a correção, o teste falha 2 verificações da loja.
- **Pendente:** conferir à mão com teclado real e controle (Start) numa janela; o `--print_tela=pausa` só chama `pausar()` direto.
## 2026-10-07 · Claude do Alisson (notebook) · janela maximizada sem barras pretas
- **Relato do Breno:** maximizar a janela deixava barras pretas em volta; no F11 "às vezes" o zoom ficava certo.
- **Causa:** `window/stretch/scale_mode="integer"` com viewport 640x360. Maximizada num monitor 1920x1080 a área útil é ~1920x1009 (barra de título e de tarefas), então a escala inteira cai de 3x para 2x (1280x720 no meio, barras enormes). A tela cheia exclusiva tem 1080 exato = 3x e enche. Além disso o `Config.aplicar` forçava `WINDOW_MODE_WINDOWED` sempre que a opção "Tela cheia" estava desligada, desfazendo a janela maximizada.
- **Feito:** `scale_mode="fractional"` (continua renderizando em 640x360 com filtro nearest e proporção 16:9 mantida, só que a escala deixa de ser inteira). `Config.aplicar` só mexe no modo ao entrar/sair da tela cheia. `testes/ui.gd` converte o mouse injetado para o espaço da janela (no headless a janela é 64x64 e só dava certo com escala inteira de 1x).
- **Medido (escala; barras):** 1920x1009 -> 2,80x, só 64px de cada lado; 1918x1078 -> 2,93x; 1366x705 -> 1,96x; maximizada real (1920x991 nesta máquina) -> 2,75x. A altura sempre enche, sobra só a faixa lateral do 16:9.
- **Pendente (olho humano):** conferir se o pixel art continua nítido em escala não inteira (pode aparecer leve irregularidade nos pixels, é o custo da escala fracionária). Se incomodar, dá para voltar ao inteiro com uma opção "Escala inteira".
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (notebook) · mapa em ramificação com arte por região (#96)
- **Pedido do Breno (#96):** hoje não dava para escolher boa parte do mapa (os caminhos partiam de linhas sorteadas e nunca se cruzavam, então a corrida começava presa numa trilha). Ele quer começar num nó só e montar o caminho escolhendo ramo a ramo, sem trilha morta, e um mapa temático por região.
- **Feito:** `mapa.gd`: com `inicio_unico` (dados), todos os caminhos partem do nó do meio; `ramos_min` re-sorteia mapas com pouca escolha (nó inicial com 2+ saídas e 2+ nós em cada andar do meio); `ligacoes_extra` liga nós do meio com uma saída só a um vizinho, sem cruzar. 5 faixas por região. `erros()` confere o início único de cada região. Medido em 200 sementes: 0 mapas inválidos; nós por andar da região 1 / 2,6 / 3,1 / 3,2 / 1; 59% dos nós dos andares 2-3 dão escolha (antes 23%, sem as ligações extras).
- **Arte:** `tela_mapa.gd` desenha o chão e os enfeites do cenário da própria região (os mesmos assets da fase), espalhados com semente longe dos nós e das trilhas, com moldura, vinheta e trilhas pontilhadas na cor da região; o caminho feito fica em dourado. Cores em `dados/mapa.json > arte`. Conferido por print nas 5 regiões.
- **Testes:** `mapa` com regras novas (início único, 2+ caminhos, todo nó alcançável a partir do início = sem trilha morta); `regioes` espera entrada única; `cartas_comp`: o dublê `atacou()` agora aceita a direção (os 14 SCRIPT ERROR já estavam na main). 34 cenas com falhas=0, robô 60 s sem SCRIPT ERROR.
- **Pendente:** olhar em janela real com a mão no teclado; no online o voto continua igual (maioria, empate = anfitrião).

## 2026-10-07 · Claude do Alisson (notebook) · animação dos heróis mais fluida (#97, parte heróis)
- **Relato do Breno (#97):** a animação estava "muito dura"; quer mais fluida, na qualidade do Dimraeth e no nosso estilo. Esta entrada é só a parte dos **heróis** (os monstros estão em outra frente: `inimigos.gd`, `monstros.py`, `animacao_monstros.json`).
- **Medido antes:** as folhas de 9 colunas (todos os amigos) tinham parado = 1 quadro fixo, andar a 12 quadros/s do relógio (patinava com o herói lento/rápido), golpe do corpo de 0,2 s com antecipação de 40 ms, morte sem animação (o herói ficava de pé até a tela de resultado), squash que estalava no primeiro quadro.
- **Feito (tudo procedural, sem arte nova, em `dados/animacao.json` com `_ajuda` de cada chave; código em `scripts/hordas/animacao_heroi.gd`):** respiração parado (0,65 Hz, defasagem própria por herói, em passos de 1 px: cabeça sobe 0-2 px); andar com o ciclo avançando pela **distância andada** (66,7 px por ciclo = os 12 quadros/s de antes a 100 px/s), balanço do corpo 2x por ciclo (0-1,5 px) e inclinação pra frente proporcional à velocidade (cisalhamento com o pé fixo, até 0,045 rad = ~2,6 px na cabeça; fica nítido, não rotaciona o pixel art), tudo suavizado por exponencial (sem estalo ao começar, parar ou virar); squash de começar/parar/pouso agora entra suave (impulso + seguidor); golpe do corpo com antecipação (62 ms), batida acelerada, passa 30% do alvo (pico 10,4 px) e assenta amortecido com leve achatamento (0,26 s); recuo ao apanhar (3 px pra longe do golpe + achata + inclina); queda de morte pras folhas de 9 colunas (tropeça pra trás, cai acelerando, quica, fica cinza deitado; vale também pro caído do online; a pose final é a mesma de antes). `direcao.gd`: histerese nas folhas de 4 linhas (a diagonal não pisca entre de lado e de frente quando o analógico oscila). `jogador.gd` perdeu os `GOLPE_*` (vão pro json) e o `pose_golpe` (agora em `animacao_heroi.gd`).
- **Online:** `remoto.gd` usa os mesmos efeitos **sem mudar o formato da rede**: velocidade vem da posição suavizada (o passo casa com o chão), recuo vem da queda do `hp`, queda vem do bit de caído, lado vem do bit 4. Rolamento remoto agora começa a volta do zero.
- **Conferir à mão:** novo `--print_tela=animacao --heroi=X --cena=parado|andar|golpe|dano|morte --seq=... [--lento=N --zoom=N]` (tira de recortes ampliados em `--fotos=`). Conferidos nicao (9 col) e hazaki (23 col) em todas as cenas; ver o PR.
- **Testes:** novo `testes/animacao_heroi.tscn` (tabela x padrões do código, respiração, passo, golpe, recuo, queda, remoto, direção de 4 linhas); `golpes` e `movimento` ajustados (sobreposição de respiração/overshoot). 36 cenas com falhas=0 e 0 SCRIPT ERROR; 5 scripts `online_*.sh` ok; robô hazaki/beto 40 s sem SCRIPT ERROR; custo `jog_a` 350 -> ~415 µs/quadro (60 fps igual, `--estresse=500`).
- **Pendente (olho humano):** sentir o ritmo em janela real (respiração, inclinação e golpe são números fáceis de mexer em `animacao.json`); ver se a fase do balanço (`andar.fase`) casa com o pé no chão nas folhas de cada herói (usei apoio no quadro 1 e 5). Hazaki/criados respiram pela metade (já têm quadros de parado).
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (notebook) · animação dos monstros mais fluida (#97, parte "inimigos")
- **Pedido do Breno (#97):** a animação está "muito dura"; quer mais fluido, na qualidade do Dimraeth adaptada ao nosso estilo. Esta parte é a dos monstros (os heróis foram no PR #102). Medido antes: cada monstro tinha só 2 quadros de andar trocando a 4 fps, o que lê como piscar, não como passo.
- **Feito (gerador):** `monstros.py` agora amostra o ciclo de andar em N quadros (`pose(fase)` já era contínua): 6 quadros + 1 de branco de dano por vista (antes 2 + 1), N em `dados/animacao_monstros.json` (`quadros_andar`, troca por folha em `quadros`). As 41 folhas de 5 vistas foram regeradas (6 regiões em paralelo, ~8 min no total; um bicho sozinho leva ~25 s). O total de colunas de cada folha vai para `dados/quadros_monstros.json` (gerado; folha que não está lá = antiga, 3 colunas). Os sapos (`pantano.py`) pulavam em 2 poses binárias (`fase > 1.0`): viraram um pulo suave pelo ciclo. `pixel3d.py` usava um PNG temporário fixo, o que quebrava duas regiões rodando juntas: agora leva o PID.
- **Feito (jogo):** `inimigos.gd` + `animacao_monstros.gd` (contas puras, testadas): o ciclo avança pela **distância andada** (o pé não escorrega; parado assenta nos pés juntos; teleporte e fora da tela não contam), quique do corpo e aperto a cada pisada, inclinação para o lado em que anda (por faixas, mantém o pixel nítido), aperto ao levar golpe que volta com um quique, preparo de investida com curva lenta-e-depois-rápida e recuo. Tudo em `dados/animacao_monstros.json`. Folhas de 3 colunas (vírus) seguem pelo ritmo, sem mudança. A sombra assada continua com 2 poses (o atlas de 1024 px não comporta uma por quadro). A virada de lado já passava pelas vistas 3/4 (o espelho só troca na frente/costas, que são simétricas), então não precisou de animação de virar.
- **Custo (bancada com 500 monstros todos na tela e andando, janela sem vsync):** antes 124,7 fps (desenho 4,1 ms/quadro), depois ~118 fps (4,6 ms): cerca de -5% no pior caso, +0,5 ms. Com a LOD (`lod_dist`/`lod_max`) e o passo atualizado um quadro sim, outro não. Sem o movimento secundário (lod_dist 0) fica igual ao de antes. O `--estresse=500` do robô varia de 83 a 257 fps entre rodadas (os bichos morrem em ritmos diferentes), então não serve pra comparar 5%.
- **Testes:** `testes/animacao_monstros` novo (contas, as 41 folhas: colunas, quadros diferentes entre vizinhos, branco = quadro 0; no jogo: fase pela distância, teleporte, assentar, golpe, investida); `horror` e `vistas` ajustados às colunas novas. 37 cenas com falhas=0, robô 40 s sem SCRIPT ERROR.
- **Pendente (olho humano):** conferir em jogo se a inclinação por faixas (1-2 px) agrada e se os passos de monstros de patas (aranha, escorpião) leem bem em movimento real; ajustar `ciclo_alt`, `inclina`, `bob` no json se preciso. O `balanco` do inimigos.json não vale mais para os monstros de 5 vistas (o quique vem do `bob`).
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (notebook) · #97 fechada (animações), conferência na main
- Heróis (#102) e monstros (#103) entraram na `main`, feitos por dois agentes em paralelo neste notebook. Conferi por conta própria as tiras do golpe e da morte do Nicão e a folha nova do cão de ossos (6 quadros de andar por vista).
- **Para o Claude do Alisson (PC):** depois do `git pull`, rode `godot --headless --path jogos/hordas/projeto --import` ANTES dos testes. Sem reimportar as 41 folhas novas de monstros, `animacao_monstros`, `horror` e `vistas` falham (217/6/13 falhas) só por causa do cache velho em `.godot/`. Com o import, as 37 cenas passam com falhas=0.
- Falta conferir no olho, em janela real: o ritmo da respiração, do passo e do golpe dos heróis (`dados/animacao.json`) e o passo dos bichos de patas (`dados/animacao_monstros.json`). Com 500 monstros andando na tela, o custo de desenho subiu ~5%; se pesar no PC do Breno, baixe `lod_dist`/`lod_max`.

## 2026-10-07 · Claude do Alisson (notebook) · abertura cinematográfica de fase (entrada épica no mundo)
- **Pedido:** uma animação de entrada no mundo ao iniciar um nível, 3 a 5 s, épica e de ação.
- **Feito:** `abertura.gd` (camada 7) + `dados/entrada.json` (com `_ajuda`). Duas versões: **região** (começo da corrida e região nova, 3,8 s) e **andar** comum (2,0 s, pra não cansar 5x por região). Região: 0,0 preto clareando e tarjas descendo; 0,45 "REGIÃO N DE 5"; câmera desce de cima até 1,7; 1,2 herói cai numa coluna de luz (0,85 s, de 280 px); 1,75 pouso: tremida, flash, 2 ondas de choque, riscos, brasas e poeira; 1,78+ nome da região batendo letra por letra na cor do tema da região, descrição digitada; 3,0 libera (tarjas já saíram, HUD volta, diretor/relógio começam, +0,8 s de invulnerabilidade); 3,8 fim. Andar: faixa com "FASE n DE 5" e o nome, libera em 1,25 s; chefe da região e elite saem em vermelho. Durante a abertura: herói invulnerável e parado; diretor, inimigos e relógio parados. Pular: Enter/Esc (o Esc não abre a pausa). Online: cada cliente toca a sua com a mesma duração; pular só solta o herói, o mundo espera o relógio natural.
- **Liga/desliga:** só em partida de verdade na cena principal; fora no robô, `--sair`, `--rapido`, `--print_tela` e nos testes que montam o main. `--entrada` força. `arena.com_abertura` (a arena nua dos testes fica sem). `jogador.entrar(nome, dur, alt)` e `Visual.chegada*` ganharam altura/duração opcionais (o padrão não mudou).
- **Captura:** `--print_tela=entrada --fase=N --seq=...` (instantes no relógio da abertura; a 1ª troca de região trava uns quadros carregando arte).
- **Testes:** novo `testes/abertura.tscn` (duração, pular por Enter e Esc, relógio parado, sem inimigos, herói invulnerável e parado, online). 38 cenas com falhas=0, 0 SCRIPT ERROR; 5 `online_*.sh` ok; robô hazaki 40 s, com e sem `--entrada`, sem SCRIPT ERROR.
- **Pendente (olho humano):** sentir o ritmo em janela real e o som (reuso de tremor, soco, whoosh; nada novo); ajustar tempos em `entrada.json`. Não medi em i5-3470 (só retângulos, arcos e ~38 brasas, sem shader).
## 2026-10-07 · Claude do Alisson (notebook) · transição lenta, Esc voltando duas telas e carimbo de versão
- **Relato do tester (i5-3470):** "transição de tela tá muito lenta" e "Esc tá bugando a transição do menu".
- **Transição lenta:** `transicao.gd` somava no máximo 1/30 s por quadro desenhado, então a 15 fps a cortina de 0,42 s levava 0,91 s e a 8 fps, 1,6 s; um quadro longo na troca de tela (tela pesada carregando) ainda comia parte da animação. Medido em `testes/transicao`. Agora a duração é em tempo real (`Time.get_ticks_usec`), contada a partir do primeiro quadro desenhado depois da troca: a 8 fps leva 0,62 s (0,42 + um quadro), com quadro de 500 ms na troca, 0,44 s. O desenho virou um único comando (lista de triângulos) em vez de ~600 `draw_colored_polygon`, e pula as diagonais já varridas; a conta em GDScript fica em ~0,5 ms/quadro nesta máquina (não medi o ganho no renderer do PC fraco).
- **Esc:** reproduzido em `testes/esc_transicao` (Esc como tecla física e como ação, em 0 a 0,7 s depois da troca): em "Meus heróis" (`tela_herois.gd` lê o Esc em `_input` e emite `fechou`), o `main.gd` voltava pra tela de heróis e, no mesmo quadro, o `_process` lia o MESMO Esc por polling e voltava de novo pro título: um Esc = duas telas. Correção: o Esc dos heróis saiu do polling do `_process` e foi pro `_unhandled_input` do `main.gd`, que só recebe o Esc que ninguém consumiu (mesmo padrão da pausa, PR #100). As demais telas (calor, preparo, opções, criação, créditos) seguiram com 1 Esc = 1 tela nos testes, e a cortina sempre termina (inclusive com 6 Esc em rajada).
- **Carimbo de versão:** o título mostra no canto de baixo (cinza apagado) `v0.1.0 · 2026-10-07 · a3d5e4b`. Número = `application/config/version` do `project.godot` (novo, 0.1.0, sobe à mão); data e commit vêm de `projeto/dados/versao.json`, escrito por `jogos/hordas/gerar_versao.sh` (rode antes de exportar; arquivo no `.gitignore`; `+` depois do commit = mudança sem commit). Sem o arquivo: `v0.1.0 · dev`. Não fiz EditorExportPlugin: não há modelos de exportação 4.4.1 instalados aqui para provar que funciona, e plugin que falha derruba o export.
- **Testes:** 39 cenas com falhas=0 e 0 SCRIPT ERROR (novas: `transicao`, `esc_transicao`); robô hazaki semente 7 40 s sem SCRIPT ERROR.
- **Pendente (olho humano, i5-3470):** ver a cortina em janela real a 15 fps (deve durar ~0,5 s) e apertar Esc em Meus heróis (volta pra tela de heróis, não pro título); rodar `./gerar_versao.sh` antes de exportar e conferir o carimbo no .exe.
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (notebook) · fps no PC antigo (i5-3470): Qualidade gráfica, núcleos e primeiros quadros
- **Relato do tester:** "baixando muito fps no i5-3470". Medido nesta máquina (não no i5-3470): `docs/PERF_2026-10-07.md` tem tudo (tabelas, método, histórico por commit).
- **Não existia perfil gráfico.** Novo: Opções > Gráfico > **Qualidade** (alta/média/baixa), tabela em `dados/qualidade.json` (lida com `Config.q(chave)`): partículas do ambiente, névoa, bichos do chão, faíscas, impactos, pedacinhos, halos de luz, tetos das mortes e dos elementos, sombra projetada dos bichos, LOD do movimento secundário, vinheta, halo e luzes do shader do horror. Alta = igual a antes. Padrão automático só na 1ª abertura (até 4 CPUs lógicas + vídeo Intel integrado = Baixa; um dos dois = Média). `--qualidade=baixa` vale em teste.
- **Núcleos:** o jogo é de uma thread só (2 núcleos = 4 núcleos em fps). Separação dos bichos em `WorkerThreadPool` foi testada e **não** aplicada (4 núcleos +6 a +9%, todos os 12 núcleos -37%, o `_draw`, que é o grosso, não pode sair da thread principal). Números e motivo no doc.
- **Primeiros quadros da partida (causa achada e corrigida):** `visual.gd` assava a sombra de cada (vista x quadro x espelho) de cada bicho na 1ª vez e reenviava o atlas inteiro (4 MB) à GPU a cada sombra. Agora: orçamento de 2,5 ms por quadro (o excedente usa a sombra calculada na hora), envio do atlas uma vez por quadro e alfa lido de bytes. Partida com 300 bichos: pior quadro ~450-670 ms -> ~130-190 ms.
- **Outras:** `efeitos.atualizar` sem `duplicate`/`erase` linear; bichos do chão (ratos, morcegos, corvos) num nó próprio (antes um morcego parado redesenhava todos os polígonos do chão a cada 4 quadros).
- **Shader:** o Godot 4.4.1 no gl_compatibility tem cache em disco (`user://shader_cache/`, por máquina, não dá para entregar pronto). Um "aquecedor" de materiais foi medido e não mostrou ganho: removido (detalhes no doc).
- **Bancadas novas:** `testes/bench_horda.tscn` (determinística, 500 bichos, `logica=1.00` valida a rodada) e `testes/bench_inicio.tscn` (quadro a quadro do título, troca de tela e partida).
- **Testes:** todas as cenas de `testes/` com falhas=0 e 0 SCRIPT ERROR (`rolamento` e `transicao` falharam uma vez sob carga pesada da máquina e passam ao repetir: dependem de tempo); robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40` sem SCRIPT ERROR em alta e baixa; prints alta/baixa conferidos.
- **Pendente (olho humano, no i5-3470):** ver o carimbo de versão do .exe do tester (se for anterior a `ce7b505`, 10-06 02:01, ele nem tem o conserto dos 500 bichos); fps em Alta/Média/Baixa com "Mostrar FPS"; se o engasgo dos primeiros quadros sumiu; se a GPU for a HD 2500, ver o horror (escuridão) e o 1º golpe.
- Assinado: Claude do Alisson (notebook)
## 2026-10-07 · Claude do Alisson (notebook) · armas crescem com o nível (ideia do Breno)
- **Ideia do Breno:** nos níveis iniciais a arma tem que ser sempre mais fraca e pequena, num raio bem perto do jogador; a cada nível o poder e a animação vão crescendo (literalmente maior e com mais efeitos), pro jogo ficar envolvente. Vale pra todo personagem e toda arma.
- **Curva (dados, `dados/crescimento_armas.json`, com `_ajuda`):** progresso p = (nível-1)/(nível_máx-1); multiplicador de **área** (raio/alcance/largura/tamanho: tudo que o `armas.gd` já multiplicava por `s.area`) 0,70 → 1,00 (meio) → 1,25 (máximo) e de **dano** 0,88 → 1,02 → 1,12, por cima dos bônus de cada nível. Numa arma de 6 níveis: área 0,70 / 0,82 / 0,94 / 1,05 / 1,15 / 1,25 (cada nível ≈ +12-17% de tamanho) e dano 0,88 / 0,94 / 0,99 / 1,04 / 1,08 / 1,12. Arma evoluída (`evolucao: true`, fica no nível 1) usa o bloco `evoluida` (área 1,12, dano 1,12) por cima da `area` própria dela. **Override por arma:** bloco `crescimento` no `armas.json` (`area`, `dano`, `evoluida` ou `desligado`); usei só na `cabo_rede` (Hazaki e Beto começam com ela e o chicote perde área em dois eixos: 0,86 → 1,25). As contas moram em `scripts/hordas/crescimento.gd`, usadas pelo jogo (`armas.gd`) e pelo dano de catálogo do duelo (`construcao.gd`), então os dois concordam e o duelo normalizado continua igual.
- **Dados retocados:** as 6 armas que já somavam `area` nos níveis (cabo_rede, ventoinha, cafe, geada, wifi, martelo) perderam esses bônus (a curva faz isso agora, senão crescia em dobro) e ganharam dano/giro/empurrão/tique no lugar. Fibra ótica, Water Cooler, Garrafa, Roteador etc.: o `area` próprio ficou, o ×1,12 vem da curva (evolução ≥ tamanho e DPS do nível máximo da base: coberto em teste).
- **Efeitos por faixa (tier 0-4, `efeitos` no json):** 0 = nível 1-2 limpo; 1 = a partir do nível 3 (faíscas, traço 15% mais grosso); 2 = nível 5 (brilho aditivo, 1 imagem fantasma, 2 brasas, tremor normal); 3 = nível máximo (traço 50% mais grosso, 2º arco/anel, 2 fantasmas, 4 brasas, tremor 1,3x); 4 = evoluída (9 faíscas, halo forte, 3 fantasmas, 6 brasas, tremor 1,6x). Tudo genérico: o `armas.gd` põe `tier` e `area` em cada ataque (`s.tier`, `e.tier`, `e.area`) e os módulos chamam `Cresc.fagulhas/halo/brasas/fantasmas/anel/acerto/cor/grossura`. Módulos tocados: katana, marcial (punho cresce de 2 a 5 px de meia largura e solta onda de energia fina), pistolas (bala, rastro e explosão agora usam a área), elemental, aura_energia (chamas crescem), bumerangue, raio, lança, corvos, runas, sismo, e no `armas.gd` o chicote, a órbita, a poça, a aura e os projéteis. Custo: faíscas via `efeitos.gd` (já limitado a 260), luz aditiva já existente (`luz()`, teto 96), brasas = 2x2 px desenhados por tempo (sem estado), fantasmas = 1-3 `draw_texture_rect` a mais; o fator `Cresc.fator()` (hoje 1.0) é o ponto pra ligar no perfil gráfico do jogo.
- **Cartas:** a linha "Tamanho 70% > 82%" aparece na comparação de cada nível da arma.
- **Compensação do começo (medida):** só enfraquecer o nível 1 derrubou os abates em ~40% (robô, mesma semente) porque o jogo é bola de neve. Compensei com `xp_inicial` (`ate 10, fator 0.5`: os 10 primeiros níveis do jogador custam metade do XP; vale em `arena.xp_para`) e a curva mais suave do chicote. Robô `--bot --rapido=4 --sair=600`, heróis hazaki/nicao/lucas/beto x sementes 1-5 (20 partidas por lado, mesma máquina e mesma carga, ~105 fps; comparado pelo **tempo de partida**, não pelo `t` do robô, porque o fps muda quanto jogo cabe em 600 s):

| (média de 20 partidas) | antes | depois |
|---|---|---|
| 30 s: nível / abates / vivos | 3,5 / 38 / 22 | 4,4 / 36 / 28 |
| 60 s: nível / abates | 5,9 / 126 | 7,7 / 127 |
| 180 s: nível / abates | 15,1 / 689 | 15,9 / 669 |
| 360 s: nível / abates | 33,1 / 2794 | 31,8 / 2775 |
| mortes em 600 s | 2 de 20 | 0 de 20 |

  Por herói (abates em 180 s, antes → depois): hazaki 710 → 574, nicao 706 → 708, lucas 733 → 779, beto 608 → 615. **Hazaki é o único que ficou claramente mais fraco** (no 30 s: 41 → 22 abates): é o herói de maior variação e a janela de 30 s é pequena, mas é o primeiro lugar a olhar na mão. Ruído do robô entre duas rodadas iguais: ±10-15%.
- **Fotos conferidas por mim (PNG, `--print_tela=golpe --heroi=X --arma=Y --nivel_arma=N`, novo `--nivel_arma` (99 = máximo; alvos aguentam todos os golpes, sem números de dano) com recorte ampliado 3x e uma linha por nível):** 26 armas em nível 1, 4 e máximo + a evoluída (katana, arte marcial, desert eagles, poder elemental, aura, corrente→fibra ótica, adaga→SSD, lâminas→water cooler, fogo grego→garrafa, sino→roteador, machado, raio→fúria, lança→lança ardente, corvos→revoada, runas→círculo, martelo→terremoto). O crescimento é óbvio e continua legível (nada some nem tapa o herói); 5 composições em `jogos/hordas/prints/armas_crescem_*.png`. Ajustei depois de ver: soco da arte marcial quase não mudava (agora o punho cresce e há onda de energia), corvo do nível 1 sumia (tamanho mínimo 0,85), luz das runas lavava a tela (agora do tamanho da runa), o anel de chamas da aura nunca fica mais estreito que o herói (`testes/suavidade`).
- **Online:** nenhum formato mudou. O ataque do jogador é desenhado/calculado só na máquina dele, a partir do nível da arma dele; os outros jogadores não têm o ataque desenhado na tela (só o dano vem pelo `golpe`), então não há o que dimensionar por nível remoto. `online_golpe.sh` ok (204 golpes, 193 com arma).
- **Também corrigido:** `elementos.gd:327` (SCRIPT ERROR raro em partida longa do robô, já existia na `main`: uma reação do mesmo laço apagava o estado antes de ele ser lido) com um `has()`.
- **Testes:** 41 cenas com falhas=0 e 0 SCRIPT ERROR; nova `testes/crescimento.tscn` (curva monotônica por arma, nível 1 < máximo, tiers 0-3 e evolução no 4 com DPS e área ≥ máximo da base, override por arma, dados padrão, XP inicial); `testes/suavidade` ganhou o piso do anel. Robô hazaki semente 7 40 s e partida de duelo (`--duelo=3`) sem SCRIPT ERROR; 20 partidas de 600 s sem SCRIPT ERROR.
- **Pendente (olho humano, i5-3470):** sentir o começo com a mão (principalmente Hazaki e o Sino/aura de Matheus, que não testei no robô), ajustar `dados/crescimento_armas.json` (curva, `xp_inicial` e `efeitos`) e olhar o custo dos efeitos do tier 3-4 com 500 bichos; ligar `Cresc.fator()` ao perfil gráfico quando ele entrar.
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (notebook) · instalador Windows (Inno Setup), ícone e versão em todas as telas

- **Feito:** instalador por usuário (`jogos/hordas/instalador/kikiu.iss`: sem administrador, em `%LOCALAPPDATA%\Programs\KIKIU`, atalhos no menu Iniciar, atalho opcional na área de trabalho, desinstalador, textos em português). `./gerar_instalador.sh` (em `jogos/hordas/`) roda o carimbo, importa, exporta o `.exe` e compila o instalador; saídas em `build/` (fora do Git).
- **Ícone:** escudo com marca de caos (`fonte_arte/icone_jogo.gd` desenha 16 px e amplia por vizinho mais próximo para 32, 48, 64, 128 e 256; `projeto/assets/icone/kikiu.ico` com os seis tamanhos).
- **Arte do assistente:** `instalador/gerar_arte.sh` (ffmpeg) recorta o cavaleiro de `docs/imagens/cavaleiro.png`, escurece as bordas e escreve "K.I.K.I.U" em BMP 24 bits (164x314, 328x628, miniaturas 55x58 e 110x116).
- **Versão em todas as telas:** addon `projeto/addons/kikiu_versao` escreve `dados/versao.json` (data e commit, com `+` se houver mudança sem commit) antes de cada exportação, até pelo editor. "Versão 0.1.0 · 07/10/2026 · 20bf57a" aparece no título (canto), em Opções (canto superior direito) e no menu de pausa. A função está em `Dados.texto_versao()`. O nome do instalador leva versão e commit (`KIKIU-Setup-0.1.0-20bf57a-mod.exe`).
- **Rótulo:** "Qualidade (partículas, sombras, luz)" virou "Qualidade gráfica".
- **Pendente (olho humano):** o `.exe` NÃO leva o ícone embutido. O export do Godot 4.4 ainda chama o `rcedit` quando "Modificar recursos" está ligado, e não há rcedit nesta máquina; por isso o passo ficou desligado (`application/modify_resources=false`). O ícone aparece nos atalhos e na desinstalação, porque o instalador copia o `kikiu.ico`. Para embutir: baixar o rcedit, apontar em Editor > Configurações > Exportar > Windows > rcedit e religar o `modify_resources`. A arte do assistente do Inno só foi conferida como PNG, não numa janela de instalação.
- **Testes:** 41 cenas `testes/*.tscn` com falhas=0 e 0 SCRIPT ERROR; robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40` sem SCRIPT ERROR; instalação e desinstalação silenciosas ok; `--print_tela=titulo|opcoes|pausa` no `.exe` exportado e no instalado.
- **Para o Claude do Breno:** para gerar o instalador, instale o Inno Setup 6 e os modelos 4.4.1, depois rode `./gerar_instalador.sh` em `jogos/hordas/`. O `gerar_versao.sh` continua valendo, mas já não é preciso rodá-lo.
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (notebook) · arte do instalador com sprites reais e ícone embutido no .exe

- **Arte do assistente refeita:** `jogos/hordas/instalador/gerar_arte.gd` (Godot, não roda em `--headless`) monta a cena num SubViewport com arte real do jogo: Hazaki em camadas (corpo, botas, armadura de samurai, braçadeiras, máscara, elmo com chifres e katana, pose de ataque), monstros das folhas `inimigo_*.png` (cultista, espectro, cavaleiro oco, lobo sombrio, cão de ossos) como silhuetas ao fundo, piso e árvores da Floresta Sombria, lua, neblina, luz de tocha, brasas, vinheta e o título "K.I.K.I.U" com o subtítulo na fonte do jogo. A pequena é o escudo do ícone numa moldura de noite. Os dois tamanhos são a mesma cena com escala inteira dobrada (não ampliação do PNG pequeno). `gerar_arte.sh` chama o Godot e converte para BMP 24 bits com o ffmpeg; prévias em `prints/instalador_wizard_*.png` e `prints/instalador_small_*.png`.
- **Ícone no .exe:** `application/modify_resources=true` de volta no preset (o rcedit v2.0.0 está em `C:/Dev/Tools/rcedit`, apontado no editor_settings desta máquina). Provado: `ExtractAssociatedIcon` do `KIKIU.exe` devolve o escudo (`prints/instalador_exe_icone_extraido.png`) e o `VersionInfo` mostra K.I.K.I.U / Breno e Alisson / 0.1.0.0.
- **Sem rcedit o export NÃO falha:** o Godot só imprime o aviso "Modificação de Recursos: não foi possível iniciar o executável rcedit", sai com código 0 e entrega um .exe com o ícone e os detalhes do Godot (conferi). Por isso o `gerar_instalador.sh` agora confere o rcedit antes e avisa em letras grandes; o README (seção "Gerar o executável") explica como instalar (https://github.com/electron/rcedit/releases e Editor > Configurações do editor > Exportar > Windows > rcedit). Os números `product_version`/`file_version` do preset são fixos: sobem à mão junto com `application/config/version`.
- **Testes:** instalador gerado de commit limpo (`KIKIU-Setup-0.1.0-<commit>.exe`, sem "-mod"), instalação e desinstalação silenciosas ok, jogo instalado abre (`--print_tela=titulo`); `--import`, 41 cenas `testes/*.tscn` com falhas=0 e 0 SCRIPT ERROR; robô de 40 s sem SCRIPT ERROR.
- **Pendente (olho humano):** ver o assistente de verdade rodando (não tirei foto da tela do usuário): se as BMP ficam bem nas telas de boas-vindas e de fim e se a miniatura do canto combina com o cabeçalho claro do estilo moderno.
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (PC) · #94: começo do Hazaki recalibrado: fator inicial das armas 0.7→0.85 (área) e 0.88→0.95 (dano)
Só o primeiro ponto das curvas `area` e `dano` de `dados/crescimento_armas.json` mudou; 0.5 e 1.0 intactos, então as armas terminam grandes como antes. Robô `--bot --heroi=hazaki --sair=60`, abates em t=30 / t=60 (3 sementes em paralelo; há ruído entre rodadas, uma rodada serial da semente 3 deu 13 aos 30 s):

| semente | antes (30 s / 60 s) | depois (30 s / 60 s) |
|---|---|---|
| 3 | 46 / 178 | 59 / 233 |
| 7 | 19 / 97 | 34 / 129 |
| 11 | 32 / 126 | 41 / 167 |
| média | 32,3 / 133 | 44,7 / 176 |

Meta (≥ 85% de 41 = 34,9 aos 30 s) atingida. `armas_novas`, `golpes`, `regras_armas` com falhas=0; 0 SCRIPT ERROR. Pendente: se ficar fácil demais, tentar 0.8 / 0.92. Sem push/PR (worktree).
## 2026-10-07 - Fase (#112, marco A): prorrogação, portal de saída e transição
- **Prorrogação:** `dados/prorrogacao.json` (com `_ajuda`). O chefe nasce no fim de `duracao`; o jogador tem `janela_chefe` (120 s) pra derrubá-lo. Passou disso, o HUD mostra o cronômetro subindo (`+MM:SS`, "PRORROGAÇÃO nível N  ouro xN"). A cada 5 s (`degrau_s`) sobe um degrau: +0,35 min de dificuldade no diretor, +25% de ouro por abate e +12% de créditos, até `max_degraus` (40). Sem prorrogação na última fase (Enxame Final). Funções em `diretor_hordas.gd` (`pror_t`, `pror_degrau`, `mult_ouro`, `janela_resta`); o ouro entra em `arena.recompensa`. Online: cada cliente deriva o degrau do próprio `t_fase`, sem mensagem nova.
- **Saída voluntária:** matar o chefe da fase não leva mais sozinho pra próxima fase. `arena.abrir_saida` abre um portal (`saida.gd`) onde ele caiu; entra no raio e segura CONFIRMAR 1 s (`prorrogacao.json > saida`). A horda continua leve (`diretor.saida_leve`: créditos x0,35, mínimo x0,4). Ao sair: herói sugado, clarão branco, cortina (`Transicao.revelar`) e só então `fase_completa` (resultados, baú, mapa) como antes.
- **Online:** evento novo `saida_aberta` (x, y) do anfitrião (em `Rede.EVENTOS`); cada jogador avisa `saida` ao ser sugado e fica parado no portal; o anfitrião (`online.gd _checar_saida`) manda `fase_completa` quando todos os vivos estão prontos ou 45 s depois do primeiro. NÃO testado com duas instâncias reais.
- **Robô:** `jogador._bot_dir` anda até o portal quando ele abre e o robô segura confirmar sozinho.
- **Teste:** `testes/prorrogacao.tscn` ("PROR falhas=0"); mapa, regioes, abertura e pausa também com falhas=0.
- Não mexi em `cenarios.py`, `cenarios.json`, `assets/cenarios` nem `chao.gd` (outro agente).
- Para o Claude do Alisson (PC): falta ver o portal e a sucção/clarão com olho humano (nada foi visto em tela), testar online com 2 instâncias, e os itens 1, 2, 5, 6, 7 da #112 (missões do boss, loja por jogador, cenários) seguem em aberto.
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (PC) · #112 marco A (#114): cronômetro de fase, prorrogação e portal de saída
- Feito: prints com janela (`--print_tela=saida|prorrogacao`, com `--pror=N`, `--entrar --seq=`) conferidos: HUD do cronômetro/prorrogação e portal de saída legíveis, sem ajuste. Testes `prorrogacao`, `mapa`, `regioes`, `transicao`, `pausa`, `rede` com falhas=0; partida `--bot --heroi=hazaki --semente=7` sem SCRIPT ERROR.
- Pendente: nada de online testado (prioridade baixíssima).
- Próximo: marcos C e D do #112; online fica pro fim.
- Claude do Alisson (PC)
## 2026-10-07 · Claude do Alisson (notebook) · #112 item 7: cenários por andar (marco B, só a Floresta)

- **Estrutura:** `dados/cenarios.json > variantes > <base>` = lista de cenários, um por andar da região. `Cenario.variante(base, andar_regiao)` escolhe: o andar 0 usa a primeira, os outros seguem uma ordem embaralhada pela semente (`Sorte.criar("variantes_<base>")`, independente de outros sorteios, então igual no online). Sem entrada em `variantes` vale o cenário único de sempre. Variante sem config própria em `cenarios` usa a do cenário-base (`Cenario.base_de`). `chao.gd` só chama `Cenario.variante` ao ler a região da fase.
- **Floresta com 5 andares diferentes:** `floresta` (mata fechada), `floresta_clareira` (lajes e pedras, mais claro), `floresta_pantano` (poças e raízes, tom úmido), `floresta_ruina` (lajes de pedra com musgo) e `floresta_fungos` (chão roxo-azulado, cogumelos brilhando). Cada uma tem piso próprio, ambiente, pesos de enfeites e partículas próprios. `cenarios.py` ganhou `piso_floresta_var` e `_variante` (reaproveita o atlas de enfeites da base e só renderiza o piso: ~20 s para as 4, `blender -b -P cenarios.py -- floresta_clareira ...`). Props novos: nenhum.
- **Testes:** `testes/variantes.tscn` (variante por andar determinística, ordem muda com a semente, região sem variantes = cenário único) falhas=0; regioes, mapa, vistas falhas=0; robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40` sem SCRIPT ERROR. Capturas `--print_tela=hazaki --fase=1..4 --semente=7` mostram pisos e climas diferentes (olho humano ainda deve conferir o gosto).
- **Pendente:** variantes de Pântano, Deserto, Gelo e Reino (mesmo molde: uma função de piso parametrizada + `_variante` + lista em `variantes` + config em `cenarios`); props novos baratos por variante (ex.: ruína com colunas); pesos a gosto do Breno.
- **Para o Claude do Alisson (PC):** branch `alisson/cenarios-por-fase`, PR em rascunho. Para continuar, copie o bloco `VAR_FLORESTA`/`piso_floresta_var` em `cenarios.py` para a próxima região, gere, rode `--import` e `testes/variantes.tscn` (acrescente a lista da região). Não mexi em arena.gd, diretor_hordas.gd, hud.gd nem dados/fase.json.
- Assinado: Claude do Alisson (notebook)

## 2026-10-07 · Claude do Alisson (PC) · prioridade: multiplayer por último
- **Decisão do Alisson:** multiplayer/online fica em **prioridade baixíssima**, só depois de todo o refino do jogo solo. Não gastar tempo com rede, sincronização nem testes com 2 instâncias agora; só manter os testes existentes passando.
- **Para o Claude do Alisson (notebook):** vale pra você também. Itens só de rede (#112, #94 item 5, #106, chat/lobby) vão pro fim da fila.
- PC assumiu os rascunhos #113 (merge como está) e #114 (sem a parte online) e o começo do Hazaki (#94 item 2).

## 2026-10-07 · Claude do Alisson (PC) · #112 marco C: missão do chefe (pontos de interesse)
- **Feito:** o chefe da fase agora é chamado por uma missão em pontos de interesse do mapa (`scripts/hordas/missao_chefe.gd`, dados em `dados/missoes_chefe.json`). Tipos: `fragmentos` (coletar 4 e levar ao altar), `pilares` (ficar perto de cada um até despertar), `selos` (matar 3 elites marcados), `invocar` (só um altar: entrar e segurar CONFIRMAR). `por_chefe` lista os tipos de cada chefe (Bruxa do Mato: fragmentos/invocar; Rainha Sapo: selos/fragmentos; Mãe do Lodo: pilares; Sacerdote da Areia: pilares/invocar; Rei Escaravelho: fragmentos; Jarl: selos/pilares; Arauto: fragmentos/selos; Velho Carvalho, Gigante da Tempestade e Soberano do Caos: só invocar), sorteado por `Sorte.criar("missao_chefe", andar)`. Uma fase do `regioes.json` pode forçar `"missao": "tipo"` ou apagar com `"missao": false`.
- **Fluxo:** a missão aparece 24 s depois da chegada; cumprida, `diretor.chamar_chefe(onde)` (refatorado do `_eventos`) faz o chefe nascer perto do altar. Nunca trava: se não cumprir até `duracao + tolerancia` (75 s), a missão falha e o chefe vem de fora da tela como antes. Fase sem missão iniciada = comportamento antigo. HUD: título, barra, texto curto ("Fragmentos 2/4", "Leve ao altar"), setas com distância nas bordas; marcadores desenhados no mundo. O robô vai ao ponto mais perto (`jogador._bot_dir`).
- **Testes:** `testes/missao_chefe.tscn` (`MISSAOCHEFE falhas=0`: cada tipo cumpre e libera o chefe, chefe segurado enquanto a missão rola, tolerância, invocar exige segurar, escolha por chefe/fase), prorrogacao, mapa, regioes, transicao, pausa, rede, objetivos, resultado, esc_transicao falhas=0. Robô `--bot --imortal --semente=7`: 0 SCRIPT ERROR, missão cumprida (invocar na fase 1, fragmentos na fase 2) e chefe chamado. Print: `--print_tela=missao --tipo=pilares --fotos=<pasta>`.
- **Pendente:** online (só o anfitrião roda a missão; falta mandar o estado aos clientes, TODO no topo do script; prioridade baixíssima); recompensa pela missão (hoje a recompensa é o próprio chefe); balancear `inicio`/`tolerancia`/quantidades jogando de verdade; arte própria dos fragmentos/pilares/altar (hoje desenhados por código).
- **Próximo:** conferir no jogo real se 24 s de espera e a distância dos pontos (200-430 px) estão boas; depois marco D (loja, outro agente) e merge.
## 2026-10-07 · Claude do Alisson (PC) · #112 marco D: sala da loja com vendedor
- **Feito:** `scripts/hordas/loja.gd` virou uma sala (herói anda com setas/analógico até o balcão, CONFIRMAR abre a vitrine, a porta embaixo ou Esc sai). Vendedor = sprite do `fabio`; itens são as cartas que já existiam (arma, passivo, equipamento) mais a cura. Estado **por jogador** em `loja.jogadores[id]` (estoque, compras, ouro dos não-locais). **Curva de preço** em `dados/mapa.json` (tipos.loja.curva): preço = base x (1 + 0,25 x compras do jogador), teto 4x; as compras valem pra corrida toda. **Decisão de encaixe:** a loja continua sendo um nó do mapa (peso 3, máx. 2 por mapa); ao escolher o nó cai na sala e, ao sair, segue pro mapa/próxima etapa (o portal de saída do marco A não mudou). `--print_tela=loja [--vitrine]` mostra a sala/a vitrine. Robô anda até o balcão, compra e sai sozinho (teto de 12 s).
- **Testes:** `testes/loja_sala.tscn` LOJASALA falhas=0 (curva, dois jogadores independentes, sem ouro, porta leva ao mapa); prorrogacao, mapa, regioes, pausa, rede, transicao falhas=0; robô `--bot --heroi=hazaki --semente=7` 0 SCRIPT ERROR.
- **Pendente:** online (TODO em loja.gd: cada cliente sorteia e gasta a própria loja; só o local tem ouro real); opção de loja obrigatória entre fases estilo Hades (hoje só quando o mapa sorteia o nó); mais vendedores por região.
- Assinado: Claude do Alisson (PC)

## 2026-10-07 — Arte da sala da loja refeita (empório de mercador sombrio)
- **Feito:** a sala deixou de ser `draw_rect`. Novo gerador `jogos/hordas/fonte_arte/modelos3d/loja.py` (Blender 4.5, Cycles em 4x + média + paleta, mesma técnica do `cenarios.py`, mas sem importá-lo porque ele roda `main()` ao importar). Roda `blender -b -P loja.py [-- peça ...]` (peças soltas vêm do cache em `%TEMP%/loja_cache`). Saída em `assets/cenarios/loja/`: `piso.png` (tábuas com veios, repete), `parede.png` (640x112: pedra, vigas, lareira, prateleiras de poção, tapeçaria, janela com lua, lampiões, ervas), `objetos.png` (balcão com balança/vela/moedas, barris, caixotes, sacos, baú aberto com ouro, caldeirão no fogo, mesa de alquimia, suporte de armas, armadura, velas, tapete, moldura da porta) e `cenario.json` (o layout da sala mora no `loja.py`: `LAYOUT`, `LUZES_FIXAS`, `EMISSORES`).
- **loja.gd:** lê o `cenario.json`; objetos e vendedor/herói ordenados pelo pé; sombras em elipse; mapa de luz (multiplica: ambiente frio escuro + poças quentes + vinheta, 128x72 montado uma vez), halos ADD que tremulam, feixe de luar, brasas, fumaça do caldeirão e poeira. Textos e vitrine num `Control` acima da luz (com plaquinha escura pra ler). `_obst` (Rect2 por objeto) bloqueia o herói com deslize; o balcão, `BALCAO`, `PORTA`, `perto_do_balcao` e a lógica de compra ficaram iguais. Faixa central x 280..360 livre pro robô. Vitrine com cores quentes.
- **Testes:** loja_sala, mapa, pausa falhas=0. Prints: `--print_tela=loja [--vitrine]`.
- **Pendente:** nada obrigatório. Se mexer em peça, rode o `loja.py` com o nome dela e depois `--import` no Godot 4.4.1.
- Assinado: Claude do Alisson (PC)

## 2026-10-07 (issue #115): armas universais, variações, limite de slots e fusões — Claude do Alisson (PC)
- **Feito:** `dados/armas_universais.json` (50 armas base em 11+ classes: espada, machado, arco, adaga, escudo, cajado, martelo, lança, maça etc., mais 6 armas fundidas) e `scripts/hordas/universais.gd`. Cada base gera 8 variações (puro, de Sangue, Gélida, Lunar, Peçonhenta, Ardente, Astral, Dracônica) injetadas em `armas.json` na leitura (`Dados.json("armas")`), sem editar o conteúdo existente. A variação sai da semente da corrida (arma + rodada), com raridade por peso.
- **Limite:** total 5 armas, no máximo 2 únicas (2 únicas + 3 universais ou 5 universais), em `limites` do JSON; `Construcao.max_armas()` e `Universais.cabe()`.
- **30 a 40:** cartas novas `ascensao` (até 5 degraus depois do nível máximo: +12% dano, +5% área), `reforja` (troca a variação mantendo o nível) e `fusao`; a cura só sai se não sobrar nenhuma carta.
- **Fusões:** 6 receitas (2 ou 3 armas no nível máximo, qualquer variação) viram 1 arma fundida e liberam slots.
- **Testes:** `testes/armas_universais` (falhas=0); suíte inteira falhas=0; bot hazaki semente 7 sem SCRIPT ERROR.
- **Pendente:** ícones/sprites próprios (hoje reaproveita os existentes, cor e elemento diferenciam a variação); mecânicas de fusão ainda são só tipo/elemento/números, falta ligar `comportamentos.json`; rivais não usam universais; HUD com 5 slots não foi conferido visualmente; balanceamento com o robô de partida longa e fps com 500 inimigos.
- **Próximo:** conferir HUD dos 5 slots, mais receitas de fusão, ícones em pixel por variação.
## 2026-10-07 - #112 item 7: variantes de cenario das outras regioes (Claude do Alisson, PC)
- **Feito:** Pantano (base, lago, fogo-fatuo, cemiterio), Deserto (base, dunas, oasis, ruina, canion), Gelo (base, lago congelado, cristais, nevasca), Reino (base, praca, catacumba, jardim morto). Mesma ideia do #113: variante = piso novo + pesos/ambiente proprios, reaproveitando o atlas de enfeites do cenario-base. Codigo: `piso_var`/`VAR_REGIOES`/`PESOS_VAR` em `fonte_arte/modelos3d/cenarios.py` (gerar so as novas: `blender -b -P cenarios.py -- pantano_lago ...`, ~25 s cada). Lista por regiao em `dados/cenarios.json` > `variantes`. `testes/variantes.tscn` cobre as 4 regioes. Prints: `--print_tela=entrada --fase=1 --seq=3.5 --cenario=<nome>` (a opcao `--cenario=` em `chao.gd` so serve pra print), saida em `jogos/hordas/prints/variantes_regioes/`.
- **Pendente:** loja obrigatoria entre fases (parte 2: `loja_entre_fases` em `dados/fase.json` + `saida.gd`) nao foi feita. Pisos novos sao simples (sem enfeites novos por variante, ex.: palmeira no oasis). O oasis sai oliva por causa da paleta quantizada.
- **Proximo:** loja entre fases; enfeites proprios por variante.
## 2026-10-07 - Issue #98: raridade, fonte mística e textos das dádivas (Claude do Alisson (PC))
- **Feito:** raridade da dádiva aparece uma vez só (na carta, em filetes na cor da raridade, fonte mística); a tira do topo diz DÁDIVA. Fonte mística **Jacquard 12** (OFL, `assets/fonte/Jacquard12-Regular.ttf` + `OFL.txt`) em `Dados.fonte_titulo`: títulos de tela (tamanho 24), nomes das cartas e raridade (tamanho 12). Texto pequeno e números continuam em Press Start 2P (`Dados.fonte`). Todos os acentos checados no cmap das duas fontes.
- **Textos:** `dados/dadivas.json` ganhou campo `texto` (frase com `{v}`) nas 10 dádivas simples, ex.: "Regenera 1,4 de vida por segundo." Números saem com vírgula decimal (`Descobertas._valor`).
- **Testes:** todos os 49 testes (sem bench_) com falhas=0.
- **Pendente:** print visual de uma carta de dádiva (o `--print_tela=cartas` só mostra armas); conferir o visual da raridade e a legibilidade do nome em 12px. Ícones do Ímã de Almas, Sopro Ágil e Coração de Brasa não foram refeitos (item 4 da issue #98).
- Assinado: Claude do Alisson (PC)

## 2026-10-09 — Loja obrigatória entre fases (#112, último item) — Claude do Alisson (PC)
- **Feito:** ao sair da fase pelo portal, depois dos resultados e do baú (e do bônus da elite), o jogador passa pela sala da loja e só então vê o mapa (`arena.gd: fase_completa` + `loja_entre_fases_devida()`). Liga/desliga em `dados/fase.json` → `"loja_entre_fases"`. Não repete se todos os próximos nós do mapa já são loja; sem próximo nó (fim) também não abre. Preço/compra intactos; online só reaproveita `loja.fechar()` do `escolher_no`.
- **Testes:** `testes/loja_sala.gd` cobre a regra (combate → loja; só loja → não repete). `loja_sala`, `transicao`, `mapa`, `prorrogacao`, `missao_chefe`, `pausa`, `rede` com falhas=0; bot `--sair=200` sem SCRIPT ERROR. Obs.: numa worktree nova rode `--import` até terminar (sem isso dá "Could not preload" e `missao_chefe` falha).
- **Pendente:** conferir o fluxo completo (portal → loja → mapa) com os olhos num jogo de verdade.
## 2026-10-09 — Claude do Alisson (PC): #123 objetivo legível
- Feito: marcadores de objetivo (pira, totens, fugitivo, selos, fragmentos, pilares, altar) numa camada própria `z_index=50` (`objetivos.marca_topo`: halo + anel escuro de contorno + anel colorido pulsante + 4 pontas girando), por cima de inimigos, poderes e baús. Setas da borda do objetivo do andar agora mostram a distância em metros (a da missão do chefe já mostrava). Baús (`coleta.soltar`) são empurrados pra fora de 90 px dos alvos do objetivo/missão. `main.gd`: `--muitos=N` no print de `objetivo`/`missao` (horda + baú em volta do jogador).
- Pendente: reduzir opacidade de efeitos/baús em cima do objetivo e ponto no minimapa (#122); conferir visualmente as outras regiões e qualidades gráficas.
## 2026-10-09 — Issue #98: revisão ortográfica dos textos de carta (Claude do Alisson (PC))
- **Feito:** varri os 653 textos de exibição de `dados/*.json` (nome, descrição, texto, rótulo, mensagem, frase etc.; `_ajuda` de dev ficou de fora). Só 1 erro: `especiais.json` (Hazaki) "crita" → "grita". Ids, chaves e números não mexeram. Vírgula decimal já estava certa nos textos exibidos.
- **Testes:** 46 cenas (sem bench_) com falhas=0. Na worktree nova foi preciso rodar `--import` antes.
- **Pendente:** nada. `_ajuda` (notas internas) não foi revisado, se quiser uma passada extra.
- Assinado: Claude do Alisson (PC)

## 2026-10-09: decisão da v2 e fila da v1 fechada (Claude do Alisson (PC))
- **Decidido com o Alisson:** os marcos 0 a 9 do Breno (#134, #124 a #133) são a **v2** do KIKIU, "roguelike de ação com controle". A v1 é o que existe hoje, quase autobattle. O plano completo está no comentário da #122, e cada ponto tem um padrão que vale se o Breno não responder:
  - A v2 é feita no **mesmo projeto**, sem pasta nem branch separada.
  - A tag **`v1.0`** sai quando o Breno der o OK.
  - O Godot continua no **4.4.1**.
  - A performance começa em **GDScript**; C++ só entra se a medição pedir, porque complica a build web.
  - O Alisson aprovou que os **menus virem cenas `.tscn`**.
  - A direção visual se decide logo no começo.
- **Fila da v1 fechada no #135:**
  - Loja obrigatória entre fases.
  - Objetivos desenhados acima da horda (#123).
  - Revisão de ortografia dos `dados/*.json`.
- **Próximo:** esperar o OK do Breno no plano da #122. Sem ele, não começa código de combate nem de mapa (marco 2 em diante). O marco 0 (CI, build automática, ortografia, limpeza do tema antigo) pode começar.
- **Para o Claude do Alisson (notebook):** siga o plano da #122. O online continua por último.

## 2026-10-09 - Marco 0 (#124), parte técnica: CI, ortografia e export automático
- **Feito:** `.github/workflows/ci.yml` (ubuntu-latest: import 2x + todas as cenas `testes/*.tscn` menos `bench_*`, falha sem `falhas=0` ou com SCRIPT ERROR; teste de ortografia; `gdlint` só como aviso). `.github/workflows/release.yml` (a cada push na `main` exporta Windows, Linux e Web e publica Release `build-<data>-<sha>`). `ferramentas/ortografia.py` + `ferramentas/ortografia_excecoes.txt` (hunspell pt_BR; textos exibíveis dos `dados/*.json`, sem ids nem `_ajuda`). Presets Linux e Web (sem threads) em `export_presets.cfg`.
- **Validado local:** YAML válido; 44 cenas de teste com `falhas=0`; ortografia com 0 palavras fora do dicionário (verificada via spylls + dicionário LibreOffice pt_BR; erros reais nos textos: nenhum, só nomes próprios nas exceções). **Só dá pra validar no GitHub:** execução dos workflows, hunspell do apt, export Linux/Web com templates, gdlint.
- **Pendente (resto do #124):** `rcedit` não roda no Linux, então o `.exe` do Release sai sem ícone/versão (`modify_resources=false` no CI); `gdformat`/`class_name`; `testes/ortografia.tscn` com textos gerados (`{v}`); `--print_tela=cartas --todas`; limpar tema antigo; atualizar `docs/ONLINE_KIKIU.md`. O Web só foi configurado sem threads, não testado no navegador.
## 2026-10-09 - Fusões de armas universais com mecânica própria (#115)
- **Feito:** cada receita em `fusoes` (`dados/armas_universais.json`) ganhou `mecanica` (comportamento de `comportamentos.json` -> ajustes de parâmetro) e `desc`. `universais.gd` injeta ambos na arma fundida; `armas.gd` (`_comp_de`) entrega em `s.comp`. Aurora Rubra: rastro de sangue em brasa; Chuva de Estrelas: raio salta em corrente (+4); Martelo Glacial: congela e onda-eco puxa; Lança Sanguessuga: 3 pontas e rouba vida; Ciclone: órbita que respira; Lua Peçonhenta: poça explode ao secar. Novos comportamentos `so_fusao` (nunca saem em carta). Teste `armas_universais` estendido.
- **Pendente:** conferir visualmente (pontas da lança, eco do martelo).
- Claude do Alisson (PC)
## 2026-10-09: ícones próprios das armas universais (#115) (Claude do Alisson (PC))
- **Feito:** 50 ícones 16x16 em pixel art para as armas universais (`armas` sem `fusao`), gerados em `jogos/hordas/fonte_arte/icones_tema.gd` (`molde_*` por classe + `u_<id>` com `base`/`troca` de cores). `icone` de cada arma em `armas_universais.json` aponta para `u_<id>`. Saída em `assets/gerado/icone_u_*.png`.
- **Pendente:** as 6 armas de fusão (`fusao_*`, em `armas` com `fusao: true`) continuam com ícones antigos; ficaram de fora porque a tarefa pedia só as 50 e a seção de fusões é de outro agente.
- **Testes:** `armas_universais`, `regras_armas` e `cartas_comp` com falhas=0.
- **Próximo:** conferir a legibilidade no jogo, em tela, e decidir o ícone das fusões.
- Assinado: Claude do Alisson (PC)
## 2026-10-09 - Claude do Alisson (PC)
- Issue #98: ícones redesenhados no `gerar_arte.py`: Ímã de Almas (ímã em U com almas), Sopro Ágil (rajadas de vento, chave `vento_sopro`) e Coração de Brasa (coração de brasa, chave `brasa_coracao`). As dádivas `brasa` e `sopro` apontam para as chaves novas; a marmita (drop de cura) e o overclock (passivo) ficaram como estavam.
- Acento: a linha de base da raridade (ÉPICA, etc.) estava em y+78 e o filete em y+76 cortava a palavra; subiu para y+88, entre os filetes (`scripts/hordas/cartas.gd`).
- Pendente: conferir no zip do Breno se o acento de É/Á/Ã aparece nítido em resolução real (o print de teste é 640x360 e não dá para ver bem). Ortografia e sprites das demais cartas seguem na #98.
- Testes: cartas_comp, descobertas e pausa com falhas=0.
## 2026-10-09: marco 0 (limpeza do tema antigo) e ONLINE_KIKIU atualizado (Claude do Alisson (PC))
- **Feito:** apagados 4 PNGs de informática sem nenhuma referência no projeto de hordas, com o .import (~27 KB): `assets/gerado/proj_ssd`, `proj_water_cooler`, `icone_ssd`, `icone_water_cooler`. Os sprites das armas `ssd` e `water_cooler` usam `proj_tempestade` e `proj_ciclone`. **Mantidos** `assets/cenarios/cidade` e `laboratorio`: ainda estão em `dados/cenarios.json` e no `--fase` do `main.gd`. `jogos/cairu/` não foi tocado.
- **Feito:** `docs/ONLINE_KIKIU.md`: status atualizado (online é o marco 9, #133, por último) e as pendências com os TODOs de `missao_chefe.gd` e `loja.gd`.
- **Testes:** 46 cenas (sem bench_) com falhas=0 e 0 SCRIPT ERROR; bot `--heroi=hazaki --semente=7 --sair=120` sem SCRIPT ERROR. Import feito 2x.
- **Pendente:** `fonte_arte/gerar_arte.py` ainda gera esses 4 PNGs (linhas 289, 293, 380, 533 e 534). Se o gerador rodar de novo, eles voltam; tirar essas entradas dele é um passo separado. Também faltam o `cabeca_sem.png` de Hazaki (sem referência, mas não é do tema antigo) e a decisão sobre `cidade`/`laboratorio`.
- Assinado: Claude do Alisson (PC)

## 2026-10-10 · Claude do Alisson (PC) · desempenho no nível ~70 (investigação)
- **Feito:** log do `--sair` ganhou a linha `contagem:` (projéteis, poças, números, partículas, itens, mortes, nós, `quadro_ms`); `--build=N` agora é repetível com `--semente` (antes o RNG da build era solto). Cortes por tela em `coleta.gd` (sem `duplicate()`/`erase()` por quadro, gemas fora da tela não desenham), `mortes.gd` e `efeitos.gd` (partículas/números fora da tela).
- **Medido (headless, `--bot --heroi=hazaki --semente=2 --build=70 --estresse=500 --armas=cabo_rede,arte_marcial,wifi,aura_hazaki,geada --imortal --sair=17`, mediana de 3):** `quadro_ms` 9.3 -> 9.0..10.4 (dentro do ruído), `proc_ms` ~18 -> ~20. Ou seja: **não achei o gargalo de CPU de 15 fps**. Nada acumula sem teto (proj/poças/números<=70/partículas<=400/itens<=450 já têm limite). O custo é a horda (~500 vivos): `ini_atualizar` ~2.0 ms, `ini_d_*` ~1.9 ms, `mor_d` ~1.1 ms, `efe_d` ~0.75 ms, `col_d` ~0.7 ms (cortado a ~0.15), `arm_a+arm_d` ~0.9-2 ms nas builds de fusão com muita poça/efeito. Soma medida ~8 ms em headless: dá ~75-100 fps na CPU, então os 15 fps do Breno (RTX 3060) são **provavelmente GPU/preenchimento** (halos aditivos `_tex_luz` em `efeitos._draw_brilho`, `Cresc.halo` nos tiers altos, sombras) que o headless não mede. Próximo passo: medir com janela (`--sair` sem `--headless`) e testar `--qualidade=baixa`.

## 2026-10-10 (2) · Claude do Alisson (PC) · hotfix de fps
- **Feito:** overlay de diagnóstico (F3 / Select do controle, desligado por padrão: fps, quadro, proc, vivos, qualidade, resolução, 3 maiores perf_us); `limite_vivos` por qualidade em `qualidade.json` (500/350/250, vale o menor com o da fase); qualidade automática (fps < 40 por 8 s desce um degrau, só em memória, nunca sobe; opção "Baixar a qualidade se travar", ligada).
- **Medido com janela** (`--bot --heroi=hazaki --semente=2 --build=70 --armas=<5 fracas> --pular=1500 --imortal --sair=60`, ~500 vivos): alta 66 fps médio (mín 42); baixa antes (limite 500) 74 (mín 55); baixa depois (limite 250) 109 (mín 98).
- Assinado: Claude do Alisson (PC)

## 2026-10-10 (3) · Claude do Alisson (notebook) · Marco 1B: tela de status e objetivos acima da horda (#125, #123)
- **Feito:** `tela_status.gd` (segure Tab ou Back; no solo pausa, no online não): armas com nível e tamanho/dano do crescimento, passivos, equipamentos, conjuntos e 14 atributos com base em cinza e variação em verde/vermelho (recarga é o contrário: cair é verde). Usa o `tema_hud.tres` do 1A; o banner de conjunto é o do HUD novo. Ação `status` no `main.gd` (TECLAS/CONTROLE).
- **Feito:** `camada_objetivos.gd` + `legibilidade.gd`: portal de saída agora z 50 com contorno escuro e pulso; efeitos de arma (armas, poças, atrás) a 40% em cima de um alvo (shader ligado só quando há alvo); baú a 40% em cima de alvo e nunca a menos de 96 px (objetivo, missão e portal); seta do portal na borda com a distância ("SAÍDA 72m"). As setas do objetivo e da missão já eram do HUD (#135).
- **Testes:** novo `testes/status.tscn`; `testes/legibilidade.tscn` ampliado (camadas, opacidade, seta, distância do baú). Prints: `--print_tela=status|portal` (`--equip --estresse=250 --fase=N --longe`).
- **Pendente:** a lista de conjuntos continua no `hud.gd` (a 1A cuida do HUD novo e pode tirá-la); nomes de inimigo comum no HUD idem. Efeitos de inimigo (poças deles) e projéteis não ficam a 40% ainda. Texto novo sem `tr()` (o repo ainda não tem dicionário). Precisa de olho humano: Tab/Back no controle de verdade e se os 40% incomodam nas builds com muita poça.
## 2026-10-10 · Claude do Alisson (notebook) · fechamento do Marco 0 (#124)
- **Feito:**
  - **Ícone e versão no .exe da Release:** o job do Windows saiu do Ubuntu e agora roda em `windows-latest`, com o rcedit oficial (electron/rcedit v2.0.0) apontado nas editor settings do Godot 4.4.1. A versão do .exe (`product_version` e `file_version`) é copiada do `config/version` do projeto no próprio CI. Linux e Web continuam no Ubuntu. O `publicar` só roda na `main`; nas outras branches os exports viram artefatos do run.
  - **Build Web testada no navegador:** export local com o preset Web (sem threads, então sem COOP/COEP), servido por um HttpListener simples. A tela de título aparece (versão 0.1.0) e dá para começar uma partida (Hazaki, Sem calor, arena carregada). O download da build é de cerca de 62,6 MB (wasm 42,7 MB, pck 19,6 MB). Não medi o tempo exato até a tela de título.
  - **Formatação e ortografia:** `ci.yml` ganhou um passo `gdformat --check` só como aviso. Criei `jogos/hordas/formatar.sh` (não executado). As exceções da ortografia saíram de `ferramentas/ortografia_excecoes.txt` para `jogos/hordas/projeto/dados/dicionario.json` (chave `excecoes`, com `_ajuda`), e o `ortografia.py` lê de lá.
- **Provas:**
  - exe local com rcedit: `FileVersion=0.1.0.0`, `ProductName=K.I.K.I.U`, ícone extraído em 32x32.
  - `--import` ok; as cenas de `testes/*.tscn` (sem `bench_*`) passaram sozinhas.
  - robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40`: exit 0, zero SCRIPT ERROR.
- **Pendente (PR próprio, logo depois do Marco 1):** formatação geral com gdformat. Hoje `gdformat --check` marca 132 de 136 arquivos. Não formatei agora para não conflitar com hud.gd, arena.gd e config.gd do Marco 1. Depois que o Marco 1 entrar, rodar `jogos/hordas/formatar.sh` num PR só de formatação e trocar o aviso do CI por falha.
- **Recado:** a bateria de testes roda com a máquina sob carga. `abertura`, `elementos`, `equipamentos`, `regras_armas` e `transicao` falharam na bateria inteira e passaram sozinhos. `elementos` mede tempo em microssegundos (443 us contra 400 us), então é sensível à carga. Quem rodar a bateria deve evitar outros jogos e exports em paralelo.
## 2026-10-10 (3) · Claude do Alisson (notebook) · Marco 1A: HUD novo e opções de leitura (#125)
- **Feito:** o HUD virou cena (`jogos/hordas/projeto/cenas/hud.tscn`, Theme único em `cenas/tema_hud.tres`): esquerda = retrato, nome, vida e carga (energia do dragão ou fragmentos); direita = ouro e almas (almas fica em 0 até o Marco 7); topo = cronômetro, região/andar, prorrogação, objetivo e missão; embaixo à esquerda = 2 slots de habilidade (o especial do herói no 1, o 2 vazio até o Marco 6) e os consumíveis; embaixo à direita = `Minimapa` reservado (escondido até o Marco 4). `hud.gd` só liga os dados aos nós; o desenho à mão saiu (restam as setas da borda em `hud_setas.gd` e o quadradinho `hud_slot.gd`). Saíram da tela: contador de abates e lista de conjuntos (virou um banner de 2 s quando um degrau de conjunto liga; a lista inteira é da tela de status do 1B). Nome de inimigo comum já não aparecia; só elite/chefe, agora com a opção "Nomes de inimigo".
- **Opções** (grupo "Leitura da tela"): tamanho da fonte do HUD 1x/1,5x/2x (a chave `texto_hud` ganhou o valor `medio`; `normal`/`grande` de antes continuam valendo; o Theme aplica), números de dano, nomes de inimigo e partículas (Todas/Poucas/Nenhuma). A tela de Opções ficou com mais de 20 itens e agora rola.
- **Tradução:** `assets/traducao/textos.csv` (chave, pt_BR), registrado em `project.godot` com `pt_BR` como fallback; textos novos do HUD e das opções usam `tr()`. Os textos antigos de outras telas seguem em português direto.
- **Testes:** `testes/hud.tscn` (elementos e posições, fonte, partículas/números, banner de 2 s, prorrogação, pausa). Prints: `--print_tela=hazaki ... --fonte=medio|grande` nas 5 regiões, Baixa e Alta.
- **Pendente / olho humano:** o jogo usa a PressStart2P no HUD (a Jacquard 12 só nos títulos), mantive. Com fonte 2x o centro do topo e o painel do herói ficam apertados. O 1B entrega a tela de status (Tab) e a camada dos objetivos; a #125 só fecha quando as duas partes entrarem.
- Assinado: Claude do Alisson (notebook)

## 2026-10-10 (4) · Claude do Alisson (notebook) · Marco 2: esquiva com i-frames, esquiva perfeita e mira direcional (#126)
- **Feito:**
  - **Esquiva** (`dados/movimento.json`, com `_ajuda`): rolamento de 0,45 s no total, 0,25 s invulnerável (`invulneravel`), sem recuperação extra, recarga 1,2 s, 2 cargas (3 com o item do Pombo). A distância continua parecida (vel 1,8 x 0,45 s).
  - **Esquiva perfeita** (`esquiva_perfeita` no mesmo JSON): inimigo ou tiro a menos de 24 px no instante de rolar dá som, clarão dourado no herói, anel no chão, câmera lenta LOCAL (os vírus a 140 px ficam lentos por 0,5 s, o resto do jogo anda normal) e +25% no PRÓXIMO golpe (um golpe em área leva o bônus em todos os acertos do mesmo quadro; vale 4 s; marquinha dourada embaixo do herói). O bônus entra em `inimigos.ferir()` por `jogador.golpe_extra()` (3 linhas).
  - **Mira direcional** (`dados/mira.json`, com `_ajuda`): campo `mira` por arma (`"auto"|"direcional"`); sem o campo vale o padrão do tipo. Direcionais: projétil, lança, pistolas, raio, katana. Automáticas: órbita, aura, poça, corvos, runas e o resto. Entrada: analógico direito (`mira_*`) ou mouse (mexeu há 2 s, ou botão esquerdo apertado). Assistência de 20 graus (opção "Mira assistida"); sem entrada de mira as armas miram no mais perto, como antes. Lógica em `armas.gd` (`modo_mira`, `resolver_mira` pura, `mirar`, `mirar_alvo`).
  - **Retículo** no herói (`jogador._desenhar_reticulo`): alvo pequeno com contorno e pontinhos até o herói; dourado quando o bônus da esquiva perfeita está pronto. Opção "Retículo da mira".
  - **Opções > Controles:** retículo, mira assistida, mirar com o mouse e **remapeamento** de esquiva, especial, transformar e status (Enter na linha, aperte a tecla ou o botão; Esc cancela; fica em `[teclas]` do `opcoes.cfg` e `Config.aplicar_teclas()` põe no InputMap ao abrir). Padrões: Espaço/Shift e B/RB esquivam; analógico esquerdo anda, direito mira; Y especial; Back status.
  - **Robô:** esquiva com vírus colado (e já machucado, para não gastar fôlego à toa) e mira no meio do bando perto; no duelo mira no rival mais perto. O log do `--sair` ganhou a linha `esquiva: rolamentos= perfeitas= mira=`.
  - **Dica do portal** ("Segure CONFIRMAR para sair", #125): saiu do `_draw` do mundo e foi para uma camada de tela (layer 8, acima dos números de dano e do HUD) com caixa escura e contorno (`saida.gd`, `posicao_dica`).
  - Print novo `--print_tela=esquiva [--equip --estresse=N --mira=x,y --antes=S --espera=S --sem_rolar]`.
- **Testes:** novos `testes/esquiva.tscn` (i-frames, cargas, recarga, esquiva perfeita, bônus, robô) e `testes/mira.tscn` (modos por arma, assistência pura, fallback, analógico, projétil, lança, katana, pistolas, raio, automáticas); `rolamento` e `opcoes` ajustados (remapeamento). Suíte inteira (sem `bench_*`): tudo `falhas=0`, 0 SCRIPT ERROR; `criacao2` falhou só na rodada em paralelo (divide o arquivo de heróis com `criacao`) e passou sozinho.
- **Equilíbrio (robô, hazaki, 3 sementes, 600 s):** tabela no PR. Resumo: no mesmo tempo de jogo (partida ~205 s) fase, nível e abates ficaram iguais dentro do ruído do robô (ele escolhe cartas ao acaso, então a mesma semente varia ~30%); as rodadas longas "depois" andaram menos tempo de jogo por causa da máquina carregada (quadros longos), não por causa do jogo.
- **Pendente / olho humano:** controle de verdade (analógico direito, RB/B, remapeamento por botão) e mouse não foram testados com mão; botão de toque da esquiva não existe (o jogo ainda não tem camada de toque); LB não virou "especial" (continua `pular` das cartas). O bônus da esquiva perfeita é gasto pelo primeiro dano que o jogador causar, inclusive dano contínuo (queimadura, poça): se parecer injusto, trocar para só golpe direto.
- Assinado: Claude do Alisson (notebook)

## 2026-10-10 (4) · Claude do Alisson (notebook) · Marco 3: inimigos em lote, limite por fase e atlas (#127)
- **Feito:** os inimigos agora são desenhados por duas `MultiMeshInstance2D` (sprites e sombras) em vez de uma chamada de desenho por bicho (`inimigos.gd`, um shader simples compatível com `gl_compatibility`). Aura, brilho de elite e nuvem de nascer viraram discos da mesma MultiMesh; inclinação = 2 faixas. A lógica de `inimigos.gd` não mudou, só o `_draw` (e os 3 nós filhos que guardam a ordem: sombras, marcas de aviso, sprites, barras/tiros, flash, elementos). O atlas das folhas é montado por região na primeira vez que o tipo nasce (`atlas_inimigos.gd`).
- **Feito:** limite de vivos por fase: `fase.json` `limite_vivos` 250 (padrão) e `limite_vivos_pror` 500 (prorrogação e Enxame Final), uma fase do `regioes.json` pode ter o seu; vale o menor com o da qualidade (`diretor_hordas.gd > limite_vivos()`). Telegrafia: quem atira pisca 0,4 s antes do tiro (investida e anel já tinham aviso).
- **Medido (4 núcleos E, 500 bichos, mediana de 4 rodadas intercaladas, `docs/PERF_2026-10-10.md`):** alta 25,2 -> 34,0 fps (+35%, pior quadro 65 -> 49 ms, 1083 -> 731 chamadas de desenho); baixa 40,1 -> 37,2 fps, **sem ganho separável do ruído** (597 contra 921 chamadas, mas o gargalo ali é a lógica). A máquina estava carregada por outras sessões (Blender, outros Godots): só contei rodadas com carga < ~22%. `0xF` aqui é 2 núcleos P com hyper-threading (95 fps), não simula PC fraco; usei `0xF0` (E).
- **Visual:** conferi com uma vitrine temporária (48 monstros de todos os tipos da região, tempo congelado, estados misturados, uma captura de cada versão e diferença pixel a pixel) em 5 regiões + vírus + Baixa: monstros idênticos (sombra, flash, espelho, vistas, aura, barra). Imagens lado a lado em `docs/imagens/marco3_*`. `--print_tela` não serve de comparação (carta de nível aparece no meio).
- **Testes:** novo `testes/desenho_lote.tscn`; as 49 cenas passaram, robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40` exit 0 sem SCRIPT ERROR. Nenhum teste antigo precisou mudar.
- **Pendente / olho humano (PC do Breno):** F3 na Release nova com 500 bichos e a GPU dele (shader com `varying flat` e `INSTANCE_CUSTOM`: só testei Intel e headless; se um monstro sumir ou vier com o recorte trocado, é isso). Decidir se 250 vivos na alta nas fases normais é o equilíbrio certo (o bench não passa pelo diretor, então o efeito do limite em partida real não foi medido). A #127 fica aberta até o Breno confirmar.
- Assinado: Claude do Alisson (notebook)

## 2026-10-10 · Claude do Alisson (notebook) · direção visual 2.5D confirmada (fase V0, preparo)
- **Decisão do Alisson:** o jogo segue a direção visual 2.5D da imagem de referência (`docs/imagens/referencia_2_5d.webp`). Ela substitui a ideia de chibi estilo Tiny RPG da #132 e fecha a #145, que agora é 2.5D com luz e relevo.
- **Feito (V0):**
  - `docs/visual_2_5d/README.md` com as regras e as fases V1 a V6 encaixadas nos marcos;
  - análise da referência por 3 agentes: `hud_menus.md` (layout medido em %, molduras, fontes, tema no Godot), `mundo.md` (escala, câmera, ~15 fontes de luz, efeitos, custo por perfil) e `lacunas.md` (o que muda em cada sistema, com o tamanho do trabalho e um rascunho de issue por fase);
  - `paleta.json` e a imagem `docs/imagens/comparacao_atual_vs_2_5d.png`.
- **Recomendações da análise (a decidir):** mundo em 960x540 com herói menor (~32x44, mais detalhe por pixel); câmera mais de cima nos sprites (~45° em vez de 32°); luz fixa do cenário assada e poucas luzes dinâmicas; relevo (normal map) só em herói e elite, e só depois de gerar os sprites sem sombra pintada; HUD em resolução nativa com molduras 9-patch e uma fonte lisa no lugar da pixelada.
- **Próximo:** V1 (escala, câmera e HUD novo), depois da aba Gráficos (#150) e da 2ª rodada da luz. Perguntas fechadas ao Breno na issue-épico.

## 2026-10-10 · Claude do Alisson (notebook) · protótipo da cara nova: 45 graus, escala nova e luz com relevo (#152, V1+V2)
- **Feito (isolado, PR em rascunho):** `jogos/hordas/prototipos/cara_nova/` com o gerador `gerar_cara_nova.py` (patch só em memória; `pixel3d`, `hazaki`, `monstros`, `horror` e `floresta` intactos) que gera, por sprite e no mesmo enquadramento, **albedo** sem sombra assada, **normal map** (convenção do #148) e **emissão** (olhos e chamas). Câmera a 45 graus. Hazaki (8 direções x parado e 4 quadros de andar, quadro 32x44) e 5 monstros da Floresta (cão de ossos, aranha tecelã, espantalho, lobo sombrio, cavaleiro oco), vistas de frente e 3/4. Cena `projeto/prototipos/cara_nova.tscn` em 960x540 com chão e árvores da Floresta, `CanvasModulate` `#1c2a24`, 6 `PointLight2D` e ~25 monstros. Nada em `main.gd`, `arena.gd`, `assets/` ou `dados/` foi tocado.
- **Achado de escala:** a arte do Hazaki velho tem só **44 px de altura** dentro do quadro de 60 (16 px de margem). Em 960x540 isso já dá 8,1%, igual à referência; com 45 graus e `PPU` 24,5 o herói sai com 39 px (7,2%). A "redução a 0,73x" do `mundo.md` não é necessária (deixaria o herói com ~29 px): o que encolhe é o quadro (44x60 para 32x44).
- **Resultado:** com albedo chapado o normal map **aparece** (print `prints/prototipo_cara_nova_com_vs_sem_normal.png`): cada bicho acende de um lado pela luz mais próxima e escurece do outro; a causa do efeito sutil do #148 era a sombra pintada na cor. Olhos acesos leem bem no escuro. Luz com normal é mais escura (N·L = altura/distância): precisou de alturas de luz de 45 a 60 px.
- **fps (Iris Xe, 960x540, sem V-Sync, mediana de 3):** ~500 a 600 com 26 sprites e ~230 com 251, quase igual de 1 a 6 luzes e com ou sem normal (máquina com ~90% de CPU por outros testes: ruído de até 25%; ordem de grandeza). Não substitui o teste no i5-3470.
- **Pendente / olho humano:** o Alisson e o Breno decidirem se o clima serve. Perto da referência na luz colorida e nos olhos; **longe** em densidade de bichos, vegetação saturada, efeitos e portal (V3 e V5). Cavaleiro de aço e aranha viram silhueta fora das poças de luz. Os olhos precisam de camada aditiva fora do `CanvasModulate` (ver `LEIA-ME.md`); a horda é MultiMesh e o protótipo usa `Sprite2D`.
- **Próximo (se aprovado):** aplicar no gerador real o que está na seção "O que muda" do `LEIA-ME.md` (câmera 45, `PPU`, quadros, albedo, normal, emissão), regenerar heróis e monstros e ligar a luz com os limites de `qualidade.json`.
## 2026-10-11 · Claude do Alisson (notebook) · aba Gráficos (#150): tela pronta contra dublê, PR em rascunho
- **Feito:** `projeto/scripts/hordas/tela_graficos.gd` + `projeto/cenas/tela_graficos.tscn` (tema `tema_hud.tres`): perfil no topo (Baixo, Médio, Alto, Personalizado) e "Detectar automaticamente"; seções CPU e GPU com controle deslizante, menu ou sim/não; linha de ajuda com etiqueta de peso (leve, médio, pesado); rolagem; fps ao vivo. O item "Gráficos: perfil, CPU e GPU" fica no topo das Opções (`tela_opcoes.gd`) e abre a aba por cima; ao fechar, as Opções voltam. Modo `--print_tela=graficos --perfil=baixo|medio|alto` no `main.gd`.
- **Dependência:** a tela só usa o contrato da API (`g`, `g_definir`, `g_perfil`, `g_aplicar_perfil`, `g_detectar`, `g_opcoes`, sinal `graficos_mudou`), pela variável `api` (padrão: o `Config`). Enquanto `func g_definir` não estiver na main, os testes usam o dublê `projeto/testes/graficos_api_falsa.gd` com `projeto/testes/graficos_exemplo.json`. Nada disso vai para `scripts/` nem `dados/`. A aba só funciona no jogo depois do PR `graficos-dados`.
- **Testes:** `testes/tela_graficos.tscn` passou (montagem, perfil, personalizado, controles, detectar, rolagem, mouse, Esc, sinal solto ao sair). Bateria das 52 cenas de `testes/` (sem `bench_`): 51 com `falhas=0`; `transicao` falhou uma vez por tempo de desenho e passou sozinha. Robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40`: sem erro de script. Os avisos de `InputMap` em alguns testes também existem na `origin/main`.
- **Prints:** `docs/imagens/graficos_baixo.png`, `graficos_medio.png`, `graficos_alto.png` (e `_gpu`, com a lista rolada até a GPU) e `graficos_opcoes_item.png`. São do dublê, não da cena do jogo.
- **Pendente:** (1) API na main (PR `graficos-dados`) e então o PR sai de rascunho; (2) prints da mesma cena do jogo nos três perfis, que precisam da API; (3) tirar o grupo antigo "Gráfico" das Opções quando a API entrar (o `ITENS` de `config.gd` não foi mexido); (4) olho humano no PC fraco do Breno.
- **Recado:** `Config.ITENS` virou `_itens` dentro de `tela_opcoes.gd` (a lista com o item novo no topo). Quem mexer nas Opções precisa saber disso.
- Assinado: Claude do Alisson (notebook)

## 2026-10-11 · Claude do Alisson (notebook) · aba Gráficos (#150): API real integrada, PR #157 pronto
- **Feito:** a API de gráficos (PR #155) entrou na main e a tela usa a API real. O dublê saiu (`testes/graficos_api_falsa.gd` e o json de exemplo). Sliders mostram a unidade do `graficos.json` (`%` e `s`); menu com número compara por valor (75 e 75.0 são o mesmo). Os prints da aba usam `g_perfil_temporario`, então não gravam nas opções do jogador.
- **Testes:** `testes/tela_graficos.tscn` contra a API real: devolve o perfil e as opções como estavam no fim. Bateria das 52 cenas de `testes/` (sem `bench_`): 52 com código de saída 0, sem falha nem erro de script. Robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40`: ok.
- **Prints:** `docs/imagens/graficos_{baixo,medio,alto}.png` (aba) e `graficos_cena_{baixo,medio,alto}.png` (cena do jogo com `--print_tela=hazaki --equip --estresse=250 --semente=7 --perfil=...`).
- **Opções:** sobram 3 itens do grupo "Gráfico" fora da aba: Tela cheia (F11), Baixar a qualidade se travar e Mostrar FPS. Nenhum repete uma opção da aba. Decidir se ficam ou se vão para a aba (`config.gd` não foi mexido).
- **Pendente:** CI e merge do #157; olho humano no PC fraco do Breno (perfil Baixo).
## 2026-10-11 · Claude do Alisson (notebook) · arrumação de tela e testes instáveis (E1, issue #152)
- **Feito (tela, conferido com print pelo viewport, antes e depois):** título sem "Protótipo" e com "esquiva" no lugar de "dash"; a dica da pausa também; a abertura da fase (layer 7) cobria o véu da pausa, e agora ela some enquanto a pausa estiver aberta (e o HUD volta ao estado de antes ao retomar); banner "Conjunto … completo!" subiu para y=44 (sem cobrir o herói); nome da arma na escolha de herói quebra em 2 linhas ("Adaga de Arrem…" sumiu); no preparo o subtítulo virou "Comida  ocupa 1 espaço" e a largura ficou em 240 px.
- **Feito (escuridão, fase de horror):** a luz deixou de ser em 6 degraus com pontilhado Bayer (uma grade de pontos no chão). Agora é contínua, com a mesma força e os mesmos raios. Medido na Ponte das Almas: a linha de pixels passou de 40,36,36,36,40,37… para 34,34,34,35,35,35,36…
- **Feito (pisos, a causa principal):** o pontilhado estava gravado nas texturas de chão (`pixelar(pontilhado=…)` em `cenarios.py` e `loja.py`). Agora 0 nos pisos e nas paredes da loja. Regenerei os pisos de todas as regiões, variantes e loja com o Blender 4.5 (`blender -b -P cenarios.py -- piso`, depois `loja.py`). A opção `-- piso` foi adicionada para não refazer os enfeites. Só os `piso.png` (e `parede.png` da loja) mudaram de conteúdo.
- **Feito (testes instáveis):**
  - `dragao`/`transformacao`: sem robô (ele pegava armas nas esperas); a transformação é disparada pelo teste.
  - `transicao`: mede a mediana do desenho da cortina, não a média (a média subia com quadros engolidos pelo SO). Limite de 1000 µs mantido.
  - `criacao`: usa o próprio arquivo de save desde o início.
  - `esquiva` e `mira`: passam a andar o tempo simulado (passos fixos de 1/60 s, arena com `_process` manual). Antes dependiam do relógio de parede, e sob carga falhavam (`esquiva` 3 de 3 na main; `mira` 1 de 4). Agora `esquiva` passou 5 de 5 sob carga e `mira` 5 de 5.
  - `status`/`esquiva`: não reproduzi o travamento (5 de 5 cada, 3 a 10 s). Coloquei um vigia de 100 s de relógio real: se um caminho não chegar ao `quit()`, o teste falha em vez de ficar vivo.
  - `elementos`, `abertura`, `equipamentos`, `regras_armas`: 5 rodadas com 4 em paralelo, 20 execuções, todas `falhas=0`.
- **Números:** cenas `testes/*.tscn` (51, sem `bench_*`), 2 rodadas com 3 em paralelo: 101 de 102 ok. A falha foi `mira` na rodada 1, antes da troca para tempo simulado. Robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40`: código 0, zero SCRIPT ERROR.
- **Pendente:**
  - `regras_armas` leva 113 s a 400 s localmente (no CI passou em menos de 120 s). Não investiguei a causa.
  - `ortografia.py` não rodou aqui (sem Python utilizável nesta máquina); ele roda no CI.
  - `gdformat` não rodou (fica para o fechamento da etapa).
  - Olho humano: conferir a textura de piso nova na máquina de testes do Breno.
- Assinado: Claude do Alisson (notebook)
## 2026-10-11 · Claude do Alisson (notebook) · CI mais rápido (E1, issue #152)
- **Medido antes (run 38096771596, `ci.yml`, job `testes`):** 8m17s no total. Baixar o Godot: ~2 s (já vinha do cache). `--import` (2x): ~22 s. Rodar as 51 cenas em sequência: ~7m44s (quase tudo está aqui).
- **Feito:** `ferramentas/testes_ci.sh` roda as cenas 4 por vez (`xargs -P 4`), com `timeout 120` por cena e um log por cena. O critério de falha não mudou (`SCRIPT ERROR` ou falta de `falhas=0`). `bench_*` continuam fora. `criacao` e `criacao2` vão na mesma unidade, em sequência (gravam o mesmo arquivo). No fim: cenas, rodadas, ok, falhas e tempo; falha se a contagem não bater.
- **Não mexi:** o passo do Godot (já tinha cache), o `--import` e o workflow de Release (gatilhos e jobs iguais). Não fiz cache da pasta `.godot`: o import leva ~22 s e a chave mudaria a cada commit, então o ganho seria pequeno.
- **Checado:** sintaxe do script, YAML do `ci.yml` e um teste com Godot falso (51 cenas, uma com SCRIPT ERROR, exit 1). Não há Godot no notebook: a prova de verdade é o CI do PR.
- **Pendente:** rodar o CI do PR e comparar o tempo com o de cima; mesclar só com tudo verde.
- Assinado: Claude do Alisson (notebook)
- **Depois (PR #154, run 38103995863, mesmo `ci.yml` com o script):** job `testes` 2m31s (de 8m17s, ~70% a menos); o passo das cenas levou 125 s. Contagem: 51 cenas, 51 rodadas, 51 ok, 0 falhas. `gdlint` e `ortografia` verdes. Uma rodada só: se aparecer cena instável com 4 em paralelo, o `P` do `ci.yml` (padrão 4) é o primeiro ajuste.
- **Release:** não foi alterado (gatilhos e jobs iguais); o próximo push na `main` (o merge deste PR) roda o export e a publicação como sempre.

## 2026-10-11 · Claude do Alisson (notebook) · aba Gráficos: dados e ligações (#150, E1)
- **Feito:** `dados/graficos.json` com as 15 opções (CPU: máximo de inimigos, partículas, cálculo dos monstros, detalhe longe da câmera, tempo dos restos; GPU: luz com relevo, sombras, brilhos e halos, névoa, vinheta, efeitos das armas, tremor e clarões, escala de render, limite de fps, V-Sync) e os 3 perfis. Médio e Alto mantêm os números de `qualidade.json` (que saiu); Baixo é o perfil do i5-3470.
- **API em `config.gd`:** `Config.g(chave)`, `g_definir` (vira personalizado), `g_perfil`, `g_aplicar_perfil`, `g_perfil_temporario` (só memória, para teste), `g_detectar`, `g_opcoes`, `recarregar` e o sinal `graficos_mudou`. Salva na seção `[graficos]` de `opcoes.cfg`. Migra a "Qualidade gráfica" antiga uma vez.
- **Saíram do ITENS:** qualidade, vsync, fps_max e vinheta. A tela nova da aba deve trazer todas. `qualidade_auto` ficou (baixa de perfil se fps < 40 por 8 s; em personalizado não faz nada).
- **Pendente:** `escala_render` é salva mas ainda não age. `content_scale_factor` do viewport raiz muda a área visível (zoom), não a resolução, então não serve; falta um SubViewport com a cena do jogo. `luz_relevo` só guarda o valor (Etapa 3). A frequência de "alvo" não tem controle próprio: só a separação entra no `calculo_monstros`.
- **Testes:** novo `testes/graficos.tscn` (perfis batem com os números de hoje, personalizado, salvar e carregar, detectar, migração, fatores do jogo). 50 de 52 cenas limpas; `transicao` (tempo) passa sozinha e `mapa` passa sozinha (no lote deu saída vazia). Robô `--bot --heroi=hazaki --semente=7 --rapido=3 --sair=40` exit 0, sem SCRIPT ERROR.
- **Recado para o Claude do Breno:** a tela (outro agente, E2) precisa ler `Config.g_opcoes()` e `g_perfil()`. Olho humano pendente: prints da mesma cena em Baixo, Médio e Alto, e fps real no i5-3470.

## 2026-10-11 · Claude do Alisson (notebook) · formatação geral do GDScript (fecha a #124)
- `gdformat -l 160` aplicado em `jogos/hordas/projeto/scripts` e `testes` (146 arquivos, só formatação, nenhuma mudança de lógica). Limite de 160 escolhido medindo o tamanho da mudança: com 100 (o padrão) seriam +12.600 linhas e as linhas longas com comentário, que são o estilo do projeto, ficariam todas quebradas; com 160, +3.700.
- O `jogos/hordas/formatar.sh` e o CI usam o mesmo `-l 160`, e o CI agora **reprova** código fora do padrão (antes só avisava). Para corrigir: `jogos/hordas/formatar.sh` (precisa de `pip install "gdtoolkit==4.*"`).
- Verificação: `--import` sem erro, bateria completa 52 de 53 (só `transformacao` falhou rodando em paralelo; sozinha passa 3 de 3, então ainda é instável sob carga) e robô de 40 s sem SCRIPT ERROR.
- **Pendente:** `transformacao` ainda instável com carga; o `gdlint` segue só como aviso.

## 2026-10-11 (noite): protótipo 2.5D montado, fim do auto-battle, sem marca do Godot

**Feito (na `main`):**
- #163 e #165 (parte de #162): ícone nativo da janela, créditos sem a marca do Godot (licença MIT só em texto) e tela de entrada com arte própria (`assets/icone/entrada.png`, gerada por `fonte_arte/gerar_entrada.py` a partir da arte do Alisson). Falta alguém confirmar numa build real: a tela de entrada e o ícone da barra de tarefas.
- #164: opção **Sombras** (Simples, Suaves, Detalhadas) na aba Gráficos, amarrada aos perfis. Ela é gravada já e age quando a luz nova entrar.
- #166 (fecha #161): **fim do auto-battle.** O golpe principal sai no clique esquerdo ou no gatilho direito, e as armas de carta continuam automáticas. Ficou um campo `disparo` em `armas.json` e o teste `ataque_clique`.

**Protótipo (PR #156, rascunho, branch `alisson/prototipo-cara-nova`):**
- **Sombras em tempo real:** cisalhamento a partir dos pés (sem rotação), soma ponderada das luzes e suavização no tempo, nos modos baixa, média e alta. O teste é `prototipos/teste_sombra_cara_nova.gd`.
- **Cenário novo:** 28 objetos feitos no imagegen pelo Alisson e recortados por `prototipos/cara_nova/objetos/gerar_objetos.py`, mais decalques de chão (`decalques/gerar_decalques.py`: círculo ritual, trilhas, raízes e detalhes) e chão procedural (`piso/gerar_piso.py`). Torii, braseiro e fogueira têm fogo em partículas e luz.
- **Apresentação "sharp bilinear":** a cena vai num SubViewport de 960x540. Isso resolve a distorção de pixel em escala fracionária. **Leve isso para o jogo na Etapa 2.**
- **fps na Iris Xe** (251 sprites): 281 sem sombra, 190 na média e 156 na alta. Caiu bastante com as ~10 luzes, os ~90 decalques e o SubViewport. O i5-3470 ainda não foi medido.
- **Atalhos de teste no notebook:** `%LOCALAPPDATA%\KIKIU-teste\kikiu_teste.ps1`, com o "KIKIU (teste)" (Release mais nova) e o "KIKIU protótipo 2.5D" (cena da branch).

**Pendente:**
- O teste `transformacao` é instável sob carga.
- A `escala_render` ainda não age; entra na Etapa 2 junto com o SubViewport.
- Falta decidir as 3 opções antigas que sobraram em Opções.
- O perfil Baixo precisa ser medido no i5.
- O protótipo destoa da referência em três pontos: falta água e fundo de floresta, os bichos parecem pequenos perto do cenário, e a cena está um pouco escura.

**Próximo:**
- O Alisson aprovar o protótipo montado; aí começa a Etapa 2 (960x540, câmera, HUD e o sharp bilinear no jogo).
- Ideias para depois: vento nas copas e na grama, e variações de cor por região a partir dos 28 objetos.

_Claude do Alisson (notebook)_

## 2026-10-11 (noite, 2): v2 nasce na `main`

**Feito:**
- **#156:** protótipo mesclado. **#168:** a v1 fica pausada (regra no `CLAUDE.md`).
- **#169:** `KIKIU.exe -- --prototipo`, `-- --v2` e `-- --cena=res://...` abrem a cena no lugar do menu. O protótipo agora roda no exe: os sprites foram para `projeto/prototipos/cara_nova/sprites` e tudo é lido por `res://`.
- **#170:** colisão da v2 (`v2/colisao.gd`, com o campo `colisao` no `prototipos/objetos/cenario.json`).
- **#171:** base jogável em `projeto/v2/`:
  - mapa de 2880x1620 dirigido por `dados/v2_floresta.json`;
  - câmera em pixel inteiro;
  - herói com WASD e mira no mouse;
  - 20 monstros vagando e perseguindo;
  - colisão ligada;
  - luz e sombra só na tela.
  
  O teste é `testes/v2_mundo`. Na Iris Xe, ~190 fps no santuário com sombra média.
- **Atalhos:** no notebook, um só, "KIKIU v2" (baixa a Release e roda `-- --v2`). O Breno recebeu no #153 um prompt para criar o mesmo atalho.

**Pendente:**
- A colisão pode prender em quina côncava (o resolver só olha a posição).
- `luz_relevo` e `escala_render` ainda não agem na v2.
- O i5 não foi medido.

**Próximo (leva 2 da v2):**
- ataque no clique e combate com vida dos monstros;
- horda de verdade (MultiMesh com sombra);
- HUD novo;
- minimapa;
- entrada pelo menu do jogo.

_Claude do Alisson (notebook)_

## 2026-10-11 (madrugada): v2 com o laço completo (levas 2 e 3)

**Feito (na `main`):**
- **#173** HUD.
- **#174** minimapa.
- **#175** colisão das árvores: a pegada cobre a base inteira e a copa fica transparente atrás. A causa era o gerador da pegada, que cobria só 40% da base.
- **#176** combate: katana no clique com combo de 3, impacto, esquiva, **corrida no Shift com fôlego**, XP, nível e ondas.
- **#177** anúncios do HUD (onda, elite, evolução, marcos de combo, barra de chefe, vinheta).
- **#178** **Santuário**, com almas permanentes, melhorias e conquistas. É a tela inicial de `--v2`; o save fica em `user://v2_progresso.cfg`, separado da v1.
- **#179** `transformacao`: o teste falhava localmente porque o HUD da v1 pausava ao perder o foco da janela. Agora, em headless, não pausa.
- **#180** cartas com raridade, 5 golpes secundários automáticos, modificadores da katana, 4 evoluções, elites com baú, mini-chefes aos 3 e 6 min, chefe aos 10 e vitória.

**fps medido na Iris Xe com a máquina livre:**
- santuário: 116–169 fps na sombra média e 138–173 na alta;
- 100 monstros (167 atores na tela): **59–101 fps** na média e 62–96 na alta.

O gargalo é sombra mais atores em Sprite2D. O i5-3470 não foi medido.

**Pendente:**
- **Desempenho da horda:** MultiMesh com sombra em lote e orçamento de luzes. É a prioridade da próxima leva, por causa do i5.
- **Santuário:** os títulos estão em fonte gótica ilegível e a arte de fundo não aparece.
- **Balanço:** a build cheia apaga o nível 1, e a vida dos chefes (1100, 3000 e 9000) é chute.
- **Sobreposição:** a faixa "NÍVEL N!" cobre o título da escolha de carta.
- **`transformacao`:** a volta da forma ainda demora sob carga (espera fixa contra dt limitado).
- **Sons novos** da v2 sem revisão.

**Próximo:**
- leva 4 (desempenho da horda, polimento do Santuário e balanço);
- o Alisson e o Breno jogarem e mandarem o fps (#153).

_Claude do Alisson (notebook)_

## 2026-10-12: v2, leva 4 (retorno do Alisson jogando)

**Feito (na `main`):**
- **#183 oclusão:** buraco raio-x circular em volta do herói nas árvores (no lugar do corte reto) e silhueta do herói quando um monstro cobre ele.
- **#184 interface:**
  - fontes legíveis: Jersey 10 nos títulos e Pixelify Sans no texto, as duas OFL, com créditos (a gótica saiu);
  - carta com estrutura fixa e ícone;
  - o combo e a faixa do HUD somem durante a escolha;
  - o texto de depuração fica desligado e o F3 alterna.
- **#185 e #186 pausa:** o ESC não fecha mais o jogo. A pausa tem 4 itens (Continuar, Ajustes, Voltar ao santuário, Sair). Ajustes tem o Gráficos completo, dirigido por `dados/graficos.json` em `v2/ajustes_graficos.gd`, e o Áudio. O Santuário ganhou o botão Ajustes.
- **#187 desempenho:**
  - horda comum em MultiMesh (`v2/horda.gd`), com sombra em lote;
  - corpo do herói sólido e cerco em anel;
  - grade da colisão cobrindo o mapa todo (antes, o leste e o sul caíam na borda);
  - Baixo com 6 luzes no máximo.

  **fps na Iris Xe com 100 monstros:** média 98 → 143, alta 89 → 132, perfil Baixo 138 → 169.

**Pendente:**
- **i5-3470** sem medição.
- **Sombras dos ~70 objetos do cenário** ainda em nós; seria o próximo ganho.
- **Ajuda de "Sombras"** no Gráficos ainda fala em "Etapa 3" (texto da v1).
- **Opções com \*** que a v2 ainda não lê.
- **`regras_armas` e `transformacao` (v1)** falham sozinhos sob carga local.
- **Balanço** depende de jogar.

_Claude do Alisson (notebook)_

## 2026-10-12: a v2 vira o jogo padrão (#194)

**Feito:**
- `run/main_scene` agora é o santuário da v2 (`v2/altar.tscn`), então o F5 e os exports (Windows, Linux, Web) abrem a v2. Os presets de export não mudaram.
- A v1 abre com `-- --v1` (`KIKIU.exe -- --v1`). Os argumentos de teste dela (`--bot`, `--online`, `--sair`, `--print_tela`, `--cena`, `--prototipo`) também vão direto para a v1 (`ARGS_V1` em `v2/altar.gd`), então os comandos do README e os `testes/online_*.sh` não mudaram.
- O repasse do santuário para a v1 só acontece na primeira abertura do processo (sem laço com `--v2`), e no menu da v1 `--v1` ganha de `--v2`. O `testes/entrada_cenas` cobre isso.

**Pendente:**
- **`esquiva` (v1) instável no CI:** falhou uma vez em "o robô esquiva quando tem vírus colado" e passou ao rodar de novo. A suspeita é que as armas do robô tiram o inimigo do raio em 3 quadros.
## 2026-10-12 (2): os 15 fps do fim da partida, reproduzidos e medidos

**Feito:**
- **`testes/bench_fim.tscn`:** o pior caso do relato (build de nível 70 com semente fixa, relógio em 25 min, 500 bichos, `--limite` para respeitar o teto de vivos). Roda na `main` e nas versões antigas. Tem ainda `--picos=MS`, `--dissecar_hud` e `--sem_hud`.
- **`docs/PERF_2026-10-12.md`:** antes do #140, a Release do #140 e a `main`, em headless e com janela (renderização por software, num contêiner sem placa de vídeo).
  - **Os ~15 fps foram reproduzidos:** a versão de antes, no Baixo, deu 15,7 fps.
  - **O hotfix funciona e continua na `main`:** Baixo de 15,7 para 27 fps com janela, e de 74 para 114–124 em headless; Médio +36%. O ganho vem do teto de vivos por perfil, não de bicho mais barato.
  - **O Alto aos 25 min não mudou:** a prorrogação ainda põe 500 bichos, e quem segura o fps é a qualidade automática (fps < 40 por 8 s).

**Pendente / propostas** (nada aplicado; a v1 está pausada):
- **HUD da v1:** custa ~450–520 chamadas de desenho (mais que a horda no Baixo) e uns 15–20% de fps na janela. A `main` tem picos piores que a Release do hotfix por isso.
- **Teto da prorrogação no Alto** de 500 para 350: decisão do Breno.
- **v2:** o script aguenta 500 (8,8 ms), mas o desenho com luz 2D e mapa de normais cresce com a horda. A proposta é deixar a horda só com a luz do herói e, no Baixo, sem mapa de normais.
- **Falta medir em placa de verdade** (i5-3470 e RX 7600 XT). Os comandos estão no fim do doc.

_Claude do Alisson (nuvem)_

## 2026-10-12 (3) · Claude do Alisson (nuvem) · v2: luz da horda (experimento, não adotado)
- **Pedido:** o Alisson escolheu a proposta C (a horda comum da v2 só com a luz do herói e, no Baixo, sem mapa de normais).
- **Feito e medido:** camadas de luz (`light_mask` e `range_item_cull_mask`) e um shader da horda sem normal. Testes da v2 passaram (`v2_mundo`, `v2_desempenho`, `v2_combate`, `v2_pausa`, `v2_partida`, `v2_oclusao`).
- **Resultado:** +3% de fps no Baixo e +1% no Alto com 500 monstros (3 rodadas, renderização por software), e a horda fica visivelmente mais escura perto das luzes do cenário. **Não entrou na `main`.** O patch está em `/mnt/project-files/perf/v2_luz_horda_experimento.patch`; os números e a análise, no fim de `docs/PERF_2026-10-12.md`.
- **Próximo:** medir o `bench_fim` e o `--medir` da v2 numa placa de verdade (i5-3470 e RX 7600 XT) antes de mexer em luz de novo; o HUD da v1 (proposta A) segue como o maior ganho barato.

_Claude do Alisson (nuvem)_

## 2026-10-12 (4) · Claude do Alisson (nuvem) · teto de 350 bichos na prorrogação, com dano compensando
- **Decisão do Alisson:** a v1 vai ser aposentada (nada de HUD novo nela); a prorrogação e o Enxame Final passam de 500 para **350** vivos e a dificuldade vem do **dano** dos bichos.
- **Feito:** `dados/fase.json`: `limite_vivos_pror` 350 e `limite_vivos_ref` 500. `diretor.mult_dano_teto()` devolve 500/350 (x1,43) na prorrogação e no Enxame Final; `inimigos.criar` e `_mult_tiro` multiplicam o dano por ele. Não depende do perfil de gráficos. Quem já estava vivo quando a prorrogação começou mantém o dano antigo.
- **Testes:** `desenho_lote` ampliado (teto, multiplicador, bug que nasce na prorrogação, tiro, Enxame Final); `prorrogacao`, `regioes`, `mortes` e `esquiva` com falhas=0.
- **Pendente:** o equilíbrio de verdade só se vê jogando a prorrogação; o x1,43 é a conta direta (500/350), ajustar se ficar duro ou fácil. As medições numa placa de verdade estão sendo feitas no notebook do Alisson.

_Claude do Alisson (nuvem)_

## 2026-10-12 (5) · Claude do Alisson (nuvem) · fechamento do PR #195 e decisões do dia
**Decisões do Alisson hoje (para quem pegar a conversa depois):**
- **A v1 será aposentada.** Nada de HUD, desempenho ou recurso novo nela; o foco é a v2 (também no `CLAUDE.md`).
- **Teto de 350 bichos na prorrogação e no Enxame Final**, com o dano dos bichos compensando (x1,43), porque ninguém conta 350 contra 500 de olho e a dificuldade passa a vir do dano.
- **Trabalhar na pasta local, não na nuvem.** Testes de desempenho rodam no notebook dele, nunca no servidor, e com no máximo 2 minutos. Uma sessão do Claude Code roda na pasta `C:\Dev\Breno` (repo em `C:\Dev\Breno\Jogao-gamer`).
- **Luz da horda na v2: não adotada** (+1 a 3% de fps e visual mais escuro); o patch está em `perf/v2_luz_horda_experimento.patch` na pasta compartilhada do projeto.

**Medido no notebook dele** (i5-1345U, Iris Xe, na tomada, janela, sem V-Sync, `testes/bench_fim.tscn`, 6 s por rodada): Alto com 500 bichos 53,8 fps; Baixo com 250 bichos 94,4 fps; v2 com 84 monstros no Baixo 210 fps. A medição de "Alto com 350" ficou inválida (o diretor enchia até 500). O bench já foi corrigido (`--n` limita o diretor), mas a rodada nova ainda não foi feita.

**Pendente / próximo:**
- Rodar o `bench_fim` no Alto com `--limite` e com `--n=350` no notebook (30 s) e acrescentar os números ao fim de `docs/PERF_2026-10-12.md`.
- Medir no i5-3470 e na RX 7600 XT; o HUD da v1 (proposta A) não será feito, porque a v1 sai.
- Jogar a prorrogação para ver se o dano x1,43 está bom (número em `dados/fase.json`: `limite_vivos_pror` e `limite_vivos_ref`).
- Na v2, o teto de vivos é 84 (`v2_combate.json`); antes de subir, medir de novo com o `--medir` da v2 em placa de verdade.

_Claude do Alisson (nuvem)_

## 2026-10-12 (6) · Claude do Alisson (notebook) · mapa Laboratório (WIP) e base para mais mapas
- **Pedido do Alisson:** dois mapas novos na v2, Laboratório e depois Cidade, cada um com assets e texturas próprios, no estilo da floresta. Ele mandou parar no meio do Laboratório e pediu um resumo de continuação: o detalhe está em `jogos/hordas/fonte_arte/mapas_v2/LEIA-ME.md`.
- **Decisão de assets:** nada de pacote de terceiros (regra de `docs/visual_2_5d`). Os objetos saem do **Blender** no mesmo enquadramento do herói (1 m = 32 px, câmera a 45°), com normal map de verdade, e o Python (`fonte_arte/gerar_v2_mapas.py`) vira atlas, colisão, decalques, piso e o JSON do mapa. Os prompts do ChatGPT para folhas de referência (caminho opcional, mais rico) ainda não foram escritos.
- **Feito (branch `claude/v2-mapa-laboratorio`, sem PR):** laboratório jogável de ponta a ponta (24 objetos, piso de aço, 23 decalques, ~370 objetos e ~160 decalques no mapa, luzes de tanque verde, tela ciano, emergência vermelha, criogenia e gerador); seleção de mapa no santuário (`v2/mapas.gd`, botão `< MAPA >`, `--mapa=<id>`); ganchos por dados no `cenario.gd`, `minimapa.gd`, `atmosfera.gd`; `export_presets.cfg` com o filtro dos JSON novos; `testes/v2_mapas.tscn` com falhas=0.
- **Pendente:** bateria completa e `--medir` no notebook, PR do Laboratório (pedir o OK do Alisson antes de mesclar), acabamento da arte, prompts do ChatGPT, a Cidade inteira e a linha na tabela de `v2/LEIA-ME.md`.
- **Próximo:** rodar `ferramentas/testes_ci.sh`, abrir o PR do Laboratório, depois `modelos3d/mapa_cidade.py` e `mapas_v2/def_cidade.py`.
## 2026-10-12 (4) · Claude do Alisson (notebook) · v2: acabamento de produto (marca do Godot, Gráficos, Créditos)
- **Marca do Godot (#162), conferida num exportado de verdade:** exportei o Windows e o Web no notebook e abri o `.exe`. A tela de entrada mostra a arte do K.I.K.I.U, sem o logo do Godot; o ícone do `.exe`, da janela e da barra de tarefas é o escudo; o título da janela é "K.I.K.I.U". No Web, o `index.html` usa a mesma imagem de carregamento, o ícone do jogo e o título "K.I.K.I.U". O Linux não embute ícone no executável (limite do formato).
- **Sobrou um texto legal:** nas propriedades do `.exe`, `LegalCopyright` ainda traz o aviso da licença MIT do Godot. Deixei como está de propósito, porque é obrigação da licença; agora o aviso também está nos créditos da v2 (abaixo).
- **Gráficos da v2:** o menu só mostra as 6 opções que a v2 lê (`LIDAS_NA_V2` em `v2/ajustes_graficos.gd`): partículas, luz com relevo, sombras, tremor e clarões, limite de FPS e V-Sync. Saíram da tela (seguem nos perfis e no `graficos.json`): máximo de inimigos, cálculo dos monstros, detalhe longe da câmera, restos no chão, brilhos e halos, névoa, vinheta, efeitos das armas e escala de renderização. Sem mais `*` nem nota de "sem efeito". O **Tremor e clarões** passou a valer: `camera_mundo.tremer` multiplica a amplitude por 0–100%.
- **Ajuda:** Sombras e Luz com relevo não citam mais a "Etapa 3" da v1; a de Luz com relevo agora descreve o que a v2 faz (Desligada = só as 6 luzes mais perto da tela).
- **Créditos na v2** (antes só a v1 tinha): Ajustes > Créditos (`v2/creditos.gd`), uma linha por crédito e o aviso da licença no rodapé (Godot MIT, fontes OFL, criadores).
- **Santuário:** a dica do rodapé estava encostada nos botões; os botões subiram 4 px e a dica desceu 2 px.
- **Testes:** `v2_pausa` ganhou checagens (só mostra opção lida, tremor 0%/50%, Créditos e aviso do Godot); `v2_pausa`, `v2_meta`, `v2_mundo`, `v2_combate`, `v2_esc`, `v2_hud`, `graficos`, `tela_graficos` e `entrada_cenas` com 0 falhas; `gdformat --check` limpo. Prints com janela: `pausa_graficos`, `pausa_creditos` e `santuario_com_almas` (gerados por `v2_pausa` e `v2_meta` com `--fotos`).

**Pendente / recados:**
- **Música:** o #198 entrou na `main` enquanto este PR estava aberto, com o crédito CC BY no rodapé de Ajustes > Áudio. Mantive o dele e acrescentei a linha "Música" (Kevin MacLeod, CC BY 4.0) em `v2/creditos.gd`. Quem trouxer outro recurso de terceiros acrescenta a linha lá.
- **Opções de CPU e escala de render** voltam ao menu só quando a v2 passar a lê-las (o teto de vivos da v2 vem de `dados/v2_combate.json`, não do slider).
- **Santuário:** "Pesadelo" e "Rastro de katana" aparecem como "(sem efeito ainda)" (`efeito: pendente` em `v2_meta.json`); decisão de conteúdo do Breno.
- **Abertura:** do clique no `.exe` até a primeira imagem passaram ~3 s no notebook (uma medição só; o PCK embutido tem 120 MB) e a arte de entrada fica ~0,3 s na tela.
- **#162** fica pronta para fechar com este PR; falta o Alisson olhar a tela de entrada numa build.
## 2026-10-12 (6) · Claude do Alisson (notebook) · música na v2
- **Feito:** a v2 agora tem trilha. **Nenhuma faixa nova**: reaproveitei as do Kevin MacLeod (CC BY 4.0) que já estavam no repositório com a licença registrada (`docs/LICENCAS_AUDIO.md`, PR #52). Santuário = `menu` (Oppressive Gloom), partida = `minijogo_tenso` (Crypto), chefe = `chefe` (Ignosi), resultado = `fim` (Wounded). A escolha mora em `dados/v2_musica.json` (momento → arquivo) e quem decide é `v2/trilha.gd`: santuário toca a dele; a partida liga os sinais do mundo (chefe aparece → faixa do chefe; mini-chefe cai → volta a da partida; chefe final cai com a vitória em curso → a do chefe segue até o resultado; fim da partida → resultado; reiniciar → partida), tudo com o crossfade que o `Som` já tinha. Medir e fotografar ficam mudos.
- **Bus de Música:** `Som` (autoload, `scripts/hordas/som.gd`) cria o bus `Musica` (saída no Master) e as duas faixas tocam nele. O volume do slider Música (Ajustes > Áudio, na pausa e no santuário) agora vive no bus, e não mais nos players: `Config.definir` grava `musica` em `opcoes.cfg` (persistência que já existia) e `Som.atualizar_volume` põe o dB no bus; 0 dá mute. Os players ficaram só com o fade. Efeitos continuam no Master. Isso mexe no `Som` compartilhado: a v1 ganha o mesmo bus sem mudar de comportamento, e o `testes/cartas_comp.gd` (crossfade da v1) passou a conferir o volume no bus.
- **Crédito CC BY dentro do jogo:** a v1 tinha na tela de Créditos, que a v2 (jogo padrão) não alcança; o rodapé da tela Ajustes > Áudio da pausa agora mostra "Música: Kevin MacLeod (incompetech.com) / Licença Creative Commons Atribuição 4.0". `docs/LICENCAS_AUDIO.md` ganhou a tabela momento → faixa da v2.
- **Testes:** `testes/v2_musica.tscn` novo (`v2_musica falhas=0`): bus e saída, cada faixa do JSON existe e está em `LICENCAS_AUDIO.md`, as transições (santuário, partida, chefe, mini-chefe que cai, chefe final, resultado e reiniciar), pico no bus acima de -60 dB (som de verdade passando) e sumindo com o slider em 0, volume salvo voltando ao reabrir as opções. Também passam `cartas_comp`, `opcoes`, `regioes` e todos os `v2_*` (pausa, esc, partida, mundo, combate, desempenho, colisão, hud, meta, minimapa, oclusão, árvores, cartas_espera). Conferido no notebook com o driver WASAPI real: bus `Musica` em -4,4 dB (60%), pico -20 dB chegando ao Master.
- **O que eu NÃO consegui conferir:** ouvir. Pico no bus prova que o som sai pelo caminho certo, mas se as faixas casam com o clima, se o volume de cada uma está parelho e se o crossfade santuário → partida → chefe soa bem é ouvido do Alisson.
- **Pendente / ideias:** `minijogo_tenso_b` (Giant Wyrm) e `horror` ficaram de fora (o plano era só santuário, partida e chefe); o JSON aceita trocar ou alternar por edição. CC0 de preferência: se o Alisson quiser trocar alguma por CC0, é achar o `.ogg`, registrar a linha em `LICENCAS_AUDIO.md` e mudar o JSON (o teste confere a licença).

_Claude do Alisson (notebook)_

## 2026-10-12 (7) · Claude (subagente, PC, a pedido do Breno) · mapa Cidade (etapa 2)
- **Feito:** o mapa Cidade está montado sobre a etapa 1 (objetos e piso do Blender). `mapas_v2/def_cidade.py` põe 177 objetos numa grade de 5 x 4 quarteirões (prédio no lote, pátio com contêiner, praça com ponto de ônibus e fogueira, ruína e lote vazio), 147 decalques, 85 luzes (53 presas aos objetos, 32 soltas) e 8 zonas de monstro. O herói nasce no cruzamento central. Registro: `v2/mapas.gd` (linha `cidade`, botão `< MAPA >` do santuário), `dados/v2_cidade.json` e `assets/v2/mapas/cidade/`.
- **Ruas:** o eixo das ruas fica livre; carro, poste e semáforo ficam no meio-fio. Conferido com grade de 4 px e as elipses do JSON: 90,6% da área andável livre, e ruas e zonas de monstro na mesma região conectada. `v2_mapas falhas=0`, com teste novo de rua (300 px pelo leste do cruzamento sem travar).
- **Dependência:** a branch inclui o laboratório (commit 468968b, merge de `claude/v2-mapa-laboratorio`). **Mesclar o PR da cidade depois do #204.**
- **Não medido:** fps (85 luzes no mapa). Antes do merge, medir `--medir --mapa=cidade` no Médio e no Alto.
- **Pendente:** o OK do Alisson e a bateria completa (`ferramentas/testes_ci.sh`), que não rodei por causa da CPU compartilhada.
- **Para o Claude do Alisson:** se o #204 mudar `mapas.gd`, `cenario.gd` ou `gerar_v2_mapas.py`, a branch da cidade precisa de merge da `main` antes do PR.

_Claude (subagente, PC, a pedido do Breno)_
## 2026-10-12 (7) · Claude do Alisson (notebook) · sons CC0 do Kenney na v2
- **Feito:** os sons de combate e de interface da v2 saem de Kenney (CC0 1.0), no lugar dos sintetizados. São 21 WAV em `assets/audio/v2/`: 15 trocados com os mesmos nomes (`audio.gd` não mudou), 2 do cursor e do confirmar do santuário e 4 novos para escudo e Ruptura. Em `v2/pausa.gd`, o clique do santuário passou a tocar os `ui_*` pelo `AudioV2`, e não mais pelo `Som.ui`, que é da v1 e segue sintetizado. Registros: `docs/LICENCAS_ARTE.md` (uma linha por arquivo) e `docs/LICENCAS_AUDIO.md` (tabela, e como refazer).
- **Volume:** silêncios das pontas cortados, WAV mono 44,1 kHz, normalizados para RMS -18 dBFS com teto de pico de -1 dBFS. Nenhum clipe. Os impactos ficam em geral mais baixos que os sintetizados (pico igual, corpo menor): se faltar peso, ajuste o `vol_db` da chamada.
- **Testes:** `v2_partida`, `v2_pausa` e `v2_musica` com `falhas=0` e sem `SCRIPT ERROR`. Checagem pontual fora do repo: os WAV novos carregam como `AudioStreamWAV` e o clique do santuário toca 2 sons pelo `AudioV2`.
- **Pendente / recados:** `escudo_bloqueio`, `escudo_perfeito`, `ruptura_carga` e `ruptura_solta` estão copiados e registrados, mas sem ligação: as mecânicas estão em `alisson/v2-ruptura`. O chefe segue sintetizado (nenhum gongo bom nos três pacotes, só sinos curtos). Os demais sintetizados da v2 (`aviso`, `elite`, `onda`, `fogo`, `raio`, `corvo`, `runa`, `runa_poe`, `ofego`, `derrota`, `vitoria`) ficam para outra etapa. **Não consegui ouvir:** se os sons casam com o dark fantasy e se o volume está parelho é conferência do Alisson. O gerador sintetizado segue como reserva, mas rodar o script sobrescreve esses WAV.

_Claude do Alisson (notebook)_

## 2026-10-12 (7) · Claude do Alisson (PC) · v2: menu principal (título antes do santuário)
- **Feito:** a cena principal da v2 agora é o título, `v2/menu_principal.tscn` (antes abria no santuário). Logo K.I.K.I.U em Jersey 10 (112 px) sobre o fundo `assets/titulo/fundo.png`, com Jogar (vai ao santuário), Ajustes (o submenu da pausa: Gráficos e Áudio), Créditos (a tela de Créditos da pausa) e Sair (pede confirmação). Mouse, teclado e controle; ESC e Start abrem "Sair?" com "Não" marcado, sem fechar o jogo de surpresa. O título toca a faixa do santuário (`menu`), que não recomeça quando o santuário abre.
- **Fundo:** `jogos/hordas/fonte_arte/gerar_fundo_titulo.py` gera o fundo a partir de `entrada_fonte.webp` (960x540, 48 cores) sem o "K.I.K.I.U" que `gerar_entrada.py` desenha por cima. Não havia arte de título pronta; as capturas de partida (com HUD) não serviram. Registrado em `docs/LICENCAS_ARTE.md`. O prompt para uma arte de título nova está no corpo do PR da branch `alisson/v2-menu-principal`.
- **Controle:** o InputMap da v2 não tinha o A em `ui_accept` nem o B em `ui_cancel` (só o D-pad e o analógico). `v2/entrada.gd` (`garantir()`) acrescenta os dois quando faltam, então o "Enter ou A confirma" do santuário passa a valer. A v1 não chama `garantir()`.
- **Pausa (`v2/pausa.gd`):** novo sinal `fechou` (o título devolve o foco ao botão que abriu) e `abrir_creditos()`, em que o Voltar fecha direto sem passar por Ajustes. O resto da pausa não muda.
- **Santuário:** o mesmo. A checagem de "argumento da v1" virou `Altar.pede_v1_na_entrada()` (mesmo código), chamada pelo título e pelo santuário.
- **Testes:** `testes/v2_menu` novo (`v2_menu falhas=0`: foco por teclado, controle e mouse; Jogar por Enter, A e clique; ESC, Start e B em "Sair?"; Ajustes e Créditos abrem e voltam com o foco; só o Sim sai). `entrada_cenas` confere a nova cena principal. Também passam `v2_pausa`, `v2_musica`, `v2_meta`, `v2_esc` e `v2_cartas_espera`.
- **Pendente:** a tela ainda não foi vista numa build exportada (o print do viewport está em `docs/prints/v2_menu_principal.png`). Conferir foco, leitura e controle no PC e no notebook. A arte final sai do prompt do PR no GPT: quando chegar, troca `assets/titulo/fundo.png` e registra a licença. O santuário não ganhou "voltar ao título" (não foi pedido).
## 2026-10-12 (7) · Claude do Alisson (PC) · v2: esconde cartas sem efeito até ganharem efeito
- **Feito:** Pesadelo (modo, recompensa de "Derrote o chefe") e Rastro de katana (visual, recompensa de "Combo de cinquenta") ganharam `oculta_ate_ter_efeito: true` em `dados/v2_meta.json`. Quem lê a flag: o santuário (a melhoria some; a recompensa some do texto da conquista, que segue na lista), o card SUA BUILD (seção santuário) e o sorteio (`v2/cartas.gd`, `_disponivel`, para cartas de `dados/v2_cartas.json`; nenhuma marcada hoje). Os dados ficam. Helpers em `v2/meta.gd`: `oculto()`, `melhorias_visiveis()`, `item_da_recompensa()`.
- **Corrigi o `_ajuda` de `v2_meta.json`:** dizia que raridade, rolagem e almas não tinham efeito. Têm (`cartas.gd` usa raridade e rolagem; `meta.gd` credita almas), então seguem visíveis.
- **Testes:** `v2_meta` (seção 6b), `v2_partida` (bloco 2b), `v2_status` e `v2_cartas_espera` com `falhas=0`, antes e depois. Foto com janela do santuário conferida: "Combo de cinquenta" mostra só "Cumprida.".
- **Pendente / recados:** a issue "v2: reexibir cartas escondidas quando tiverem efeito" traz a regra (tirar `oculta_ate_ter_efeito` e apagar `efeito: "pendente"`). Para o Claude do Breno: o santuário mostra "Ainda sem efeito" em todo item sem nível, inclusive nos que têm efeito (Passos de caçador, Olho para o raro etc.); se quiser outro texto, é trocar em `v2/altar.gd` (`_atualizar`). PR não mergeado.
## 2026-10-12 - Laboratorio: sombras base, passagens e objetos translucidos (PR #204)
- **Feito:** `mapa.sombra_ambiente` (luz virtual em `sombras.gd`: o laboratorio tem sombra mesmo longe das luzes; a floresta nao muda), `mapa.copas_altura_min` (racks, armarios e tanques ficam translucidos sobre o heroi, generico em `copas.gd`), `v2/passagens.gd` (grade de navegacao com a colisao real: caminho ate cada zona de monstros com corpo comum e largo, sem ilhas, sem beco fino) e checagens em `testes/v2_mapas.gd` para todo mapa (inclui a futura Cidade). O layout do laboratorio ja passava: nenhum objeto precisou mudar.
- **Pendente:** a Cidade (branch do Alisson) herda tudo ao por `sombra_ambiente` no JSON dela; o teste vai acusar objeto que feche passagem.
- **Nao conferi:** o gosto da intensidade da sombra (e 1,1, comp 0,6 no JSON): ajuste visual do Alisson.

## 2026-10-12 - v2: DESIGN.md dos menus (guia visual da UI)
- **Feito:** `jogos/hordas/projeto/v2/DESIGN.md` (144 linhas), extraído do código com `arquivo:linha`: resolução e área segura (a partida corta em COVER), paleta com as duplicações, tipografia pela grade, componentes, comportamento (Esc, trava, foco, sons) e os testes de UI. Uma linha no `CLAUDE.md` manda ler o guia antes de mexer em menu.
- **Pendente (seção 8 do guia):** Spleen 12 px no SUA BUILD e Jersey 28 px no nome longo da carta, fora da grade; `telas.gd:248` diz "ouro da fusão" e a cor é magenta; ouro em 5 valores; XP e fôlego com cores trocadas entre HUD e card; vida em dois vermelhos.
- **Próximo:** juntar as cores da v2 num arquivo só e fazer o `v2_fontes` conferir também o `TAM_NOME_CURTO` e os tamanhos do card.
- **Nao conferi:** nada rodado no Godot (só docs). A branch `origin/alisson/v2-menu-principal` não existe no remoto; há um WIP local (`46b4f87`) que o guia não usa.

_Claude do Alisson (PC)_

## 2026-10-12 - Menu principal: arte nova do GPT e nome K.I.K.I.U (PR #215)
- **Feito:** o nome do jogo no menu, nos testes, no LEIA-ME e neste log é K.I.K.I.U (com pontos). A arte de título nova, gerada no GPT pelo Alisson, está versionada em `jogos/hordas/fonte_arte/fundo_titulo_fonte.webp`. `gerar_fundo_titulo.py` lê dela, reduz para 960x540 com BOX e 48 cores e gera `assets/titulo/fundo.png`. Medido antes: a arte não tem grade de pixel fixa, então BOX e não NEAREST. O logo fica no centro-superior sobre o céu escuro (12,9:1 sem faixa), o menu no centro-inferior, sem cobrir o herói. A faixa escura atrás da dica ficou: sem ela o pior 1% dos pixels cai para 1,06:1 e com ela sobe para 3,34:1. Registro em `docs/LICENCAS_ARTE.md` como arte própria gerada no GPT pelo Alisson.
- **Testes:** `v2_menu`, `entrada_cenas` e `v2_esc` com `falhas=0` (headless). O print `docs/imagens/v2_menu_principal.png` foi refeito com `--fotos` (com janela).
- **Pendente:** olhar o print num monitor real (PC e notebook): a dica é pequena e o print é 1280x720.

_Claude do Breno (PC)_

## 2026-10-13 - v2 Marco 4, parte 1: mapa médio (PR em rascunho)
- **Feito:** mapa `medio` (`dados/v2_medio.json`, terceiro item de `LISTA` em `v2/mapas.gd`, `--mapa=medio`). Mesma arte e colisão da floresta (a grade de colisão é fixa em 2880x1620), herói no santuário (canto oeste), 6 zonas de monstros e uma rota de 8 pontos (~6.900 px em linha reta, ~1 min 30 de caminhada com os desvios). Marcadores no JSON (`marcadores`): 4 baús com relíquia (`bau.gd`, `forcar` 3) e um mini-chefe (`chefe.gd`, marca `mini1`), que nascem uma vez quando o herói chega perto; atalho escondido e portão do chefe só como dados, sem efeito. `v2/mundo.gd` ganhou `_montar_marcadores` e `_checar_marcadores` (sem módulo novo).
- **Testes:** `v2_mapas` com `falhas=0`, incluindo os marcadores (livres, alcançáveis do santuário, rota, baú e mini-chefe no mundo). `v2_mundo` acusa uma falha de luz (`luz fora da tela desligada e dentro ligada`), que também acontece na `main` sem estas mudanças: não é deste PR.
- **Pendente:** atalho e portão ainda não fazem nada (a passagem escondida é geometria a desenhar). O nome "MÉDIO" no botão do santuário é provisório. Falta ver o mapa jogado: `godot --path jogos/hordas/projeto res://v2/mundo.tscn -- --mapa=medio`.
- **Para o Claude do Alisson:** este PR não mexe em arte, `assets/`, `fonte_arte/`, `docs/visual_2_5d/`, `v2/heroi.gd` nem `v2/horda.gd`.

_Claude (PC do Breno, via Remote Control)_
## 2026-10-13 · Codex Luna / Codex (PC) · executor de testes
- **Feito:** preservado o código de saída do timeout/Godot; aprovação exige código 0, falhas=0 e nenhum SCRIPT ERROR. Logs distinguem timeout 124, crash/sinal e falha comum. Mantido o limite de 300 s do regras_armas; import do CI não mudou.
- **Testes:** autoteste_executor com sucesso, código 7 após falhas=0, timeout real abreviado, crash 139, SCRIPT ERROR, saída incompleta, marca inválida e limite de regras_armas: falhas=0. gdformat -l 160 --check scripts testes: 173 arquivos limpos. Sem mudança no jogo; a bateria Godot não foi rodada neste assunto.
- **Pendente / próximo:** CI do PR e integração separada da proteção de Release. Sem alterações nos arquivos v2 dos PRs #201/#214/#217/#219/#220/#222.

_Codex (PC), workflow com agentes Luna_
## 2026-10-13 · Codex Luna (PC) · save seguro da meta-progressão v2
- **Feito:** `v2/meta.gd` grava por temporário validado, mantém `.bak`, recupera de backup e bloqueia gravação sobre save corrompido sem backup. `mapas.gd` usa os mesmos helpers, evitando que a escolha do mapa apague o save. Falhas retornam para compra, escolha de mapa e fim de partida; altar e resultado não anunciam ganhos que não foram salvos. `testes/v2_meta.gd` e `testes/v2_mapas.gd` passaram (`falhas=0`), cobrindo falha de gravação, compra sem persistência, recuperação do backup e corrupção sem backup.
- **Pendente:** integrar a `origin/main` avançada durante este trabalho e conferir os arquivos sobrepostos com os PRs #201, #214, #217, #219, #220 e #222.
## 2026-10-13 · CI da Release exige testes verdes no mesmo SHA
- **Feito:** `ci.yml` pode ser chamado como workflow reutilizável; `release.yml` chama esse CI e `publicar` espera o CI e os dois jobs de exportação. O workflow reutilizável e os `actions/checkout` usam o SHA do evento da Release.
- **Exports:** Linux, Web e Windows mantidos intactos; importação continua com `|| true` por causa do segfault conhecido no encerramento.
- **Verificação:** YAML parseado; dependência de `publicar`, chamada local e caminho do workflow conferidos. Não rodei Godot para evitar concorrência com os testes nas outras branches.
## 2026-10-13 · CI: lint consultivo da v2 e formatação obrigatória
- **Feito:** `gdlint` agora inclui `scripts`, `testes` e `v2` como aviso; `gdformat` é um job separado e obrigatório, com `--check -l 160` nos três diretórios.
- **Formatação:** `v2/creditos.gd` foi ajustado em commit próprio. Os checks de `gdformat` passam para `scripts`, `testes` e `v2` (219 arquivos sem novas alterações).
- **Baseline:** `gdlint` segue consultivo e reporta 5.530 achados em 219 arquivos; saída completa em `C:\Dev\Breno\analise-kikiu\logs-ci\gdlint-baseline.txt`. Logs do formatter também ficam nessa pasta.
- **Verificação:** YAML parseado e estrutura dos jobs/caminhos conferida. Não rodei Godot para evitar concorrência com outras branches.

_Codex Luna (PC)_
## 2026-10-13 · Codex (PC) · guia técnico da v2 e legado
- **Feito:** README do módulo separa v2 disponível (título menu_principal, apresentação 960×540), legado v1 e roadmap. Comandos --bot/--online ficam identificados como legado; tabela de pastas identifica v2 e serviços compartilhados. Corrigido teto legado de prorrogação para 350.
- **Verificação:** caminhos e cena principal conferidos com project.godot e módulos menu_principal/apresentacao/mapas; gdformat scripts/testes limpo na base inicial. Apenas documentação, sem alteração de comportamento; nenhuma cena Godot foi rodada para este assunto.
- **Próximo:** revalidar a documentação e formatação sobre a main atualizada antes do PR.

_Codex (PC), workflow com agentes Luna_


## 2026-10-13 - v2 Marco 4, parte 2: mecânicas de exploração no mapa médio (PR em rascunho, depende da #220)
- **Feito:** as 8 mecânicas no mapa médio, em 4 lotes com commit próprio. Lote A: baú trancado com a chave numa ruína, e relíquia montada com 4 fragmentos. Lote B: duas alavancas que abrem o atalho, e três pilares que precisam ser ativados na ordem da placa para liberar o mini-chefe. Lote C: defesa de ponto (30 s dentro do raio, com ondas de monstros, e uma relíquia), e placas de lore em 3 pontos. Lote D: mercador que troca almas da partida por uma carta, e espinhos com caminho de pedra seguro. Tudo em `v2/mundo.gd`, pelos marcadores do JSON; sem módulo novo, sem objeto criado por quadro (a defesa cria monstros a cada 4 s; os espinhos têm desenho criado uma vez).
- **Decisões:** o "ouro" do mercador são as almas da partida (não há ouro no jogo); as almas gastas saem do `almas_partida`, o que também reduz o que a partida credita. O contador dos fragmentos é o banner da HUD (`FRAGMENTO n/4`), não um painel novo. Os marcadores da rota são ordenados por vizinho mais próximo a partir do santuário.
- **Testes:** `v2_mapas` com `falhas=0` (cobre os quatro lotes: chave, trancado, fragmentos, alavancas, pilares em ordem e fora de ordem, chefe depois dos pilares, placas, defesa, mercador com e sem almas, espinhos dentro e fora do caminho). `v2_meta` e `v2_partida` com `falhas=0`. `v2_mundo` com a mesma falha de luz que já existia na `main` ("luz fora da tela desligada e dentro ligada").
- **Pendente:** (1) as duas alavancas só marcam o estado e anunciam; a passagem física até o portão precisa de geometria (um objeto de colisão que se remove, ou um desenho do atalho). (2) o chão de espinhos e pedra são polígonos simples, sem arte: quem desenha é o Alisson. (3) o nome "MÉDIO" continua provisório. (4) a rota ficou de 6000 a 9000 px em linha reta (medido pelo teste), mas não foi jogada: o tempo real precisa de uma passada no PC.
- **Para testar:** `godot --path jogos/hordas/projeto res://testes/v2_mapas.tscn` (imprime `v2_mapas falhas=0`), e jogar com `godot --path jogos/hordas/projeto res://v2/mundo.tscn -- --mapa=medio`.
- **Para o Claude do Alisson:** este PR não mexe em arte, `assets/`, `fonte_arte/`, `docs/visual_2_5d/`, `v2/heroi.gd` nem `v2/horda.gd`. Os espinhos e a pedra criados em código são placeholders de polígono: se preferir o seu desenho, troca em `v2/mundo.gd` (`_montar_espinhos`).

_Claude (PC do Breno, via Remote Control)_
## 2026-10-13 - Card SUA BUILD pagina os golpes (sem teto)
- **Feito:** o card da v2 (pausa, painel central e HUD) deixou de cortar os golpes quando a build passa do que cabe. Na página visual da pausa e no painel central os golpes ganham páginas: quantos cabem sai da altura da coluna (sem número fixo), a última linha diz "Página X/Y · Q E", e Q e E trocam de página (pela entrada da pausa e do painel central). No HUD o compacto mostra o que cabe e o pé diz "+N golpes" (escolhido por ser o mais leve: sem troca automática de página). Golpe com nome longo e sem `curto` corta com "." no HUD, em vez de estourar a coluna. Com um golpe só não há paginação.
- **Testes:** `v2_status` com `falhas=0` (novo bloco `_paginacao`: 50 golpes no HUD, na pausa e no painel central). Prints com os 50 golpes em `status_hud_50_golpes` e `status_pausa_50_golpes`.
- **Pendente:** o detalhe da pausa (Tab) ainda corta com "+N golpes" em vez de paginar. Os 50 golpes de `dados/v2_armas/lote_*.json` não têm `curto`, então no HUD e na página visual os nomes saem cortados com "." (um `curto` por golpe resolve).

_Claude do Breno (PC)_

## 2026-10-13 · Codex (PC) · executor revalidado sobre a main atualizada
- **Feito:** incorporada a main cdf67f7 sem descartar o trabalho paralelo. A formatação pendente em testes/v2_status.gd, vinda da main, foi corrigida em commit separado exclusivamente de formatação.
- **Testes:** autoteste_executor falhas=0; gdformat -l 160 --check scripts testes: 174 arquivos limpos. O CI do PR #223 está em execução; imports do workflow permanecem intactos.
- **Próximo:** integrar os PRs por assunto após conferir os checks.

_Codex (PC), workflow com agentes Luna_

## 2026-10-13 · Codex (PC) · autoteste integrado ao executor
- **Feito:** o executor normal roda seu autoteste antes da bateria, sem recursão nos workers --uma. Assim o próprio CI verifica código 7 após marca de sucesso e timeout, sem alterar o import do Godot.
- **Verificação:** autoteste_executor falhas=0; testes de sintaxe Bash e gdformat scripts/testes limpos. A instabilidade do esquiva legado está documentada no PR #223 com o log.

_Codex (PC), workflow com agentes Luna_
## 2026-10-13 (2) · Codex Luna (PC) · validação do save seguro
- **Feito:** após integrar `origin/main` (`cdf67f7`), passaram `v2_meta`, `v2_mapas`, `v2_pausa`, `v2_esc`, `v2_musica` e `v2_status` com `falhas=0`; `gdformat --line-length 160 --check` passou em 174 scripts e testes. O fixture `v2_mapas` limpa também `.tmp` e `.bak`, gerados pelo save seguro.
- **Sobreposição com PRs:** #201 não altera os arquivos de save; #214 altera `meta.gd` e `altar.gd`; #217 altera `altar.gd` e `resultado_meta.gd`; #219 já está integrado; #220 altera `mapas.gd`, `v2_mapas.gd` e `LEIA-ME.md`; #222 altera `v2_mapas.gd` e `LEIA-ME.md`. Os PRs ainda abertos que compartilham arquivos precisam de revisão ao integrar.
- **Pendente:** PR/push será tratado pelo root.

_Codex Luna (PC)_
## 2026-10-13 · Codex (PC) · Release revalidada na main atualizada
- **Feito:** incorporada a main cdf67f7 e mantidos os exports intactos. A Release chama o CI reutilizável local do mesmo commit, e publicar depende dele. Import com segfault de saída conhecido permanece tolerado.
- **Verificação:** YAML e dependência do mesmo commit conferidos; gdformat scripts/testes: 174 arquivos limpos. Formatação pendente do teste v2_status da main foi isolada em commit próprio. Não rodei Godot local para mudança exclusiva de workflows; o CI do PR executa as cenas.
- **Próximo:** conferir os checks e integrar com o PR separado de lint.
## 2026-10-13 · Codex (PC) · lint revalidado na main atualizada
- **Feito:** main cdf67f7 incorporada; formatação adicional de v2/status.gd e testes/v2_status.gd em commits exclusivamente de formatação. O job gdformat é obrigatório; gdlint permanece aviso; ambos incluem v2.
- **Verificação:** gdformat scripts/testes/v2: 221 arquivos limpos; YAML e separação dos jobs conferidos. Não executei Godot local para mudança de workflow e formatação; CI do PR executa as cenas.
- **Próximo:** integrar junto à proteção de Release; mudanças de workflow compatíveis por hunks distintos.
## 2026-10-13 · Codex (PC), agentes Luna · grade de separação sem vizinho duplicado
- **Feito:** cache dos hashes vizinhos únicos em vetores planos reutilizados por índice de ator. Recalcula só ao mudar a célula ou o alcance; cada bucket é visitado uma vez. Sem Dictionary por quadro e sem mudança em mundo.gd.
- **Testes:** v2_combate: código 0, falhas=0, sem SCRIPT ERROR, incluindo raio comum no caso (84,214)/(73,203) e reutilização do cache.
- **Custo:** benchmark headless, algoritmo original completo como referência, semente fixa, 20 amostras de 100 chamadas alternando ordem. Cache aquecido: 100 atores −35,2%, 500 −19,9%; em movimento a 45 px/s atravessando células: 100 −4,1%, 500 −3,2%. São tempos da separação, não FPS; confirmar em hardware alvo.
- **Pendente / conflitos:** combate.gd pode sobrepor #201/#214/#220/#222. #217 mexe na UI; #219 já está na base cdf67f7. A correção do quadro extra é outro PR.
## 2026-10-13 · Codex (PC), agentes Luna · sem quadro extra ao abrir a escolha
- **Feito:** passo_tempo retorna 0.0 se _fim_camera_lenta abriu a escolha e ativou a pausa. Mudança de duas linhas em combate.gd; mundo.gd permanece igual. A grade é outro PR.
- **Testes:** Godot 4.4.1 headless, após import real: v2_combate, v2_esc e v2_pausa, código 0, falhas=0 e sem SCRIPT ERROR. Teste força movimento do herói e confere relógio da partida e posições do herói/monstro no quadro exato da transição. gdformat scripts/testes limpo; formatação de teste v2_status da main em commit separado.
- **Pendente / conflitos:** conferir sobreposição de combate.gd com #201/#214/#220/#222. #217 é UI; #219 já está na base atualizada.
## 2026-10-13 · Codex (PC) · guia v2 revalidado sobre a main
- **Feito:** documentação conferida sobre main cdf67f7; não anuncia recursos dos PRs abertos como entregues. Formatação pendente do teste v2_status da main em commit separado.
- **Testes:** Godot 4.4.1 headless: v2_menu e entrada_cenas, código 0, falhas=0, sem SCRIPT ERROR. Cena principal e dimensões 960×540 conferidas nos arquivos; gdformat scripts/testes: 174 arquivos limpos.
- **Próximo:** manter guia e roadmap alinhados a cada port da v1 ou integração de PR.

_Codex (PC), workflow com agentes Luna_
## 2026-10-13 · Codex com agentes Luna (PC) · recompensas em 1 segundo
- **Feito:** escolha inicial e baú da v2 aguardam 1 s real; no baú todas as cartas são reveladas juntas ao completar esse segundo, independentemente de haver 1, 2 ou 3 recompensas. Rerrolar/banir mantém 0,8 s. A pausa e o descarte de cliques antecipados continuam cobertos.
- **Testes:** Godot 4.4.1, import real; `v2_cartas_espera`, `v2_partida`, `v2_esc` e `v2_status`: código 0, `falhas=0`, sem `SCRIPT ERROR`. O fuzz de ESC ganhou 1000 passos para manter os mesmos mínimos de cobertura com a escolha mais curta; o teste do painel mede 0,25 s dentro da nova espera. `gdformat -l 160 --check jogos/hordas/projeto/scripts jogos/hordas/projeto/testes` limpo. A tentativa inicial de executar `v2_cartas.tscn` não rodou: a cena não existe, e não é contada como teste aprovado.
- **Pendente / recados:** conferir sensação em uma partida. Conflitos potenciais de dados/estilo com #201, #209, #214 e #217; as mudanças de mecânicas do mapa #220/#222 usam baús e devem preservar a espera nova.

_Codex com agentes Luna (PC)_
## 2026-10-13 · Névoa Espectral e leitura visual dos ataques
- **Feito:** nuvens da v2 ganharam motivos animados próprios (espectros, fumaça de sono, bolhas, cristais, brasas e sangue), volume oval no chão, entrada/saída em fade e pulso proporcional à vida efetivamente removida. Projéteis, anéis, meteoros e aliados usam silhuetas próprias quando ajudam a identificar fogo, veneno, gelo ou sombra; pool fixo em 48.
- **Compatibilidade:** a Névoa Espectral usa o sprite opcional `sp` quando ele existir, mantendo o pulso de acerto por cima. Assim, os sprites da PR #209 poderão assumir o corpo sem duplicação; os motivos por código funcionam mesmo sem ela.
- **Mecânica e guia:** preservados lentidão, contagem de acertos e multiplicador de gelo da nuvem; pulso só ocorre com perda real de vida. Descrição/arte da carta e guia v2 atualizados.
- **Verificação:** importação real Godot 4.4.1 concluída; `v2_partida` terminou com `falhas=0`; `gdformat -l 160 --check` e `git diff --check` limpos. Captura de viewport real (960×540, não vazia) em `C:\Dev\Breno\analise-kikiu\logs-ataques\identidade_nuvens.png`; rótulos da imagem pertencem apenas à cena de demonstração.

_Codex LunaPC_

- **Ajuste da conferência:** o roteiro de foto foi retirado de `testes/` e preservado como ferramenta local, pois aguardar `frame_post_draw` sem renderer trava a execução headless. Ele não é teste funcional nem participa do CI. Os testes de dano/feedback permanecem em `v2_partida`; rótulos pertencem somente à demonstração. A formatação global scripts/testes exige o commit separado de `v2_status` da main.

## 2026-10-13 · Névoas com volume legível e carta espectral dentro do limite
- **Visual:** veneno tem véus verdes claros irregulares sobrepostos, dobras sombreadas, deriva e entrada/saída suave. Espectros, bruma com cristais, sono lilás, cinzas densas, cortina de sangue, chuva ácida e esporos preservam motivos próprios. Textura procedural compartilhada criada uma vez; nó de fumaça criado na montagem, sem mistura aditiva, sem nós ou dicionários novos por desenho. Pool permanece em 48; mecânica de dano, raio, tique e duração não mudou.
- **Carta e CI:** a descrição espectral anterior media 64 px no espaço de 54 px. A nova frase “Névoa com espectros que ferem quem fica nela.” mede 48 px; o critério de v2_fontes foi preservado.
- **Verificação:** Godot 4.4.1 v2_partida, v2_status e v2_fontes com falhas=0; gdformat -l 160 --check (scripts/testes e fontes alteradas) e git diff --check passaram. Capturas OpenGL do veneno em escala 1× e grade de motivos em 2× ficaram fora do repositório, junto do wrapper local. Runners ainda reportam recursos/RID em uso ao encerrar, sem SCRIPT ERROR. Splash temporário da captura foi restaurado.

_Codex GPT-6.1 Sol (PC)_
## 2026-10-13 - v2: barra de vida das elites
- **Feito:** elites ganham uma barra pequena acima da região visual do sprite, calculada com o retângulo, offset e escala do Sprite2D. A barra nasce sob demanda só ao marcar elite, acompanha vida/vida máxima imediatamente ao receber dano, some com vida zero/morte e permanece escondida se o ator voltar ao pool como monstro comum; a mesma instância é reutilizada se virar elite outra vez.
- **Testes:** `v2_hud falhas=0` (headless), cobrindo posição visual, fração de vida, morte, retorno ao pool como comum e reutilização como elite. Captura com renderer real em `C:\Dev\Breno\analise-kikiu\logs-hud\elite_barra_vida.png`.
- **Formatação:** `gdformat -l160 --check` nos arquivos alterados.

- **Conferência final:** formatação global de scripts/testes limpa após commit separado de formatação do teste de status da main. Captura real revisada; a primeira chamada com parâmetros de foto incorretos executou asserts de F3 e falhou em quatro rótulos no renderer, sem alterar esses testes. A chamada corrigida de captura terminou com código 0. A aprovação funcional citada acima é a execução headless com `falhas=0` e sem `SCRIPT ERROR`.
## 2026-10-13 · Codex com agentes Luna (PC) · splash usa a arte atual
- **Feito:** o menu já usava a arte nova do PR #215, mas `boot_splash/image` ainda referenciava `assets/icone/entrada.png`. A configuração da inicialização passa a apontar para `assets/titulo/fundo.png`, a mesma arte atual do menu. Nenhuma arte nova nem alteração dos exports.
- **Testes:** Godot 4.4.1 com import real, `v2_menu` e `entrada_cenas`: código 0, `falhas=0`, sem `SCRIPT ERROR`; imagem configurada existente e referência conferida. Formatação global scripts/testes limpa em commit separado; `git diff --check` limpo.
- **Pendente / recados:** conferir a abertura na próxima build; nenhuma mudança de combate. Guia atualizado.

_Codex com agentes Luna (PC)_
## 2026-10-13 - v2: árvores bloqueiam corrida e esquiva (Codex Luna PC)
- **Causa:** `mundo.mover()` resolvia apenas a posição final. Um passo de esquiva com `delta=0,1` desloca cerca de 31 px; a pegada mais estreita pode ficar inteiramente entre posição inicial e final. O JSON de `prototipos/objetos/cenario.json` exporta as colisões das cinco árvores/tocos/troncos testadas, e os movimentos do herói passam por `mundo.mover()`: não era falta de export nem um bypass do herói.
- **Correção:** passos de até 8 px quando o segmento pode tocar a caixa expandida de alguma forma; segmentos em área aberta continuam com uma única chamada ao resolver. O pré-filtro usa a grade já existente e o teste de caixa é conservador, sem alocação por quadro. O tamanho de 8 px fica abaixo da menor largura vertical de colisão expandida entre as pegadas de árvore e o raio 6 px do herói. A copa continua atravessável.
- **Regressão:** `testes/v2_arvores.tscn` agora percorre o cenário real com as 572 formas: corrida e esquiva via `Heroi.atualizar()` contra os cinco tipos, percurso longo que começa/termina livre atravessando a árvore, e passagem pela copa. Reproduzida antes: início (1398,433), passo (0,35), base em (1402,456), terminou do outro lado; depois da correção, `v2_arvores falhas=0`.
- **Desempenho:** benchmark local com 500 corpos em posições fixas do mapa, monstros a 45 px/s e um herói correndo/esquivando; medianas de 5×10 quadros, no `Godot 4.4.1`. Corrida 60fps: 2,90→3,46 ms/quadro (+0,56 ms); esquiva 60fps: 2,92→3,43 ms (+0,51 ms); corrida `dt=0,1`: 2,76→3,14 ms (+0,38 ms); esquiva `dt=0,1`: 3,19→3,44 ms (+0,26 ms). Também medido o pior caso artificial em que os 500 corpos fazem esquiva: corrigido 2,6× baseline em `dt=0,1`; isso não representa a horda (monstros não esquivam). Log fora do repositório: `C:\Dev\Breno\analise-kikiu\logs-arvores\v2-arvores-passo8-full.txt`.
- **Testes e revisão:** import real executado; depois dele, `v2_arvores falhas=0`, `v2_colisao falhas=0` e `v2_combate falhas=0`, todos exit 0 e sem SCRIPT ERROR. Uma execução de `v2_combate` antes do reimport emitiu atribuição de `n` em Nil em `v2/horda.gd:282`; após o reimport, não se reproduziu. Os runners de árvores/combate imprimem avisos de RID/recursos em uso no encerramento. `gdformat -l 160 --check jogos/hordas/projeto/scripts jogos/hordas/projeto/testes` e `git diff --check` passam. PRs sobrepostos consultados: #201 e #214 tocam movimento do herói/mundo, mas não alteram a rota `mundo.mover`; #217 não conflita; #220/#222 só tocam marcadores do mundo, sem conflito lógico.
- **Guia mínimo:** ao mudar uma pegada, edite a fonte do protótipo e regenere `prototipos/objetos/cenario.json`; faça `godot --headless --path jogos/hordas/projeto --import`, rode `res://testes/v2_arvores.tscn`, e não versione `.import`, `.uid` nem `.godot/` gerados.

_Codex Luna (PC)_

- **Refino do caminho comum:** movimentos curtos usam comprimento ao quadrado e resolvem uma única vez, sem divisão nem laço de subpassos. O benchmark acima descreve a versão anterior com laço de uma iteração; o refino não é uma promessa de FPS. Guia da v2 atualizado.

- **CI / teste de mundo:** a primeira execução do PR falhou em `v2_mundo`: o teste deixava o herói junto de uma forma após a perseguição e esperava deslocamento puro (início 1150,213/443,742; feito 10,249/5,331). A nova resolução intermediária corretamente corrige a colisão. O caso de soma agora encontra um trajeto livre dentro da área andável sem apagar as formas; o clamp é testado separadamente com ator fora do limite. `v2_mundo` passou com código 0, `falhas=0`, sem `SCRIPT ERROR`. Log da falha do CI e diagnóstico preservados.
## 2026-10-13 - HUD de habilidades E/Q da v2
- **Feito:** cards originais E/Q na faixa inferior, lendo apenas o estado real da Ruptura quando o herói o publica. Na main, E fica indisponível; Q fica cinza com “EM BREVE” até existir mecânica. No PR201, os desenhos antigos dos slots ficam transparentes e seus nós/flags permanecem intactos. Layout evita XP e coluna de status.
- **Testes:** `v2_hud` e teste de integração temporário no checkout `origin/alisson/v2-ruptura`, ambos `falhas=0`; integração verificou prontidão, carga, recarga e transparência dos controles antigos. Capturas OpenGL em `C:\Dev\Breno\analise-kikiu\logs-hud\overwatch_pr201_*.png`.
- **Pendente:** Q não tem mecânica implementada. Documentação em `docs/v2_hud_habilidades.md`.

_Codex (PC)_
- **Conferência:** `v2_status` e `v2_esc` na base principal, `v2_escudo`, `v2_ruptura` e a integração real em PR201 sem `SCRIPT ERROR`. Formatação global no escopo obrigatório scripts/testes limpa após commit separado de status; os scripts do adaptador também passam. O projeto inteiro contém outras pendências de formatação alheias, preservadas. Desenho do adaptador revisado por GPT-6.1 Sol leve; nenhuma mecânica nova de Q.

## 2026-10-12 — v2: Ruptura no botão direito (PR #201)
- **O que entrou:** habilidade nova no botão direito do mouse e no gatilho esquerdo do controle (`v2/ruptura.gd`, dados em `dados/v2_ruptura.json`): segurar carrega, soltar racha o chão em 360° (dano, atordoamento, empurrão; chefe só leva dano e lentidão), com recarga, janela de soltura perfeita, contragolpe, 5 cartas de melhoria, slot no HUD, 4 sons e `--roteiro=ruptura` para fotos/medição.
- **Testes:** `testes/v2_ruptura.tscn` (`falhas=0`), mais `v2_combate`, `v2_hud`, `v2_pausa` e `v2_fontes` depois de mesclar a main (#203).
- **O que NÃO foi conferido:** o feeling no jogo aberto (tempo de carga, peso do tremor e do hit-stop, volume dos sons) — só teste automático e prints. Precisa de alguém jogando.
- **Pendente:** ao mesclar depois do #190 (card SUA BUILD) há conflito de texto em `combate.gd` e `LEIA-ME.md`; resolver e rodar `v2_status`, `v2_combate` e `v2_ruptura`.

_Claude do Alisson (notebook)_

## 2026-10-12 — v2: esquema Overwatch nos botões (PR #201)
- **Decisão do Alisson:** botão direito = tiro SECUNDÁRIO definido por herói (hoje: ESCUDO), **E** (LB) = habilidade (a Ruptura saiu do botão direito), **Q** (RB) = ultimate (reservado: só a ação `ultimate` e um slot vazio no HUD, sem mecânica).
- **Escudo** (`v2/escudo.gd`, dados em `dados/v2_secundario.json`, com `_ajuda`): segurar ergue um arco de 120° na direção da mira que barra o dano vindo da frente (contato, avisos no chão e ataques do chefe, tudo por `Heroi.levar_dano(valor, de, quem)`, que agora devolve true também quando o golpe é barrado). Anda a 60%, não corre nem golpeia, gasta 1,2 de fôlego por segundo (o mesmo da corrida; zerar deixa cansado e o escudo cai). Bloqueio perfeito (primeiros 0,15 s): sem gasto, empurra e atordoa 0,7 s quem bateu. Qual secundário cada herói tem é dado (`v2_secundario.json > padrao` e `herois`): a branch `alisson/v2-herois` só mapeia a chave do herói para outro id quando o módulo dele existir.
- **Testes:** `v2_escudo` novo (`falhas=0`); `v2_ruptura` adaptado para E/LB; `v2_combate`, `v2_esc`, `v2_hud` e `v2_status` ok. Merge da main (#190 card SUA BUILD e #199) resolvido em `combate.gd` e `LEIA-ME.md`.
- **O que NÃO foi conferido:** o jogo na janela real: a legibilidade do arco azul, o peso do bloqueio perfeito (hit-stop e tremor), o volume dos sons reaproveitados, o LT/LB com controle de verdade, e se segurar o direito com o mouse parado mira para onde se espera.
- **Pendente:** o painel de status (`status.gd`) ainda não mostra o escudo (`escudo.resumo()` está pronto); o ultimate (Q) não tem mecânica.

_Claude do Alisson (notebook)_

## 2026-10-13 · Codex GPT-6.1 Sol (PC) · integração para entrega
- **Feito:** PRs #223–#235 e #201 integrados por merges preservando todos os históricos, sobre main a78829f (mapa médio #220). Guias combinados, splash obrigatório `res://assets/titulo/fundo.png`, E carrega/solta Ruptura, botão direito/LT escudo e Q reservado. Exports/presets sem alteração.
- **Correções da integração:** teste de Ruptura atualizado para os 50 golpes existentes na base; fixtures de status, ESC, pausa, música e fontes limpam os backups e temporários dos seus saves de teste. A falha inicial do status (backup recuperado pelo novo save seguro) foi preservada em log separado. Formatação de escudo/Ruptura/mundo em commit próprio.
- **Validação real:** Godot 4.4.1, duas importações, código 0 e sem SCRIPT ERROR. Cenas v2_ruptura, v2_escudo, v2_hud, v2_meta, v2_arvores, v2_mundo, v2_combate, v2_cartas_espera, v2_partida, v2_esc, v2_status, v2_fontes, v2_menu, entrada_cenas, v2_mapas, v2_pausa e v2_musica: código 0, falhas=0, sem SCRIPT ERROR. Meta provoca erros de parse do save corrompido intencionalmente; avisos de recursos/RID no encerramento headless permanecem, sem falha nas cenas.
- **Checks:** autoteste_executor código 0/falhas=0; gdformat -l 160 --check scripts/testes/v2 (227 arquivos limpos), git diff --check e ancestralidade dos 14 heads conferidos. Nenhuma entrada anterior da main removida do LOGBOOK; imports/cache/UID aleatórios fora dos commits. Logs locais em analise-kikiu/logs-entrega.
- **Próximo:** revisão, CI da integração e build exportada pelo agente responsável; nenhum push/merge GitHub feito neste bloco.

_Codex GPT-6.1 Sol (PC)_
## 2026-10-13 · Codex GPT-6.1 Sol (PC) · retomada da integração para entrega
- **Feito:** integração atualizada por merge da main a6004a7, incluindo mecânicas do mapa médio #222 e correção do teste do elmo #221. Os 14 heads de #201 e #223–#235 continuam preservados. Splash permanece em `res://assets/titulo/fundo.png`; E/Ruptura e botão direito/escudo preservados; Q reservado. Exports/presets sem alteração.
- **Validação real após a atualização:** Godot 4.4.1 headless nas 18 cenas v2_mapas, v2_mundo, v2_ruptura, v2_escudo, v2_hud, v2_esc, v2_combate, v2_cartas_espera, v2_status, equipamentos, v2_arvores, v2_partida, v2_meta, v2_fontes, v2_menu, entrada_cenas, v2_pausa e v2_musica: todas código 0, falhas=0 e sem SCRIPT ERROR. Logs em analise-kikiu/logs-entrega-retomada. Meta exercita save corrompido intencionalmente; avisos de recursos/RID no encerramento headless permanecem.
- **Checks:** gdformat -l 160 --check scripts/testes/v2: código 0, 227 arquivos limpos; git diff --check limpo. Imports/UID não rastreados permanecem fora dos commits.
- **Limite confirmado por leitura do código:** os espinhos de #222 chamam Heroi.levar_dano com origem na posição do herói; Escudo.cobre considera origem a menos de 0,5 px como coberta. Assim, escudo erguido bloqueia espinhos pela regra existente. Nenhuma mudança de design feita nesta integração; comportamento deve entrar na revisão de gameplay da build.
- **Próximo:** atualizar PR #236, obter CI verde e exportar/validar a candidata com este commit; publicação e merge remoto ficam com o agente responsável.

_Codex GPT-6.1 Sol (PC)_

## 2026-10-13 · Claude do Breno (PC) · pacote de construções da floresta
- **Feito:** 17 fichas em `docs/construcoes_floresta/`, `BALANCEAMENTO.md` (tabela e revisão), `PACOTE_ALISSON.md` (primeiro mapa médio com 7 construções) e `MAIS_IDEIAS.md` (4 ideias novas para revisão). Só documentação: nenhum código, cena, dado ou arte foi alterado.
- **Pendente:** comentário no GitHub para o Alisson não foi postado, porque o `gh` não está instalado neste PC. Este registro é o aviso.
- **Para o Claude do Alisson:** o pacote está em `docs/construcoes_floresta/PACOTE_ALISSON.md`. Ainda não leia os prompts como definitivos: o Breno revisa `MAIS_IDEIAS.md` primeiro. Não mexa nas suas artes ao usar os prompts.

_Claude do Breno (PC)_

## 2026-10-13 · Cidade na seleção e Ruínas da Floresta
- **Antes/depois:** a build main 5dd7972 mostrava Floresta, Laboratório e Médio. Integrada a Cidade da PR #211 (head 2aa41db) por merge da main, preservando histórico e assets: a seleção agora oferece Floresta, Laboratório, Cidade e Ruínas da Floresta. O antigo `medio` conserva id, dados, progresso e mecânicas #220/#222; só os textos mudam para RUÍNAS DA FLORESTA e ENTRAR NAS RUÍNAS. Save seguro, árvores, E/Ruptura e escudo da main preservados.
- **Testes:** import real Godot 4.4.1 exit 0; v2_mapas, v2_mundo e v2_arvores exit 0/falhas=0/sem SCRIPT ERROR. v2_mapas cobre os quatro mapas, rua da Cidade de 300 px, passagens, marcadores/espinhos das ruínas, save legado bruto `medio`, preservação de outros dados e fallback desconhecido. Renderer OpenGL real (Intel Iris Xe) também v2_mapas exit 0/falhas=0; capturas do mundo e seleção 960×540 revisadas, nome e botão das ruínas cabem.
- **Custo CPU, sem promessa de FPS:** benchmark headless de `mundo.avancar(1/60)`, 20 monstros, semente 211, 100 passos de aquecimento por caso e 20 amostras de 100 passos, alternando ordem dos quatro casos e montando um mundo por vez. Medianas: Laboratório média 410,98 µs/alta 457,55 µs; Cidade média 372,42 µs/alta 417,38 µs. Cidade conserva 177 objetos e 85 luzes do mapa (87 no mundo incluindo duas do herói); Laboratório 376 objetos/122 luzes totais. Mede CPU com renderer dummy, não custo de GPU nem gameplay completo. Primeira tentativa via --script não carregou autoloads e foi encerrada; log da falha preservado, não contado como validação.
- **Checks/limites:** gdformat scripts/testes/v2 (227 arquivos) e git diff --check limpos. Logs, capturas e wrapper local em C:/Dev/Breno/analise-kikiu/logs-cidade-nova, fora do Git. Avisos RID/recursos no encerramento headless permanecem. Nenhum push/merge remoto neste bloco; publicação/CI/build ficam com o agente principal.

_CodexSolPC_

- **Correção da conferência visual:** o nome inteiro aparecia no PNG anterior, mas isso não provava ausência de sobreposição. Assert após `process_frame` reproduziu seletor de Ruínas terminando em x348 contra ENTRAR em x300 (48 px sobrepostos). `_atualizar_mapa` agora mantém fonte Jersey 19 em todos os mapas, texto completo, tooltip e largura 248 px. O teste espera o mínimo diferido do Godot e verifica geometria nos quatro mapas. `v2_mapas`, `v2_meta` e `v2_fontes` sobre a correção: exit 0/falhas=0/sem SCRIPT ERROR; renderer real também passou os limites. Formatação global (227 arquivos) e diff limpos.

## 2026-10-13 · Codex GPT-6.1 Sol (PC) · Santuário compacto e volta ao título
- **Feito:** ESC/Start/B e botão VOLTAR retornam do Santuário ao menu principal. Só o título pede Sair por ESC; a pausa da partida mantém seu fluxo. Ajustes/Gráficos continuam voltando um nível e devolvem foco ao botão Ajustes quando fecham.
- **Visual:** melhorias em grade 3×3 com marcadores de nível e custo/estado, detalhe único por foco ou mouse (inclusive bloqueadas/máximas), conquistas com barras rotuladas pela última partida e descrição acessível pelo teclado/controle. Fundo atual `assets/titulo/fundo.png`, sem mudar splash/exports. Nome completo de mapa cabe no botão em fonte 19, inclusive RUÍNAS DA FLORESTA; resumo inicial neutro.
- **Validação:** Godot 4.4.1 real: v2_santuario, v2_meta, v2_pausa, v2_menu, v2_esc, v2_status, v2_fontes e v2_musica com código 0/falhas=0. Teste novo usa Input.parse_input_event e current_scene real para ESC, Start, B, Enter e clique; confere foco, estados bloqueado/máximo, barras e limites de cartões/textos. Falha de gravação e itens ocultos preservados por v2_meta. gdformat -l 160 --check scripts/testes/v2 limpo (228 arquivos); git diff --check limpo.
- **Conferência visual:** capturas reais do viewport 960×540, janela oculta e frame_post_draw, antes/depois com saldo zero/com almas, barras parciais e conquistas cumpridas. Logs/fotos locais em `C:/Dev/Breno/analise-kikiu/logs-santuario`, fora do Git. Avisos de recursos/RID ao encerrar headless continuam; erros de parse de save em meta são intencionais. Nenhuma arte binária/import/cache adicional versionada.
- **Próximo:** agente principal publica PR coeso do Santuário e integra com o PR separado dos mapas antes da build conjunta; nenhum push/merge feito neste bloco.

_Codex GPT-6.1 Sol (PC)_
## 2026-10-13 · Codex GPT-6.1 Sol (PC) · validação conjunta Santuário e Cidade
- **Feito:** merge local da branch Cidade (`9337defd5088bb61fd6c876f0f3dd33b782570ec`) no Santuário, preservando ambos os históricos. Guia combina os dois blocos; LOGBOOK mantém todas as entradas. Grade, navegação, fundo atual e detalhes do Santuário preservados; seletor fica em fonte Jersey 19, largura 248 px e tooltip com nome completo. Removida só uma linha vazia final herdada de `cidade_pecas.py` para diff-check.
- **Validação conjunta:** import real Godot 4.4.1 código 0/sem SCRIPT ERROR. v2_mapas, v2_santuario, v2_meta, v2_fontes, v2_menu e v2_esc: código 0/falhas=0/sem SCRIPT ERROR. gdformat scripts/testes/v2 limpo (228 arquivos); git diff --check e git diff --cached --check limpos. Avisos de recursos no encerramento e save corrompido intencional de meta permanecem.
- **Visual:** renderer OpenGL real, viewport 960×540, janela oculta e frame_post_draw; capturas de RUÍNAS DA FLORESTA e CIDADE revisadas. Nomes completos, ENTRAR, grade e VOLTAR cabem; seletor termina em x284 contra ENTRAR em x300. Logs/fotos em `C:/Dev/Breno/analise-kikiu/logs-santuario/conjunto`, fora do Git.
- **Próximo:** agente principal atualiza PR #238 por push normal e mescla Cidade #211 após CI verde; publicação/build conjunta ficam com ele. Nenhum push/main/PR feito neste bloco.

_Codex GPT-6.1 Sol (PC)_

## 2026-10-13 · Codex GPT-6.1 Sol (PC) · morte e retorno seguro ao santuário
- **Antes/depois:** Alisson relatou travamento/fechamento ao morrer. Windows registrou 0xc0000005 na build b7a1d87; reprodução com Enter em CONTINUAR saiu -1073741819. No Godot de desenvolvimento, a mesma entrada produz SCRIPT ERROR em mundo.gd:694 (viewport nulo): resultado_meta trocava a cena imediatamente antes de mundo marcar o evento. A troca agora é diferida até terminar a entrada, com guarda contra cliques repetidos.
- **Falha de save:** o relógio e o botão CONTINUAR avançam mesmo quando a meta não grava; mantém NÃO FOI POSSÍVEL SALVAR, sem creditar almas falsas nem prender o jogador na tela.
- **Testes reais:** Godot 4.4.1 import exit 0; v2_morte (novo, quatro mapas, Enter/mouse/A, entrada precoce/repetida, mundo pausado, crédito único, gravação recusada e hash do save real), v2_meta, v2_partida, v2_esc e v2_santuario: todos exit 0/falhas=0/sem SCRIPT ERROR. v2_morte também passou com renderer OpenGL Intel Iris Xe, janela oculta 960×540. Avisos de RID/recursos ao encerrar harness permanecem; recusa de .tmp é intencional. gdformat scripts/testes/v2: 229 arquivos limpos; diff-check limpo.
- **Próximo:** CI do PR e repetir no EXE exportado junto aos efeitos visuais. Splash e exports preservados. Logs fora do Git em C:/Dev/Breno/analise-kikiu/morte-*.log.

_Codex GPT-6.1 Sol (PC)_
## 2026-10-13 - #128 (Marco 4): código que faltava (PR de rascunho para a main, branch claude/v2-marco4-codigo)
- **Feito:**
  1. Determinismo: `testes/v2_mapas` confere que dois mundos do mesmo mapa têm as mesmas posições de objetos e de monstros iniciais (mesma semente, mesmo mapa).
  2. Minimapa (`v2/minimapa.gd`): Tab segurado abre o mapa grande e soltar volta ao pequeno (antes alternava); baús ativos aparecem só depois de revelados pela névoa; missões longe do herói (chefe e portão) ganham seta na borda do minimapa. A névoa por raio já existia.
  3. Pontos altos: marca `mirante` no mapa médio (1350, 1140); ao entrar no raio, o minimapa revela o mapa inteiro de uma vez.
- **Não feito (pendente):**
  - Mapas gerados por semente a partir de peças por região: o cenário da v2 é o JSON à mão, em 2880x1620. Só entra com um gerador novo, fora do formato atual.
  - Prints dos 5 mapas por região: a v2 não tem regiões (são 3 mapas).
  - Arte do Alisson: torre (o mirante é só a marca) e estruturas (ruína, altar, ponte, passagem, platô, portão).
  - Alavancas com passagem física até o portão: ainda só marcam estado.
- **Fps (medido no PC do Breno, sem linha de base aqui):** `--medir --estresse=100 --imortal --sombra=media --sem_vsync` deu 23,4 fps na floresta e 30,4 fps no médio. O `v2/fps.txt` (142 fps na horda média) veio de outra máquina (Iris Xe), então a comparação não vale. Falta medir a `main` nesta máquina para ver a diferença real. A meta do Marco 3 não está escrita no repositório; precisa de um número para comparar.
- **Testes:** `v2_mapas` falhas=0, `v2_minimapa` falhas=0, `v2_meta` falhas=0, `v2_partida` falhas=0. (Os erros de ConfigFile em `v2_meta` são do teste de save corrompido, esperados.)
- **Para testar:** no mapa médio, segurar Tab (mapa grande), passar por um baú antes de vê-lo e entrar no mirante (1350, 1140) para o mapa inteiro se revelar.
- **Para o Claude do Alisson:** este PR não mexe em arte, `assets/`, `fonte_arte/`, `docs/visual_2_5d/`, `v2/heroi.gd` nem `v2/horda.gd`.

_Claude (PC do Breno, via Remote Control)_

## 2026-10-13 · Codex GPT-6.1 Sol (PC) · Ruptura e escudo com volume
- **Feito:** visual autoral por geometria na v2: sigilos internos e halo na carga; janela perfeita com pulso dourado suave no lugar do piscar a 20 Hz; onda em camadas e fissuras com núcleo quente e ramificações. Escudo curvo elevado com painéis, nervuras e runa central; sustentação azul, bloqueio branco, perfeito dourado com oito raios; ponto de impacto acompanha a origem. Nenhum asset externo/licença adicional, nó por quadro ou alteração de alcance, dano, fôlego, janela ou controles.
- **Validação:** Godot 4.4.1 import exit 0; v2_ruptura, v2_escudo, v2_combate e v2_hud exit 0/falhas=0/sem SCRIPT ERROR. Uma falha inicial de inferência de tipo foi corrigida, preservando o log local. Capturas reais 960×540 com OpenGL/Intel Iris Xe, janela oculta: carga, carga perfeita, disparo, escudo, bloqueio comum e perfeito revisados. Avisos de RID no encerramento permanecem. Wrapper/fotos/logs locais não versionados.
- **Próximo:** agente principal revisa PR e faz build; nenhum push/merge neste bloco.

_Codex GPT-6.1 Sol (PC)_


## 2026-10-13 · Codex GPT-6.1 Sol (PC) · Emblema de solo rompido no HUD
- **Feito:** substituído o símbolo angular da Ruptura por duas placas de pedra separadas e fenda central ramificada, autoral e compacto no ícone 48×48. Estados/cores/carga/recarga continuam os mesmos; nenhum ajuste no mundo ou nos efeitos de Ruptura/escudo.
- **Validação:** Godot 4.4.1 v2_hud e v2_ruptura exit 0/falhas=0/sem SCRIPT ERROR. Capturas reais OpenGL 960×540 com janela oculta, prontidão/carga/recarga e detalhes do card inspecionados; fotos/logs locais no worktree, fora do Git. gdformat global e diff-check conferidos.
- **Próximo:** agente principal atualiza PR #240 e CI; build precisa ser reexportada com este novo ícone.

_Codex GPT-6.1 Sol (PC)_

## 2026-10-14 · Codex GPT-6.1 Sol (PC) · retomada do PR #240 sobre a main
- **Feito:** merge da main b70bf6e (#241), mantendo névoa/Tab segurado/setas/mirante, os quatro mapas, correção da morte #239, splash atual e efeitos/ícone do #240. LOGBOOK da main preservado integralmente como prefixo, notas deste PR ao fim; sem reescrever entradas anteriores. Nenhuma integração dos PRs #242/#245/#246.
- **Testes reais:** Godot 4.4.1 import código 0. v2_mapas, v2_minimapa, v2_morte, v2_ruptura, v2_escudo, v2_hud, v2_combate, v2_meta, v2_partida e v2_santuario: todos código 0/falhas=0/sem SCRIPT ERROR. gdformat scripts/testes/v2: 229 arquivos limpos; diff-check limpo. Avisos de recursos ao encerrar harness permanecem e save corrompido de meta é intencional. Logs locais pr240-retomada-*, fora do Git.
- **Próximo:** CI do head atualizado, exportação e QA do EXE com minimapa e efeitos juntos; merge e Release somente com checks verdes. Sem alteração de exports, regras de habilidades ou novas artes.

_Codex GPT-6.1 Sol (PC)_
## 2026-10-14 · Claude do Alisson (notebook) · divisão de trabalho entre os três agentes
- **Feito:** decisão do Alisson registrada no fim do `CLAUDE.md` (seção reescrita) e no `AGENTS.md` novo, que o Codex lê. Claude do Alisson: sistemas, arquitetura e **integração** (resolve conflito entre PRs). Codex do Alisson: frente visual inteira (arte, sprites, efeitos, animação, UI, paleta) e builds. Claude do Breno: leve (números e textos nos JSON, conteúdo, testes da Release no i5, decisões).
- **Regras:** reservar antes de começar, ficar na sua área de arquivos, uma só mão integra, cada um mescla só os próprios PRs.
- **Para o Codex:** ficam com você o #209 (sprites das armas: atualizar com a main) e o #217 (paleta: refazer do zero na main atual).
- **Para o Claude do Breno:** o #242 (Salão do herói) e o nosso #214 (Nicão e Lucas) se sobrepõem; o Alisson e o Breno decidem qual base vale, e o Claude do Alisson junta.

_Claude do Alisson (notebook)_

## 2026-10-12 (7) · Claude do Alisson (PC) · sprites das armas da v2 (recorte das folhas do GPT)
- **Feito:** recortei as três folhas de arte própria do Alisson (`jogos/hordas/prototipos/cara_nova/objetos/fonte_armas_*.webp`) com a ferramenta de enfeites, que ganhou o modo `python gerar_objetos.py armas`. Saíram 16 projéteis e meteoros, 9 aliados (com normal map) e 12 efeitos de área (fundo preto, aditivo, sem normal). Estão em `jogos/hordas/projeto/assets/v2/armas/`, com `indice.json` (campo `armas_sugeridas`) e a prévia em `jogos/hordas/prints/v2_armas_sprites.png`. O modo padrão (enfeites) continua gerando o mesmo arquivo.
- **Cobertura das 45 armas do #192:** 33 com sprite adequado, 6 com sprite provisório, 6 sem sprite. A lista e o prompt da 4ª folha estão no corpo do PR.
- **Pendente:** ligar no código (espera o #192 entrar na `main`); 4ª folha no GPT; olhar em jogo os projéteis finos (flecha 12x3, dardo 8x3) e o contraste da shuriken preta e da flecha roxa sobre piso escuro.
- **Próximo:** quando o #192 sair, ligar os sprites às armas e gerar os `.import` junto.
- **Recado:** a branch local `alisson/v2-sprites-armas` (sem commits próprios, atrás da `main`) está presa no worktree `wf_f38176cf-d74-1` de outra sessão. Este PR saiu de `alisson/v2-sprites-armas-2`, para não mexer no worktree dela.

## 2026-10-12 · Claude do Alisson (notebook) · sprites das armas ligados no jogo (PR #209)
- **Feito (a pedido do Breno, na branch do Alisson):** a 4ª folha (`fonte_armas_areas_2.webp`, 9 efeitos em fundo preto) entrou no gerador (`gerar_objetos.py armas`). Os 6 sem sprite e os 3 provisórios de área ganharam sprite próprio; `nevoa_fantasmal` e `anel_vento` saíram do índice e da pasta (trocados pelos da folha 21). A folha 21 usa folga de 0 px para juntar os pedaços (`GAP_FOLHA`): as caixas da linha de baixo ficam a 1-2 px, e com a folga de 6 px viravam um só. As folhas 18 a 20 ficam como estavam (mesmos PNG). Índice com 44 sprites. Contorno claro de 1 px em flecha, shuriken e dardo.
- **Ligado:** `v2/armas_novas.gd` lê o `indice.json` uma vez por processo (`carregar_sprites`) e guarda o sprite no item do pool. Projétil gira para o voo, meteoro que cai aponta para baixo, aliado flutua: os três na camada normal (`desenhar_corpo`, chamada de `v2/armas.gd`). Nuvem e anel são aditivos, esticados até o raio do golpe (brilho a 0,5 e 0,6). Sem sprite, a forma antiga. Pool fixo, nenhum nó novo.
- **Cobertura:** 45 de 45 golpes novos com sprite (42 adequados e 3 provisórios). Dos 5 antigos, nenhum ligado: `aura_fogo` tem o `anel_fogo` no índice, mas a aura é um shader em `armas.gd` (não mexi). As 25 evoluções (fusões) não têm sprite e seguem na forma antiga.
- **Testes:** `v2_armas_sprites` (novo; PNG e tamanho do índice, 45 golpes com textura, armas do índice que existem nos dados, partida com os 45 ligados: todos os tipos acertam, pool e camada sem nó novo, cada golpe ativo leva o sprite da sua arma), `v2_partida`, `v2_status` e `regras_armas` com `falhas=0`. Print: `docs/visual_2_5d/armas_v2/golpes_com_sprite.png` (viewport 960x540).
- **Achado fora do escopo:** os `.import` de `assets/v2/mapas/` e de `prototipos/` não estão no Git; o `--import` local os gera e o CI roda `--import` antes dos testes. Os de `assets/v2/armas/` estão versionados agora (o export precisa deles).
- **Pendente:** olhar em jogo a legibilidade dos projéteis finos (flecha 14x5, dardo 10x5, feixe 40x3, espinho 6x14) e a intensidade das áreas em combate cheio; decidir se a aura usa o `anel_fogo`; sprite para as 25 evoluções.
- **Recado para o Claude do Alisson:** a branch `alisson/v2-sprites-armas-2` agora tem o merge da `main` e este commit. Os `.import` das armas vieram com ele; não gere de novo na sua máquina sem olhar o diff.

_Claude do Alisson (notebook)_


## 2026-10-14 · Codex do Alisson · integração visual do PR #209
- **Feito:** main incorporada por merge, sem force-push. Sprites dos 45 golpes novos ligados à camada de desenho, preservando névoa volumétrica, motivos dos ataques (#231), Ruptura e escudo (#240). Conflito restrito à API de desenho; regras, dano, alvos e movimento mantidos. Intensidade aditiva das áreas reduzida após comparação com 45 golpes ativos; flecha 14x5 e dardo 10x5 incluem contorno claro de 1 px.
- **Validação:** Godot 4.4.1 import código 0; v2_armas_sprites, v2_partida, v2_status, v2_combate, v2_ruptura, v2_escudo e v2_fontes: código 0, falhas=0, sem SCRIPT ERROR. gdformat scripts/testes/v2: 230 arquivos limpos. Prints reais 960x540 no perfil Médio, OpenGL Intel Iris Xe, em docs/visual_2_5d/armas_v2/. Não foi medido FPS neste item.
- **Pendente:** CI no head atualizado e merge; publicação/atalho dependem de Release verde. Cota de artefatos bloqueando Release comunicada ao Claude da integração na issue #249. Próximo: paleta única em PR novo, substituindo #217; depois 5 golpes antigos e 25 evoluções.

_Codex do Alisson_

## 2026-10-14 · Claude do Alisson (notebook) · revisão da main: escudo, analógico, minimapa e portão (PR 1) e release sem docs (PR 2)
- **Feito (PR 1, `alisson/correcoes-revisao`):** espinhos do mapa médio não são barrados pelo escudo (`Heroi.levar_dano` ganhou `bloqueavel`, falso nos espinhos: sem gasto de fôlego, sem bloqueio e sem hit-stop). Analógico esquerdo não navega a escolha de cartas (`v2/telas.gd`, a mesma guarda de `v2/pausa.gd`). `Minimapa.resetar()` no `Mundo.reiniciar()`: a névoa e o mirante da partida anterior saem. O portão do médio cumpre a missão ao entrar no raio (a seta some, como a do chefe). Tab não abre o mapa grande com o card de status na tela, a escolha ou o baú. (PR 2, `alisson/release-sem-docs`): `release.yml` com `paths-ignore` (`docs/**`, `**/*.md`, `LOGBOOK.md`) no push da main; `workflow_dispatch` e o CI reutilizável seguem como estavam.
- **Validação:** Godot 4.4.1 headless, código 0, `falhas=0`, sem SCRIPT ERROR: v2_esc, v2_pausa, v2_cartas_espera, v2_minimapa, v2_escudo, v2_ruptura, v2_hud, v2_partida, v2_status, v2_mapas, v2_mundo e v2_morte. Os cinco casos novos falharam antes da correção (commit `dddc1a3`, só testes). gdformat nas pastas de scripts, testes e v2 limpo.
- **Pendente:** a passagem física até o portão (Marco 4) e o atalho (`_atalho_aberto` segue gravado e sem leitura). O card compacto (C) também tira o Tab do minimapa, porque o pedido era "painel de status aberto"; se o Breno quiser o Tab com o card compacto, a troca é a condição em `_tab_bloqueado()`.
- **Para o Codex:** `v2/status.gd` não foi tocado. A falta de saída do painel central pelo controle virou issue para ele.
- **Recado para o Claude do Alisson:** o PR 1 mexe em `v2/telas.gd` (área do Codex) e em `v2/minimapa.gd` (HUD), só nas guardas descritas. O PR 2 não toca o LOGBOOK, para não conflitar no fim do log.

_Claude do Alisson (notebook)_
## 2026-10-14 · Claude do Alisson (PC) · esquiva estável no CI
- **Feito:** `testes/esquiva.gd` deixou de depender do crítico sorteado (`randf()` sem semente em `inimigos.ferir`). A checagem do golpe seguinte aceita só 10 ou 10 x `critico_mult`. A checagem do robô usa um vírus de 100000 de vida e espera um quadro (a grade se refaz nele). Só teste; o jogo não mudou.
- **Validação:** antes, 4 de 20 rodadas falhavam (3 do crítico, 1 do robô); depois, 0 de 30, headless e em sequência. Quebras de propósito (`_quer_dash` com fôlego 3 e bônus de 99 quadros) fazem a cena falhar. gdformat limpo nas três pastas.
- **Pendente:** conferir o CI do PR "Testes: esquiva estável no CI"; daqui não dá para ver o CI.
- **Recado:** se a `esquiva` cair de novo, a mensagem diz qual checagem falhou. O problema não era timeout.

_Claude do Alisson (PC)_

## 2026-10-14 · Claude do Alisson (PC) · integração da PR #237 (construções da floresta)
- **Feito:** `origin/main` (fa2f8a7, #256) mesclada na `claude/construcoes-floresta` por merge, sem force-push e sem rebase. Sem conflito de texto: no `LOGBOOK.md` ficaram as duas partes, a entrada do Breno de 2026-10-13 e as da main. A PR só mexe em `docs/construcoes_floresta/` e no `LOGBOOK.md`; nenhum `.gd`, `.tscn`, `dados/` ou `assets/` mudou.
- **Pendente:** testes locais (gdformat e `ferramentas/testes_ci.sh`) e CI do head novo, com o resultado no comentário da PR #237. Não mesclei: a PR é do Breno e quem mescla é o dono ou o integrador, com CI verde no mesmo commit.
- **Recado para o Claude do Breno:** para seguir com `docs/construcoes_floresta/`, parta da `claude/construcoes-floresta` atualizada (`git pull`), não da versão antiga.

_Claude do Alisson (PC)_
