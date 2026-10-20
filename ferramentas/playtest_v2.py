#!/usr/bin/env python3
"""Roda o robô de playtest da v2 (#301) em lote e escreve um relatório.

Cada partida é um processo Godot com `res://v2/mundo.tscn -- --playtest --heroi=H --mapa=M --semente=S`: o robô do
v2/roteiro.gd (funções _pt_*) joga a partida inteira e imprime `PLAYTEST_JSON: {...}` no fim, ou `TRAVA: ...` antes
dele se travar. A matriz herói x mapa x semente roda em paralelo, um processo por partida. O log bruto de cada partida,
o relatorio.md e o relatorio.json ficam na pasta de saída (ferramentas/saida_playtest/, fora do Git).
Explicação completa, tipos de trava e limites do robô: docs/PLAYTEST_V2.md.

Uso (a partir da raiz do repo; só biblioteca padrão do Python 3):
  python ferramentas/playtest_v2.py --godot <Godot 4.4.1 console>       matriz inteira: 3 heróis x 4 mapas, semente 1
  python ferramentas/playtest_v2.py --herois hazaki --mapas floresta,cidade --sementes 1-3 --max 300
  python ferramentas/playtest_v2.py --janela --herois nicao --mapas cidade -- --sem_vsync     FPS real, uma por vez
  python ferramentas/playtest_v2.py --simular ...                        só imprime os comandos, não roda nada
Tudo depois de um `--` sozinho vai para o jogo, no fim da linha de cada partida (ex.: `-- --playtest_trava=cartas`).

Guarda do save real (só Windows): antes e depois do lote, tira o retrato (sha256) dos arquivos regulares da raiz de `user://`
(%APPDATA%/Godot/app_userdata/K.I.K.I.U/, sem olhar as pastas playtest/ e logs/). Se algo mudou, o relatório ganha a seção
"SAVE REAL ALTERADO" e a saída é 4. `--sem-guarda-save` desliga (para depurar). No início do lote, também apaga os
`meta_*.cfg*` órfãos de `user://playtest/` com mais de 1 hora.

Código de saída: 0 sem trava, crash nem timeout; 1 se houve algum; 2 erro de uso (Godot, herói, mapa, semente);
4 o save real mudou durante o lote (vale mais que 1 e 130); 130 lote interrompido (Ctrl+C).
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PROJETO = RAIZ / "jogos" / "hordas" / "projeto"
CENA = "res://v2/mundo.tscn"
SAIDA_PADRAO = RAIZ / "ferramentas" / "saida_playtest"
VERSAO_EXIGIDA = "4.4.1"  # outra versão do Godot reescreve o project.godot e os .uid
MAX_JOGO_ROBO = 900.0  # o padrão do --playtest_max no roteiro.gd (usado só para calcular o timeout do modo --janela)
# desfecho que o robô grava no JSON -> desfecho do relatório
DESFECHOS = {"vitoria": "vitoria", "morte": "derrota", "abandono": "derrota", "tempo": "tempo", "trava": "trava"}
PROBLEMAS = ("trava", "sem_json")
NOME_USER_PADRAO = "K.I.K.I.U"  # config/name do project.godot (pasta de user:// no Windows)
ORFAO_SEGUNDOS = 3600.0  # meta_*.cfg de playtest mais velho que isso é órfão de partida morta

_VIVOS = set()  # processos Godot rodando agora (para matar no timeout e no Ctrl+C)
_TRAVA_VIVOS = threading.Lock()
_PARAR = threading.Event()


class ErroUso(Exception):
    """Erro de configuração: vira mensagem e código 2, antes de criar pasta ou rodar partida."""


# ------------------------------------------------------------------ guarda do save real


def nome_user():
    """O config/name do project.godot decide a pasta de user:// (o projeto não usa use_custom_user_dir)."""
    try:
        m = re.search(r'^config/name="([^"]+)"', (PROJETO / "project.godot").read_text(encoding="utf-8"), re.M)
    except OSError:
        m = None
    return m.group(1) if m else NOME_USER_PADRAO


def pasta_user():
    """Raiz de user:// no Windows (%APPDATA%/Godot/app_userdata/<nome>); None fora do Windows ou sem %APPDATA%."""
    base = os.environ.get("APPDATA") if os.name == "nt" else None
    return Path(base) / "Godot" / "app_userdata" / nome_user() if base else None


def retrato_user(pasta):
    """{nome: (sha256, mtime_ns)} dos arquivos regulares da RAIZ de `pasta`. Subpastas (playtest/, logs/, shader_cache/) não entram."""
    ret = {}
    if pasta is None or not pasta.is_dir():
        return ret
    for f in sorted(pasta.iterdir()):
        try:
            if not f.is_file():
                continue
            mt = f.stat().st_mtime_ns
            ret[f.name] = (hashlib.sha256(f.read_bytes()).hexdigest(), mt)
        except OSError:
            ret[f.name] = ("ILEGIVEL", 0)  # travado pelo jogo real, por exemplo
    return ret


