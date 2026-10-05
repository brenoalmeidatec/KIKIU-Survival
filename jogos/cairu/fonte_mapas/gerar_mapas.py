"""Gera todos os mapas no estilo GBA (paleta única, paleta.py) e os detalhes animados.
    python3 gerar_mapas.py
Cada mapa tem o seu gerador; dá pra rodar um só (ex.: python3 patio_gba.py) e depois
python3 animados_mapas.py.
"""
import animados_mapas
import corredor_gba
import laboratorio_gba
import nucleo_gba
import patio_gba
import presidencia_gba
import recepcao_gba
import sala204_gba

if __name__ == '__main__':
    for g in (recepcao_gba, patio_gba, sala204_gba, corredor_gba, laboratorio_gba, nucleo_gba, presidencia_gba):
        g.main()
    animados_mapas.montar()
