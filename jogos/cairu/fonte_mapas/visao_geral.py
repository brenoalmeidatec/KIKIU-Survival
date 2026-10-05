"""Monta uma imagem de cada mapa com móveis e personagens (para conferir e mostrar)."""
from PIL import Image, ImageDraw
import json, os, sys
BASE = os.path.join(os.path.dirname(__file__), '..', 'projeto')
CAP = os.path.join(BASE, 'capitulos')
LINHA = {'baixo': 0, 'esquerda': 1, 'direita': 2, 'cima': 3}


def visao(mapa_id, debug=False):
    m = json.load(open(os.path.join(CAP, 'mapas', mapa_id + '.json')))
    c = json.load(open(os.path.join(CAP, 'cairu.json')))
    bg = Image.open(os.path.join(CAP, 'mapas', m['fundo']['imagem'])).convert('RGBA')
    itens = []
    for o in m.get('objetos', []):
        if 'imagem' in o:
            im = Image.open(os.path.join(CAP, 'mapas', o['imagem']))
            itens.append((o['y'], im, o['x'] - im.width // 2, o['y'] - im.height + o.get('desce', 0)))
    npcs = [n for n in c['npcs'] if n.get('mapa') == mapa_id]
    if c.get('mapa_inicial') == mapa_id:
        npcs.append({'personagem': 'breno', 'x': c['inicio']['x'], 'y': c['inicio']['y'], 'dir': c['inicio'].get('dir', 'baixo')})
    for n in npcs:
        if n.get('comportamento') == 'pc':          # sentado digitando (acoes2, linha 5)
            sh = Image.open(os.path.join(BASE, 'assets', 'personagens', n['personagem'], 'acoes2.png'))
            itens.append((n['y'], sh.crop((0, 5 * 64, 64, 6 * 64)), n['x'] - 32, n['y'] - 61))
            continue
        sh = Image.open(os.path.join(BASE, 'assets', 'personagens', n['personagem'], 'andando.png'))
        r = LINHA[n.get('dir', 'baixo')]
        itens.append((n['y'], sh.crop((0, r * 60, 44, r * 60 + 60)), n['x'] - 22, n['y'] - 58))
    for _, im, x, y in sorted(itens, key=lambda t: t[0]):
        bg.alpha_composite(im, (int(x), int(y)))
    if debug:
        ov = Image.new('RGBA', bg.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
        for o in m.get('objetos', []):
            if 'solido' in o:
                w, h = o['solido']; d.rectangle([o['x'] - w / 2, o['y'] - h, o['x'] + w / 2, o['y']], fill=(255, 0, 0, 90))
        for p in m.get('pontos', []):
            d.rectangle([p['x'], p['y'], p['x'] + p['w'], p['y'] + p['h']], fill=(255, 210, 0, 110))
        for p in m.get('portas', []):
            d.rectangle([p['x'], p['y'], p['x'] + p['w'], p['y'] + p['h']], fill=(0, 140, 255, 140))
        a = m['area_andavel']; d.rectangle([a[0], a[1], a[0] + a[2], a[1] + a[3]], outline=(0, 200, 0, 255))
        bg.alpha_composite(ov)
    return bg


if __name__ == '__main__':
    saida = sys.argv[1]
    for mid in sys.argv[2:]:
        visao(mid, debug='debug' in saida).save(os.path.join(saida, mid + '.png'))
