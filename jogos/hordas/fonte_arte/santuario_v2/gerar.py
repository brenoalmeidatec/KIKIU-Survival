"""Recorta a arte própria do salão usando o pipeline existente de objetos.
Uso: python jogos/hordas/fonte_arte/santuario_v2/gerar.py
Somente Pillow; saída determinística, sem chamadas de rede.
"""
import importlib.util
import json
from pathlib import Path
from PIL import Image

AQUI = Path(__file__).resolve().parent
HORDAS = AQUI.parents[1]
PIPE = HORDAS / 'prototipos/cara_nova/objetos/gerar_objetos.py'
SAIDA = HORDAS / 'projeto/assets/v2/santuario'
spec = importlib.util.spec_from_file_location('objetos', PIPE)
objetos = importlib.util.module_from_spec(spec)
spec.loader.exec_module(objetos)


def folha(nome, ids, tamanho):
    caminho = AQUI / nome
    w, h, data = objetos.carregar(caminho)
    grupos = objetos.agrupar(w, h, data, nome, len(ids), [len(ids)])
    for chave, grupo in zip(ids, grupos):
        img = objetos.recortar(grupo, w, data)
        escala = min((tamanho[0] - 4) / img.width, (tamanho[1] - 4) / img.height)
        eixo = 'L' if (tamanho[0] - 4) / img.width <= (tamanho[1] - 4) / img.height else 'A'
        alvo = tamanho[0] - 4 if eixo == 'L' else tamanho[1] - 4
        img = objetos.binarizar(objetos.escalar(img, eixo, alvo))
        img = objetos.contorno(img)
        img = objetos.quantizar(img, 96)
        tela = Image.new('RGBA', tamanho)
        tela.alpha_composite(img, ((tamanho[0] - img.width) // 2, tamanho[1] - img.height - 2))
        tela.save(SAIDA / (chave + '.png'))
        assert tela.getchannel('A').getbbox() is not None
        print(chave, tela.size)


def main():
    SAIDA.mkdir(parents=True, exist_ok=True)
    fonte = Image.open(AQUI / 'fonte_fundo.png').convert('RGB')
    # Fundo inteiro na proporção do viewport; não se inferem colisões da ilustração.
    fonte.resize((960, 540), Image.Resampling.BOX).save(SAIDA / 'fundo.png')
    folha('fonte_estruturas.png', ['estatuas', 'altar', 'codice'], (112, 112))
    folha('fonte_portais.png', ['portal_floresta', 'portal_laboratorio', 'portal_cidade', 'portal_medio', 'portal_fechado'], (112, 142))
    (SAIDA / 'indice.json').write_text(json.dumps({
        'origem': 'Arte própria Codex/imagegen, 2026-10-14',
        'fonte': 'jogos/hordas/fonte_arte/santuario_v2/',
        'viewport': [960, 540],
        'estrutura': [112, 112], 'portal': [112, 142],
        'nota': 'Geometria de interação em v2/salao_visual.gd; não são máscaras de colisão.'
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
