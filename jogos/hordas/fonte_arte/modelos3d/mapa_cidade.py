"""Vila Amaldiçoada da v2 (id interno "cidade"): junta os objetos e o piso (veja mapas_v2.py, que lê OBJETOS e PISO daqui).

    blender -b -t 6 -P modelos3d/mapas_v2.py -- cidade                     # tudo (o piso leva alguns minutos)
    blender -b -t 6 -P modelos3d/mapas_v2.py -- cidade carro_a poste_rua   # só os citados ("piso" é o chão)

Objetos de rua, carroças, barricadas, muros, barracas, poço, celeiros: vila_pecas.py. Casas: vila_casas.py. Piso: vila_piso.py. O tamanho da tela de cada
objeto (e a pegada que o jogo usa na colisão) está em mapas_v2/medidas_cidade.py, em Python puro, para o def_cidade.py ler também. Os nomes dos objetos são os
de antes da #429 (o "predio_loja" é uma casa de comércio, o "carro_a" uma carroça, a "lixeira_azul" o poço...): a planta, a colisão e as passagens não mudam.
"""
import math
import os
import sys

sys.path.append(os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mapas_v2")))
import medidas_cidade as med  # noqa: E402
import vila_casas as D  # noqa: E402
import vila_pecas as P  # noqa: E402
import vila_piso  # noqa: E402

FUNCOES = {
    # casas
    "predio_loja": D.predio_loja, "predio_bar": D.predio_bar, "predio_apto_a": D.predio_apto_a, "predio_apto_b": D.predio_apto_b,
    "predio_torre": D.predio_torre, "predio_ruina": D.predio_ruina,
    # ruas
    "poste_rua": P.poste_rua, "poste_rua_e": P.poste_rua_e, "poste_quebrado": P.poste_quebrado, "semaforo": P.semaforo,
    "semaforo_torto": P.semaforo_torto, "placa_pare": P.placa_pare, "placa_rua": P.placa_rua, "placa_neon": P.placa_neon,
    "lapide": P.lapide, "cruz_tumulo": P.cruz_tumulo, "hidrante": P.hidrante, "cone": P.cone_transito, "cone_tombado": P.cone_tombado, "barril_fogo": P.barril_fogo,
    "lixeira_metal": P.lixeira_metal, "lixeira_rodas": P.lixeira_rodas, "lixeira_azul": P.lixeira_azul, "banco": P.banco,
    "ponto_onibus": P.ponto_onibus,
    # carroças (os "_v" ao longo de Y)
    "carro_a": P.carro_a, "carro_b": P.carro_b, "carro_c": P.carro_c, "carro_queimado": P.carro_queimado,
    "carro_a_v": P.vira(P.carro_a, -math.pi / 2), "carro_b_v": P.vira(P.carro_b, math.pi / 2), "carro_c_v": P.vira(P.carro_c, -math.pi / 2),
    # barricadas, entulho, muros
    "sacos_areia": P.sacos_areia, "barricada_concreto": P.barricada_concreto, "barricada_madeira": P.barricada_madeira, "pneus": P.pneus,
    "cacamba": P.cacamba, "container_a": P.container_a, "container_b": P.container_b, "entulho_a": P.entulho_a, "entulho_b": P.entulho_b,
    "muro_tijolo": P.muro_tijolo, "muro_quebrado": P.muro_quebrado,
}

OBJETOS = {n: med.tela(n) + (FUNCOES[n],) for n in med.MEDIDAS}
PISO = (vila_piso.LADO, vila_piso.piso_vila)
