param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Instalar', 'Jogar', 'Diagnostico')]
    [string]$Acao,
    [string]$Base = $PSScriptRoot,
    [string]$Estado
)

$ErrorActionPreference = 'Stop'
$Repositorio = 'brenoalmeidatec/KIKIU-Survival'
$Base = [IO.Path]::GetFullPath($Base)
$Dados = Join-Path $Base 'releases-github'
$Ativa = Join-Path $Dados 'ativa.json'

function Confirmar-PastaComum([string]$Pasta) {
    if ((Test-Path -LiteralPath $Pasta) -and
        ((Get-Item -Force -LiteralPath $Pasta).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'A pasta da instalacao tem um link ou uma juncao.'
    }
}

function Obter-RevisaoAtiva {
    Confirmar-PastaComum $Base
    Confirmar-PastaComum $Dados
    Confirmar-PastaComum $Ativa
    if (Test-Path -LiteralPath $Ativa -PathType Leaf) {
        $revisao = Get-Content -LiteralPath $Ativa -Raw | ConvertFrom-Json
        if ($revisao.tag -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$' -or $revisao.pasta -notmatch '^v-[a-f0-9]{32}$') {
            throw 'A instalacao ativa precisa ser recuperada pelo instalador.'
        }
        $pasta = Join-Path $Dados $revisao.pasta
        Confirmar-PastaComum $pasta
        $exe = Join-Path $pasta 'KIKIU.exe'
        Confirmar-PastaComum $exe
        if (Test-Path -LiteralPath $exe -PathType Leaf) {
            return @{ Exe = $exe; Tag = $revisao.tag; Hash = $revisao.hash; HashExe = $revisao.hash_exe }
        }
    }
    $legado = Join-Path $Base 'KIKIU.exe'
    Confirmar-PastaComum $legado
    if (Test-Path -LiteralPath $legado -PathType Leaf) {
        return @{ Exe = $legado; Tag = 'instalacao-anterior'; Hash = ''; HashExe = '' }
    }
}

function Confirmar-Executavel([string]$Exe) {
    $leitor = [IO.BinaryReader]::new([IO.File]::OpenRead($Exe))
    try {
        if ($leitor.BaseStream.Length -lt 70 -or $leitor.ReadUInt16() -ne 0x5A4D) {
            throw 'O pacote nao contem um executavel Windows valido.'
        }
        $leitor.BaseStream.Position = 60
        $pe = $leitor.ReadUInt32()
        if ($pe -lt 64 -or $pe -gt $leitor.BaseStream.Length - 6) { throw 'Cabecalho PE invalido.' }
        $leitor.BaseStream.Position = $pe
        if ($leitor.ReadUInt32() -ne 0x00004550 -or $leitor.ReadUInt16() -ne 0x8664) {
            throw 'O pacote nao contem um executavel Windows x64 valido.'
        }
    } finally {
        $leitor.Dispose()
    }
}

function Expandir-PacoteSeguro([string]$Zip, [string]$Pasta) {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $arquivo = [IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        # A release publica o executavel com o PCK embutido e licencas em texto.
        $nomes = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $total = 0L
        foreach ($item in $arquivo.Entries) {
            if ($item.FullName -cnotmatch '^(KIKIU\.exe|licencas/([A-Za-z0-9][A-Za-z0-9_.-]*\.txt)?)$' -or
                $item.Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\.' -or
                (($item.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000 -or
                -not $nomes.Add($item.FullName)) {
                throw 'O ZIP contem uma entrada inesperada.'
            }
            $total += $item.Length
            if ($total -gt 2147483648L) { throw 'O ZIP excede o limite descompactado.' }
        }
        if (-not $nomes.Contains('KIKIU.exe')) { throw 'KIKIU.exe ausente no ZIP.' }
    } finally {
        $arquivo.Dispose()
    }
    [IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Pasta)
    Confirmar-Executavel (Join-Path $Pasta 'KIKIU.exe')
}

function Obter-PublicacaoMaisRecente($Http) {
    $publicacoes = for ($pagina = 1; ; $pagina++) {
        $lote = Invoke-RestMethod @Http -Uri "https://api.github.com/repos/$Repositorio/releases?per_page=100&page=$pagina" -TimeoutSec 40
        $lote | Where-Object {
            -not $_.draft -and $_.published_at -and (-not $_.prerelease -or $_.tag_name -ieq 'v2.0-rc1')
        }
        if (@($lote).Count -lt 100) { break }
    }
    $publicacoes | Sort-Object { [DateTimeOffset]$_.published_at }, id -Descending | Select-Object -First 1
}

function Atualizar-Kikiu {
    Confirmar-PastaComum $Base
    Confirmar-PastaComum $Dados
    [IO.Directory]::CreateDirectory($Dados) | Out-Null
    $trava = Join-Path $Dados 'instalar.lock'
    Confirmar-PastaComum $trava
    $lock = [IO.File]::Open($trava, 'OpenOrCreate', 'ReadWrite', 'None')
    $temporaria = Join-Path $Dados ('.preparo-' + [guid]::NewGuid().ToString('N'))
    try {
        $http = @{ UserAgent = 'KIKIU-RC1-Setup'; UseBasicParsing = $true }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $release = Obter-PublicacaoMaisRecente $http
        $tag = $release.tag_name
        if ($tag -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$') {
            throw 'O GitHub nao retornou uma release publicada valida.'
        }
        $itens = @($release.assets | Where-Object {
            $_.name -cmatch '^KIKIU-windows-[A-Za-z0-9][A-Za-z0-9._-]*\.zip$' -and $_.state -eq 'uploaded'
        })
        if ($itens.Count -ne 1) { throw 'A release publicada nao oferece o ZIP Windows esperado.' }
        $item = $itens[0]
        $url = "https://github.com/$Repositorio/releases/download/$tag/$($item.name)"
        if ($item.browser_download_url -cne $url -or $item.digest -notmatch '^sha256:[A-Fa-f0-9]{64}$' -or
            $item.size -lt 22 -or $item.size -gt 1073741824L) {
            throw 'Os dados de integridade ou o endereco do ZIP sao invalidos.'
        }
        $hash = $item.digest.Substring(7)
        $atual = Obter-RevisaoAtiva
        if ($atual -and $atual.Tag -ceq $tag -and $atual.Hash -eq $hash -and
            (Get-FileHash -LiteralPath $atual.Exe).Hash -eq $atual.HashExe) {
            return $tag
        }

        [IO.Directory]::CreateDirectory($temporaria) | Out-Null
        $zip = Join-Path $temporaria 'release.zip'
        $preparada = Join-Path $temporaria 'jogo'
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest @http -Uri $url -OutFile $zip -TimeoutSec 600
        if ((Get-Item -LiteralPath $zip).Length -ne $item.size -or (Get-FileHash -LiteralPath $zip).Hash -ne $hash) {
            throw 'O ZIP recebido esta incompleto ou nao corresponde ao SHA-256 publicado.'
        }
        Expandir-PacoteSeguro $zip $preparada
        $hashExe = (Get-FileHash -LiteralPath (Join-Path $preparada 'KIKIU.exe')).Hash

        $pasta = 'v-' + [guid]::NewGuid().ToString('N')
        [IO.Directory]::Move($preparada, (Join-Path $Dados $pasta))
        $novaMarca = Join-Path $temporaria 'ativa.json'
        @{ tag = $tag; pasta = $pasta; hash = $hash; hash_exe = $hashExe } |
            ConvertTo-Json -Compress | Set-Content -LiteralPath $novaMarca -Encoding UTF8
        if ([IO.File]::Exists($Ativa)) {
            [IO.File]::Replace($novaMarca, $Ativa, (Join-Path $temporaria 'anterior.json'))
        } else {
            [IO.File]::Move($novaMarca, $Ativa)
        }
        return $tag
    } finally {
        $lock.Dispose()
        if (Test-Path -LiteralPath $temporaria -PathType Container) {
            Remove-Item -LiteralPath $temporaria -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Exibir-Mensagem([string]$Mensagem) {
    [Windows.Forms.MessageBox]::Show($Mensagem, 'KIKIU RC1') | Out-Null
}

function Jogar([bool]$Diagnostico) {
    $build = Obter-RevisaoAtiva
    if (-not $build) { throw 'Nenhuma versao instalada. Abra o instalador do KIKIU com internet.' }
    if ($Diagnostico) {
        $pergunta = "Quer medir esta sessao do KIKIU?`n`nO relatorio contem apenas a tag da release, a duracao, o pico de memoria do jogo, o tempo de CPU e o codigo de saida. Ele e salvo apenas se voce escolher onde salvar. O envio e manual.`n`nSe escolher Nao, o jogo abre normalmente."
        $resposta = [Windows.Forms.MessageBox]::Show($pergunta, 'KIKIU RC1 | Diagnostico local', 'YesNo', 'Question', 'Button2')
        $Diagnostico = $resposta -eq 'Yes'
    }
    $relogio = [Diagnostics.Stopwatch]::StartNew()
    $jogo = Start-Process -FilePath $build.Exe -WorkingDirectory (Split-Path -Parent $build.Exe) -PassThru
    if (-not $Diagnostico) { $jogo.Dispose(); return }
    $memoria = $null
    $cpu = $null
    while (-not $jogo.WaitForExit(500)) {
        $jogo.Refresh()
        try { $memoria = [Math]::Round($jogo.PeakWorkingSet64 / 1MB) } catch {}
        try { $cpu = [Math]::Round($jogo.TotalProcessorTime.TotalSeconds, 2) } catch {}
    }
    try { $cpu = [Math]::Round($jogo.TotalProcessorTime.TotalSeconds, 2) } catch {}
    $relatorio = [ordered]@{
        release = $build.Tag
        duracao_segundos = [Math]::Round($relogio.Elapsed.TotalSeconds, 1)
        pico_memoria_amostrado_mib = $memoria
        cpu_segundos = $cpu
        codigo_saida = $jogo.ExitCode
    } | ConvertTo-Json
    $jogo.Dispose()

    $dialogo = New-Object Windows.Forms.SaveFileDialog
    try {
        $dialogo.Title = 'Salvar diagnostico local do KIKIU'
        $dialogo.FileName = 'KIKIU-relatorio.json'
        $dialogo.Filter = 'Relatorio JSON (*.json)|*.json'
        if ($dialogo.ShowDialog() -eq 'OK') { Set-Content -LiteralPath $dialogo.FileName -Value $relatorio -Encoding UTF8 }
    } finally {
        $dialogo.Dispose()
    }
}

if ($Acao -eq 'Instalar') {
    try {
        $tag = Atualizar-Kikiu
        [IO.File]::WriteAllText($Estado, $tag)
        exit 0
    } catch {
        Write-Warning $_.Exception.Message
        exit 1
    }
}

Add-Type -AssemblyName System.Windows.Forms
try {
    Jogar ($Acao -eq 'Diagnostico')
} catch {
    Exibir-Mensagem $_.Exception.Message
    exit 1
}
