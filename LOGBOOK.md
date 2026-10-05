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
