; Compilar com compilar.ps1: as versoes e os caminhos vem do projeto/exportacao.
#if Ver < 0x06030000
  #error Inno Setup 6.3+ e necessario para x64compatible
#endif
#ifndef AppVersion
  #error AppVersion deve vir do config/version de project.godot
#endif
#ifndef BuildTag
  #error BuildTag deve vir do compilar.ps1 (data e commit da build)
#endif
#ifndef GameDir
  #error GameDir deve apontar para a exportacao Windows
#endif

[Setup]
; Estavel entre versoes: reinstalar atualiza a mesma entrada e o mesmo desinstalador.
AppId={{674C8797-A1BF-4720-9183-379440492D13}
AppName=K.I.K.I.U
AppVersion={#AppVersion}
AppPublisher=Equipe KIKIU
AppPublisherURL=https://github.com/brenoalmeidatec/KIKIU-Survival
VersionInfoVersion={#VersionInfoVersion}
DefaultDirName={localappdata}\Programs\KIKIU
DefaultGroupName=K.I.K.I.U
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
SetupIconFile={#IconPath}
UninstallDisplayIcon={app}\KIKIU.exe
OutputDir={#OutputDir}
OutputBaseFilename=KIKIU-Setup-{#BuildTag}
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; O preset embute o PCK no executavel. Nenhum save ou arquivo de user:// e instalado.
Source: "{#GameDir}\KIKIU.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\K.I.K.I.U"; Filename: "{app}\KIKIU.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\K.I.K.I.U"; Filename: "{app}\KIKIU.exe"; WorkingDir: "{app}"; Tasks: desktopicon

; Sem UninstallDelete: so os arquivos/atalhos registrados pelo Inno sao removidos.
; user:// (%APPDATA%\kikiu; a pasta antiga %APPDATA%\Godot\app_userdata\K.I.K.I.U e migrada pelo jogo, que a mantem) permanece intacto.
