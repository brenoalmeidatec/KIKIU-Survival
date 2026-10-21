param(
    [Parameter(Mandatory = $true)][string]$AppDataQA,
    [Parameter(Mandatory = $true)][string]$FilaGodot
)
# Integração real, com janela: executa os dois helpers e protege opções, índice e progresso.
# Cada execução recebe um APPDATA novo dentro da pasta QA informada; nunca usa o perfil do jogador.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$execucao = Join-Path ([IO.Path]::GetFullPath($AppDataQA)) ('gifs_' + [guid]::NewGuid().ToString('N'))
$userQA = Join-Path $execucao 'Godot\app_userdata\K.I.K.I.U'
New-Item -ItemType Directory -Path $userQA -Force | Out-Null
$sentinelas = @{
    # O autoload migraria e gravaria essa opção antiga antes do _ready do helper.
    'opcoes.cfg' = "[opcoes]`nqualidade=`"baixa`"`nqualidade_auto=false`n"
    'v2_personagens.cfg' = "[geral]`nlista=[`"p1`"]`nativo=`"p1`"`n[p1]`nnome=`"Breno`"`nheroi=`"hazaki`"`n"
    'v2_personagem_p1.cfg' = "[moeda]`nalmas=12345`n[melhorias]`nvida=3`n"
    'v2_progresso.cfg' = "[moeda]`nalmas=67890`n"
}
foreach ($nome in $sentinelas.Keys) {
    [IO.File]::WriteAllText((Join-Path $userQA $nome), $sentinelas[$nome])
}
$antes = @{}
foreach ($nome in $sentinelas.Keys) { $antes[$nome] = (Get-FileHash -LiteralPath (Join-Path $userQA $nome)).Hash }
$appDataAnterior = $env:APPDATA
try {
    $env:APPDATA = $execucao
    foreach ($helper in @('matheus_gif', 'heroi_gif')) {
        $fotos = Join-Path $execucao $helper
        $log = Join-Path $execucao "$helper.log"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $FilaGodot --path (Join-Path $repo 'jogos\hordas\projeto') --position -3000,0 "res://testes/fotos/$helper.tscn" -- "--fotos=$fotos" --cena=hud *> $log
        if ($LASTEXITCODE -ne 0) { throw "$helper falhou: $LASTEXITCODE" }
        # Godot 4.4.1/GL registra caches estáticos ainda vivos no encerramento. Preserve-os no log;
        # erro de script, importação ou execução invalida a captura, mesmo com código de saída zero.
        $erros = @(Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR:|^ERROR:' | Where-Object {
            $_.Line -notmatch '^ERROR: (\d+ RID allocations|Texture with GL ID|\d+ resources still in use at exit)'
        })
        if ($erros.Count -gt 0) { throw "$helper registrou erro; veja $log" }
        if (@(Get-ChildItem -LiteralPath $fotos -Filter '*.png' -Recurse).Count -ne 1) { throw "$helper não gerou o HUD" }
        foreach ($nome in $sentinelas.Keys) {
            if ((Get-FileHash -LiteralPath (Join-Path $userQA $nome)).Hash -ne $antes[$nome]) { throw "$helper alterou $nome" }
        }
        $extras = @(Get-ChildItem -LiteralPath $userQA -File | Where-Object { $_.Name -notin $sentinelas.Keys -and $_.Name -notlike 'qa_*' })
        if ($extras.Count -gt 0) { throw "$helper criou arquivo fora do isolamento: $($extras.Name -join ', ')" }
        Write-Output "$helper : HUD capturado; quatro sentinelas SHA256 intactas; nenhum save real novo"
    }
    # Controle negativo: o jogo normal continua migrando a opção antiga, na mesma cópia descartável.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $FilaGodot --headless --path (Join-Path $repo 'jogos\hordas\projeto') --quit-after 1 *> (Join-Path $execucao 'jogo_normal.log')
    if ($LASTEXITCODE -ne 0) { throw "Jogo normal falhou: $LASTEXITCODE" }
    $opcoes = Join-Path $userQA 'opcoes.cfg'
    if ((Get-FileHash -LiteralPath $opcoes).Hash -eq $antes['opcoes.cfg']) { throw 'Guard de QA impediu migração no jogo normal' }
    if (-not (Select-String -LiteralPath $opcoes -SimpleMatch '[graficos]')) { throw 'Migração normal não gerou perfil gráfico' }
    Write-Output 'jogo normal : migração preservada fora dos dois helpers'
} finally {
    $env:APPDATA = $appDataAnterior
}
Write-Output "falhas=0; evidências em $execucao"
