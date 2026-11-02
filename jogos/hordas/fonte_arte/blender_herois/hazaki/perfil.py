"""Perfil do BRENDAN (pasta hazaki) no PADRÃO NOVO DO ELENCO (issue #586): o piloto do padrão.

O gerar.py desta pasta carrega este arquivo sozinho quando roda sem --perfil (blender -b -t 4 -P gerar.py). Os outros heróis copiam o bloco
"padrão do elenco" abaixo para o perfil.py deles e trocam só as cores e a direção da arma (ver ../LEIA-ME.md, seção "Padrão do elenco").

Cor-assinatura: VERMELHO SAMURAI saturado (casaco, mangas, lenço) com detalhe PRETO (calça, cabelo, couro, braçadeiras laqueadas) e dourado.
Arma: katana 1,5x maior e mais clara, de pé ao lado do corpo (lâmina para cima) no parado, andar e dano; no golpe, defesa, rolamento e morte
fica como foi modelada (lâmina na linha do antebraço), porque as poses do combo foram calculadas para ela (ik_katana.py).
"""
NOME = "hazaki"

PALETA = {
    "Tecido vermelho queimado": "#c0202c",   # casaco: vermelho samurai saturado (era vinho #7a2a32)
    "Vermelho iluminado": "#e03a36",         # manga da katana, gola e lenço
    "Dobras do tecido": "#7c1020",           # costura e dobras
    "Calça azul carvão": "#1f1c26",          # hakama preta (detalhe preto)
    "Cabelo quase preto": "#282c3e",          # preto-azulado: as faixas de luz ainda mostram as mechas (preto puro virava um capacete)
    "Couro castanho": "#2c2228",             # couro preto (antebraços e botas)
    "Pele": "#a87862", "Rosto iluminado": "#cc9a7c",
    "Aço azulado": "#3a3640",                # braçadeiras e faixas da bota laqueadas de preto
    "Fio polido": "#e4ecf4",                 # lâmina
    "Latão antigo": "#d0a040",               # guarda, trança do cabo, fivela: dourado
    "Olho": "#0a0c14",
}
BRILHANTES = {"Reflexo frio": "#a8d8ff"}

# ---------------------------------------------------------------- padrão do elenco (#586); todos opcionais, ver gerar.py
CABECA = 1.42                 # cabeça (era 1,22): massa da cabeça 14 -> 16 px, ~40% da altura (o gerar imprime MEDIDA)
ARMA_ESCALA = 1.5             # katana 1,5x mais comprida
ARMA_ESPESSURA = 1.15         # e só 15% mais grossa (1,5x de largura virava um remo)
ARMA_CLAREAR = 0.30           # e mais clara (cópia dos materiais da arma, 30% mais perto do branco)
_EM_PE = (0.14, -0.15, 1.0)   # lâmina para cima, um fio para fora (+x) e para a frente (-y): ao lado da cabeça e visível de perfil e de costas
ARMA_DIRECAO = {"parado": _EM_PE, "andar": _EM_PE, "dano": _EM_PE}
ARMA_ESCALA_ANIM = {"rolamento": 0.7, "morte": 0.8}   # no rolamento e na morte a lâmina de 1,5x saía do quadro: lá ela fica ~1,05x e 1,2x
ESTILO_2D = True              # contorno escuro de 1 px + rim light (ESTILO_ELENCO do gerar.py)
RETRATO = {"pasta": "hazaki"}  # assets/personagens/hazaki/retrato.png (os outros parâmetros do retrato ficam no padrão: mesma câmera para todos)


def fonte(src, trocar):
    """Mechas um fio mais baixas: a cabeça cresce (CABECA) e o topo do cabelo fica na linha 2 do quadro de 44 px no parado e no andar."""
    return trocar(src, "3.23+random.uniform(-.05,.12)", "3.19+random.uniform(-.05,.15)")