def comparar_retratos(antes, depois):
    """Lista de (nome, 'alterado'|'criado'|'apagado', mtime_ns de agora ou 0). Só o CONTEÚDO conta: mtime sozinho não acusa."""
    difs = []
    for nome in sorted(set(antes) | set(depois)):
        a, d = antes.get(nome), depois.get(nome)
        if a is None:
            difs.append((nome, "criado", d[1]))
        elif d is None:
            difs.append((nome, "apagado", 0))
        elif a[0] == "ILEGIVEL" or d[0] == "ILEGIVEL":
            difs.append((nome, "ilegível (não deu para conferir: travado?)", d[1]))  # na dúvida, acusa
        elif a[0] != d[0]:
            difs.append((nome, "alterado", d[1]))
    return difs


def limpar_orfaos(pasta, agora=None, limite=ORFAO_SEGUNDOS):
    """Apaga user://playtest/meta_*.cfg* com mais de `limite` s. Só os velhos: o de um lote paralelo ainda vivo é novo."""
    pt = pasta / "playtest" if pasta else None
    if pt is None or not pt.is_dir():
        return 0
    agora = time.time() if agora is None else agora
    apagados = 0
    for f in pt.glob("meta_*.cfg*"):
        try:
            if f.is_file() and agora - f.stat().st_mtime > limite:
                f.unlink()
                apagados += 1
        except OSError:
            pass
    return apagados


def texto_mtime(mt_ns, t_ini, t_fim):
    if not mt_ns:
        return ""
    quando = datetime.datetime.fromtimestamp(mt_ns / 1e9).strftime("%Y-%m-%d %H:%M:%S")
    dentro = t_ini <= mt_ns / 1e9 <= t_fim
    return f"mtime {quando}" + (" (DENTRO do lote: o jogo real pode estar aberto)" if dentro else " (fora do lote)")


# ------------------------------------------------------------------ argumentos


def lista(texto):
    return [x.strip() for x in texto.split(",") if x.strip()]


def ler_sementes(texto):
    """'1' -> [1]; '1,2,3' -> [1, 2, 3]; '1-5' -> [1..5]; '1-3,8' também vale."""
    r = []
    for parte in lista(texto):
        m = re.fullmatch(r"(\d+)-(\d+)", parte)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if a > b:
                raise ErroUso(f"faixa de sementes ao contrário: '{parte}' (use '{b}-{a}')")
            r += list(range(a, b + 1))
        elif re.fullmatch(r"\d+", parte):
            r.append(int(parte))
        else:
            raise ErroUso(f"semente inválida: '{parte}' (use '1', '1,2,3' ou '1-5')")
    if not r:
        raise ErroUso("nenhuma semente em --sementes")
    return list(dict.fromkeys(r))


def ids_validos():
    """Heróis de dados/v2_herois.json e mapas da LISTA do v2/mapas.gd. Lista vazia = não deu para ler, e aí não confere."""
    herois, mapas = [], []
    try:
        d = json.loads((PROJETO / "dados" / "v2_herois.json").read_text(encoding="utf-8"))
        herois = [str(h["id"]) for h in d.get("herois", [])]
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        pass
    try:
        mapas = re.findall(r'\{"id": "([a-z0-9_]+)"', (PROJETO / "v2" / "mapas.gd").read_text(encoding="utf-8"))
    except OSError:
        pass
    return herois, mapas


def conferir_ids(pedidos, validos, nome):
    if not pedidos:
        raise ErroUso(f"nenhum {nome} na lista")
    if validos:
        ruins = [x for x in pedidos if x not in validos]
        if ruins:
            raise ErroUso(f"{nome} desconhecido: {', '.join(ruins)} (válidos: {', '.join(validos)})")


def achar_godot(valor):
    if not valor:
        raise ErroUso("falta o Godot: passe --godot <caminho do Godot 4.4.1 console> ou defina a variável de ambiente GODOT")
    p = Path(valor)
    if p.is_file():
        return p.resolve().as_posix()
    w = shutil.which(valor)
    if w:
        return w
    raise ErroUso(f"Godot não encontrado em '{valor}' (nem no PATH); passe --godot <caminho do Godot {VERSAO_EXIGIDA} console>")


