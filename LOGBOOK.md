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
