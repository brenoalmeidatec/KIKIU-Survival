"""Regrava TITLE_ID (e TITLE/STITLE) no sce_sys/param.sfo de um .vpk e confere o resultado.

Por quê: o exportador do godot-vita 3.5-rc5 (platform/vita/export/vita-mksfoex.cpp) faz
`entry->data = sfo->title_id.to_upper().utf8().get_data();`, um ponteiro para uma string temporária já liberada.
Quando a memória é reaproveitada, o TITLE_ID sai com lixo ou com o título ("KIKIU Piloto") e o VitaShell recusa
a instalação com 0xF0030000 (VITASHELL_ERROR_INVALID_TITLEID: precisa ter 9 caracteres, maiúsculos).
É aleatório: o mesmo projeto exporta certo numa vez e errado na outra.

Uso: python conserta_sfo.py <arquivo.vpk> <TITLE_ID> <título>
"""
import struct
import sys
import zipfile
import os

SFO = "sce_sys/param.sfo"


def ler(sfo: bytes) -> dict:
    _, _, kt, dt, n = struct.unpack("<4sIIII", sfo[:20])
    campos = {}
    for i in range(n):
        ko, fmt, ln, mx, do = struct.unpack("<HHIII", sfo[20 + i * 16:36 + i * 16])
        nome = sfo[kt + ko:sfo.index(b"\0", kt + ko)].decode()
        campos[nome] = (i, fmt, ln, mx, dt + do)
    return campos


def gravar(sfo: bytearray, campos: dict, nome: str, texto: str) -> None:
    i, fmt, _, mx, onde = campos[nome]
    dado = texto.encode("utf-8") + b"\0"
    if len(dado) > mx:
        raise SystemExit("%s grande demais para o param.sfo (%d > %d)" % (nome, len(dado), mx))
    sfo[onde:onde + mx] = dado.ljust(mx, b"\0")
    struct.pack_into("<I", sfo, 20 + i * 16 + 4, len(dado))


def texto(sfo: bytes, campos: dict, nome: str) -> str:
    _, _, ln, _, onde = campos[nome]
    return sfo[onde:onde + ln].rstrip(b"\0").decode("utf-8", "replace")


def main() -> None:
    vpk, title_id, titulo = sys.argv[1], sys.argv[2], sys.argv[3]
    if len(title_id) != 9 or title_id != title_id.upper():
        raise SystemExit("TITLE_ID do preset inválido: %r (9 caracteres, maiúsculos)" % title_id)
    with zipfile.ZipFile(vpk) as z:
        itens = [(info, z.read(info.filename)) for info in z.infolist()]
    novo = []
    for info, dados in itens:
        if info.filename == SFO:
            sfo = bytearray(dados)
            campos = ler(bytes(sfo))
            antes = texto(bytes(sfo), campos, "TITLE_ID")
            gravar(sfo, campos, "TITLE_ID", title_id)
            gravar(sfo, campos, "TITLE", titulo)
            gravar(sfo, campos, "STITLE", titulo)
            campos = ler(bytes(sfo))
            depois = texto(bytes(sfo), campos, "TITLE_ID")
            if depois != title_id:
                raise SystemExit("falhou: TITLE_ID ficou %r" % depois)
            print("param.sfo: TITLE_ID %r -> %r" % (antes, depois))
            dados = bytes(sfo)
        novo.append((info, dados))
    tmp = vpk + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for info, dados in novo:
            z.writestr(info, dados, compress_type=zipfile.ZIP_DEFLATED)
    os.replace(tmp, vpk)


if __name__ == "__main__":
    main()
