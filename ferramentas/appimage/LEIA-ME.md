# KIKIU em AppImage (Linux)

`KIKIU-<versão>-x86_64.AppImage` é o jogo num arquivo só, sem instalar nada: o mesmo executável do ZIP Linux, empacotado
para abrir com dois cliques.

## Como rodar

1. Baixe o `.AppImage` da Release.
2. Dê permissão de execução: `chmod +x KIKIU-*-x86_64.AppImage` (ou botão direito, Propriedades, Permissões, "Permitir
   executar como programa").
3. Dois cliques no arquivo, ou `./KIKIU-*-x86_64.AppImage` no terminal.

Os saves ficam em `~/.local/share/kikiu` (ou `$XDG_DATA_HOME/kikiu`), fora do AppImage; quem tinha save em `~/.local/share/godot/app_userdata/K.I.K.I.U` tem a pasta copiada para lá no primeiro boot, e a antiga fica como backup: apagar ou trocar o arquivo não
perde o progresso.

## Item no menu de aplicativos

O AppImage não se instala sozinho. Para ganhar atalho e ícone no menu, use o **AppImageLauncher** ou o **Gear Lever**
(Flatpak): abra o arquivo com eles e escolha integrar ao sistema.

## Se não abrir

- Sem FUSE (`libfuse2`, comum no Ubuntu 22.04+): rode `./KIKIU-*-x86_64.AppImage --appimage-extract-and-run`.
- Tela preta ou erro de OpenGL: passe o renderizador na linha de comando,
  `./KIKIU-*-x86_64.AppImage --rendering-driver opengl3`. Qualquer argumento depois do nome vai direto para o jogo.

## Para quem mantém (CI)

`montar.sh` monta o AppDir, baixa o `appimagetool` 1.9.1 (URL fixa, SHA-256 conferido) e gera o arquivo;
`testar.sh` roda o AppImage com `--headless --quit-after 120`. Ambos são chamados pelo workflow `Release` logo
depois do export Linux. A versão vem do `config/version` do `project.godot`.
