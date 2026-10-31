# Atalho de teste da Maré de Sangue (#479): abre a v2 direto na Vila com o Nicão, perfil Baixo, modo beta tester, sem robô.
#
# Roda o código desta pasta (o checkout onde o script está; normalmente a main atualizada), não a Release.
# O save é separado (%USERPROFILE%\KIKIU-Teste\mare-appdata): não mexe no progresso do jogador.
# No notebook usa a fila do Godot (C:\Dev\KIKIU\notas\godot_fila.ps1) se ela existir; senão abre o Godot direto.
# O Godot vem de $env:KIKIU_GODOT ou de C:\Dev\Tools\Godot\Godot_v4.4.1-stable_win64.exe.
#
# O que observar: o Q começa vazio e carrega matando monstro; a primeira onda forte vem por volta de 60 s, com aviso
# antes e em dois pulsos; quem morre pelo Q Terremoto sai voando em pedaços. Usar o Q chama outra Maré uns 3 s depois da pancada (sem texto nenhum dizendo isso),
# e matar monstros da Maré enche o Q mais rápido. O aviso e o estouro da Maré têm prioridade no áudio (não somem no meio da horda). Relatar na #481.
#
# Instalar o atalho na área de trabalho (uma vez, em cada máquina):
#   powershell -ExecutionPolicy Bypass -File ferramentas\testar_mare_nicao.ps1 -Instalar

param([switch]$Instalar)

$ErrorActionPreference = "Stop"
$Raiz = Split-Path -Parent $PSScriptRoot
$Projeto = Join-Path $Raiz "jogos\hordas\projeto"
$Fila = "C:\Dev\KIKIU\notas\godot_fila.ps1"
$Godot = if ($env:KIKIU_GODOT) { $env:KIKIU_GODOT } else { "C:\Dev\Tools\Godot\Godot_v4.4.1-stable_win64.exe" }

if ($Instalar) {
	$Atalho = Join-Path ([Environment]::GetFolderPath("Desktop")) "Maré de Sangue - Nicão.lnk"
	$Shell = New-Object -ComObject WScript.Shell
	$Lnk = $Shell.CreateShortcut($Atalho)
	$Lnk.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
	$Lnk.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
	$Lnk.WorkingDirectory = $Raiz
	$Lnk.Save()
	Write-Host "Atalho criado: $Atalho"
	exit 0
}

try {
	if (-not (Test-Path -LiteralPath (Join-Path $Projeto "project.godot"))) { throw "Projeto não encontrado em $Projeto." }
	$Commit = (& git -C $Raiz log -1 --format="%h %cd" --date=format:"%d/%m %H:%M" 2>$null)
	$Ramo = (& git -C $Raiz branch --show-current 2>$null)
	Write-Host "Maré de Sangue: Nicão, Vila, perfil Baixo. Código: $Ramo $Commit"
	if ($Ramo -ne "main") { Write-Host "Atenção: esta pasta não está na main." -ForegroundColor Yellow }

	$env:APPDATA = "$env:USERPROFILE\KIKIU-Teste\mare-appdata"
	New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
	$ArgsJogo = @("--path", $Projeto, "res://v2/mundo.tscn", "--", "--mapa=cidade", "--heroi=nicao", "--perfil=baixo", "--beta-tester")
	if (Test-Path -LiteralPath $Fila) {
		Write-Host "Usando a fila do Godot. Se ela estiver cheia, aguarde."
		& powershell.exe -NoProfile -File $Fila @ArgsJogo
	} else {
		if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot 4.4.1 não encontrado em $Godot (defina KIKIU_GODOT)." }
		& $Godot @ArgsJogo
	}
	if ($LASTEXITCODE -ne 0) { throw "O Godot encerrou com código $LASTEXITCODE." }
} catch {
	Write-Host "Não foi possível abrir: $_" -ForegroundColor Red
	Read-Host "Pressione Enter para fechar"
	exit 1
}
