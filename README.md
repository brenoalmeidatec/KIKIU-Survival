# JOGÃO GAMER

Uma **engine em Godot 4.4.1** feita para contar histórias engraçadas e verdadeiras em pixel art, e os jogos feitos com ela.
O primeiro jogo é o **JOGO da Cairu** (histórias do Breno na Faculdade Cairu, Salvador). Tudo foi feito para ser
reaproveitado: o código é genérico e o conteúdo fica em arquivos de dados.

## O que tem em cada pasta

| Pasta | O que é |
|---|---|
| `jogos/cairu/projeto/` | **Projeto Godot do JOGO da Cairu.** `scripts/` = engine (cenas, diálogo, mapas, minijogos, online até 6 pessoas), `capitulos/` = conteúdo (mapas, histórias em `.txt`/`.json`), `assets/` = imagens e sons. |
| `jogos/cairu/ENGINE.txt` | Mapa do que é **engine** (reutilizável) e do que é **conteúdo da Cairu**. Leia antes de mexer no código. |
| `jogos/cairu/LEIA-ME.txt` | Manual completo do jogo: controles, como escrever histórias, validador, modo de teste (F5/F6), online. |
| `jogos/cairu/fonte_mapas`, `fonte_audio`, `fonte_poses`, `modelos_mapa` | Fontes dos mapas, áudios e poses (scripts e arquivos que geram os assets). |
| `jogos/cairu/ferramentas/` | Atalhos `.bat` do Windows (validar história, testar cena, túnel online). |
| `jogos/cairu/grafo/` | Grafo de conhecimento do código e dos capítulos (Graphify). Os scripts usam caminhos antigos `/mnt/project-files/jogo/...`; ajuste ao rodar. |
| `jogos/cairu/referencias/` | Imagens de referência/antes e depois. |
| `jogos/hordas/projeto/` | **Protótipo "Cairu x Vírus"** (sobrevivência de hordas, Godot). Conteúdo em `dados/*.json`. Por enquanto é só **teste**, não vai ser todo da Cairu. |
| `jogos/hordas/fonte_arte/` | `gerar_arte.py`, que desenha a arte provisória. |
| `arte/personagens/` | Arte dos personagens (Breno, Nicão, Lucas, João, Matheus, Beto, Lukako, Fábio, Seu Mauro e alunos) e os scripts que a geram. |
| `arte/prompts_gemini/` | Prompts e rostos usados para gerar os retratos. |
| `arte/voz_breno/` | Gravações de voz do Breno usadas nas falas. |
| `docs/` | Análise de jogos de horda e pesquisas (assets grátis, ideias visuais GBA). |

## Como abrir no Godot

1. Baixe o **Godot 4.4.1 (padrão, não .NET)**: https://godotengine.org/download/archive/4.4.1-stable/
2. Clone este repositório.
3. No gerenciador de projetos do Godot, **Importar** e escolha `jogos/cairu/projeto/project.godot` (ou `jogos/hordas/projeto/project.godot`).
4. Na primeira vez o Godot importa as imagens e sons (demora um pouco). Depois, **F5** roda o jogo.

## Como gerar o build (.exe)

Executáveis e zips **não** ficam no Git (são grandes). Para gerar:

- No Godot: **Projeto > Exportar > Windows Desktop** (os presets já estão em `export_presets.cfg`; precisa dos modelos de exportação do 4.4.1).
- Ou, no Linux/WSL, `jogos/cairu/construir.sh` (defina `GODOT=/caminho/do/godot`), que exporta o .exe e monta o zip.

O jogo lê capítulos e áudio da pasta ao lado do .exe, então distribua o `.exe` junto com `capitulos/` e `audio/`.

## Regras para manter o repositório atualizado (vale para os Claudes das threads)

- Este repositório é a **cópia oficial para colaboração**. Toda thread que mudar o jogo (cairu, hordas, arte ou docs) deve, ao terminar, copiar **só os arquivos-fonte alterados** para a pasta correspondente aqui e fazer commit.
- Trabalho novo vai em **branch própria** (`claude/...` ou `nome/assunto`) e **Pull Request** para a `main`; não dar push direto na `main` depois do primeiro commit.
- **Nunca** versionar: `.exe`, `.zip`, `.pck`, `.godot/`, `build/`, `__pycache__`, arquivos acima de 50 MB, chaves/senhas.
- Ao terminar um bloco de trabalho, acrescente uma entrada curta no fim do `LOGBOOK.md` (feito / pendente / próximo, e recados para o outro Claude). Nunca reescreva entradas antigas.
- Mantenha engine e conteúdo separados (veja `jogos/cairu/ENGINE.txt`) e atualize o `LEIA-ME` do módulo que mudar.
- Convenção de pastas: jogos novos em `jogos/<nome>/projeto`, arte em `arte/`, documentos em `docs/`.
- Usar só os primeiros nomes dos personagens (Nicão, Lucas, João, Matheus, Beto, Lukako, Fábio, Breno), sem sobrenomes.
