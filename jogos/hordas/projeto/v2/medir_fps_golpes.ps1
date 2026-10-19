# Mede o fps da v2 com a horda (--estresse=100) e os 36 golpes de projetil, anel, meteoro e nuvem no nivel 5 (--build=golpes),
# para comparar antes e depois das folhas animadas (docs/combate_v2). 3 repeticoes de 2 s de aquecimento + 6 s medidos, no perfil
# Baixo (o do PC fraco). Antes, confira que nao ha outro Godot rodando e que o projeto foi importado (--headless --import).
# Uso (PowerShell, na pasta jogos/hordas/projeto): .\v2\medir_fps_golpes.ps1 [-Godot caminho] [-Saida arquivo]
param(
	[string]$Godot = "D:\dev\kikiu_ferramentas\godot\Godot_v4.4.1-stable_win64_console.exe",
	[string]$Saida = "v2/fps_golpes.txt"
)
Set-Location (Join-Path $PSScriptRoot "..")
"" | Out-File -Encoding utf8 $Saida
$fps = @()
$args_g = "--path . res://v2/mundo.tscn -- --medir --perfil=baixo --sombra=baixa --particulas=poucas --duracao=6 --estresse=100 --imortal --build=golpes"
foreach ($rep in 1..3) {
	$out = Join-Path $env:TEMP "medir_golpes_out.txt"
	$p = Start-Process -FilePath $Godot -ArgumentList $args_g -RedirectStandardOutput $out -RedirectStandardError (Join-Path $env:TEMP "medir_golpes_err.txt") -PassThru -NoNewWindow
	if (-not $p.WaitForExit(90000)) { $p.Kill() }
	$linhas = Get-Content $out | Where-Object { $_ -match "MEDIDA|SCRIPT ms|RENDER" } | Select-Object -First 3
	$linhas | ForEach-Object { "rep$rep $_" } | Out-File -Append -Encoding utf8 $Saida
	$m = $linhas | Where-Object { $_ -match "fps=([0-9.]+)" } | Select-Object -First 1
	if ($m -match "fps=([0-9.]+)") { $fps += [double]$Matches[1] }
}
$ord = $fps | Sort-Object
$med = if ($ord.Count -gt 0) { $ord[[int][math]::Floor(($ord.Count - 1) / 2)] } else { 0 }
"mediana fps=$med (de $($ord -join ', '))" | Out-File -Append -Encoding utf8 $Saida
Get-Content $Saida
