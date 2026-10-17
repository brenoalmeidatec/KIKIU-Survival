# Lançador de teste do K.I.K.I.U com atualização automática (Windows).
#
# Toda vez que abre, pergunta ao GitHub qual é a build mais nova (a Release "Latest" que o CI publica a cada merge na main).
# Se for diferente da que está na máquina, baixa o zip do Windows, descompacta e abre o jogo. Sem internet, abre a última baixada.
# Tudo fica em %LOCALAPPDATA%\KIKIU-Teste (builds\<tag>, atual.txt, kikiu.ico); guarda a build atual e a anterior.
#
# Instalar o atalho na área de trabalho (uma vez):
#   powershell -ExecutionPolicy Bypass -File ferramentas\jogar_kikiu.ps1 -Instalar
# Depois é só dar duplo clique em "KIKIU (teste)".

param([switch]$Instalar, [switch]$SemAbrir)  # -SemAbrir: só baixa e confere (teste)

$ErrorActionPreference = "Stop"
$Repo = "brenoalmeidatec/KIKIU-Survival"
$Base = "$env:LOCALAPPDATA\KIKIU-Teste"
$Builds = "$Base\builds"
$ArqAtual = "$Base\atual.txt"
New-Item -ItemType Directory -Force -Path $Builds | Out-Null
# tudo o que acontece vai para ultimo_log.txt (a janela do atalho fecha sozinha)
try { Start-Transcript -Path "$Base\ultimo_log.txt" -Force | Out-Null } catch {}

function Avisar([string]$texto) {
	Add-Type -AssemblyName System.Windows.Forms
	[System.Windows.Forms.MessageBox]::Show($texto, "KIKIU (teste)") | Out-Null
}

# qualquer erro não tratado aparece numa janela, com o caminho do log
trap {
	Avisar "Deu erro no atalho:`n`n$($_.Exception.Message)`n`nLinha $($_.InvocationInfo.ScriptLineNumber). Log: $Base\ultimo_log.txt"
	exit 1
}

if ($Instalar) {
	$destino = Join-Path $Base "jogar_kikiu.ps1"
	Copy-Item -Force $PSCommandPath $destino
	$ico = Join-Path $Base "kikiu.ico"
	$icoRepo = Join-Path $PSScriptRoot "..\jogos\hordas\projeto\assets\icone\kikiu.ico"
	if (Test-Path $icoRepo) { Copy-Item -Force $icoRepo $ico }
	$sh = New-Object -ComObject WScript.Shell
	$lnk = $sh.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "KIKIU (teste).lnk"))
	$lnk.TargetPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
	$lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File `"$destino`""
	$lnk.WorkingDirectory = $Base
	if (Test-Path $ico) { $lnk.IconLocation = $ico }
	$lnk.Description = "K.I.K.I.U: baixa a build mais nova do GitHub e abre o jogo"
	$lnk.Save()
	Write-Host "Atalho 'KIKIU (teste)' criado na área de trabalho."
	exit 0
}

# 1) Qual é a build mais nova?
$tag = $null
$url = $null
try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -TimeoutSec 10 -Headers @{ "User-Agent" = "kikiu-lancador" }
	$asset = $rel.assets | Where-Object { $_.name -like "*windows*.zip" } | Select-Object -First 1
	if ($asset) {
		$tag = $rel.tag_name
		$url = $asset.browser_download_url
	}
} catch {
	Write-Host "Sem resposta do GitHub ($($_.Exception.Message)); vou abrir a última build baixada."
}

$atual = if (Test-Path $ArqAtual) { (Get-Content $ArqAtual -Raw).Trim() } else { "" }

# 2) Baixa se for nova
if ($tag -and ($tag -ne $atual -or -not (Test-Path (Join-Path $Builds $tag)))) {
	Write-Host "Baixando a build $tag ..."
	$zip = Join-Path $Base "download.zip"
	$tmp = Join-Path $Builds "$tag.tmp"
	try {
		& curl.exe -L --fail --retry 3 --silent --show-error -o $zip $url
		if ($LASTEXITCODE -ne 0) { throw "curl saiu com código $LASTEXITCODE" }
		if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
		Expand-Archive -Path $zip -DestinationPath $tmp -Force
		$final = Join-Path $Builds $tag
		if (Test-Path $final) { Remove-Item -Recurse -Force $final }
		Rename-Item $tmp $tag
		Remove-Item -Force $zip
		Set-Content -Path $ArqAtual -Value $tag -Encoding ASCII
		# guarda só a build atual e a anterior
		$anterior = $atual
		Get-ChildItem $Builds -Directory | Where-Object { $_.Name -ne $tag -and $_.Name -ne $anterior } | Remove-Item -Recurse -Force
		$atual = $tag
	} catch {
		Write-Host "Falhou o download: $($_.Exception.Message)"
	}
}

# 3) Abre o jogo
if (-not $atual -or -not (Test-Path (Join-Path $Builds $atual))) {
	Avisar "Não consegui baixar o jogo e não há nenhuma build guardada. Confira a internet e tente de novo."
	exit 1
}
$exe = Get-ChildItem (Join-Path $Builds $atual) -Recurse -Filter *.exe |
	Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1
if (-not $exe) {
	Avisar "A build $atual não tem o .exe do jogo. Avise no GitHub (issue #153)."
	exit 1
}
if ($SemAbrir) {
	Write-Host "Pronto para jogar: $($exe.FullName)"
	exit 0
}
Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName
