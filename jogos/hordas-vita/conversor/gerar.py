#!/usr/bin/env python3
"""Gera o projeto Godot 3.5 (Vita) a partir do projeto Godot 4 do jogo.

    python gerar.py <projeto_godot4> <saida>

- copia assets/ e dados/ (sem os .import/.uid do Godot 4, que o 3 não entende; o editor 3 reimporta);
- converte main.tscn para o formato 2;
- escreve project.godot no formato do 3.x (GLES2 + fallback, 480x272, autoload G4 antes dos do jogo);
- roda conversor.py nos scripts.
"""
import json
import os
import re
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))


def copiar_arvore(orig, dest):
    for raiz, pastas, arqs in os.walk(orig):
        pastas[:] = [p for p in pastas if p != ".godot"]
        for a in arqs:
            if a.endswith((".import", ".uid")):
                continue
            o = os.path.join(raiz, a)
            d = os.path.join(dest, os.path.relpath(o, orig))
            os.makedirs(os.path.dirname(d), exist_ok=True)
            if not os.path.exists(d) or os.path.getmtime(d) < os.path.getmtime(o):
                shutil.copy2(o, d)


def converter_tscn(texto):
    ids = {}
    saida = []
    for linha in texto.replace("\r\n", "\n").split("\n"):
        m = re.match(r'^\[gd_scene load_steps=(\d+) format=3.*\]$', linha)
        if m:
            saida.append("[gd_scene load_steps=%s format=2]" % m.group(1))
            continue
        m = re.match(r'^\[ext_resource type="(\w+)"(?: uid="[^"]*")? path="([^"]+)" id="([^"]+)"\]$', linha)
        if m:
            n = len(ids) + 1
            ids[m.group(3)] = n
            saida.append('[ext_resource path="%s" type="%s" id=%d]' % (m.group(2), m.group(1), n))
            continue
        linha = re.sub(r'ExtResource\("([^"]+)"\)', lambda mm: "ExtResource( %d )" % ids.get(mm.group(1), 1), linha)
        saida.append(linha)
    return "\n".join(saida)


def autoloads(proj4):
    r = []
    em = False
    for linha in open(proj4, encoding="utf-8").read().split("\n"):
        if linha.startswith("["):
            em = linha.strip() == "[autoload]"
            continue
        if em and "=" in linha:
            r.append(linha.strip())
    return r


