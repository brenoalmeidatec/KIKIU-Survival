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
