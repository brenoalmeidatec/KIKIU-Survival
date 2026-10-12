"""Cidade da v2: junta os objetos e o piso (veja mapas_v2.py, que lê OBJETOS e PISO daqui).

    blender -b -t 6 -P modelos3d/mapas_v2.py -- cidade                     # tudo (o piso leva alguns minutos)
    blender -b -t 6 -P modelos3d/mapas_v2.py -- cidade carro_a poste_rua   # só os citados ("piso" é o chão)

Objetos de rua, carros: cidade_pecas.py. Prédios: cidade_predios.py. Caçamba, contêiner, barricadas, entulho, muros e o ponto de ônibus:
cidade_adereco.py. Piso: cidade_piso.py. O tamanho da tela de cada objeto (e a pegada que o jogo usa na colisão) está em
mapas_v2/medidas_cidade.py, em Python puro, para o def_cidade.py ler também.
"""
import math
import os
import sys

sys.path.append(os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mapas_v2")))
import cidade_adereco as A  # noqa: E402
import cidade_pecas as P  # noqa: E402
import cidade_piso  # noqa: E402
import cidade_predios as D  # noqa: E402
import medidas_cidade as med  # noqa: E402

FUNCOES = {
    # prédios
    "predio_loja": D.predio_loja, "predio_bar": D.predio_bar, "predio_apto_a": D.predio_apto_a, "predio_apto_b": D.predio_apto_b,
    "predio_torre": D.predio_torre, "predio_ruina": D.predio_ruina,
    # ruas
    "poste_rua": P.poste_rua, "poste_rua_e": P.poste_rua_e, "poste_quebrado": P.poste_quebrado, "semaforo": P.semaforo,
    "semaforo_torto": P.semaforo_torto, "placa_pare": P.placa_pare, "placa_rua": P.placa_rua, "placa_neon": P.placa_neon,
    "hidrante": P.hidrante, "cone": P.cone_transito, "cone_tombado": P.cone_tombado, "barril_fogo": P.barril_fogo,
    "lixeira_metal": P.lixeira_metal, "lixeira_rodas": P.lixeira_rodas, "lixeira_azul": P.lixeira_azul, "banco": P.banco,
    "ponto_onibus": A.ponto_onibus,
    # carros (os "_v" ao longo de Y)
    "carro_a": P.carro_a, "carro_b": P.carro_b, "carro_c": P.carro_c, "carro_queimado": P.carro_queimado,
    "carro_a_v": P.vira(P.carro_a, -math.pi / 2), "carro_b_v": P.vira(P.carro_b, math.pi / 2), "carro_c_v": P.vira(P.carro_c, -math.pi / 2),
    # barricadas, entulho, muros
    "sacos_areia": A.sacos_areia, "barricada_concreto": A.barricada_concreto, "barricada_madeira": A.barricada_madeira, "pneus": A.pneus,
    "cacamba": A.cacamba, "container_a": A.container_a, "container_b": A.container_b, "entulho_a": A.entulho_a, "entulho_b": A.entulho_b,
    "muro_tijolo": A.muro_tijolo, "muro_quebrado": A.muro_quebrado,
}

OBJETOS = {n: med.tela(n) + (FUNCOES[n],) for n in med.MEDIDAS}
PISO = (cidade_piso.LADO, cidade_piso.piso_cidade)
