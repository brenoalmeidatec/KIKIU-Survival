#!/usr/bin/env python3
"""Monta os mapas novos da v2 (laboratório, cidade) a partir dos brutos do Blender e das definições em mapas_v2/def_<mapa>.py.

Uso:  python jogos/hordas/fonte_arte/gerar_v2_mapas.py <laboratorio|cidade> [--previa SAIDA.png] [--recorte=x,y,w,h]
Antes: blender -b -P jogos/hordas/fonte_arte/modelos3d/mapas_v2.py -- <mapa>   (renderiza os objetos e o piso em mapas_v2/brutos/<mapa>/)

Saída:
  projeto/assets/v2/mapas/<mapa>/  enfeites.png + enfeites_normal.png + cenario.json   (atlas dos objetos: albedo, normal e as elipses de colisão)
                                    decalques.png + decalques.json                      (decalques de chão, desenhados em kit_decalques.py)
                                    piso.png + piso_normal.png                          (azulejo que repete, já achatado por sen 45)
  projeto/dados/v2_<mapa>.json     o mapa (mesmo formato de v2_floresta.json, mais "pastas", "minimapa" e "atmosfera")

Os passos do objeto são os mesmos da floresta (prototipos/cara_nova/objetos/gerar_objetos.py, que este script reaproveita para o pé e
a colisão): alfa binário, contorno escuro de 1 px por fora, paleta curta, normal map (aqui o do Blender, de verdade), elipses de colisão
relativas ao pé. Semente fixa: a saída é sempre a mesma. O JSON do mapa é DADOS: depois de gerado pode ser editado à mão.
"""
import importlib.util
import json
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image

AQUI = Path(__file__).resolve().parent
HORDAS = AQUI.parent
PROJ = HORDAS / "projeto"
BRUTOS = AQUI / "mapas_v2" / "brutos"
sys.path.insert(0, str(AQUI / "mapas_v2"))
ACHATA = 0.7071067811865476  # sen 45: o piso e os decalques vistos de cima ficam achatados na câmera 3/4
COR_CONTORNO = (13, 15, 20)
CORES_OBJETO = 40
CORES_PISO = 56


def _carregar_gerar_objetos():
    caminho = HORDAS / "prototipos" / "cara_nova" / "objetos" / "gerar_objetos.py"
    spec = importlib.util.spec_from_file_location("gerar_objetos", caminho)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


GO = _carregar_gerar_objetos()