def main():
    orig, dest = sys.argv[1], sys.argv[2]
    os.makedirs(dest, exist_ok=True)
    for pasta in ("assets", "dados"):
        copiar_arvore(os.path.join(orig, pasta), os.path.join(dest, pasta))

    # ajustes de dados só do Vita (conversor/dados_vita.json), mesclados por cima dos JSON copiados
    def mesclar(a, b):
        for k, v in b.items():
            if isinstance(v, dict) and isinstance(a.get(k), dict):
                mesclar(a[k], v)
            else:
                a[k] = v
    ajustes = json.load(open(os.path.join(AQUI, "dados_vita.json"), encoding="utf-8"))
    for arq, aj in ajustes.items():
        if arq.startswith("_"):
            continue
        base = json.load(open(os.path.join(orig, "dados", arq), encoding="utf-8"))
        mesclar(base, aj)
        open(os.path.join(dest, "dados", arq), "w", encoding="utf-8", newline="\n").write(
            json.dumps(base, ensure_ascii=False, indent=1))
    open(os.path.join(dest, "main.tscn"), "w", encoding="utf-8", newline="\n").write(
        converter_tscn(open(os.path.join(orig, "main.tscn"), encoding="utf-8").read()))
    # cenas de teste (testes/*.tscn): os scripts delas são convertidos pelo conversor.py
    if os.path.isdir(os.path.join(orig, "testes")):
        os.makedirs(os.path.join(dest, "testes"), exist_ok=True)
        for a in os.listdir(os.path.join(orig, "testes")):
            if a.endswith(".tscn"):
                open(os.path.join(dest, "testes", a), "w", encoding="utf-8", newline="\n").write(
                    converter_tscn(open(os.path.join(orig, "testes", a), encoding="utf-8").read()))
    open(os.path.join(dest, "g4_fonte.tres"), "w", encoding="utf-8", newline="\n").write(
        '[gd_resource type="DynamicFont" load_steps=2 format=2]\n\n'
        '[ext_resource path="res://assets/fonte/PressStart2P.ttf" type="DynamicFontData" id=1]\n\n'
        '[resource]\nsize = 8\nfont_data = ExtResource( 1 )\n')
    al = "\n".join(['G4="*res://g4.gd"'] + autoloads(os.path.join(orig, "project.godot")))
    open(os.path.join(dest, "project.godot"), "w", encoding="utf-8", newline="\n").write(f"""; Gerado por jogos/hordas-vita/conversor/gerar.py a partir do projeto Godot 4. Não editar à mão.

config_version=4

[application]

config/name="KIKIU Vita"
run/main_scene="res://main.tscn"

[autoload]

{al}

[display]

window/size/width=640
window/size/height=360
window/size/test_width=960
window/size/test_height=544
window/vsync/use_vsync=true
window/stretch/mode="viewport"
window/stretch/aspect="keep"

[gui]

theme/custom_font="res://g4_fonte.tres"

[importer_defaults]

texture={{
"compress/mode": 0,
"flags/filter": false,
"flags/mipmaps": false,
"flags/repeat": 0,
"process/fix_alpha_border": true
}}

[rendering]

quality/driver/driver_name="GLES2"
quality/driver/fallback_to_gles2=true
2d/snapping/use_gpu_pixel_snap=true
environment/default_clear_color=Color( 0.1, 0.09, 0.12, 1 )
batching/options/use_batching=true
vram_compression/import_etc=true
vram_compression/import_etc2=true
""")
    # exportação: preset do Vita + LiveArea (as imagens do piloto); o --export também força a importação completa
    vita = os.path.join(dest, "vita")
    os.makedirs(vita, exist_ok=True)
    open(os.path.join(vita, ".gdignore"), "w").close()
    for n in ("icon0.png", "pic0.png", "bg.png", "startup.png"):
        shutil.copy(os.path.join(AQUI, "..", "piloto", "vita", n), os.path.join(vita, n))
    open(os.path.join(dest, "export_presets.cfg"), "w", encoding="utf-8", newline="\n").write(
        '[preset.0]\n\nname="PlayStation Vita"\nplatform="PlayStation Vita"\nrunnable=true\ncustom_features=""\n'
        'export_filter="all_resources"\ninclude_filter="*.json"\nexclude_filter=""\n'
        'export_path="../build/kikiu_vita.vpk"\nscript_export_mode=1\nscript_encryption_key=""\n\n[preset.0.options]\n\n'
        'param_sfo/title="KIKIU Vita"\nparam_sfo/title_id="KIKU00004"\nparam_sfo/parental_level=1\nparam_sfo/version="01.00"\n'
        'assets/bubble_icon_128x128="vita/icon0.png"\nassets/app_splash_960x544="vita/pic0.png"\n'
        'assets/livearea_bg_840x500="vita/bg.png"\nassets/livearea_startup_button_280x158="vita/startup.png"\n')
    shutil.copy(os.path.join(AQUI, "verificar_cena.gd"), os.path.join(dest, "_verificar.gd"))
    open(os.path.join(dest, "_verificar.tscn"), "w", encoding="utf-8", newline="\n").write(
        '[gd_scene load_steps=2 format=2]\n\n[ext_resource path="res://_verificar.gd" type="Script" id=1]\n\n'
        '[node name="Verificar" type="Node"]\nscript = ExtResource( 1 )\n')
    subprocess.check_call([sys.executable, os.path.join(AQUI, "conversor.py"), orig, dest])


if __name__ == "__main__":
    main()
