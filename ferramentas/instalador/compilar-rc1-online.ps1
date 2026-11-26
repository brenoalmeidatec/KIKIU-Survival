param(
    [Parameter(Mandatory = $true)][string]$ISCC,
    [Parameter(Mandatory = $true)][string]$Saida,
    [string]$Projeto = (Join-Path $PSScriptRoot '..\..\jogos\hordas\projeto')
)

$ErrorActionPreference = 'Stop'
$Projeto = (Resolve-Path -LiteralPath $Projeto).Path
$ISCC = (Resolve-Path -LiteralPath $ISCC).Path
$Saida = (New-Item -ItemType Directory -Path $Saida -Force).FullName
$versao = [regex]::Match((Get-Content -LiteralPath (Join-Path $Projeto 'project.godot') -Raw), '(?m)^config/version="([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)"\s*$').Groups[1].Value
if (-not $versao) { throw 'Versao numerica ausente no project.godot.' }

Add-Type -AssemblyName System.Drawing
$artes = Join-Path $Projeto 'assets\icone'
$temporaria = New-Item -ItemType Directory -Path (Join-Path $Saida ('.arte-' + [guid]::NewGuid().ToString('N')))
$banner = Join-Path $temporaria.FullName 'banner.bmp'
$logo = Join-Path $temporaria.FullName 'logo.bmp'
$capa = [Drawing.Image]::FromFile((Join-Path $artes 'entrada.png'))
$icone = [Drawing.Image]::FromFile((Join-Path $artes 'kikiu_256.png'))
$quadro = [Drawing.Bitmap]::new(164, 314, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
$quadroPequeno = [Drawing.Bitmap]::new(55, 55, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [Drawing.Graphics]::FromImage($quadro)
$gPequeno = [Drawing.Graphics]::FromImage($quadroPequeno)
$fundo = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(11, 21, 25))
$ouro = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(198, 144, 91))
try {
    $pixels = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.InterpolationMode = $pixels
    $gPequeno.InterpolationMode = $pixels
    $px = [Drawing.GraphicsUnit]::Pixel
    $g.DrawImage($capa, [Drawing.Rectangle]::new(0, 0, 164, 314), 190, 0, 188, 360, $px)
    $g.FillRectangle($fundo, 0, 14, 164, 50)
    $g.DrawImage($capa, [Drawing.Rectangle]::new(10, 29, 144, 17), 171, 66, 302, 36, $px)
    $g.FillRectangle($ouro, 16, 61, 132, 1)
    $g.FillRectangle($ouro, 16, 296, 132, 1)
    $gPequeno.Clear($fundo.Color)
    $gPequeno.DrawImage($icone, [Drawing.Rectangle]::new(5, 5, 45, 45), 0, 0, 256, 256, $px)
    $quadro.Save($banner, [Drawing.Imaging.ImageFormat]::Bmp)
    $quadroPequeno.Save($logo, [Drawing.Imaging.ImageFormat]::Bmp)
    $ico = Join-Path $artes 'kikiu.ico'
    & $ISCC /Qp "/DAppVersion=$versao" "/DWizardBanner=$banner" "/DWizardIcon=$logo" "/DIconPath=$ico" "/DOutputDir=$Saida" (Join-Path $PSScriptRoot 'kikiu-rc1-online.iss')
    if ($LASTEXITCODE -ne 0) { throw "Falha do Inno Setup ($LASTEXITCODE)." }
    $exe = Get-Item -LiteralPath (Join-Path $Saida 'KIKIU-RC1-Setup-Online.exe')
    if ($exe.Length -eq 0) { throw 'O instalador foi gerado vazio.' }
    Get-FileHash -LiteralPath $exe.FullName -Algorithm SHA256
} finally {
    @($ouro, $fundo, $gPequeno, $g, $quadroPequeno, $quadro, $icone, $capa) | ForEach-Object { $_.Dispose() }
    Remove-Item -LiteralPath $banner, $logo -ErrorAction SilentlyContinue
    [IO.Directory]::Delete($temporaria.FullName)
}
