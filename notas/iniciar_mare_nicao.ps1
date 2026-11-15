$ErrorActionPreference = 'Stop'
$repositorio = 'C:\Dev\KIKIU\beta2-20261029\mare'
$projeto = Join-Path $repositorio 'jogos\hordas\projeto'
$fila = 'C:\Dev\KIKIU\notas\godot_fila.ps1'
$revisao = '5d04cd05c62bdb1532dbc4417a797cbec793fb3a'

try {
    if (-not (Test-Path -LiteralPath $fila) -or -not (Test-Path -LiteralPath (Join-Path $projeto 'project.godot'))) {
        throw 'O projeto ou a fila do Godot nao foram encontrados.'
    }
    $atual = (& git -C $repositorio rev-parse HEAD 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $atual -ne $revisao) {
        throw 'A versao local mudou. O atalho foi criado para o PR 479 e precisa ser atualizado.'
    }
    & git -C $repositorio diff --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Ha alteracoes locais na versao de teste. Confira antes de abrir.' }
    & git -C $repositorio diff --cached --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Ha alteracoes locais preparadas na versao de teste. Confira antes de abrir.' }

    $env:APPDATA = 'C:\Dev\KIKIU\beta2-20261029\mare-jogador-appdata'
    New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    Write-Host 'Abrindo a Mare de Sangue: Nicao, Vila, perfil Baixo. Se a fila estiver cheia, aguarde.'
    & powershell.exe -NoProfile -File $fila --path $projeto 'res://v2/mundo.tscn' -- --mapa=cidade --heroi=nicao --perfil=baixo --beta-tester
    if ($LASTEXITCODE -ne 0) { throw "O Godot encerrou com codigo $LASTEXITCODE." }
} catch {
    Write-Host "Nao foi possivel abrir o prototipo: $_" -ForegroundColor Red
    Read-Host 'Pressione Enter para fechar'
    exit 1
}
