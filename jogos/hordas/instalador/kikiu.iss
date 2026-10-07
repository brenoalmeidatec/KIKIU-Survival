; K.I.K.I.U: instalador Windows (Inno Setup 6). Quem compila é o gerar_instalador.sh, que passa /DVERSAO=<versão> lida de
; projeto/project.godot (application/config/version) e exige que ../build/KIKIU.exe já esteja exportado.
; Instalação por usuário: não pede administrador e fica em %LOCALAPPDATA%\Programs\KIKIU.

#ifndef VERSAO
  #define VERSAO "0.1.0"
#endif
#ifndef COMMIT
  #define COMMIT "?"
#endif

[Setup]
AppId={{7B26EDFD-7BCD-400E-948C-05952DAA21D3}
AppName=K.I.K.I.U
AppVersion={#VERSAO}
AppVerName=K.I.K.I.U {#VERSAO}
AppPublisher=Breno e Alisson
AppPublisherURL=https://github.com/brenoalmeidatec/KIKIU-Survival
AppComments=Knights In Kaos, Infinite Upgrades
DefaultDirName={localappdata}\Programs\KIKIU
DefaultGroupName=K.I.K.I.U
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\build\instalador
OutputBaseFilename=KIKIU-Setup-{#VERSAO}-{#COMMIT}
SetupIconFile=..\projeto\assets\icone\kikiu.ico
UninstallDisplayIcon={app}\kikiu.ico
UninstallDisplayName=K.I.K.I.U
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
WizardImageFile=wizard_164x314.bmp,wizard_328x628.bmp
WizardSmallImageFile=small_55x58.bmp,small_110x116.bmp
VersionInfoVersion={#VERSAO}.0
VersionInfoCompany=Breno e Alisson
VersionInfoProductName=K.I.K.I.U
VersionInfoDescription=K.I.K.I.U: instalador

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "atalhoarea"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked

[Files]
Source: "..\build\KIKIU.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\projeto\assets\icone\kikiu.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\K.I.K.I.U"; Filename: "{app}\KIKIU.exe"; IconFilename: "{app}\kikiu.ico"
Name: "{group}\Desinstalar K.I.K.I.U"; Filename: "{uninstallexe}"; IconFilename: "{app}\kikiu.ico"
Name: "{autodesktop}\K.I.K.I.U"; Filename: "{app}\KIKIU.exe"; IconFilename: "{app}\kikiu.ico"; Tasks: atalhoarea

[Run]
Filename: "{app}\KIKIU.exe"; Description: "Abrir o K.I.K.I.U"; Flags: nowait postinstall skipifsilent