def versao_godot(godot):
    """Roda `godot --version` (não abre o projeto) e exige a 4.4.1."""
    try:
        r = subprocess.run([godot, "--version"], cwd=RAIZ, stdin=subprocess.DEVNULL, capture_output=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise ErroUso(f"'{godot}' não respondeu a --version: {e}")
    saida = (r.stdout or b"").decode("utf-8", "replace") + (r.stderr or b"").decode("utf-8", "replace")
    m = re.search(r"^(\d+\.\d+(?:\.\d+)?)\.\S+", saida, re.M)
    if not m:
        raise ErroUso(f"'{godot}' não parece um Godot: --version respondeu {saida.strip()[:200]!r}")
    if m.group(1) != VERSAO_EXIGIDA:
        raise ErroUso(
            f"o projeto exige o Godot {VERSAO_EXIGIDA} e '{godot}' é o {m.group(0)} (outra versão reescreve o project.godot e os .uid)"
        )
    return m.group(0)


def criar_parser():
    nucleos = os.cpu_count() or 2
    p = argparse.ArgumentParser(
        prog="playtest_v2.py",
        description="Roda o robô de playtest da v2 (#301) na matriz herói x mapa x semente, em paralelo, e escreve relatorio.md e "
        "relatorio.json. Tudo depois de um `--` sozinho vai para o jogo. Detalhes: docs/PLAYTEST_V2.md.",
    )
    p.add_argument("--godot", default=os.environ.get("GODOT", ""), help="Godot 4.4.1 (console no Windows); padrão: variável GODOT")
    p.add_argument("--herois", default="hazaki,nicao,lucas", help="lista separada por vírgula (padrão: hazaki,nicao,lucas)")
    p.add_argument("--mapas", default="floresta,laboratorio,cidade,medio", help="lista separada por vírgula (padrão: os 4 mapas)")
    p.add_argument("--sementes", default="1", help="'1', '1,2,3' ou '1-5' (padrão: 1)")
    metade = max(1, nucleos // 2)
    p.add_argument("--paralelas", type=int, default=None, help=f"partidas ao mesmo tempo (padrão: metade dos núcleos, {metade})")
    p.add_argument("--max", type=float, default=None, help="teto de tempo de JOGO em s, repassado como --playtest_max (padrão do robô: 900)")
    p.add_argument("--timeout", type=float, default=1200.0, help="limite de tempo REAL por partida em s (padrão: 1200)")
    p.add_argument("--saida", default=None, help="pasta do relatório e dos logs (padrão: ferramentas/saida_playtest/<data-hora>)")
    p.add_argument("--janela", action="store_true", help="modo FPS: sem --headless e sem --fixed-fps, uma partida por vez (abre janela)")
    p.add_argument("--sem-guarda-save", dest="sem_guarda", action="store_true",
                   help="não confere se a raiz de user:// (o save real) mudou durante o lote (depuração)")
    p.add_argument("--simular", action="store_true", help="só imprime os comandos de cada partida, sem rodar nem criar pasta")
    return p


# ------------------------------------------------------------------ rodar


def plural(n, singular, plural_):
    return f"{n} {singular if n == 1 else plural_}"


def montar_comando(cfg, heroi, mapa, semente, log_godot=None):
    c = [cfg["godot"]]
    if not cfg["janela"]:
        c += ["--headless", "--fixed-fps", "60"]
    else:
        c += ["--audio-driver", "Dummy"]  # sem som no alto-falante durante o lote
    if log_godot is not None:  # log do motor próprio da partida: não gira o user://logs/godot.log do jogo real
        c += ["--log-file", Path(log_godot).as_posix()]
    c += ["--path", PROJETO.as_posix(), CENA, "--", "--playtest", f"--heroi={heroi}", f"--mapa={mapa}", f"--semente={semente}"]
    if cfg["max"] is not None:
        c.append(f"--playtest_max={cfg['max']:g}")
    return c + cfg["extras"]


def matar_arvore(proc):
    """Mata o processo e os filhos dele. O Godot _console.exe abre um Godot_*.exe filho, que sobrevive se só o pai morrer.
    Só por PID: nunca por nome de imagem, porque outros Godot (de outras sessões) podem estar rodando na máquina."""
    if proc.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], stdin=subprocess.DEVNULL, capture_output=True)
    else:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
    try:
        proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()


def comando_texto(cmd):
    """Comando para colar no terminal: aspas duplas no Windows (cmd/PowerShell), POSIX no resto."""
    if os.name == "nt":
        return " ".join(f'"{x}"' if re.search(r"[\s&|<>^]", x) or not x else x for x in cmd)
    return shlex.join(cmd)


def descrever_codigo(c):
    if c is None:
        return "?"
    if c > 0xFFFF:  # Windows: exceção (0xC0000005 = acesso inválido, por exemplo)
        return f"{c} (0x{c:08X})"
    if c < 0:  # POSIX: morto por sinal
        return f"{c} (sinal {-c})"
    return str(c)


