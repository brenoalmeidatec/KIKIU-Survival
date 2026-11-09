# Roda testes do Godot (headless) ou um comando qualquer DENTRO do Windows Sandbox, sem tocar no Windows de quem roda.
# Regra do repositório (docs/WINDOWS_SANDBOX.md): tudo o que não precisa de aceleração gráfica roda aqui.
#
# Exemplos (da raiz do repositório, num PowerShell):
#   powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Testes v2_martelo,v2_teia_lento
#   powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Comando "%GODOT% --headless --path . res://testes/v2_combate.tscn"
#   powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Ferramentas C:\Python312 -Comando "python C:\trabalho\ferramentas\playtest_v2.py --herois hazaki --mapas floresta --sementes 1"
#   powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Janela        # só abre com o projeto copiado, para mexer à mão
#
# Como funciona: o projeto (jogos/hordas/projeto), as ferramentas/ e a pasta do Godot entram SÓ LEITURA; o dentro.ps1 copia o
# projeto e as ferramentas para C:\trabalho lá dentro (a mesma estrutura do repositório). Só a pasta de saída (logs, resumo,
# o que o comando gravar em C:\kikiu\saida) volta para o Windows de verdade. Ao fechar, a sandbox apaga tudo.
# Funciona no Windows 10 e no 11 (não depende do wsb.exe do 11 24H2).
# Códigos de saída: 0 passou, 1 falhou, 2 falta Sandbox ou Godot, 3 já há uma sandbox aberta, 4 passou do -LimiteMin,
# 5 a sandbox fechou sem terminar.

param(
	[string[]]$Testes = @(),  # nomes das cenas em jogos/hordas/projeto/testes, sem .tscn (aceita "a,b" numa string só)
	[string]$Comando = "",  # comando de cmd rodado em C:\trabalho\jogos\hordas\projeto; %GODOT% = o Godot console de dentro
	[string]$Godot = "",  # o Godot_v4.4.1-stable_win64_console.exe do host (padrão: $env:KIKIU_GODOT ou E:\Dev\Godot_4.4.1)
	[string]$Saida = "",  # pasta de saída no host (padrão: %USERPROFILE%\KIKIU-Sandbox\<data-hora>); é limpa antes de rodar
	[string[]]$Ferramentas = @(),  # pastas portáteis do host (Python, MinGit...) que entram SÓ LEITURA e vão para o PATH lá dentro
	[switch]$Rede,  # liga a rede dentro da sandbox (desligada por padrão)
	[switch]$Janela,  # não fecha no fim (para olhar ou mexer à mão)
	[int]$MemoriaMB = 6144,
	[int]$LimiteMin = 40,  # prazo total; o comando livre tem esse prazo, cada teste tem 15 min e o import 10 min
	[int]$PrazoTesteMin = 15
)

$ErrorActionPreference = "Stop"
$Raiz = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$Exe = Join-Path $env:SystemRoot "System32\WindowsSandbox.exe"
$Processos = "WindowsSandboxRemoteSession", "WindowsSandboxClient"
if (-not (Test-Path -LiteralPath $Exe)) {
	Write-Host "O Windows Sandbox não está ativado nesta máquina. Veja docs/WINDOWS_SANDBOX.md (instalação no Windows 10 e 11)." -ForegroundColor Red
	exit 2
}
if (Get-Process -Name $Processos -ErrorAction SilentlyContinue) {
	Write-Host "Já existe uma sandbox aberta. O Windows abre uma por vez: feche a outra e rode de novo." -ForegroundColor Red
	exit 3
}

if (-not $Godot) { $Godot = if ($env:KIKIU_GODOT) { $env:KIKIU_GODOT } else { "E:\Dev\Godot_4.4.1\Godot_v4.4.1-stable_win64_console.exe" } }
if (-not (Test-Path -LiteralPath $Godot)) { Write-Host "Godot não encontrado: $Godot (use -Godot ou a variável KIKIU_GODOT)" -ForegroundColor Red; exit 2 }
$GodotDir = Split-Path -Parent (Resolve-Path -LiteralPath $Godot).Path
$GodotExe = Split-Path -Leaf $Godot
if ($GodotExe -notmatch "_console") { Write-Host "Aviso: use o Godot *_console.exe, senão a saída dos testes não aparece no log." -ForegroundColor Yellow }

