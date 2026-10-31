# Este teste instala/desinstala no perfil descartavel do GitHub Actions, nunca no perfil de desenvolvimento.
[CmdletBinding()]
param(
    [string]$Projeto = (Join-Path $PSScriptRoot '..\..\jogos\hordas\projeto'),
    [string]$Exportado = (Join-Path $PSScriptRoot '..\..\jogos\hordas\build\win'),
    [string]$Saida = (Join-Path $PSScriptRoot '..\..\jogos\hordas\build\instalador')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Teste de instalacao permitido somente no runner descartavel do GitHub Actions.' }
$instaladores = @(Get-ChildItem -LiteralPath $Saida -Filter 'KIKIU-Setup-*.exe')
if ($instaladores.Count -ne 1) { throw "Esperava um instalador em $Saida, achei $($instaladores.Count)." }
$instalador = $instaladores[0].FullName
$pastaApp = Join-Path $env:LOCALAPPDATA 'Programs\KIKIU'
$pastaMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'K.I.K.I.U'
$atalhoMenu = Join-Path $pastaMenu 'K.I.K.I.U.lnk'
$atalhoDesktop = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'K.I.K.I.U.lnk'
$chave = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{674C8797-A1BF-4720-9183-379440492D13}_is1'
$registroUsuario = [Microsoft.Win32.RegistryKey]::OpenBaseKey('CurrentUser', 'Registry64')
$registroMaquina = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64')
$logs = Join-Path $env:RUNNER_TEMP 'kikiu-installer-qa'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

function Confirmar($condicao, [string]$mensagem) {
    if (-not $condicao) { throw $mensagem }
}
function Executar-Setup([string]$executavel, [string[]]$extras, [string]$nomeLog) {
    $argumentos = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/LOG=`"$(Join-Path $logs $nomeLog)`"") + $extras
    $processo = Start-Process -FilePath $executavel -ArgumentList $argumentos -WindowStyle Hidden -Wait -PassThru
    Confirmar ($processo.ExitCode -eq 0) "$executavel terminou com codigo $($processo.ExitCode)."
}
function Conferir-Atalho([string]$caminho) {
    Confirmar (Test-Path -LiteralPath $caminho) "Atalho ausente: $caminho"
    $atalho = (New-Object -ComObject WScript.Shell).CreateShortcut($caminho)
    Confirmar ($atalho.TargetPath -eq (Join-Path $pastaApp 'KIKIU.exe')) "Destino incorreto: $caminho"
    Confirmar ($atalho.WorkingDirectory -eq $pastaApp) "Diretorio incorreto: $caminho"
}