def ler_log(r, log):
    texto = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
    linhas = [x.rstrip() for x in texto.splitlines()]
    for linha in linhas:
        if "PLAYTEST_JSON: " in linha:
            try:
                r["json"] = json.loads(linha.split("PLAYTEST_JSON: ", 1)[1])
            except ValueError:
                r["motivo"] = "linha PLAYTEST_JSON ilegível (cortada?)"
        elif linha.startswith("TRAVA: "):
            r["trava_linha"] = linha
        elif "SCRIPT ERROR" in linha:
            r["erros_script"] += 1
    r["_cauda"] = [x for x in linhas if x.strip()][-15:]


def classificar(r, estourou, timeout):
    j = r["json"]
    if isinstance(j, dict):
        bruto = str(j.get("desfecho", "?"))
        r["desfecho_jogo"] = bruto
        r["desfecho"] = DESFECHOS.get(bruto, bruto)
        if r["desfecho"] == "trava" and not r["trava_linha"]:
            r["trava_linha"] = f"TRAVA: {j.get('trava', '')} (do PLAYTEST_JSON; a linha TRAVA não apareceu no log)"
        if r["desfecho"] != "trava" and (estourou or r["codigo"] not in (0, 3, None)):
            # imprimiu o JSON mas morreu depois (crash ao sair ou pendurado): conta como problema, sem jogar o JSON fora
            r["desfecho"] = "sem_json"
            if estourou:
                r["motivo"] = f"PLAYTEST_JSON impresso, mas o processo passou de {timeout:g} s reais e foi morto (código {descrever_codigo(r['codigo'])})"
            else:
                r["motivo"] = f"PLAYTEST_JSON impresso, mas o processo saiu com código {descrever_codigo(r['codigo'])} (crash?)"
        return
    r["json"] = None
    if r["trava_linha"]:
        r["desfecho"] = "trava"
        r["motivo"] = "TRAVA sem PLAYTEST_JSON depois"
    elif estourou:
        r["desfecho"] = "sem_json"
        r["motivo"] = f"timeout: passou de {timeout:g} s reais e foi morto (código {descrever_codigo(r['codigo'])})"
    else:
        r["desfecho"] = "sem_json"
        r["motivo"] = r["motivo"] or f"saiu sem PLAYTEST_JSON, código {descrever_codigo(r['codigo'])} (crash?)"


def rodar_partida(cfg, p):
    nome = f"{p['heroi']}_{p['mapa']}_s{p['semente']}"
    log = cfg["saida"] / "logs" / f"{nome}.log"
    cmd = montar_comando(cfg, p["heroi"], p["mapa"], p["semente"], cfg["saida"] / "logs" / f"{nome}.godot.log")
    r = {
        "heroi": p["heroi"],
        "mapa": p["mapa"],
        "semente": p["semente"],
        "desfecho": "sem_json",
        "desfecho_jogo": "",
        "motivo": "",
        "codigo": None,
        "tempo_real_s": 0.0,
        "log": f"logs/{nome}.log",
        "trava_linha": "",
        "erros_script": 0,
        "comando": comando_texto(cmd),
        "json": None,
        "_cauda": [],
    }
    if _PARAR.is_set():
        r["motivo"] = "não rodou (lote interrompido)"
        return r
    t0 = time.monotonic()
    estourou = False
    with open(log, "wb") as f:
        extra = {} if os.name == "nt" else {"start_new_session": True}
        try:
            proc = subprocess.Popen(cmd, cwd=PROJETO, stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.STDOUT, **extra)
        except OSError as e:
            r["motivo"] = f"o Godot não abriu: {e}"
            return r
        with _TRAVA_VIVOS:
            _VIVOS.add(proc)
        try:
            r["codigo"] = proc.wait(timeout=cfg["timeout"])
        except subprocess.TimeoutExpired:
            estourou = True
            matar_arvore(proc)
            r["codigo"] = proc.returncode
        finally:
            with _TRAVA_VIVOS:
                _VIVOS.discard(proc)
    r["tempo_real_s"] = round(time.monotonic() - t0, 1)
    ler_log(r, log)
    classificar(r, estourou, cfg["timeout"])
    if _PARAR.is_set() and r["desfecho"] in PROBLEMAS:
        r["motivo"] += " (lote interrompido)"
    return r


def linha_progresso(n, total, r, janela):
    base = f"[{n}/{total}] {r['heroi']} {r['mapa']} s{r['semente']}: "
    j = r["json"]
    if r["desfecho"] == "trava":
        return base + f"TRAVA {r['trava_linha'].removeprefix('TRAVA: ')} (log: {r['log']})"
    if j is None or r["desfecho"] == "sem_json":
        return base + f"SEM_JSON {r['motivo']} (log: {r['log']})"
    p95 = (j.get("proc_ms") or {}).get("p95", "?")
    txt = f"{r['desfecho']} t={fmt_tempo(j.get('tempo_jogo'))} nível {j.get('nivel', '?')}, {j.get('abates', '?')} abates, proc p95 {p95} ms"
    q = j.get("quadro_ms") or {}
    if janela and q.get("media"):  # no headless o dt é fixo (--fixed-fps): FPS não quer dizer nada
        txt += f", {1000.0 / q['media']:.0f} FPS médio"
    if r["erros_script"]:
        txt += f", {r['erros_script']} SCRIPT ERROR"
    return base + txt + f" ({r['tempo_real_s']:.0f} s reais)"