$Testes = @($Testes | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Ferramentas = @($Ferramentas | ForEach-Object { $_ -split "," } | Where-Object { $_ } | ForEach-Object { (Resolve-Path -LiteralPath $_.Trim()).Path })
# padrão fora do %TEMP%: em algumas máquinas ele vem com nome curto (SOURC-~1), que o .wsb pode não aceitar
if (-not $Saida) { $Saida = Join-Path $env:USERPROFILE ("KIKIU-Sandbox\" + (Get-Date -Format "yyyyMMdd_HHmmss")) }
New-Item -ItemType Directory -Force -Path $Saida | Out-Null
$Saida = (Get-Item -LiteralPath $Saida).FullName
if ($Saida.StartsWith($Raiz, [StringComparison]::OrdinalIgnoreCase)) { Write-Host "A pasta de saída não pode ficar dentro do repositório." -ForegroundColor Red; exit 2 }
# limpa o que uma execução anterior deixou (senão um fim.txt velho vira resultado falso)
Get-ChildItem -LiteralPath $Saida -File -ErrorAction SilentlyContinue |
	Where-Object { $_.Name -in "fim.txt", "fim.tmp", "resumo.txt", "tarefa.json", "kikiu.wsb" -or $_.Extension -eq ".log" } |
	Remove-Item -Force
if (Test-Path -LiteralPath (Join-Path $Saida "saida_playtest")) { Write-Host "Aviso: $Saida\saida_playtest é de uma execução anterior." -ForegroundColor Yellow }

# a tarefa que o dentro.ps1 lê lá dentro
@{
	testes = $Testes
	comando = $Comando
	godot_exe = $GodotExe
	fechar = (-not $Janela.IsPresent)
	ferramentas = @(for ($i = 0; $i -lt $Ferramentas.Count; $i++) { "C:\kikiu\ferramenta$i" })
	prazo_import_s = 600
	prazo_teste_s = $PrazoTesteMin * 60
	prazo_comando_s = [Math]::Max(60, $LimiteMin * 60 - 120)
} | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $Saida "tarefa.json")

function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }
function Mapa([string]$host_, [string]$dentro, [bool]$leitura) {
	$ro = if ($leitura) { "true" } else { "false" }
	"    <MappedFolder><HostFolder>$(Esc $host_)</HostFolder><SandboxFolder>$dentro</SandboxFolder><ReadOnly>$ro</ReadOnly></MappedFolder>`n"
}
# só o projeto e as ferramentas (não a raiz: o .git, o .claude e as notas locais ficam fora da sandbox)
$mapas = (Mapa (Join-Path $Raiz "jogos\hordas\projeto") "C:\kikiu\repo\jogos\hordas\projeto" $true) +
	(Mapa (Join-Path $Raiz "ferramentas") "C:\kikiu\repo\ferramentas" $true) +
	(Mapa $GodotDir "C:\kikiu\godot" $true) +
	(Mapa $Saida "C:\kikiu\saida" $false)
for ($i = 0; $i -lt $Ferramentas.Count; $i++) { $mapas += Mapa $Ferramentas[$i] "C:\kikiu\ferramenta$i" $true }
$xmlRede = if ($Rede) { "Enable" } else { "Disable" }
$wsb = @"
<Configuration>
  <VGpu>Disable</VGpu>
  <Networking>$xmlRede</Networking>
  <MemoryInMB>$MemoriaMB</MemoryInMB>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <PrinterRedirection>Disable</PrinterRedirection>
  <AudioInput>Disable</AudioInput>
  <VideoInput>Disable</VideoInput>
  <MappedFolders>
$mapas  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\kikiu\repo\ferramentas\sandbox\dentro.ps1</Command>
  </LogonCommand>
</Configuration>
"@
$ArqWsb = Join-Path $Saida "kikiu.wsb"
Set-Content -Encoding UTF8 -LiteralPath $ArqWsb -Value $wsb

Write-Host "Abrindo o Windows Sandbox (saída em $Saida) ..."
Start-Process -FilePath $Exe -ArgumentList "`"$ArqWsb`""
if ($Janela) { Write-Host "Sandbox aberta. O projeto fica em C:\trabalho\jogos\hordas\projeto lá dentro; feche a janela para apagar tudo."; exit 0 }

$fim = Join-Path $Saida "fim.txt"
$inicio = Get-Date
$prazo = $inicio.AddMinutes($LimiteMin)
while (-not (Test-Path -LiteralPath $fim)) {
	if ((Get-Date) -gt $prazo) { Write-Host "Passou de $LimiteMin min sem terminar. A sandbox ficou aberta para olhar; o log parcial está em $Saida." -ForegroundColor Red; exit 4 }
	# depois de 90 s de carência, se a sandbox sumiu sem o fim.txt, ela caiu ou alguém fechou a janela
	if (((Get-Date) - $inicio).TotalSeconds -gt 90 -and -not (Get-Process -Name $Processos -ErrorAction SilentlyContinue)) {
		Start-Sleep -Seconds 3
		if (-not (Test-Path -LiteralPath $fim)) { Write-Host "A sandbox fechou sem terminar. Veja $Saida\dentro.log." -ForegroundColor Red; exit 5 }
	}
	Start-Sleep -Seconds 5
}
$txt = (Get-Content -LiteralPath $fim -Raw).Trim()
$codigo = if ($txt -match '^\d+$') { [int]$txt } else { 1 }
$resumo = Join-Path $Saida "resumo.txt"
if (Test-Path -LiteralPath $resumo) { Get-Content -LiteralPath $resumo -Encoding UTF8 }
# espera a sandbox fechar (até 30 s), para a próxima execução não cair no "já existe uma aberta"
$ate = (Get-Date).AddSeconds(30)
while ((Get-Process -Name $Processos -ErrorAction SilentlyContinue) -and (Get-Date) -lt $ate) { Start-Sleep -Seconds 2 }
Write-Host ("Terminou com código {0}. Logs em {1}" -f $codigo, $Saida)
exit $codigo
