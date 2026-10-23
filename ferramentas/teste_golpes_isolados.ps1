param(
    [Parameter(Mandatory = $true)][string]$AppDataQA,
    [Parameter(Mandatory = $true)][string]$FilaGodot,
    [string[]]$Cenas = @('v2_adagas_impacto', 'v2_golpes_visuais', 'fotos/v2_contrato_golpes'),
    [switch]$SemExportacao
)
# QA sintética suja; nunca lê/copia/restaura o perfil verdadeiro. Um Godot serial pela fila.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$execucao = Join-Path ([IO.Path]::GetFullPath($AppDataQA)) ('golpes_' + [guid]::NewGuid().ToString('N'))
$userQA = Join-Path $execucao 'kikiu'
New-Item -ItemType Directory -Path $userQA -Force | Out-Null
$sentinelas = @{
    'opcoes.cfg' = "[opcoes]`nqualidade=`"baixa`"`nqualidade_auto=true`n[graficos]`nperfil=`"personalizado`"`nbase=`"alto`"`nsombras=`"projetadas`"`n"
    'v2_personagens.cfg' = "[geral]`nlista=[`"p1`"]`nativo=`"p1`"`n[p1]`nnome=`"Nicão`"`nheroi=`"nicao`"`n"
    'v2_personagem_p1.cfg' = "[moeda]`nalmas=987654`n[melhorias]`nvida=3`n"
    'v2_progresso.cfg' = "[moeda]`nalmas=123456`n[melhorias]`nvida=4`n"
}
foreach ($nome in @($sentinelas.Keys)) {
    $sentinelas["$nome.bak"] = $sentinelas[$nome] + "`n; backup protegido`n"
    $sentinelas["$nome.tmp"] = 'temporário preexistente protegido'
}
$antes = @{}
foreach ($nome in $sentinelas.Keys) {
    $caminho = Join-Path $userQA $nome
    [IO.File]::WriteAllText($caminho, $sentinelas[$nome])
    $antes[$nome] = @{bytes = (Get-Item -LiteralPath $caminho).Length; sha256 = (Get-FileHash -LiteralPath $caminho).Hash}
}
$relatorio = [ordered]@{perfil = 'QA sintética migrável; raízes lógicas'; protegidos = $antes; execucoes = @(); estado = 'pendente'}
$appDataAnterior = $env:APPDATA
Write-Output "QA em $execucao"
try {
    $env:APPDATA = $execucao
    foreach ($cena in $Cenas) {
        $nome = Split-Path $cena -Leaf
        if ($nome -notmatch '^v2_[A-Za-z0-9_]+$') { throw 'Cena fora do namespace da fixture v2' }
        $residuos = Join-Path $userQA "testes_v2\$nome\residuos\.oculto"
        New-Item -ItemType Directory -Path $residuos -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $residuos 'antigo.cfg.bak'), 'resíduo de fixture interrompida')
        if ($env:OS -eq 'Windows_NT') { [IO.File]::SetAttributes($residuos, [IO.FileAttributes]::Directory -bor [IO.FileAttributes]::Hidden) }
        $log = Join-Path $execucao "$nome.log"
        $saida = Join-Path $execucao "$nome.json"
        $argumentos = @()
        if (-not $SemExportacao) { $argumentos = @('--', "--saida=$saida") }
        # Windows PowerShell converte stderr nativo em ErrorRecord. Avisos de RID no encerramento
        # não podem abortar o runner antes de verificar código, hashes e erros de script.
        $erroAnterior = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & powershell -NoProfile -ExecutionPolicy Bypass -File $FilaGodot --headless --path (Join-Path $repo 'jogos\hordas\projeto') "res://testes/$cena.tscn" @argumentos *> $log
            $codigo = $LASTEXITCODE
        } finally { $ErrorActionPreference = $erroAnterior }
        $iguais = $true
        $depois = @{}
        foreach ($arquivo in $sentinelas.Keys) {
            $caminho = Join-Path $userQA $arquivo
            $depois[$arquivo] = @{bytes = -1; sha256 = ''; existe = $false}
            if (Test-Path -LiteralPath $caminho) {
                $depois[$arquivo] = @{bytes = (Get-Item -LiteralPath $caminho).Length; sha256 = (Get-FileHash -LiteralPath $caminho).Hash; existe = $true}
            }
            if ($depois[$arquivo].bytes -ne $antes[$arquivo].bytes -or $depois[$arquivo].sha256 -ne $antes[$arquivo].sha256) { $iguais = $false }
        }
        $fixture = Join-Path $userQA "testes_v2\$nome"
        $limpa = -not (Test-Path -LiteralPath $fixture)
        $extras = @(Get-ChildItem -LiteralPath $userQA -File -Force | Where-Object { $_.Name -notin $sentinelas.Keys } | ForEach-Object Name)
        $scriptErro = [bool](Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Parse Error|FALHOU:')
        $userConfirmado = [bool](Select-String -LiteralPath $log -SimpleMatch ('ISOLAMENTO_USERDIR ' + $userQA.Replace('\', '/')))
        $passou = [bool](Select-String -LiteralPath $log -Pattern 'falhas=0|contrato_golpes: 8 casos')
        $relatorio.execucoes += @{cena = $cena; exportacao_explicita = -not $SemExportacao; codigo = $codigo; arquivos_depois = $depois; hashes_iguais = $iguais; fixture_limpa = $limpa; extras_raiz = $extras; script_error = $scriptErro; user_dir_confirmado = $userConfirmado; passou = $passou}
        if ($codigo -ne 0 -or -not $iguais -or -not $limpa -or $extras.Count -gt 0 -or $scriptErro -or -not $userConfirmado -or -not $passou) { throw "Falhou contrato de isolamento de $cena; preservar QA e log" }
        Write-Output "$nome : 12 sentinelas intactas; fixture removida; sem slots/opções novos fora dela"
    }
    $relatorio.estado = 'falhas=0'
} catch {
    $relatorio.estado = 'falhou; QA preservada'
    throw
} finally {
    $env:APPDATA = $appDataAnterior
    $relatorio | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $execucao 'isolamento.json') -Encoding utf8
}
Write-Output 'teste_golpes_isolados falhas=0'