def rodar_lote(cfg, matriz):
    """Roda tudo e devolve (resultados na ordem da matriz, interrompido)."""
    total = len(matriz)
    resultados = [None] * total
    feitos = 0
    ex = concurrent.futures.ThreadPoolExecutor(max_workers=cfg["paralelas"])
    futuros = {ex.submit(rodar_partida, cfg, p): i for i, p in enumerate(matriz)}
    pendentes = set(futuros)
    interrompido = False
    try:
        while pendentes:
            # espera com prazo curto: assim o Ctrl+C chega ao Python também no Windows
            prontos, pendentes = concurrent.futures.wait(pendentes, timeout=0.5, return_when=concurrent.futures.FIRST_COMPLETED)
            for fut in prontos:
                r = fut.result()
                resultados[futuros[fut]] = r
                feitos += 1
                print(linha_progresso(feitos, total, r, cfg["janela"]), flush=True)
    except KeyboardInterrupt:
        interrompido = True
        _PARAR.set()
        print("\nInterrompido: matando as partidas em andamento...", flush=True)
        with _TRAVA_VIVOS:
            vivos = list(_VIVOS)
        for proc in vivos:
            matar_arvore(proc)
        ex.shutdown(wait=True, cancel_futures=True)
        for fut, i in futuros.items():
            if resultados[i] is None and fut.done() and not fut.cancelled():
                resultados[i] = fut.result()
    finally:
        ex.shutdown(wait=True)
    return [r for r in resultados if r is not None], interrompido


# ------------------------------------------------------------------ relatório


def fmt_tempo(s):
    if s is None:
        return "?"
    s = int(round(float(s)))
    return f"{s // 60}:{s % 60:02d}"


def fmt(v, casas=0):
    if v is None or v == "":
        return "—"
    if isinstance(v, (int, float)):
        return f"{v:.{casas}f}" if casas else str(int(round(v)))
    return str(v)


def celula(texto):
    return str(texto).replace("|", "\\|").replace("\n", " ")


def tipo_trava(r):
    if r["desfecho"] == "trava":
        t = (r["json"] or {}).get("trava") or r["trava_linha"].removeprefix("TRAVA: ")
        return t.split(" ")[0]
    if r["desfecho"] == "sem_json":
        return r["motivo"]
    return ""


def pct(j, chave, campo):
    return ((j or {}).get(chave) or {}).get(campo)


def fps_de(ms):
    return 1000.0 / ms if ms else None


def tabela(cab, linhas):
    out = ["| " + " | ".join(cab) + " |", "|" + "|".join("---" for _ in cab) + "|"]
    out += ["| " + " | ".join(celula(c) for c in ln) + " |" for ln in linhas]
    return out


def media(vals):
    v = [x for x in vals if isinstance(x, (int, float))]
    return sum(v) / len(v) if v else None


def agregados(res, chave, rotulo, janela):
    grupos = {}
    for r in res:
        grupos.setdefault(r[chave], []).append(r)
    cab = [rotulo, "Partidas", "Vitórias", "Derrotas", "Tempo esgotado", "Travas", "Sem JSON", "Tempo de jogo médio", "Nível médio",
           "Abates médios", "Dano sofrido médio", "Golpes tomados médios", "proc_ms p95 médio", "proc_ms p99 pior"]
    if janela:
        cab += ["FPS médio", "quadro_ms p99 pior"]
    linhas = []
    for k, rs in grupos.items():
        js = [r["json"] for r in rs if r["json"]]
        conta = {d: sum(1 for r in rs if r["desfecho"] == d) for d in ("vitoria", "derrota", "tempo", "trava", "sem_json")}
        p99 = [pct(j, "proc_ms", "p99") for j in js if pct(j, "proc_ms", "p99") is not None]
        ln = [k, len(rs), conta["vitoria"], conta["derrota"], conta["tempo"], conta["trava"], conta["sem_json"],
              fmt_tempo(media(j.get("tempo_jogo") for j in js)) if js else "—", fmt(media(j.get("nivel") for j in js), 1),
              fmt(media(j.get("abates") for j in js)), fmt(media(j.get("dano_sofrido") for j in js)),
              fmt(media(j.get("golpes_tomados") for j in js), 1), fmt(media(pct(j, "proc_ms", "p95") for j in js), 2),
              fmt(max(p99) if p99 else None, 2)]
        if janela:
            q99 = [pct(j, "quadro_ms", "p99") for j in js if pct(j, "quadro_ms", "p99") is not None]
            ln += [fmt(fps_de(media(pct(j, "quadro_ms", "media") for j in js))), fmt(max(q99) if q99 else None, 2)]
        linhas.append(ln)
    return tabela(cab, linhas)


