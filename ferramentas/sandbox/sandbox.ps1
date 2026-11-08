# Roda testes do Godot (headless) ou um comando qualquer DENTRO do Windows Sandbox, sem tocar no Windows de quem roda.
# Regra do repositório (docs/WINDOWS_SANDBOX.md): tudo o que não precisa de aceleração gráfica roda aqui.
#
# Exemplos (da raiz do repositório):
#   powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Testes v2_martelo,v2_teia_lento
#   powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Comando "%GODOT% --headless --path . res://testes/v2_combate.tscn"
#   powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Janela        # só abre a sandbox com o projeto copiado, para mexer à mão
#
# Como funciona: o repositório e a pasta do Godot entram SÓ LEITURA; o projeto e as ferramentas são copiados para C:\trabalho dentro da sandbox (mesma estrutura do repositório);
# só a pasta de saída (logs, resumo, o que o comando gravar em C:\kikiu\saida) volta para o Windows de verdade.
# Ao fechar, a sandbox apaga tudo. Funciona no Windows 10 e no 11 (não depende do wsb.exe do 11 24H2).

param(
	[string[]]$Testes = @(),  # nomes das cenas em jogos/hordas/projeto/testes, sem .tscn (aceita "a,b" numa string só)
	[string]$Comando = "",  # comando de cmd rodado em C:\trabalho\jogos\hordas\projeto; %GODOT% = o Godot console de dentro
	[string]$Godot = "",  # o Godot_v4.4.1-stable_win64_console.exe do host (padrão: $env:KIKIU_GODOT ou E:\Dev\Godot_4.4.1)
	[string]$Saida = "",  # pasta de saída no host (padrão: %TEMP%\kikiu_sandbox\<data-hora>)
	[string[]]$Ferramentas = @(),  # pastas portáteis do host (Python, MinGit...) que entram SÓ LEITURA e vão para o PATH lá dentro
	[switch]$Rede,  # liga a rede dentro da sandbox (desligada por padrão)
	[switch]$Janela,  # não fecha no fim (para olhar ou mexer à mão)
	[int]$MemoriaMB = 6144,
	[int]$LimiteMin = 40  # desiste de esperar depois disso (a sandbox continua aberta para olhar)
)

$ErrorActionPreference = "Stop"
$Raiz = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Exe = Join-Path $env:SystemRoot "System32\WindowsSandbox.exe"
if (-not (Test-Path $Exe)) {
	Write-Host "O Windows Sandbox não está ativado nesta máquina. Veja docs/WINDOWS_SANDBOX.md (instalação no Windows 10 e 11)." -ForegroundColor Red
	exit 2
}
if (Get-Process -Name "WindowsSandboxRemoteSession", "WindowsSandboxClient" -ErrorAction SilentlyContinue) {
	Write-Host "Já existe uma sandbox aberta. O Windows abre uma por vez: feche a outra e rode de novo." -ForegroundColor Red
	exit 3
}

if (-not $Godot) { $Godot = if ($env:KIKIU_GODOT) { $env:KIKIU_GODOT } else { "E:\Dev\Godot_4.4.1\Godot_v4.4.1-stable_win64_console.exe" } }
if (-not (Test-Path $Godot)) { Write-Host "Godot não encontrado: $Godot (use -Godot ou a variável KIKIU_GODOT)" -ForegroundColor Red; exit 2 }
$GodotDir = Split-Path -Parent (Resolve-Path $Godot).Path
$GodotExe = Split-Path -Leaf $Godot
if ($GodotExe -notmatch "_console") { Write-Host "Aviso: use o Godot *_console.exe, senão a saída dos testes não aparece no log." -ForegroundColor Yellow }

$Testes = @($Testes | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Ferramentas = @($Ferramentas | ForEach-Object { $_ -split "," } | Where-Object { $_ } | ForEach-Object { (Resolve-Path $_).Path })
if (-not $Saida) { $Saida = Join-Path $env:TEMP ("kikiu_sandbox\" + (Get-Date -Format "yyyyMMdd_HHmmss")) }
New-Item -ItemType Directory -Force -Path $Saida | Out-Null
$Saida = (Resolve-Path $Saida).Path

# a tarefa que o dentro.ps1 lê lá dentro
@{
	testes = $Testes
	comando = $Comando
	godot_exe = $GodotExe
	fechar = (-not $Janela.IsPresent)
	ferramentas = @(for ($i = 0; $i -lt $Ferramentas.Count; $i++) { "C:\kikiu\ferramenta$i" })
} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $Saida "tarefa.json")

function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }
$xmlFerr = ""
for ($i = 0; $i -lt $Ferramentas.Count; $i++) {
	$xmlFerr += "    <MappedFolder><HostFolder>$(Esc $Ferramentas[$i])</HostFolder><SandboxFolder>C:\kikiu\ferramenta$i</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>`n"
}
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
    <MappedFolder>
      <HostFolder>$(Esc $Raiz)</HostFolder>
      <SandboxFolder>C:\kikiu\repo</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(Esc $GodotDir)</HostFolder>
      <SandboxFolder>C:\kikiu\godot</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>$(Esc $Saida)</HostFolder>
      <SandboxFolder>C:\kikiu\saida</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
$xmlFerr  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\kikiu\repo\ferramentas\sandbox\dentro.ps1</Command>
  </LogonCommand>
</Configuration>
"@
$ArqWsb = Join-Path $Saida "kikiu.wsb"
Set-Content -Encoding UTF8 -Path $ArqWsb -Value $wsb

Write-Host "Abrindo o Windows Sandbox (saída em $Saida) ..."
Start-Process -FilePath $Exe -ArgumentList "`"$ArqWsb`""
if ($Janela) { Write-Host "Sandbox aberta. O projeto fica em C:\trabalho\jogos\hordas\projeto lá dentro; feche a janela para apagar tudo."; exit 0 }

$fim = Join-Path $Saida "fim.txt"
$prazo = (Get-Date).AddMinutes($LimiteMin)
while (-not (Test-Path $fim)) {
	if ((Get-Date) -gt $prazo) { Write-Host "Passou de $LimiteMin min sem terminar. A sandbox ficou aberta para olhar; o log parcial está em $Saida." -ForegroundColor Red; exit 4 }
	Start-Sleep -Seconds 5
}
Start-Sleep -Seconds 1
$codigo = [int]((Get-Content $fim -Raw).Trim())
$resumo = Join-Path $Saida "resumo.txt"
if (Test-Path $resumo) { Get-Content $resumo }
Write-Host ("Terminou com código {0}. Logs em {1}" -f $codigo, $Saida)
exit $codigo
