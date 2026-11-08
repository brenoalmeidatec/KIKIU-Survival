# Roda DENTRO do Windows Sandbox (chamado pelo LogonCommand do .wsb que o sandbox.ps1 gera). Não rode no seu Windows.
# Copia o projeto e as ferramentas (só leitura em C:\kikiu\repo) para C:\trabalho, na mesma estrutura do repositório, importa, roda os testes ou o comando da tarefa e grava
# os logs, o resumo.txt e o fim.txt (código de saída) em C:\kikiu\saida, a única pasta que volta para o host.

$ErrorActionPreference = "Continue"
$S = "C:\kikiu\saida"
$codigo = 1
try {
	Start-Transcript -Path "$S\dentro.log" -Force | Out-Null
	$t = Get-Content "$S\tarefa.json" -Raw | ConvertFrom-Json
	$godot = "C:\kikiu\godot\" + $t.godot_exe
	$proj = "C:\trabalho\jogos\hordas\projeto"  # a mesma estrutura do repositório: as ferramentas acham o projeto pela posição
	$env:APPDATA = "C:\trabalho\appdata"  # o save e as configurações do Godot ficam lá dentro (somem ao fechar)
	New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
	$env:GODOT = $godot
	foreach ($d in @($t.ferramentas)) { if ($d) { $env:PATH = "$d;$d\Scripts;$d\cmd;$env:PATH" } }  # Python, MinGit etc. (pastas só leitura)

	$c0 = Get-Date
	robocopy "C:\kikiu\repo\jogos\hordas\projeto" $proj /E /XD .godot /NFL /NDL /NJH /NJS /NP | Out-Null
	robocopy "C:\kikiu\repo\ferramentas" "C:\trabalho\ferramentas" /E /XD __pycache__ /NFL /NDL /NJH /NJS /NP | Out-Null
	"copia do projeto: {0:N0} s" -f ((Get-Date) - $c0).TotalSeconds

	$i0 = Get-Date
	& $godot --headless --path $proj --import *> "$S\import.log"
	"import: {0:N0} s (codigo {1})" -f ((Get-Date) - $i0).TotalSeconds, $LASTEXITCODE

	$linhas = @()
	$falhou = $false
	foreach ($nome in $t.testes) {
		$a0 = Get-Date
		$log = "$S\$nome.log"
		& $godot --headless --path $proj "res://testes/$nome.tscn" *> $log
		$ex = $LASTEXITCODE
		$txt = Get-Content $log -Raw -ErrorAction SilentlyContinue
		$m = [regex]::Matches("$txt", "falhas=(\d+)")
		$f = if ($m.Count) { [int]$m[$m.Count - 1].Groups[1].Value } else { -1 }
		$erro = "$txt" -match "SCRIPT ERROR"
		if ($f -ne 0 -or $erro) { $falhou = $true }
		$linhas += "{0}: falhas={1}{2} ({3:N0} s, saida {4})" -f $nome, $(if ($f -lt 0) { "?" } else { $f }), $(if ($erro) { " + SCRIPT ERROR" } else { "" }), ((Get-Date) - $a0).TotalSeconds, $ex
	}

	if ($t.comando) {
		Push-Location $proj
		cmd /c "$($t.comando) > `"$S\comando.log`" 2>&1"  # o próprio cmd grava stdout e stderr (o PowerShell embrulharia o stderr em erro)
		$ex = $LASTEXITCODE
		Pop-Location
		$linhas += "comando: saida $ex (log em comando.log)"
		# o robô de playtest grava o relatório dentro da sandbox: traz para a saída antes que ela feche
		if (Test-Path "C:\trabalho\ferramentas\saida_playtest") {
			robocopy "C:\trabalho\ferramentas\saida_playtest" "$S\saida_playtest" /E /NFL /NDL /NJH /NJS /NP | Out-Null
			$linhas += "relatorio do robo copiado para saida_playtest"
		}
		if ($ex -ne 0) { $falhou = $true }
	}

	$linhas | Set-Content -Encoding UTF8 "$S\resumo.txt"
	$codigo = if ($falhou) { 1 } else { 0 }
} catch {
	"ERRO dentro da sandbox: $($_.Exception.Message)" | Add-Content -Encoding UTF8 "$S\resumo.txt"
	$codigo = 1
} finally {
	try { Stop-Transcript | Out-Null } catch {}
	Set-Content -Encoding ASCII "$S\fim.txt" "$codigo"
	if ($t -and $t.fechar) { shutdown.exe /s /t 3 }
}
