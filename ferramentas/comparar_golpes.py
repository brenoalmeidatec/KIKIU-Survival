"""Compara saídas de testes/fotos/contrato_golpes.tscn: antes.json depois.json resumo.json."""

import hashlib
import json
import sys
from pathlib import Path


def digest(value):
    return hashlib.sha256(json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def main():
    antes, depois = [json.loads(Path(p).read_text(encoding="utf-8")) for p in sys.argv[1:3]]
    assert len(antes) == len(depois) == 8
    resumo = []
    impacto = "--impacto-lucas" in sys.argv[4:]
    for a, b in zip(antes, depois):
        assert (a["nome"], a["hz"], a["folha"]) == (b["nome"], b["hz"], b["folha"])
        if impacto and a["nome"] == "Lucas":
            def eventos(c):
                return [{"passo": p[0], "dano": anterior[10] - p[10], "golpe": p[4], "hit_stop": p[14]}
                        for anterior, p in zip(c["mecanica"], c["mecanica"][1:]) if anterior[10] != p[10]]

            ea, eb = eventos(a), eventos(b)
            assert [(e["dano"], e["golpe"]) for e in ea] == [(e["dano"], e["golpe"]) for e in eb]
            assert a["rng_final"] == b["rng_final"]
            assert a["mecanica"][-1][1:3] == b["mecanica"][-1][1:3], "posição física final mudou"
            assert a["mecanica"][-1][9:11] == b["mecanica"][-1][9:11], "fôlego/dano final mudou"
            resumo.append({"personagem": a["nome"], "hz": a["hz"], "eventos_envelope": ea,
                           "eventos_hit_stop": eb, "rng_final_igual": a["rng_final"],
                           "dano_folego_posicao_final_iguais": True, "mecanica_por_passo_igual": False})
            continue
        assert a["mecanica"] == b["mecanica"], (a["nome"], a["hz"], "mecânica mudou")
        assert a["rng_final"] == b["rng_final"], "RNG mudou"
        assert [x[4:] for x in a["visual"]] == [x[4:] for x in b["visual"]], "colunas ou efeitos mudaram"
        eventos = []
        anterior = a["mecanica"][0]
        for p in a["mecanica"][1:]:
            if p[10] != anterior[10]:
                eventos.append({"passo": p[0], "dano": anterior[10] - p[10], "golpe": p[4], "golpe_t": p[5], "hit_stop": p[14]})
            anterior = p
        resumo.append({
            "personagem": a["nome"], "hz": a["hz"], "folha": a["folha"],
            "passos_iguais": len(a["mecanica"]), "sha256_mecanica_antes_e_depois": digest(a["mecanica"]),
            "rng_final_igual": a["rng_final"], "eventos": eventos,
            "sha256_colunas_fx_antes_e_depois": digest([x[4:] for x in a["visual"]]),
            "quadros_corpo_alterados": sum(x[:4] != y[:4] for x, y in zip(a["visual"], b["visual"])),
        })
    Path(sys.argv[3]).write_text(json.dumps(resumo, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("contrato_golpes falhas=0:", "só Lucas muda relógio; dano/fôlego/RNG preservados" if impacto else "8 casos, mecânica/RNG/colunas/efeitos idênticos")


if __name__ == "__main__":
    main()
