# 🤝 Como colaborar

> [!IMPORTANT]
> Estas regras valem pra todo mundo, **inclusive pros Claudes das threads** (a rotina deles está no [`CLAUDE.md`](CLAUDE.md)).

## 📂 Onde fica cada coisa

| Pasta | O que é | Etiqueta |
|---|---|---|
| [`jogos/hordas/`](jogos/hordas/README.md) | **K.I.K.I.U** (Godot 4.4.1): o jogo ativo, foco do repositório | `kikiu` |
| `jogos/hordas-vita/` | Port do K.I.K.I.U para **PS Vita** (Godot 3 + godot-vita), experimental; por enquanto só na branch `alisson/vita-piloto` | `vita` |
| [`jogos/cairu/`](jogos/cairu/README.md) | **JOGO da Cairu**: pausado, só muda se o Breno pedir | `cairu` |
| `arte/personagens/` | Arte dos personagens (Breno, Nicão, Lucas, João, Matheus, Beto, Lukako, Fábio, Seu Mauro e alunos) e os scripts que a geram | |
| `arte/prompts_gemini/` | Prompts e rostos usados pra gerar os retratos | |
| `arte/voz_breno/` | Gravações de voz do Breno usadas nas falas | |
| [`docs/`](docs/README.md) | Desenho do jogo, online, visual, análises e pesquisas | |
| [`LOGBOOK.md`](LOGBOOK.md) | Diário do projeto: o que foi feito, o que falta, recados | |

Cada pasta de jogo é um projeto Godot independente: abrir um não importa nem exporta nada dos outros.

## 📏 Regras

- 🏠 Este repositório é a **cópia oficial pra colaboração**. Toda thread que mudar o jogo (cairu, hordas, arte ou docs) deve, ao terminar, copiar **só os arquivos-fonte alterados** pra pasta correspondente aqui e fazer commit.
- 🌿 Trabalho novo vai em **branch própria** (`claude/...` ou `nome/assunto`) e **Pull Request** pra `main`; não dar push direto na `main`.
- 🏷️ Toda issue e PR leva a etiqueta do projeto (`kikiu`, `vita` ou `cairu`), e o título da issue começa com o nome do projeto.
- 🧹 Ao mesclar, apague a branch (`gh pr merge --squash --delete-branch`). O PR guarda o histórico e tem o botão "Restore branch".
- 🚫 **Nunca** versionar: `.exe`, `.zip`, `.pck`, `.godot/`, `build/`, `__pycache__`, arquivos acima de 50 MB, chaves e senhas.
- 📓 Ao terminar um bloco de trabalho, acrescente uma entrada curta no fim do `LOGBOOK.md` (feito / pendente / próximo, e recados pro outro Claude). Nunca reescreva entradas antigas.
- ✅ O Alisson (e o Claude dele) podem fazer o merge dos próprios PRs na `main` quando não houver erro nem risco: sem conflito, testado no Godot (2 instâncias se mexer no online), sem .exe/zip/credencial e com entrada no `LOGBOOK.md`. Na dúvida, deixe aberto.
- 🧩 Mantenha engine e conteúdo separados (veja `jogos/cairu/ENGINE.txt` e `jogos/hordas/projeto/dados/`) e atualize o README ou o `LEIA-ME` do módulo que mudar.
- 📖 O [README principal](README.md) é a vitrine do projeto: só apresentação, sem detalhe técnico nem processo interno. O técnico vai no README de cada pasta.
- 📁 Convenção de pastas: jogos novos em `jogos/<nome>/projeto`, arte em `arte/`, documentos em `docs/`.
- 🏷️ Usar só os primeiros nomes dos personagens (Nicão, Lucas, João, Matheus, Beto, Lukako, Fábio, Breno), sem sobrenomes.
