param(
    [Parameter(Mandatory = $true)][string]$ISCC,
    [Parameter(Mandatory = $true)][string]$Saida,
    [string]$Projeto
)

$ErrorActionPreference = 'Stop'
if (-not $Projeto) { $Projeto = Join-Path $PSScriptRoot '..\..\jogos\hordas\projeto' }
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
$capa = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'arte\capa-rc1.png'))
$icone = [Drawing.Image]::FromFile((Join-Path $artes 'kikiu_256.png'))
$fontes = [Drawing.Text.PrivateFontCollection]::new()
$fontes.AddFontFile((Join-Path $Projeto 'assets\fonte\jersey10\Jersey10-Regular.ttf'))
$fonteTitulo = [Drawing.Font]::new($fontes.Families[0], 30, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
$quadro = [Drawing.Bitmap]::new(164, 314, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
$quadroPequeno = [Drawing.Bitmap]::new(55, 55, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [Drawing.Graphics]::FromImage($quadro)
$gPequeno = [Drawing.Graphics]::FromImage($quadroPequeno)
$fundo = [Drawing.Color]::FromArgb(22, 29, 27)
$bronze = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(182, 140, 96))
$ouro = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(221, 185, 133))
$centro = [Drawing.StringFormat]::new()
$centro.Alignment = [Drawing.StringAlignment]::Center
try {
    $pixels = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.InterpolationMode = $pixels
    $gPequeno.InterpolationMode = $pixels
    $px = [Drawing.GraphicsUnit]::Pixel
    # Recorte central na proporção do assistente. O céu escuro da arte deixa o título legível.
    $larguraCorte = [Math]::Min($capa.Width, [int]($capa.Height * $quadro.Width / $quadro.Height))
    $alturaCorte = [Math]::Min($capa.Height, [int]($capa.Width * $quadro.Height / $quadro.Width))
    $corteX = [int](($capa.Width - $larguraCorte) / 2)
    $corteY = [int](($capa.Height - $alturaCorte) / 2)
    $g.DrawImage($capa, [Drawing.Rectangle]::new(0, 0, $quadro.Width, $quadro.Height), $corteX, $corteY, $larguraCorte, $alturaCorte, $px)
    $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::SingleBitPerPixelGridFit
    $g.DrawString('K.I.K.I.U', $fonteTitulo, $ouro, 82.0, 12.0, $centro)
    $g.FillRectangle($bronze, 52, 48, 60, 1)
    $g.FillRectangle($bronze, 52, 299, 60, 1)
    $gPequeno.Clear($fundo)
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
    @($centro, $ouro, $bronze, $gPequeno, $g, $quadroPequeno, $quadro, $fonteTitulo, $fontes, $icone, $capa) | ForEach-Object { $_.Dispose() }
    Remove-Item -LiteralPath $banner, $logo -ErrorAction SilentlyContinue
    [IO.Directory]::Delete($temporaria.FullName)
}
