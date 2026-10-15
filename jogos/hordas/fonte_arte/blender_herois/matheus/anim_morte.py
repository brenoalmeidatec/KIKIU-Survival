"""MORTE do Matheus: a do Hazaki (../hazaki/anim_morte.py) com a pose final PADRONIZADA entre as 8 direções.

Na do Hazaki o herói gira em pé o menor ângulo que o deixa de frente ou de costas e cai para o lado contrário do olhar: cada direção termina de um
jeito (de bruços, de costas, cabeça para a esquerda ou a direita) e algumas passam dos 32 px e cortam (cima_dir). Aqui, durante a queda, o corpo
gira até a MESMA orientação final em todas as direções (de barriga para cima, cabeça para a direita da tela) e os quadros do chão (q3 a q7)
saem idênticos nas 8 linhas. Só o começo (q0 e q1, ainda de pé) depende da direção do golpe.
"""
import importlib.util
import math
from pathlib import Path

_spec = importlib.util.spec_from_file_location("anim_morte_hazaki", Path(__file__).resolve().parent.parent / "hazaki" / "anim_morte.py")
_base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_base)

N_QUADROS = _base.N_QUADROS
S_POR_QUADRO = _base.S_POR_QUADRO
QUADROS = _base.QUADROS


def _escolher(ang):
    """Giro (rad) que leva o herói da direção `ang` (graus) ao yaw 180 (de costas para a câmera) pelo caminho mais curto e rolamento
    para a direita da tela: ele termina deitado de barriga para cima, com o colete azul à mostra e a cabeça para a direita."""
    return math.radians(((180.0 - ang + 180.0) % 360.0) - 180.0), 1.0


_base.escolher = _escolher
_base.DOBRA_PERNA = 1.9      # coxas mais encolhidas: deitado, o corpo cabe nos 32 px da célula


def posar(arm, quadro, n_quadros, ang=0.0):
    _base.posar(arm, quadro, n_quadros, ang)
