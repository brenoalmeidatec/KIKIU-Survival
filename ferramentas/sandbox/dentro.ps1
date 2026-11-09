# Roda DENTRO do Windows Sandbox (chamado pelo LogonCommand do .wsb que o sandbox.ps1 gera). Não rode no seu Windows.
# Copia o projeto e as ferramentas (só leitura em C:\kikiu\repo) para C:\trabalho, na mesma estrutura do repositório,
# importa, roda os testes ou o comando da tarefa e grava os logs, o resumo.txt e o fim.txt (código de saída) em
# C:\kikiu\saida, a única pasta que volta para o host. Todo processo tem prazo: um Godot travado é morto e vira "TEMPO",
# e o fim.txt sai sempre, para a sandbox fechar e não bloquear a próxima execução.

$ErrorActionPreference = "Continue"
$S = "C:\kikiu\saida"
$codigo = 1
$t = $null
$linhas = @()


# Roda uma linha de cmd com o stdout e o stderr num arquivo (bytes crus, sem o embrulho do PowerShell) e com prazo.
# Devolve o código de saída, ou -999 se estourou o prazo (o processo e os filhos são mortos).
function Rodar([string]$linha, [string]$log, [int]$prazoS, [string]$pasta = "C:\trabalho") {
	$p = Start-Process -FilePath "cmd.exe" -ArgumentList "/c ($linha) > `"$log`" 2>&1" -WorkingDirectory $pasta -WindowStyle Hidden -PassThru
	if (-not $p.WaitForExit($prazoS * 1000)) {
		taskkill.exe /T /F /PID $p.Id | Out-Null
		Add-Content -LiteralPath $log -Value "`r`n[sandbox] passou do prazo de $prazoS s: processo morto"
		return -999
	}
	return $p.ExitCode
}

try {
	Start-Transcript -Path "$S\dentro.log" -Force | Out-Null
	$t = Get-Content -LiteralPath "$S\tarefa.json" -Raw | ConvertFrom-Json
	$godot = "C:\kikiu\godot\" + $t.godot_exe
	$proj = "C:\trabalho\jogos\hordas\projeto"  # a mesma estrutura do repositório: as ferramentas acham o projeto pela posição
	$env:APPDATA = "C:\trabalho\appdata"  # o save e as configurações do Godot ficam lá dentro (somem ao fechar)
	New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
	$env:GODOT = $godot
	foreach ($d in @($t.ferramentas)) { if ($d) { $env:PATH = "$d;$d\Scripts;$d\cmd;$env:PATH" } }  # Python, MinGit etc. (pastas só leitura)
	$falhou = $false

	$c0 = Get-Date
	robocopy "C:\kikiu\repo\jogos\hordas\projeto" $proj /E /XD .godot /NFL /NDL /NJH /NJS /NP | Out-Null
	$rc1 = $LASTEXITCODE
	robocopy "C:\kikiu\repo\ferramentas" "C:\trabalho\ferramentas" /E /XD __pycache__ saida_playtest /NFL /NDL /NJH /NJS /NP | Out-Null
	$rc2 = $LASTEXITCODE
	if ($rc1 -ge 8 -or $rc2 -ge 8) { $falhou = $true; $linhas += "copia: ERRO do robocopy ($rc1, $rc2)" }
	"copia do projeto: {0:N0} s" -f ((Get-Date) - $c0).TotalSeconds

	$i0 = Get-Date
	$ex = Rodar "`"$godot`" --headless --path `"$proj`" --import" "$S\import.log" ([int]$t.prazo_import_s)
	"import: {0:N0} s (codigo {1})" -f ((Get-Date) - $i0).TotalSeconds, $ex
	if ($ex -eq -999) { $falhou = $true; $linhas += "import: TEMPO (passou de $($t.prazo_import_s) s)" }

	foreach ($nome in @($t.testes)) {
		if (-not $nome) { continue }
		$a0 = Get-Date
		$log = "$S\$nome.log"
		$ex = Rodar "`"$godot`" --headless --path `"$proj`" res://testes/$nome.tscn" $log ([int]$t.prazo_teste_s) $proj
		$txt = Get-Content -LiteralPath $log -Raw -ErrorAction SilentlyContinue
		$m = [regex]::Matches("$txt", "falhas=(\d+)")
		$f = if ($m.Count) { [int]$m[$m.Count - 1].Groups[1].Value } else { -1 }
		$erro = "$txt" -match "SCRIPT ERROR"
		# vermelho: falha contada, falhas= ausente, SCRIPT ERROR, prazo estourado ou o Godot saindo com erro (crash depois do falhas=0)
		if ($f -ne 0 -or $erro -or $ex -ne 0) { $falhou = $true }
		$estado = if ($ex -eq -999) { "TEMPO" } else { "saida $ex" }
		$linhas += "{0}: falhas={1}{2} ({3:N0} s, {4})" -f $nome, $(if ($f -lt 0) { "?" } else { $f }), $(if ($erro) { " + SCRIPT ERROR" } else { "" }), ((Get-Date) - $a0).TotalSeconds, $estado
	}

	if ($t.comando) {
		$ex = Rodar $t.comando "$S\comando.log" ([int]$t.prazo_comando_s) $proj
		$linhas += $(if ($ex -eq -999) { "comando: TEMPO (passou de $($t.prazo_comando_s) s; log em comando.log)" } else { "comando: saida $ex (log em comando.log)" })
		if ($ex -ne 0) { $falhou = $true }
		# o robô de playtest grava o relatório dentro da sandbox: traz para a saída antes que ela feche
		if (Test-Path -LiteralPath "C:\trabalho\ferramentas\saida_playtest") {
			robocopy "C:\trabalho\ferramentas\saida_playtest" "$S\saida_playtest" /E /NFL /NDL /NJH /NJS /NP | Out-Null
			$linhas += "relatorio do robo copiado para saida_playtest"
		}
	}

	$codigo = if ($falhou) { 1 } else { 0 }
} catch {
	$linhas += "ERRO dentro da sandbox: $($_.Exception.Message)"
	$codigo = 1
} finally {
	$linhas | Set-Content -Encoding UTF8 -LiteralPath "$S\resumo.txt"
	try { Stop-Transcript | Out-Null } catch {}
	# atômico: o host nunca lê um fim.txt pela metade
	Set-Content -Encoding ASCII -LiteralPath "$S\fim.tmp" -Value "$codigo"
	Move-Item -LiteralPath "$S\fim.tmp" -Destination "$S\fim.txt" -Force
	# fecha, a não ser que a tarefa peça explicitamente para ficar aberta (-Janela); sem tarefa lida, fecha também
	if (-not ($t -and $t.fechar -eq $false)) { shutdown.exe /s /t 3 }
}
