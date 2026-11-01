# KIKIU em AppImage (Linux)

`KIKIU-build-<AAAA-MM-DD>-<commit>-x86_64.AppImage` é o jogo num arquivo só, sem instalar nada: o mesmo executável do ZIP Linux, empacotado
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

## Atalho do testador (abre sempre a build mais nova)

É o par Linux do atalho "KIKIU (teste)" do Windows (`ferramentas/jogar_kikiu.ps1`). A cada clique ele pergunta ao GitHub
qual é a Release mais nova, baixa o AppImage se ele mudou e abre o jogo. Sem internet, abre o último baixado. Tudo fica
em `~/KIKIU-Teste`: `builds/<tag>.AppImage` (guarda só a atual e a anterior), `atual.txt` e `ultimo_log.txt`, que mostra
o que aconteceu no último clique.

Instalar, uma vez só, num terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/brenoalmeidatec/KIKIU-Survival/main/ferramentas/jogar_kikiu.sh -o /tmp/jogar_kikiu.sh
bash /tmp/jogar_kikiu.sh --instalar
```

Isso cria o atalho "KIKIU (teste)" na área de trabalho e no menu de aplicativos, com o ícone do jogo. Depois é só clicar.
No Arch, instale antes o FUSE 2 com `sudo pacman -S fuse2`. Sem ele o atalho ainda abre, mas extrai o jogo a cada vez e
demora mais.

Se o atalho da área de trabalho não abrir:
- **GNOME:** clique com o botão direito no atalho e escolha "Permitir iniciar".
- **KDE:** na primeira vez ele pergunta se confia no arquivo; responda que sim.
- **XFCE:** na primeira vez ele pede para marcar o atalho como executável; aceite.
- Pelo menu de aplicativos ("KIKIU (teste)") ele funciona em qualquer ambiente.
- Para conferir sem abrir o jogo, rode no terminal `~/KIKIU-Teste/jogar_kikiu.sh --sem-abrir` e depois
  `cat ~/KIKIU-Teste/ultimo_log.txt`.

Desinstalar: apague `~/KIKIU-Teste`, `~/.local/share/applications/kikiu-teste.desktop` e o atalho da área de trabalho.

## Para quem mantém (CI)

`montar.sh` monta o AppDir, baixa o `appimagetool` 1.9.1 (URL fixa, SHA-256 conferido) e gera o arquivo;
`testar.sh` roda o AppImage com `--headless --quit-after 120`. Ambos são chamados pelo workflow `Release` logo
depois do export Linux. A versão vem do `config/version` do `project.godot`.