def escrever_relatorio(cfg, matriz_desc, res, duracao, interrompido):
    janela = cfg["janela"]
    conta = {d: sum(1 for r in res if r["desfecho"] == d) for d in ("vitoria", "derrota", "tempo", "trava", "sem_json")}
    problemas = conta["trava"] + conta["sem_json"]
    g = cfg.get("guarda") or {"estado": "desligada", "mudancas": []}
    estado = "INTERROMPIDO" if interrompido else ("COM PROBLEMAS" if problemas else "OK")
    if g["estado"] == "alterado":
        estado = "SAVE REAL ALTERADO" + (" + " + estado if estado != "OK" else "")
    agora = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    md = [f"# Playtest da v2: lote de {agora} ({estado})", ""]
    md += [
        "Robô de playtest (#301) rodado por `ferramentas/playtest_v2.py`; o que cada coluna e cada trava quer dizer está em "
        "`docs/PLAYTEST_V2.md`.",
        "",
        f"- **Godot:** {cfg['versao']} (`{cfg['godot']}`)",
        "- **Modo:** " + ("janela, sem `--fixed-fps` (FPS real de render, uma partida por vez)" if janela else
                          "headless com `--fixed-fps 60` (o custo é o `proc_ms`; FPS não vale neste modo)"),
        f"- **Matriz:** {matriz_desc}; {cfg['paralelas']} em paralelo",
        "- **Teto de tempo de jogo:** " + (f"{cfg['max']:g} s (`--max`)" if cfg["max"] is not None else "900 s (padrão do robô)")
        + f"; timeout real por partida: {cfg['timeout']:g} s",
        f"- **Argumentos extras para o jogo:** `{' '.join(cfg['extras'])}`" if cfg["extras"] else "- **Argumentos extras para o jogo:** nenhum",
        f"- **Tempo real do lote:** {fmt_tempo(duracao)}",
        "- **Guarda do save real:** " + {"ok": "conferida, a raiz de `user://` não mudou", "alterado": "**ALTERADO** (veja a seção abaixo)",
                                         "pulada": "pulada: " + g.get("motivo", ""), "desligada": "desligada (`--sem-guarda-save`)"}[g["estado"]],
        f"- **Resultado:** {plural(len(res), 'partida', 'partidas')}: {plural(conta['vitoria'], 'vitória', 'vitórias')}, "
        f"{plural(conta['derrota'], 'derrota', 'derrotas')}, {conta['tempo']} no teto de tempo, "
        f"**{plural(conta['trava'], 'trava', 'travas')}**, **{conta['sem_json']} sem JSON** (crash ou timeout)",
        "",
    ]
    if g["estado"] == "alterado":
        md += ["## SAVE REAL ALTERADO", "",
               f"Arquivos da raiz de `{g['pasta']}` mudaram de conteúdo entre o começo e o fim do lote. O robô só deveria escrever em "
               "`user://playtest/` e `user://logs/`. Duas causas: o jogo real estava aberto (ou foi aberto) durante o lote, ou o robô "
               "escreveu onde não devia (bug: confira o desvio `Meta.caminho_save` no `mundo.gd`).", ""]
        md += [f"- `{n}`: {t}" + (f"; {m}" if m else "") for n, t, m in g["mudancas"]]
        md.append("")
    if interrompido:
        md += ["**O lote foi interrompido (Ctrl+C):** só as partidas que terminaram estão aqui.", ""]

    if janela:
        md += ["## FPS de render (modo janela)", "",
               "FPS = 1000 / quadro_ms. O alvo é o i5-3470 do Breno: 60 FPS (quadro_ms até 16,7) também no p95 e no p99.", ""]
        linhas = []
        for r in res:
            j = r["json"]
            q = (j or {}).get("quadro_ms") or {}
            linhas.append([f"{r['heroi']} / {r['mapa']} / {r['semente']}", fmt(fps_de(q.get("media"))), fmt(fps_de(q.get("p95"))),
                           fmt(q.get("media"), 2), fmt(q.get("p50"), 2), fmt(q.get("p95"), 2), fmt(q.get("p99"), 2), fmt(q.get("max"), 2),
                           fmt(pct(j, "proc_ms", "p95"), 2), fmt((j or {}).get("pico_vivos"))])
        md += tabela(["Partida", "FPS médio", "FPS no p95", "quadro_ms média", "p50", "p95", "p99", "máx", "proc_ms p95", "Pico de vivos"],
                     linhas)
        md.append("")

    md += ["## Partidas", "",
           "Tempo de jogo em min:s. `proc_ms` = tempo do `_process` do mundo por quadro (lógica do jogo e o robô, sem o render), em ms; "
           "p95 = 95% dos quadros gastaram até isso.", ""]
    linhas = []
    for r in res:
        j = r["json"] or {}
        des = r["desfecho"] if r["desfecho"] not in PROBLEMAS else f"**{r['desfecho']}**"
        vida = f"{fmt(j.get('vida_final'))}/{fmt(j.get('vida_max'))}" if j else "—"
        chefes = j.get("chefes")
        linhas.append([r["heroi"], r["mapa"], r["semente"], des, fmt_tempo(j.get("tempo_jogo")) if j else "—", fmt(j.get("nivel")),
                       fmt(j.get("abates")), fmt(j.get("dano_sofrido")), fmt(j.get("golpes_tomados")), vida, fmt(j.get("baus")),
                       fmt(j.get("elites")), fmt(len(chefes)) if isinstance(chefes, list) else "—", fmt(pct(j, "proc_ms", "p95"), 2),
                       fmt(pct(j, "proc_ms", "p99"), 2), tipo_trava(r)])
    md += tabela(["Herói", "Mapa", "Semente", "Desfecho", "Tempo de jogo", "Nível", "Abates", "Dano sofrido", "Golpes tomados",
                  "Vida final", "Baús", "Elites", "Chefes", "proc_ms p95", "proc_ms p99", "Trava"], linhas)
    md += ["", "## Por herói", ""] + agregados(res, "heroi", "Herói", janela)
    md += ["", "## Por mapa", ""] + agregados(res, "mapa", "Mapa", janela)

    travas = [r for r in res if r["desfecho"] == "trava"]
    md += ["", "## Travas", ""]
    if not travas:
        md.append("Nenhuma.")
    for r in travas:
        md += [f"### {r['heroi']} / {r['mapa']} / semente {r['semente']}", "", "```", r["trava_linha"], "```", ""]
        if r["motivo"]:
            md += [f"Observação: {r['motivo']}.", ""]
        md += [f"Log: `{r['log']}`. Reproduzir:", "", "```", r["comando"], "```", ""]

    sem = [r for r in res if r["desfecho"] == "sem_json"]
    md += ["", "## Sem PLAYTEST_JSON (crash ou timeout)", ""]
    if not sem:
        md.append("Nenhuma.")
    for r in sem:
        md += [f"### {r['heroi']} / {r['mapa']} / semente {r['semente']}", "",
               f"{r['motivo']}. Tempo real: {r['tempo_real_s']:g} s. Log: `{r['log']}`. Fim do log:", "", "```"]
        md += r["_cauda"] or ["(log vazio)"]
        md += ["```", "", "Reproduzir:", "", "```", r["comando"], "```", ""]

    obs = [r for r in res if r["desfecho"] not in PROBLEMAS and (r["motivo"] or r["erros_script"])]
    obs += [r for r in res if r["desfecho"] in PROBLEMAS and r["erros_script"]]
    if obs:
        md += ["", "## Observações", ""]
        for r in obs:
            partes = [r["motivo"]] if r["motivo"] and r["desfecho"] not in PROBLEMAS else []
            if r["erros_script"]:
                partes.append(f"{r['erros_script']} linhas `SCRIPT ERROR` no log")
            md.append(f"- {r['heroi']} / {r['mapa']} / semente {r['semente']}: {'; '.join(partes)} (`{r['log']}`).")

    md.append("")
    (cfg["saida"] / "relatorio.md").write_text("\n".join(md), encoding="utf-8", newline="\n")
    crus = [{k: v for k, v in r.items() if not k.startswith("_")} for r in res]
    (cfg["saida"] / "relatorio.json").write_text(json.dumps(crus, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    return problemas


# ------------------------------------------------------------------ principal


def preparar(a, extras):
    herois, mapas = lista(a.herois), lista(a.mapas)
    h_ok, m_ok = ids_validos()
    conferir_ids(herois, h_ok, "herói")
    conferir_ids(mapas, m_ok, "mapa")
    sementes = ler_sementes(a.sementes)
    pedido = a.paralelas is not None
    if not pedido:
        a.paralelas = max(1, (os.cpu_count() or 2) // 2)
    if a.paralelas < 1:
        raise ErroUso("--paralelas precisa ser 1 ou mais")
    if a.timeout <= 0 or (a.max is not None and a.max <= 0):
        raise ErroUso("--timeout e --max precisam ser maiores que zero")
    godot = achar_godot(a.godot)
    cfg = {
        "godot": godot,
        "versao": "(não conferida: --simular)" if a.simular else versao_godot(godot),
        "janela": a.janela,
        "max": a.max,
        "timeout": a.timeout,
        "paralelas": a.paralelas,
        "extras": extras,
        "saida": Path(a.saida).resolve() if a.saida else SAIDA_PADRAO / datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S"),
    }
    avisos = []
    if a.janela:
        if pedido and a.paralelas != 1:
            avisos.append(f"modo --janela: --paralelas {a.paralelas} virou 1 (partidas juntas roubam FPS uma da outra)")
        cfg["paralelas"] = 1
        # na janela o jogo anda em tempo real: o timeout precisa cobrir o teto de tempo de jogo inteiro
        minimo = (a.max if a.max is not None else MAX_JOGO_ROBO) * 1.2 + 120.0
        if cfg["timeout"] < minimo:
            avisos.append(f"modo --janela: timeout subiu de {cfg['timeout']:g} s para {minimo:g} s (o jogo anda em tempo real)")
            cfg["timeout"] = minimo
    matriz = [{"heroi": h, "mapa": m, "semente": s} for h in herois for m in mapas for s in sementes]
    cfg["paralelas"] = max(1, min(cfg["paralelas"], len(matriz)))
    desc = (f"{len(matriz)} {'partida' if len(matriz) == 1 else 'partidas'} "
            f"({len(herois)} {'herói' if len(herois) == 1 else 'heróis'} x {len(mapas)} {'mapa' if len(mapas) == 1 else 'mapas'} "
            f"x {len(sementes)} {'semente' if len(sementes) == 1 else 'sementes'}): "
            f"heróis {', '.join(herois)}; mapas {', '.join(mapas)}; sementes {', '.join(map(str, sementes))}")
    return cfg, matriz, desc, avisos


def main(argv=None):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    argv = list(sys.argv[1:] if argv is None else argv)
    extras = []
    if "--" in argv:
        i = argv.index("--")
        argv, extras = argv[:i], argv[i + 1:]
    a = criar_parser().parse_args(argv)
    try:
        cfg, matriz, desc, avisos = preparar(a, extras)
    except ErroUso as e:
        print(f"playtest_v2: erro: {e}", file=sys.stderr)
        return 2
    for av in avisos:
        print(f"playtest_v2: aviso: {av}")
    if a.simular:
        print(f"Simulação: {desc}. Comandos:")
        for p in matriz:
            lg = cfg["saida"] / "logs" / f"{p['heroi']}_{p['mapa']}_s{p['semente']}.godot.log"
            print(shlex.join(montar_comando(cfg, p["heroi"], p["mapa"], p["semente"], lg)))
        return 0
    (cfg["saida"] / "logs").mkdir(parents=True, exist_ok=True)
    print(f"Playtest v2: {desc}; {cfg['paralelas']} em paralelo; Godot {cfg['versao']}.")
    print(f"Saída: {cfg['saida']}", flush=True)
    pasta = pasta_user()
    n_orfaos = limpar_orfaos(pasta)
    if n_orfaos:
        print(f"playtest_v2: {plural(n_orfaos, 'save temporário órfão apagado', 'saves temporários órfãos apagados')} de user://playtest/.")
    antes = None
    if a.sem_guarda:
        cfg["guarda"] = {"estado": "desligada", "mudancas": []}
    elif pasta is None or not pasta.is_dir():
        motivo = "só confere no Windows" if pasta is None else f"pasta {pasta} não existe (o jogo nunca foi aberto aqui?)"
        cfg["guarda"] = {"estado": "pulada", "motivo": motivo, "mudancas": []}
        print(f"playtest_v2: aviso: guarda do save real pulada: {motivo}.")
    else:
        antes = retrato_user(pasta)
    t_ini = time.time()
    t0 = time.monotonic()
    res, interrompido = rodar_lote(cfg, matriz)
    if antes is not None:
        mud = [(n, t, texto_mtime(mt, t_ini, time.time())) for n, t, mt in comparar_retratos(antes, retrato_user(pasta))]
        cfg["guarda"] = {"estado": "alterado" if mud else "ok", "mudancas": mud, "pasta": str(pasta)}
    problemas = escrever_relatorio(cfg, desc, res, time.monotonic() - t0, interrompido)
    conta = {d: sum(1 for r in res if r["desfecho"] == d) for d in ("vitoria", "derrota", "tempo", "trava", "sem_json")}
    print(f"Fim: {plural(conta['vitoria'], 'vitória', 'vitórias')}, {plural(conta['derrota'], 'derrota', 'derrotas')}, "
          f"{conta['tempo']} no teto, {plural(conta['trava'], 'trava', 'travas')}, "
          f"{conta['sem_json']} sem JSON, em {fmt_tempo(time.monotonic() - t0)}.")
    print(f"Relatório: {cfg['saida'] / 'relatorio.md'}")
    if cfg["guarda"]["estado"] == "alterado":
        print(f"playtest_v2: SAVE REAL ALTERADO: {', '.join(n for n, _, _ in cfg['guarda']['mudancas'])} (veja o relatório).", file=sys.stderr)
        return 4
    if interrompido:
        return 130
    return 1 if problemas else 0


if __name__ == "__main__":
    sys.exit(main())
