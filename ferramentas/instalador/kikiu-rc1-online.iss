#if Ver < 0x06030000
  #error Inno Setup 6.3 ou mais recente e necessario.
#endif

[Setup]
; Mesmo identificador e pasta do instalador Windows existente.
AppId={{674C8797-A1BF-4720-9183-379440492D13}
AppName=K.I.K.I.U
AppVerName=KIKIU | Teste da RC1
AppVersion={#AppVersion}
AppPublisher=Equipe KIKIU
AppPublisherURL=https://github.com/brenoalmeidatec/KIKIU-Survival
VersionInfoDescription=KIKIU | Instalador online de teste da RC1
VersionInfoVersion={#AppVersion}
DefaultDirName={localappdata}\Programs\KIKIU
DefaultGroupName=K.I.K.I.U
DisableWelcomePage=no
DisableProgramGroupPage=yes
UsePreviousTasks=no
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
WizardImageFile={#WizardBanner}
WizardSmallImageFile={#WizardIcon}
SetupIconFile={#IconPath}
UninstallDisplayIcon={app}\kikiu-rc1.ico
OutputDir={#OutputDir}
OutputBaseFilename=KIKIU-RC1-Setup-Online
Compression=lzma2
SolidCompression=yes
CloseApplications=no
RestartApplications=no

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Messages]
brazilianportuguese.WelcomeLabel2=Instale a publicação mais recente do KIKIU no GitHub para participar dos testes da RC1.%n%nA versão instalada aparece no final. Você pode abrir este instalador de novo para atualizar.

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "diagnostico"; Description: "Criar atalho de diagnóstico local (pede permissão a cada sessão)"; GroupDescription: "Diagnóstico opcional"; Flags: unchecked

[Files]
Source: "rc1-windows.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#IconPath}"; DestDir: "{app}"; DestName: "kikiu-rc1.ico"; Flags: ignoreversion

[Icons]
Name: "{group}\K.I.K.I.U"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\rc1-windows.ps1"" -Acao Jogar"; WorkingDir: "{app}"; IconFilename: "{app}\kikiu-rc1.ico"
Name: "{autodesktop}\K.I.K.I.U"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\rc1-windows.ps1"" -Acao Jogar"; WorkingDir: "{app}"; IconFilename: "{app}\kikiu-rc1.ico"; Tasks: desktopicon
Name: "{group}\KIKIU - Diagnóstico local"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\rc1-windows.ps1"" -Acao Diagnostico"; WorkingDir: "{app}"; IconFilename: "{app}\kikiu-rc1.ico"; Tasks: diagnostico

[InstallDelete]
Type: files; Name: "{group}\KIKIU - Diagnóstico local.lnk"; Check: not WizardIsTaskSelected('diagnostico')

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\rc1-windows.ps1"" -Acao Jogar"; WorkingDir: "{app}"; Description: "Abrir o KIKIU"; Flags: postinstall nowait unchecked skipifsilent runhidden

[UninstallDelete]
; O diretório de saves do Godot (%APPDATA%\kikiu) fica fora da instalação.
Type: filesandordirs; Name: "{app}\releases-github"

[Code]
var
  Progresso: TOutputMarqueeProgressWizardPage;
  TagInstalada: AnsiString;

procedure InitializeWizard;
begin
  Progresso := CreateOutputMarqueeProgressPage('Buscando a publicação mais recente',
    'Consultando o GitHub e verificando o pacote do Windows.');
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Codigo: Integer;
  Estado, Argumentos: String;
begin
  Result := 'Não foi possível obter e verificar a publicação mais recente. Confira a conexão e tente novamente. Se o KIKIU já estiver instalado, a versão anterior continua disponível.';
  Estado := ExpandConstant('{tmp}\release-instalada.txt');
  ExtractTemporaryFile('rc1-windows.ps1');
  Argumentos := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File ' + AddQuotes(ExpandConstant('{tmp}\rc1-windows.ps1')) +
    ' -Acao Instalar -Base ' + AddQuotes(ExpandConstant('{app}')) + ' -Estado ' + AddQuotes(Estado);
  Progresso.SetText('Aguarde a confirmação do pacote oficial.', 'brenoalmeidatec/KIKIU-Survival');
  Progresso.Show;
  try
    Progresso.Animate;
    if Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), Argumentos, '', SW_HIDE, ewWaitUntilTerminated, Codigo) then
      if (Codigo = 0) and LoadStringFromFile(Estado, TagInstalada) then
        Result := '';
  finally
    Progresso.Hide;
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
    WizardForm.FinishedLabel.Caption := 'Publicação instalada do GitHub' + #13#10 + String(TagInstalada);
end;