# Um perfil que ja tenha o jogo nunca pode ser sobrescrito por este teste.
Confirmar (-not (Test-Path -LiteralPath $pastaApp)) 'KIKIU ja instalado; abortando sem alterar a instalacao.'
Confirmar ($null -eq $registroUsuario.OpenSubKey($chave)) 'Registro de instalacao existente; abortando.'
Confirmar ($null -eq $registroMaquina.OpenSubKey($chave)) 'Instalacao global existente; abortando.'
Confirmar (-not (Test-Path -LiteralPath $pastaMenu)) 'Menu existente; abortando.'
Confirmar (-not (Test-Path -LiteralPath $atalhoDesktop)) 'Atalho existente; abortando.'
# O payload pode ter centenas de MB; ler em blocos ate o manifesto do loader, antes do jogo comprimido.
$fluxo = [IO.File]::OpenRead($instalador)
$buffer = New-Object byte[] 65536
$resto = ''
$nivelExecucao = ''
try {
    while (($lidos = $fluxo.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $trecho = $resto + [Text.Encoding]::UTF8.GetString($buffer, 0, $lidos)
        if ($trecho -match 'requestedExecutionLevel\s+level="([^"]+)"') { $nivelExecucao = $Matches[1]; break }
        $resto = $trecho.Substring([Math]::Max(0, $trecho.Length - 256))
    }
} finally { $fluxo.Dispose() }
Confirmar ($nivelExecucao -eq 'asInvoker') 'O instalador nao declara execucao sem elevacao.'

$pastaSave = Join-Path $env:APPDATA 'kikiu'
New-Item -ItemType Directory -Force -Path $pastaSave | Out-Null
$sentinela = Join-Path $pastaSave "qa379-$([guid]::NewGuid().ToString('N')).txt"
Set-Content -LiteralPath $sentinela -Value 'Save que a desinstalacao deve preservar.' -Encoding utf8
$hashSave = (Get-FileHash -LiteralPath $sentinela -Algorithm SHA256).Hash
$desinstalador = Join-Path $pastaApp 'unins000.exe'
try {
    Executar-Setup $instalador @() 'instalar.log'
    $instalado = Join-Path $pastaApp 'KIKIU.exe'
    Confirmar ((Get-FileHash -LiteralPath $instalado).Hash -eq (Get-FileHash -LiteralPath (Join-Path $Exportado 'KIKIU.exe')).Hash) 'O jogo instalado difere do exportado.'
    Confirmar (Test-Path -LiteralPath $desinstalador) 'Desinstalador nao foi criado.'
    $entrada = $registroUsuario.OpenSubKey($chave)
    Confirmar ($null -ne $entrada) 'A instalacao nao foi registrada em HKCU.'
    try {
        Confirmar ($entrada.GetValue('DisplayVersion') -eq $versao) 'Versao do registro diferente do projeto.'
        Confirmar ($entrada.GetValue('InstallLocation').TrimEnd('\') -eq $pastaApp) 'Pasta padrao nao e LocalAppData\Programs\KIKIU.'
    } finally { $entrada.Dispose() }
    Confirmar ($null -eq $registroMaquina.OpenSubKey($chave)) 'A instalacao criou registro global em HKLM.'
    Conferir-Atalho $atalhoMenu
    Confirmar (-not (Test-Path -LiteralPath $atalhoDesktop)) 'Atalho de desktop foi criado sem escolher a opcao.'

    # Reinstalar a mesma AppId deve atualizar no lugar e permitir a opcao de desktop.
    Executar-Setup $instalador @('/TASKS=desktopicon') 'reinstalar.log'
    Conferir-Atalho $atalhoMenu
    Conferir-Atalho $atalhoDesktop
    $provaEscrita = Join-Path $pastaApp 'qa379-atualizador.tmp'
    Set-Content -LiteralPath $provaEscrita -Value 'O atualizador pode gravar nesta pasta.'
    Remove-Item -LiteralPath $provaEscrita
    Executar-Setup $desinstalador @() 'desinstalar.log'
    Confirmar (-not (Test-Path -LiteralPath $instalado)) 'Desinstalacao deixou o executavel instalado.'
    Confirmar (-not (Test-Path -LiteralPath $atalhoMenu)) 'Desinstalacao deixou o atalho do menu.'
    Confirmar (-not (Test-Path -LiteralPath $atalhoDesktop)) 'Desinstalacao deixou o atalho do desktop.'
    Confirmar ($null -eq $registroUsuario.OpenSubKey($chave)) 'Desinstalacao deixou registro em HKCU.'
    Confirmar ((Get-FileHash -LiteralPath $sentinela -Algorithm SHA256).Hash -eq $hashSave) 'A desinstalacao alterou o save.'
    Write-Host 'Instalador: pasta por usuario, versao, reinstalacao, atalhos opcionais e preservacao do save OK.'
} finally {
    if (Test-Path -LiteralPath $desinstalador) { Executar-Setup $desinstalador @() 'limpeza.log' }
    if (Test-Path -LiteralPath $sentinela) { Remove-Item -LiteralPath $sentinela }
    $registroUsuario.Dispose()
    $registroMaquina.Dispose()
}
