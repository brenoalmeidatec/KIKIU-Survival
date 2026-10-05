import sys, os
from PIL import Image, ImageDraw, ImageFont
BASE = '/mnt/project-files/personagens'
NAMES = ['breno', 'nicao', 'lucas', 'joao', 'matheus', 'beto', 'lukako', 'fabio']
DIRS = ['baixo', 'esquerda', 'direita', 'cima']
BG = (240, 226, 188)
CICLO = [1, 0, 2, 0]

def frames(n):
    sh = Image.open(f'{BASE}/{n}/{n}_sprites_cairu.png').convert('RGBA')
    return {d: [sh.crop((c * 32, r * 32, c * 32 + 32, r * 32 + 32)) for c in range(3)] for r, d in enumerate(DIRS)}

def walk_gif(n, S=8):
    fr = frames(n); out = []
    for d in ['baixo', 'direita', 'cima', 'esquerda']:
        for _ in range(2):
            for c in CICLO:
                bg = Image.new('RGBA', (32, 32), BG + (255,)); bg.alpha_composite(fr[d][c])
                out.append(bg.resize((32 * S, 32 * S), Image.NEAREST).convert('P', palette=Image.ADAPTIVE))
    out[0].save(f'{BASE}/{n}/{n}_andando_cairu.gif', save_all=True, append_images=out[1:], duration=150, loop=0)

def todos_gif():
    S = 4; out = []
    allf = {n: frames(n) for n in NAMES}
    for d in ['baixo', 'direita', 'cima', 'esquerda']:
        for _ in range(2):
            for c in CICLO:
                im = Image.new('RGBA', (4 * 32 * S + 20, 2 * 32 * S + 12), BG + (255,))
                for i, n in enumerate(NAMES):
                    im.alpha_composite(allf[n][d][c].resize((32 * S, 32 * S), Image.NEAREST), ((i % 4) * 32 * S + 10, (i // 4) * 32 * S + 6))
                out.append(im.convert('P', palette=Image.ADAPTIVE))
    os.makedirs(f'{BASE}/_todos', exist_ok=True)
    out[0].save(f'{BASE}/_todos/todos_andando.gif', save_all=True, append_images=out[1:], duration=150, loop=0)

if __name__ == '__main__':
    for n in NAMES: walk_gif(n)
    todos_gif()
    print('ok')
