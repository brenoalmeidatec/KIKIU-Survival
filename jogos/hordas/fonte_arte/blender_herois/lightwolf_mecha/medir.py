"""Mede os quatro lados de cada quadro, incluindo o contorno externo de um pixel.

    python medir.py rolamento
    python medir.py --todos

Saída diferente de zero se algum quadro estiver vazio, ausente ou encostar na borda.
"""
import argparse
import os

from PIL import Image, ImageChops

from montar_folha import AQUI, ANIMACOES, DIRECOES, H, W, mascara_contorno


def medir_animacao(anim, n):
    pasta = os.path.join(AQUI, "quadros", anim)
    erros = []
    for direcao in DIRECOES:
        larguras, alturas, margens = [], [], []
        contatos = []
        for quadro in range(n):
            caminho = os.path.join(pasta, "%s_%d_cor.png" % (direcao, quadro))
            if not os.path.isfile(caminho):
                erros.append("%s/%s_%d: arquivo ausente" % (anim, direcao, quadro))
                continue
            with Image.open(caminho) as imagem:
                if imagem.size != (W, H):
                    erros.append("%s/%s_%d: tamanho %s, esperado %s" % (anim, direcao, quadro, imagem.size, (W, H)))
                    continue
                alfa = imagem.convert("RGBA").getchannel("A")
            opaco = alfa.point(lambda a: 255 if a else 0)
            cobertura = ImageChops.lighter(opaco, mascara_contorno(alfa))
            caixa = cobertura.getbbox()
            if caixa is None:
                erros.append("%s/%s_%d: quadro vazio" % (anim, direcao, quadro))
                continue
            x0, y0, x1, y1 = caixa
            # bbox é exclusivo em x1/y1; as quatro margens incluem o contorno.
            lados = {"esquerda": x0, "direita": W - x1, "cima": y0, "baixo": H - y1}
            larguras.append(x1 - x0)
            alturas.append(y1 - y0)
            margens.append(lados)
            tocados = [lado for lado, margem in lados.items() if margem == 0]
            if tocados:
                contatos.append("%d:%s" % (quadro, ",".join(tocados)))
        if larguras:
            minimo = {lado: min(m[lado] for m in margens) for lado in ("esquerda", "direita", "cima", "baixo")}
            print("%-10s %-10s largura %2d..%2d altura %2d..%2d margens E/D/C/B %d/%d/%d/%d borda: %s" % (
                anim, direcao, min(larguras), max(larguras), min(alturas), max(alturas),
                minimo["esquerda"], minimo["direita"], minimo["cima"], minimo["baixo"],
                "; ".join(contatos) if contatos else "ok"))
        if contatos:
            erros.append("%s/%s toca borda: %s" % (anim, direcao, "; ".join(contatos)))
    return erros


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("anim", nargs="?", help="uma animação; omita ou use --todos para medir todas")
    parser.add_argument("--todos", action="store_true", help="mede todas as animações")
    args = parser.parse_args()
    animacoes = {nome: n for nome, n, _ in ANIMACOES}
    if args.anim and args.todos:
        parser.error("escolha uma animação ou --todos")
    if args.anim and args.anim not in animacoes:
        parser.error("animação desconhecida: %s" % args.anim)
    escolhidas = [args.anim] if args.anim else list(animacoes)
    erros = []
    for nome in escolhidas:
        erros.extend(medir_animacao(nome, animacoes[nome]))
    for erro in erros:
        print("ERRO:", erro)
    return 1 if erros else 0


if __name__ == "__main__":
    raise SystemExit(main())
