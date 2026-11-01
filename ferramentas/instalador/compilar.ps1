[CmdletBinding()]
param(
    [string]$Projeto = (Join-Path $PSScriptRoot '..\..\jogos\hordas\projeto'),
    [string]$Exportado = (Join-Path $PSScriptRoot '..\..\jogos\hordas\build\win'),
    [string]$Saida = (Join-Path $PSScriptRoot '..\..\jogos\hordas\build\instalador'),
    [string]$ISCC,
    [switch]$BaixarCompilador,
    [string]$CacheCompilador = (Join-Path ([IO.Path]::GetTempPath()) 'kikiu-inno-6.7.3')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Encontrar-ISCC {
    $comando = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($comando) { return $comando.Source }
    foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)) {
        if (-not $base) { continue }
        foreach ($subpasta in @('Inno Setup 6', 'Inno Setup 7', 'Programs\Inno Setup 6', 'Programs\Inno Setup 7')) {
            $candidato = Join-Path $base "$subpasta\ISCC.exe"
            if (Test-Path -LiteralPath $candidato -PathType Leaf) { return $candidato }
        }
    }
}

$Projeto = (Resolve-Path -LiteralPath $Projeto).Path
$Exportado = (Resolve-Path -LiteralPath $Exportado).Path
$jogo = Get-Item -LiteralPath (Join-Path $Exportado 'KIKIU.exe')
if ($jogo.Length -eq 0) { throw 'A exportacao Windows esta vazia.' }
$textoProjeto = Get-Content -LiteralPath (Join-Path $Projeto 'project.godot') -Raw
$versao = [regex]::Match($textoProjeto, '(?m)^config/version="([^"]+)"\s*$').Groups[1].Value
if ($versao -notmatch '^\d+\.\d+\.\d+(?:\.\d+)?$') {
    throw 'config/version deve ter tres ou quatro componentes numericos (ex.: 0.1.0).'
}
$componentes = @($versao.Split('.') | ForEach-Object {
    if ([int]$_ -gt 65535) { throw 'Componente de config/version maior que 65535.' }
    [int]$_
})
while ($componentes.Count -lt 4) { $componentes += 0 }
$versaoWindows = $componentes -join '.'
# Mesmo sufixo do tag da Release (build-AAAA-MM-DD-commit), para o nome dizer de qual build veio.
$sha = (& git -C $PSScriptRoot rev-parse --short HEAD)
if ($LASTEXITCODE -ne 0 -or -not $sha) { $sha = 'local' }
$sufixo = "build-$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd'))-$sha"

if ($ISCC) {
    $ISCC = (Resolve-Path -LiteralPath $ISCC).Path
} else {
    $ISCC = Encontrar-ISCC
}
if (-not $ISCC -and $BaixarCompilador) {
    # Fallback oficial e fixo. /PORTABLE=1 nao registra/desinstala o compilador no Windows.
    # https://github.com/jrsoftware/issrc/blob/is-6_7_3/isportable.iss
    New-Item -ItemType Directory -Force -Path $CacheCompilador | Out-Null
    $CacheCompilador = (Resolve-Path -LiteralPath $CacheCompilador).Path
    $download = Join-Path $CacheCompilador 'innosetup-6.7.3.exe'
    $esperado = '9c73c3bae7ed48d44112a0f48e66742c00090bdb5bef71d9d3c056c66e97b732'
    if (-not (Test-Path -LiteralPath $download) -or (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $esperado) {
        Invoke-WebRequest 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_3/innosetup-6.7.3.exe' -OutFile $download
    }
    if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash -ne $esperado) { throw 'SHA-256 do Inno Setup nao confere.' }
    $assinatura = Get-AuthenticodeSignature -LiteralPath $download
    if ($assinatura.Status -ne 'Valid' -or $assinatura.SignerCertificate.Subject -notmatch 'Pyrsys B\.V\.') {
        throw 'Assinatura oficial do Inno Setup invalida.'
    }
    $destino = Join-Path $CacheCompilador 'compilador'
    $argumentos = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', '/CURRENTUSER', '/PORTABLE=1', "/DIR=`"$destino`"")
    $processo = Start-Process -FilePath $download -ArgumentList $argumentos -WindowStyle Hidden -Wait -PassThru
    if ($processo.ExitCode -ne 0) { throw "Preparacao do Inno Setup falhou: codigo $($processo.ExitCode)." }
    $ISCC = Join-Path $destino 'ISCC.exe'
}
if (-not $ISCC -or -not (Test-Path -LiteralPath $ISCC -PathType Leaf)) {
    throw 'ISCC.exe nao encontrado. Instale Inno Setup 6.3+ ou use -BaixarCompilador (portatil oficial).'
}
# ISCC/ISCmplr.dll podem ter FileVersion 0.0.0.0. O .iss valida a versao real com a variavel Ver do preprocessor.
Write-Host "Compilador: $ISCC"

New-Item -ItemType Directory -Force -Path $Saida | Out-Null
$Saida = (Resolve-Path -LiteralPath $Saida).Path
$instalador = Join-Path $Saida "KIKIU-Setup-$sufixo.exe"
if (Test-Path -LiteralPath $instalador) { Remove-Item -LiteralPath $instalador }
$icone = Join-Path $Projeto 'assets\icone\kikiu.ico'
& $ISCC /Qp "/DAppVersion=$versao" "/DVersionInfoVersion=$versaoWindows" "/DBuildTag=$sufixo" "/DGameDir=$Exportado" "/DOutputDir=$Saida" "/DIconPath=$icone" (Join-Path $PSScriptRoot 'kikiu.iss')
if ($LASTEXITCODE -ne 0) { throw "ISCC falhou: codigo $LASTEXITCODE." }
$arquivo = Get-Item -LiteralPath $instalador
if ($arquivo.Length -eq 0 -or $arquivo.VersionInfo.ProductVersion.Trim() -ne $versao -or $arquivo.VersionInfo.FileVersion.Trim() -ne $versaoWindows) {
    throw 'O instalador saiu vazio ou com versao diferente de config/version.'
}
Write-Host "Instalador validado: $instalador ($($arquivo.Length) bytes)"
Write-Host "SHA-256: $((Get-FileHash -LiteralPath $instalador -Algorithm SHA256).Hash)"
