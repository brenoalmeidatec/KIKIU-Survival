#!/usr/bin/env python3
"""Patches do port no motor godot-vita (7ca87562). Idempotente: pode rodar antes de todo build.
    python3 patches_motor.py ~/godot-vita
1. joypad_vita.cpp: L/R do Vita nos índices 4/5 (JOY_L/JOY_R do Godot), não 6/7 (que o Godot usa para L2/R2).
2. os_vita.cpp: ao encostar o dedo, guarda a posição (o "soltar" saía com a posição do toque anterior).
"""
import sys

raiz = sys.argv[1]


def trocar(rel, velho, novo):
    p = raiz + "/" + rel
    s = open(p, encoding="utf-8").read()
    if novo in s:
        print("ok (já aplicado):", rel)
        return
    if velho not in s:
        sys.exit("trecho não encontrado em " + rel)
    open(p, "w", encoding="utf-8").write(s.replace(velho, novo, 1))
    print("aplicado:", rel)


trocar("platform/vita/joypad_vita.cpp",
       "SCE_CTRL_L2, SCE_CTRL_R2, SCE_CTRL_L1, SCE_CTRL_R1,",
       "SCE_CTRL_L1, SCE_CTRL_R1, SCE_CTRL_L2, SCE_CTRL_R2, // KIKIU: L/R = JOY_L/JOY_R (4/5)")
trocar("platform/vita/os_vita.cpp",
       "\t\t\t\tst->set_index(i);\n\t\t\t\tst->set_position(pos);\n\t\t\t\tst->set_pressed(true);",
       "\t\t\t\tst->set_index(i);\n\t\t\t\tst->set_position(pos);\n\t\t\t\tlast_touch_pos[i] = pos; // KIKIU: o soltar usa esta posição\n\t\t\t\tst->set_pressed(true);")
