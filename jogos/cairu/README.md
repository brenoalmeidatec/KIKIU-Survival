# 🎓 JOGO da Cairu — guia técnico

> Histórias engraçadas e verdadeiras do Breno na Faculdade Cairu, em Salvador.

<p align="center">
  <img src="referencias/beto_cismado.png" alt="Diálogo com o Beto" width="720">
</p>

- 💬 **Cenas e diálogos com rosto e voz**, escritos numa sintaxe curta em `.txt` (dá pra escrever história sem programar).
- 🕹️ **Minijogos** dentro das histórias: religar cabos, destravar impressora, QW das antigas e mais.
- ✅ **Validador de história** e modo de teste (F5/F6) pra conferir as cenas antes de jogar.
- 🌐 **Online até 6 pessoas**, vendo as cenas juntos.
- ♻️ **Engine separada do conteúdo:** um jogo novo reaproveita o código e troca só os dados ([`ENGINE.txt`](ENGINE.txt)).

<p align="center">
  <img src="referencias/minijogos_novos.png" alt="Minijogos" width="720">
</p>

## 🚀 Como rodar

Com o **Godot 4.4.1 (padrão, não .NET)**, importe `jogos/cairu/projeto/project.godot` no gerenciador de projetos e aperte **F5**. Na primeira vez o Godot importa imagens e sons.

## 📦 Gerar o executável (.exe)

- 🛠️ No Godot: **Projeto › Exportar › Windows Desktop** (o preset já está em `export_presets.cfg`; precisa dos modelos de exportação do 4.4.1).
- 🐧 Ou, no Linux/WSL, `construir.sh` (defina `GODOT=/caminho/do/godot`), que exporta o .exe e monta o zip.

> [!NOTE]
> O jogo lê capítulos e áudio da pasta ao lado do .exe, então distribua o `.exe` junto com `capitulos/` e `audio/`.

## 📂 Estrutura

| Pasta | O que é |
|---|---|
| `projeto/` | **Projeto Godot.** `scripts/` = engine (cenas, diálogo, mapas, minijogos, online até 6 pessoas), `capitulos/` = conteúdo (mapas, histórias em `.txt`/`.json`), `assets/` = imagens e sons. |
| `ENGINE.txt` | Mapa do que é **engine** (reutilizável) e do que é **conteúdo da Cairu**. Leia antes de mexer no código. |
| `LEIA-ME.txt` | Manual completo do jogo: controles, como escrever histórias, validador, modo de teste (F5/F6), online. |
| `fonte_mapas`, `fonte_audio`, `fonte_poses`, `modelos_mapa` | Fontes dos mapas, áudios e poses (scripts e arquivos que geram os assets). |
| `ferramentas/` | Atalhos `.bat` do Windows (validar história, testar cena, túnel online). |
| `grafo/` | Grafo de conhecimento do código e dos capítulos (Graphify). Rode a partir da raiz do repo (caminhos relativos). |
| `referencias/` | Imagens de referência e de antes e depois. |
