# Fila do Godot no notebook: no máximo $env:KIKIU_GODOT_VAGAS (padrão 2) instâncias ao mesmo tempo,
# somando Claude, Codex e qualquer outro. Quem chega sem vaga espera a sua vez.
# Uso: powershell -NoProfile -File C:\Dev\KIKIU\notas\godot_fila.ps1 <argumentos do Godot>
#   ex.: ... godot_fila.ps1 --headless --path jogos/hordas/projeto res://testes/v2_hud.tscn
# A saída e o código de saída são os do próprio Godot.
# Sem --headless, a janela abre oculta (saída vem no fim, não ao vivo). Ver bloco no fim do script.
#
# Cada vaga é um Mutex nomeado (Local\KIKIU_Godot_vaga_N). Se o processo que segura a vaga morrer
# (agente parado, janela fechada, kill), o Windows marca o Mutex como abandonado e o próximo da fila
# o recebe na hora. A versão antiga usava um semáforo, que perdia a vaga para sempre nesse caso
# (travou duas vezes em 29/10).
$ErrorActionPreference = 'Stop'
$godot = 'C:\Dev\Tools\Godot\Godot_v4.4.1-stable_win64_console.exe'
$vagas = if ($env:KIKIU_GODOT_VAGAS) { [int]$env:KIKIU_GODOT_VAGAS } else { 2 }
$mutexes = 1..$vagas | ForEach-Object { New-Object System.Threading.Mutex($false, "Local\KIKIU_Godot_vaga_$_") }
$espera = [Diagnostics.Stopwatch]::StartNew()
$minha = $null
while ($null -eq $minha) {
    foreach ($m in $mutexes) {
        try {
            if ($m.WaitOne(0)) { $minha = $m; break }
        } catch [System.Threading.AbandonedMutexException] {
            [Console]::Error.WriteLine('[fila godot] vaga abandonada por processo morto, recuperada')
            $minha = $m; break
        }
    }
    if ($null -eq $minha) {
        if ($espera.Elapsed.TotalSeconds -ge 5 -and [int]$espera.Elapsed.TotalSeconds % 30 -lt 1) {
            [Console]::Error.WriteLine("[fila godot] esperando vaga ha $([int]$espera.Elapsed.TotalSeconds) s")
        }
        Start-Sleep -Milliseconds 500
    }
}
try {
    # Com janela (Movie Maker, fotos com render real): abre OCULTA, pedido do Alisson em 05/11/2026.
    # Medido nesse dia: oculta grava quadros certos; MINIMIZADA grava tudo preto (o Godot não desenha
    # janela minimizada), então minimizar não serve. KIKIU_GODOT_JANELA=normal mostra a janela.
    $comJanela = -not ($args -contains '--headless') -and $env:KIKIU_GODOT_JANELA -ne 'normal'
    if ($comJanela) {
        $gui = 'C:\Dev\Tools\Godot\Godot_v4.4.1-stable_win64.exe'
        $linha = ($args | ForEach-Object {
            $s = [string]$_
            if ($s -eq '' -or $s -match '[\s"]') { '"' + ($s -replace '"', '\"') + '"' } else { $s }
        }) -join ' '
        $tmp = Join-Path $env:TEMP ("godot_fila_" + [guid]::NewGuid().ToString('N'))
        $p = Start-Process $gui -ArgumentList $linha -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput "$tmp.out" -RedirectStandardError "$tmp.err"
        $null = $p.Handle  # sem isso o PowerShell 5.1 perde o ExitCode
        $p.WaitForExit()
        $codigo = $p.ExitCode
        if (Test-Path "$tmp.out") { Get-Content "$tmp.out" | Write-Output; Remove-Item "$tmp.out" -ErrorAction SilentlyContinue }
        if (Test-Path "$tmp.err") { Get-Content "$tmp.err" | ForEach-Object { [Console]::Error.WriteLine($_) }; Remove-Item "$tmp.err" -ErrorAction SilentlyContinue }
    } else {
        & $godot @args
        $codigo = $LASTEXITCODE
    }
} finally {
    $minha.ReleaseMutex()
    $mutexes | ForEach-Object { $_.Dispose() }
}
exit $codigo
