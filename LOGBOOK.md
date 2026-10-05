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
