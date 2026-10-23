# Instalador e smoke da Release (#379)

O workflow `Release` continua exportando os ZIPs portáteis Windows, Linux e Web. O job Windows também gera
`KIKIU-Setup-<config/version>.exe`, publicado como quarto asset nas duas Releases existentes. Nas branches, todos ficam
somente nos artefatos do run; o job de publicação exige `refs/heads/main`.

O instalador usa Inno Setup 6.3+, instala sem pedir administrador em `%LOCALAPPDATA%\Programs\KIKIU` e cria um atalho no
menu Iniciar. O atalho na área de trabalho é opcional e começa desmarcado. A pasta é gravável pelo usuário para permitir
atualizações. A `AppId` é fixa: uma nova versão reutiliza a instalação e a entrada de desinstalação.

O desinstalador remove o executável e os atalhos que instalou. Não contém `UninstallDelete` nem toca em `user://`, que
neste projeto fica em `%APPDATA%\kikiu` (a pasta padrão do Godot, `%APPDATA%\Godot\app_userdata\K.I.K.I.U`, é copiada para lá no primeiro boot e fica como backup). Saves e configurações sobrevivem à desinstalação.
O preset Windows embute o PCK; se a exportação passar a exigir arquivos auxiliares, eles também precisarão entrar em
`[Files]` e no teste de instalação.

## Compilar depois da exportação Windows

Na raiz do repositório, com PowerShell:

```powershell
.\ferramentas\instalador\compilar.ps1
# Sem Inno Setup instalado: download oficial, SHA-256 fixo e assinatura verificados, modo portátil em TEMP.
.\ferramentas\instalador\compilar.ps1 -BaixarCompilador
# Ou indique um compilador portátil existente:
.\ferramentas\instalador\compilar.ps1 -ISCC C:\QA\Inno\ISCC.exe
```

A versão vem de `jogos/hordas/projeto/project.godot`, `config/version` (três ou quatro componentes numéricos de 0 a 65535).
O script verifica o código de saída do compilador, tamanho e versão do instalador. O fallback fixado é o Inno Setup
6.7.3 oficial, em modo `/CURRENTUSER /PORTABLE=1`, sem registrar o compilador ou alterar o PATH. Primeiro é usado o ISCC
disponível no runner; o fallback só baixa quando ele não é encontrado.

## Validação no CI e execução manual da branch

O job Windows compila e instala no perfil descartável do runner, confere hash do jogo, versão/registro em HKCU, pasta
padrão, menu Iniciar, desktop desmarcado e depois selecionado, reinstalação e desinstalação com um save sentinela.
`testar.ps1` recusa execução fora do GitHub Actions para não instalar no perfil de desenvolvimento. Os logs do Inno
ficam no artefato `installer-smoke-logs`, inclusive se o teste falhar.

O job Ubuntu verifica o ELF x86_64 e suas dependências, copia somente o binário Linux para uma pasta temporária e abre
a cena principal em modo headless por 120 frames, com timeout de 90 segundos. Os diretórios XDG ficam isolados; o log
é publicado em `linux-smoke-logs`. Esse smoke verifica inicialização/scripts/recursos, não renderização ou controles.
Wine não é necessário: o Linux exportado executa nativamente e a instalação Windows é testada no Windows.

Depois do push da branch, disparar sem publicar Release:

```powershell
gh workflow run release.yml --repo brenoalmeidatec/KIKIU-Survival --ref codex/instalador-379
gh run list --repo brenoalmeidatec/KIKIU-Survival --workflow release.yml --branch codex/instalador-379
```

No run, baixar `windows-installer` para testar a interface do instalador e os três artefatos portáteis para testar o jogo.
O job `publicar` deve aparecer como ignorado na branch. Um dispatch na **main** mantém a publicação normal.

Referências primárias:

- [Inno: privilégios por usuário](https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm),
  [constantes de pastas](https://jrsoftware.org/ishelp/topic_consts.htm),
  [compilador e códigos de saída](https://jrsoftware.org/ishelp/topic_compilercmdline.htm),
  [remoção adicional de arquivos](https://jrsoftware.org/ishelp/topic_uninstalldeletesection.htm).
- [Inno 6.7.3 oficial](https://github.com/jrsoftware/issrc/releases/tag/is-6_7_3),
  [modo portátil oficial](https://github.com/jrsoftware/issrc/blob/is-6_7_3/isportable.iss),
  [verificação do download](https://jrsoftware.org/isdl-verify.php).
- [Software do runner Windows 2025](https://github.com/actions/runner-images/blob/main/images/windows/Windows2025-Readme.md)
  e [opções de linha de comando do Godot 4.4](https://docs.godotengine.org/en/4.4/tutorials/editor/command_line_tutorial.html).
