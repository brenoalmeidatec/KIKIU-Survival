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