# ------------------------------------------------------------------ objetos
def quantizar(rgb, cores):
    """Paleta curta sem dithering (pixel art), só com os pixels opacos; devolve RGB na paleta."""
    q = rgb.quantize(colors=cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return q.convert("RGB")


def processar_objeto(mapa, nome):
    pasta = BRUTOS / mapa
    cor = Image.open(pasta / (nome + ".png")).convert("RGBA")
    nor = Image.open(pasta / (nome + "_n.png")).convert("RGBA")
    origem = json.loads((pasta / (nome + ".json")).read_text())["origem"]
    a = np.asarray(cor.getchannel("A")) >= 128
    ys, xs = np.nonzero(a)
    if len(xs) == 0:
        raise SystemExit("%s: objeto vazio (alfa)" % nome)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    a = a[y0:y1, x0:x1]
    rgb = np.asarray(cor.convert("RGB"))[y0:y1, x0:x1].copy()
    nrm = np.asarray(nor.convert("RGB"))[y0:y1, x0:x1].copy()
    h, w = a.shape
    # miolo quantizado: pixels fora da silhueta viram a média, para não puxar a paleta
    rgb[~a] = rgb[a].mean(axis=0).astype(np.uint8)
    q = np.asarray(quantizar(Image.fromarray(rgb, "RGB"), CORES_OBJETO)).copy()
    # contorno escuro por fora (1 px, 4 vizinhos): a imagem cresce 1 px em cada lado
    pa = np.zeros((h + 2, w + 2), dtype=bool)
    pa[1:-1, 1:-1] = a
    viz = np.zeros_like(pa)
    viz[1:, :] |= pa[:-1, :]
    viz[:-1, :] |= pa[1:, :]
    viz[:, 1:] |= pa[:, :-1]
    viz[:, :-1] |= pa[:, 1:]
    anel = viz & ~pa
    alb = np.zeros((h + 2, w + 2, 4), dtype=np.uint8)
    alb[1:-1, 1:-1, :3] = q
    alb[pa, 3] = 255
    alb[anel, :3] = COR_CONTORNO
    alb[anel, 3] = 255
    nn = np.zeros((h + 2, w + 2, 4), dtype=np.uint8)
    nn[:, :, :3] = (128, 128, 255)
    nn[1:-1, 1:-1, :3] = np.where(a[..., None], nrm, np.array([128, 128, 255], dtype=np.uint8))
    nn[pa | anel, 3] = 255
    # origem (centro da pegada, no chão) no sprite pronto: +1 do contorno
    return Image.fromarray(alb, "RGBA"), Image.fromarray(nn, "RGBA"), (origem[0] - x0 + 1, origem[1] - y0 + 1)


def formas_colisao(alb, pe, nome, cfg):
    tipo = cfg.get("col", "disco")
    if tipo == "passavel":
        return []
    if tipo == "caixa" and cfg.get("forma") == "retangulo":
        # objeto de pegada retangular sólida (prédio, carro, contêiner...): a caixa cheia w x d (o resolver 'caixa' usa centro e meio-tamanho em px),
        # que cobre os cantos e o fundo que a elipse inscrita deixava passar; o pé é a frente da pegada
        folga = cfg.get("folga", 1.0)
        return [{"tipo": "caixa", "centro": [0.0, round(-cfg["d"] * 11.315, 1)], "meio": [round(cfg["w"] * 16.0 * folga, 1), round(cfg["d"] * 11.315 * folga, 1)]}]
    if tipo == "caixa":
        # pegada em metros (w x d): elipse inscrita, na projeção de verdade (1 m = 32 px de largura e 22,6 px de fundo); o pé é a frente da pegada
        rx = cfg["w"] * 16.0 * cfg.get("folga", 1.05)
        ry_m = cfg["d"] * 11.315
        return [{"tipo": "elipse", "centro": [0.0, round(-ry_m, 1)], "raio": [round(rx, 1), round(max(ry_m * cfg.get("folga", 1.05), 3.0), 1)]}]
    if tipo == "pegada":
        return GO._pegada_de_base(alb, pe, nome)
    if tipo == "larga":
        return GO._elipse_larga(alb, pe, nome)
    if tipo == "parede":
        # parede fina: uma elipse na largura da base e de profundidade ry (o resolver aceita qualquer ry; ela fica na linha do pé)
        faixa = GO._faixa_de_base(alb, pe, nome)
        esq = min(l for _, l, _r in faixa)
        dir_ = max(r for _, _l, r in faixa)
        rx = max(GO.COLISAO_RX_MIN, (dir_ - esq + 1) / 2.0)
        ry = float(cfg.get("ry", 8.0))
        return [{"tipo": "elipse", "centro": [round((esq + dir_) / 2.0, 1), round(-ry, 1)], "raio": [round(rx, 1), round(ry, 1)]}]
    if tipo == "disco_fino":  # poste: um disco só com o raio dado (px)
        r = float(cfg.get("r", 5.0))
        return [{"tipo": "elipse", "centro": [0.0, round(-r / 2.0, 1)], "raio": [r, round(r / 2.0, 1)]}]
    return GO._elipse_da_base(alb, pe, nome)


def montar_atlas_objetos(mapa, defs, saida):
    itens, albs, nors = [], [], []
    for nome, cfg in defs.items():
        alb, nor, origem = processar_objeto(mapa, nome)
        if cfg.get("pe"):
            pe = cfg["pe"]
        elif "d" in cfg:  # a frente da pegada: a origem do Blender mais metade da profundidade projetada
            pe = [int(round(origem[0])), min(alb.height - 1, int(round(origem[1] + cfg["d"] * 11.315)))]
        else:
            pe = GO.pe_do_objeto(alb)
        formas = formas_colisao(alb, pe, nome, cfg)
        albs.append(alb)
        nors.append(nor)
        itens.append({"nome": nome, "peso": cfg.get("peso", 1), "pe": list(pe), "colisao": formas})
        print("  %-20s %3dx%-3d pe %s colisao %d" % (nome, alb.width, alb.height, pe, len(formas)))
    pos, largura, altura = GO.empacotar([(i.width, i.height) for i in albs])
    folha = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
    folha_n = Image.new("RGBA", (largura, altura), (128, 128, 255, 0))
    for (x, y), a, n, it in zip(pos, albs, nors, itens):
        folha.paste(a, (x, y))
        folha_n.paste(n, (x, y))
        it["regiao"] = [x, y, a.width, a.height]
        if "fogo" in defs[it["nome"]]:
            fx, fy = defs[it["nome"]]["fogo"]
            it["fogo"] = [int(fx * a.width), int(fy * a.height)]
    folha.save(saida / "enfeites.png")
    folha_n.save(saida / "enfeites_normal.png")
    cen = {"_gerado_por": "jogos/hordas/fonte_arte/gerar_v2_mapas.py (nao edite a mao)", "enfeites": "enfeites.png",
           "enfeites_normal": "enfeites_normal.png", "itens": itens}
    (saida / "cenario.json").write_text(json.dumps(cen, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("atlas de objetos %dx%d" % (largura, altura))
    return {i["nome"]: i for i in itens}, folha


# ------------------------------------------------------------------ piso e decalques
def processar_piso(mapa, saida, detalhe=None):
    """detalhe (opcional, vem do def_<mapa>.py como detalhar_piso(img, rng)): pinta desgaste no azulejo achatado antes da paleta."""
    pasta = BRUTOS / mapa
    img = Image.open(pasta / "piso.png").convert("RGB")
    nor = Image.open(pasta / "piso_n.png").convert("RGB")
    h2 = int(round(img.height * ACHATA))
    img = img.resize((img.width, h2), Image.BOX)
    nor = nor.resize((nor.width, h2), Image.BOX)
    if detalhe is not None:
        img = detalhe(img)
    img = quantizar(img, CORES_PISO)
    img.save(saida / "piso.png")
    nor.save(saida / "piso_normal.png")
    print("piso %dx%d" % img.size)
    return img


def montar_decalques(defs, saida, rng):
    nomes, imgs = [], []
    for nome, f in defs.items():
        im = f(rng)
        nomes.append(nome)
        imgs.append(im)
    pos, largura, altura = GO.empacotar([(i.width, i.height) for i in imgs])
    folha = Image.new("RGBA", (largura, altura), (0, 0, 0, 0))
    itens = []
    for (x, y), im, nome in zip(pos, imgs, nomes):
        folha.paste(im, (x, y))
        itens.append({"nome": nome, "regiao": [x, y, im.width, im.height], "centro": [im.width // 2, im.height // 2]})
    folha.save(saida / "decalques.png")
    (saida / "decalques.json").write_text(json.dumps({"_gerado_por": "jogos/hordas/fonte_arte/gerar_v2_mapas.py (nao edite a mao)",
                                                      "itens": itens}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("decalques: %d em %dx%d" % (len(itens), largura, altura))
    return {i["nome"]: i for i in itens}, folha


# ------------------------------------------------------------------ JSON do mapa
def escrever_json(caminho, mapa_json):
    ordem = ["_ajuda", "semente", "mapa", "nascimento", "luz_tipos", "luz_objetos", "luzes", "minimapa", "atmosfera", "objetos", "decalques"]
    linhas = ["{"]
    for k in ordem:
        if k not in mapa_json:
            continue
        v = mapa_json[k]
        ult = k == ordem[-1] or k == [x for x in ordem if x in mapa_json][-1]
        fim = "" if ult else ","
        if k in ("objetos", "decalques", "luzes"):
            linhas.append('\t"%s": [\n' % k + ",\n".join("\t\t" + json.dumps(e, ensure_ascii=False) for e in v) + "\n\t]" + fim)
        elif k in ("luz_tipos", "luz_objetos", "minimapa", "atmosfera"):
            linhas.append('\t"%s": {\n' % k + ",\n".join("\t\t%s: %s" % (json.dumps(a, ensure_ascii=False), json.dumps(b, ensure_ascii=False))
                                                     for a, b in v.items()) + "\n\t}" + fim)
        else:
            linhas.append('\t"%s": %s%s' % (k, json.dumps(v, ensure_ascii=False), fim))
    linhas.append("}")
    caminho.write_text("\n".join(linhas) + "\n", encoding="utf-8")


# ------------------------------------------------------------------ prévia
def previa(mapa_json, obj_info, obj_folha, dec_info, dec_folha, piso, caminho, recorte=None, escala=0.5):
    from PIL import ImageEnhance
    W, H = mapa_json["mapa"]["tam"]
    tela = Image.new("RGBA", (W, H))
    for y in range(0, H, piso.height):
        for x in range(0, W, piso.width):
            tela.paste(piso, (x, y))
    for n, x, y, *r in mapa_json["decalques"]:
        i = dec_info[n]
        rg = i["regiao"]
        im = dec_folha.crop((rg[0], rg[1], rg[0] + rg[2], rg[1] + rg[3]))
        if r:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        tela.alpha_composite(im, (int(x - i["centro"][0]), int(y - i["centro"][1]))) if 0 <= x < W and 0 <= y < H else None
    for n, x, y in sorted(mapa_json["objetos"], key=lambda o: o[2]):
        i = obj_info[n]
        rg = i["regiao"]
        im = obj_folha.crop((rg[0], rg[1], rg[0] + rg[2], rg[1] + rg[3]))
        px, py = int(x - i["pe"][0]), int(y - i["pe"][1])
        tela.alpha_composite(im, (max(0, px), max(0, py)), (max(0, -px), max(0, -py))) if px < W and py < H and px + im.width > 0 and py + im.height > 0 else None
    tela = tela.convert("RGB")
    if recorte:
        x, y, w, h = recorte
        tela = tela.crop((x, y, x + w, y + h))
        escala = 2.0
    tela = tela.resize((int(tela.width * escala), int(tela.height * escala)), Image.LANCZOS if escala < 1 else Image.NEAREST)
    tela = ImageEnhance.Brightness(tela).enhance(1.0)
    tela.save(caminho)
    print("prévia ->", caminho)


def main():
    mapa = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else None
    if mapa is None:
        raise SystemExit(__doc__)
    mod = __import__("def_" + mapa)
    saida = PROJ / "assets" / "v2" / "mapas" / mapa
    saida.mkdir(parents=True, exist_ok=True)
    rng = random.Random(mod.SEMENTE)
    print("== %s ==" % mapa)
    obj_info, obj_folha = montar_atlas_objetos(mapa, mod.OBJETOS, saida)
    piso = processar_piso(mapa, saida, getattr(mod, "detalhar_piso", None))
    dec_info, dec_folha = montar_decalques(mod.DECALQUES, saida, random.Random(mod.SEMENTE + 1))
    tam = {n: (i["regiao"][2], i["regiao"][3], i["pe"]) for n, i in obj_info.items()}
    mapa_json = mod.montar(tam, rng)
    mapa_json["mapa"]["pastas"] = {"objetos": "res://assets/v2/mapas/" + mapa, "decalques": "res://assets/v2/mapas/" + mapa,
                                   "piso": "res://assets/v2/mapas/" + mapa}
    mapa_json.setdefault("_ajuda", mod.AJUDA)
    escrever_json(PROJ / "dados" / ("v2_%s.json" % mapa), mapa_json)
    print("objetos", len(mapa_json["objetos"]), "decalques", len(mapa_json["decalques"]), "luzes", len(mapa_json["luzes"]))
    if "--previa" in sys.argv:
        rec = None
        for a in sys.argv:
            if a.startswith("--recorte="):
                rec = [int(v) for v in a.split("=")[1].split(",")]
        previa(mapa_json, obj_info, obj_folha, dec_info, dec_folha, piso, sys.argv[sys.argv.index("--previa") + 1], rec)


if __name__ == "__main__":
    main()
