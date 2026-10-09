#!/usr/bin/env python3
"""Conversor GDScript 4 (Godot 4.4) -> GDScript 1 (Godot 3.5) para o port PS Vita do KIKIU Survival.

A main muda todo dia; por isso o port é GERADO: rode de novo a cada atualização.
    python conversor.py <projeto_godot4> <saida_godot3>
O que não tem tradução direta vira chamada ao autoload G4 (g4.gd, copiado para a saída). Arquivos em
`../jogo_vita_manual/` (mesmo caminho relativo) substituem o gerado. Cada troca duvidosa deixa um comentário
"# G4?" na linha, e o relatório (conversao.json) lista o que ficou para revisar.
"""
import json
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lambdas  # noqa: E402
import ajustes_vita  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- lexer por linha (código / string / comentário)
# Divide uma linha em segmentos ("c", texto) para código, ("s", texto) para strings (com aspas) e ("#", texto).
# Strings de três aspas que atravessam linhas: estado `em_tripla` passa de uma linha para a outra.


def segmentar(linha, em_tripla):
    segs = []
    i = 0
    n = len(linha)
    atual = ""
    if em_tripla:
        fim = linha.find('"""')
        if fim < 0:
            return [("s", linha)], True
        segs.append(("s", linha[:fim + 3]))
        i = fim + 3
    while i < n:
        ch = linha[i]
        if ch == "#":
            if atual:
                segs.append(("c", atual))
                atual = ""
            segs.append(("#", linha[i:]))
            return segs, False
        if linha.startswith('"""', i):
            if atual:
                segs.append(("c", atual))
                atual = ""
            fim = linha.find('"""', i + 3)
            if fim < 0:
                segs.append(("s", linha[i:]))
                return segs, True
            segs.append(("s", linha[i:fim + 3]))
            i = fim + 3
            continue
        if ch in "\"'":
            # prefixos de StringName (&"x") e NodePath (^"x") do Godot 4 caem fora: viram string comum
            if atual.endswith("&") or atual.endswith("^"):
                atual = atual[:-1]
            if atual:
                segs.append(("c", atual))
                atual = ""
            j = i + 1
            while j < n:
                if linha[j] == "\\":
                    j += 2
                    continue
                if linha[j] == ch:
                    break
                j += 1
            segs.append(("s", linha[i:j + 1]))
            i = j + 1
            continue
        atual += ch
        i += 1
    if atual:
        segs.append(("c", atual))
    return segs, False


def juntar(segs):
    return "".join(t for _, t in segs)


# ---------------------------------------------------------------- tabelas de renomeação (só em código)

TIPOS = {
    "RefCounted": "Reference", "Sprite2D": "Sprite", "AnimatedSprite2D": "AnimatedSprite",
    "CharacterBody2D": "KinematicBody2D", "RenderingServer": "VisualServer", "PhysicsServer2D": "Physics2DServer",
    "PackedStringArray": "PoolStringArray", "PackedVector2Array": "PoolVector2Array",
    "PackedVector3Array": "PoolVector3Array", "PackedColorArray": "PoolColorArray",
    "PackedInt32Array": "PoolIntArray", "PackedFloat32Array": "PoolRealArray",
    # 64 bits: os Pool*Array do Godot 3 são de 32 bits (chaves empacotadas perdiam o índice); Array guarda 64 bits
    "PackedInt64Array": "Array", "PackedFloat64Array": "Array", "PackedByteArray": "PoolByteArray",
    "Vector2i": "Vector2", "Rect2i": "Rect2", "Vector3i": "Vector3", "StringName": "String",
    "TileMapLayer": "TileMap", "GPUParticles2D": "Particles2D", "Node3D": "Spatial", "Texture2D": "Texture",
    "CompressedTexture2D": "StreamTexture", "AudioStreamWAV": "AudioStreamSample",
    "AudioStreamOggVorbis": "AudioStreamOGGVorbis", "SubViewport": "Viewport",
    "SubViewportContainer": "ViewportContainer", "FontFile": "DynamicFont", "SystemFont": "DynamicFont",
    "TYPE_PACKED_STRING_ARRAY": "TYPE_STRING_ARRAY", "TYPE_PACKED_VECTOR2_ARRAY": "TYPE_VECTOR2_ARRAY",
    "TYPE_PACKED_INT32_ARRAY": "TYPE_INT_ARRAY", "TYPE_PACKED_FLOAT32_ARRAY": "TYPE_REAL_ARRAY",
    "TYPE_PACKED_COLOR_ARRAY": "TYPE_COLOR_ARRAY", "TYPE_PACKED_BYTE_ARRAY": "TYPE_RAW_ARRAY",
    "TYPE_VECTOR2I": "TYPE_VECTOR2", "TYPE_RECT2I": "TYPE_RECT2", "TYPE_STRING_NAME": "TYPE_STRING",
    "TYPE_CALLABLE": "TYPE_OBJECT", "TYPE_FLOAT": "TYPE_REAL",
    "MOUSE_BUTTON_LEFT": "BUTTON_LEFT", "MOUSE_BUTTON_RIGHT": "BUTTON_RIGHT", "MOUSE_BUTTON_MIDDLE": "BUTTON_MIDDLE",
    "MOUSE_BUTTON_WHEEL_UP": "BUTTON_WHEEL_UP", "MOUSE_BUTTON_WHEEL_DOWN": "BUTTON_WHEEL_DOWN",
    "JOY_BUTTON_A": "JOY_XBOX_A", "JOY_BUTTON_B": "JOY_XBOX_B", "JOY_BUTTON_X": "JOY_XBOX_X",
    "JOY_BUTTON_Y": "JOY_XBOX_Y", "JOY_BUTTON_START": "JOY_START", "JOY_BUTTON_BACK": "JOY_SELECT",
    "JOY_BUTTON_LEFT_SHOULDER": "JOY_L", "JOY_BUTTON_RIGHT_SHOULDER": "JOY_R",
    "JOY_BUTTON_LEFT_STICK": "JOY_L3", "JOY_BUTTON_RIGHT_STICK": "JOY_R3",
    "JOY_BUTTON_DPAD_UP": "JOY_DPAD_UP", "JOY_BUTTON_DPAD_DOWN": "JOY_DPAD_DOWN",
    "JOY_BUTTON_DPAD_LEFT": "JOY_DPAD_LEFT", "JOY_BUTTON_DPAD_RIGHT": "JOY_DPAD_RIGHT",
    "JOY_AXIS_LEFT_X": "JOY_AXIS_0", "JOY_AXIS_LEFT_Y": "JOY_AXIS_1", "JOY_AXIS_RIGHT_X": "JOY_AXIS_2",
    "JOY_AXIS_RIGHT_Y": "JOY_AXIS_3", "JOY_AXIS_TRIGGER_LEFT": "JOY_AXIS_6", "JOY_AXIS_TRIGGER_RIGHT": "JOY_AXIS_7",
    "PROCESS_MODE_ALWAYS": "PAUSE_MODE_PROCESS", "PROCESS_MODE_PAUSABLE": "PAUSE_MODE_STOP",
    "PROCESS_MODE_INHERIT": "PAUSE_MODE_INHERIT", "PROCESS_MODE_WHEN_PAUSED": "PAUSE_MODE_PROCESS",
    "CONNECT_ONE_SHOT": "CONNECT_ONESHOT", "PackedVector4Array": "Array", "Vector4": "Color",
    "TYPE_VECTOR4": "TYPE_COLOR",
    "HORIZONTAL_ALIGNMENT_LEFT": "0", "HORIZONTAL_ALIGNMENT_CENTER": "1", "HORIZONTAL_ALIGNMENT_RIGHT": "2",
    "HORIZONTAL_ALIGNMENT_FILL": "3", "VERTICAL_ALIGNMENT_TOP": "0", "VERTICAL_ALIGNMENT_CENTER": "1",
    "VERTICAL_ALIGNMENT_BOTTOM": "2", "VERTICAL_ALIGNMENT_FILL": "3", "Geometry2D": "Geometry",
    "NOTIFICATION_APPLICATION_FOCUS_OUT": "NOTIFICATION_WM_FOCUS_OUT",
    "NOTIFICATION_APPLICATION_FOCUS_IN": "NOTIFICATION_WM_FOCUS_IN",
    "NOTIFICATION_WM_CLOSE_REQUEST": "NOTIFICATION_WM_QUIT_REQUEST",
    "NOTIFICATION_APPLICATION_PAUSED": "NOTIFICATION_APP_PAUSED",
    "NOTIFICATION_APPLICATION_RESUMED": "NOTIFICATION_APP_RESUMED",
    "PRESET_FULL_RECT": "PRESET_WIDE", "RENDER_TOTAL_DRAW_CALLS_IN_FRAME": "RENDER_2D_DRAW_CALLS_IN_FRAME",
    "RENDER_TOTAL_OBJECTS_IN_FRAME": "RENDER_2D_ITEMS_IN_FRAME", "RENDER_TOTAL_PRIMITIVES_IN_FRAME": "RENDER_2D_ITEMS_IN_FRAME", "NavigationRegion2D": "NavigationPolygonInstance", "ENetMultiplayerPeer": "NetworkedMultiplayerENet", "OfflineMultiplayerPeer": "Reference",
}

FUNCOES = {  # nome( -> nome(
    "queue_redraw": "update", "is_empty": "empty", "clampi": "clamp", "clampf": "clamp", "maxi": "max",
    "maxf": "max", "mini": "min", "minf": "min", "absi": "abs", "absf": "abs", "signi": "sign", "signf": "sign",
    "deg_to_rad": "deg2rad", "rad_to_deg": "rad2deg", "randf_range": "rand_range", "snapped": "stepify",
    "snappedf": "stepify", "lerpf": "lerp", "remap": "range_lerp", "set_shader_parameter": "set_shader_param",
    "get_shader_parameter": "get_shader_param", "add_theme_color_override": "add_color_override",
    "add_theme_constant_override": "add_constant_override", "add_theme_font_override": "add_font_override",
    "add_theme_stylebox_override": "add_stylebox_override", "instantiate": "instance", "print_rich": "print",
    "get_process_frames": "get_idle_frames", "is_zero_approx": "is_zero_approx",
    "roundf": "round", "floorf": "floor", "ceilf": "ceil", "sqrtf": "sqrt", "fmodf": "fmod",
    "linear_to_db": "linear2db", "db_to_linear": "db2linear", "horizontal_alignment": "align",
    "var_to_bytes": "var2bytes", "bytes_to_var": "bytes2var", "var_to_str": "var2str", "str_to_var": "str2var",
    "get_closest_point_to_segment": "get_closest_point_to_segment_2d",
    "segment_intersects_segment": "segment_intersects_segment_2d", "line_intersects_line": "line_intersects_line_2d",
    "offset_polygon": "offset_polygon_2d", "clip_polygons": "clip_polygons_2d", "merge_polygons": "merge_polygons_2d",
    "intersect_polygons": "intersect_polygons_2d", "convex_hull": "convex_hull_2d",
}

SO_GLOBAIS = {"var_to_bytes", "bytes_to_var", "var_to_str", "str_to_var", "randf_range", "deg_to_rad", "rad_to_deg", "snapped", "snappedf", "lerpf", "remap", "clampi", "clampf",
              "maxi", "maxf", "mini", "minf", "absi", "absf", "signi", "signf", "roundf", "floorf", "ceilf", "sqrtf",
              "fmodf", "linear_to_db", "db_to_linear"}

G4_FUNCOES = ["randi_range", "pingpong", "posmod_g4", "angle_difference", "is_same",
              "is_finite", "is_inf_g4"]   # f(x) -> G4.f(x)

# Funções embutidas do GDScript 1: no Godot 3 são palavras reservadas e não podem ser nome de variável.
BUILTINS_GD3 = set("""sin cos tan sinh cosh tanh asin acos atan atan2 sqrt fmod fposmod posmod floor ceil round abs sign
pow log exp is_nan is_inf is_equal_approx is_zero_approx ease decimals step_decimals stepify lerp lerp_angle inverse_lerp
range_lerp smoothstep move_toward dectime randomize randi randf rand_range seed rand_seed deg2rad rad2deg linear2db
db2linear polar2cartesian cartesian2polar wrapi wrapf max min clamp nearest_po2 weakref funcref convert typeof
type_exists char ord str print printt prints printerr printraw print_debug push_error push_warning var2str str2var
var2bytes bytes2var range load inst2dict dict2inst validate_json parse_json to_json hash Color8 ColorN print_stack
get_stack instance_from_id len""".split())


def renomear_reservados(texto):
    """Variáveis/parâmetros/laços com nome de função embutida do GDScript 1 ganham "_" (ord -> ord_)."""
    nomes = set(re.findall(r"\bvar\s+(\w+)", texto)) | set(re.findall(r"\bfor\s+(\w+)\s+in\b", texto))
    for sig in re.findall(r"\bfunc\s*\w*\s*\(([^)]*)\)", texto):
        for prm in sig.split(","):
            mp = re.match(r"\s*(\w+)", prm)
            if mp:
                nomes.add(mp.group(1))
    alvo = sorted(nomes & BUILTINS_GD3)
    if not alvo:
        return texto
    linhas = []
    em_tripla = False
    for linha in texto.split("\n"):
        segs, prox = segmentar(linha, em_tripla)
        novos = []
        for tp, tx in segs:
            if tp == "c":
                tx = re.sub(r"(?<![\.\w])(%s)\b(?!\s*\()" % "|".join(alvo), r"\1_", tx)
            novos.append((tp, tx))
        linhas.append(juntar(novos))
        em_tripla = prox
    return "\n".join(linhas)


AUTOLOADS = []        # preenchido pelo main() com os autoloads do project.godot do Godot 4

COR_CONST = re.compile(r"\bColor\.([A-Z][A-Z_]+)\b")

# Classes Control: no Godot 3 o tamanho/posição delas é rect_size/rect_position/... (Node2D continua position/scale).
CONTROLES = set("""Control Label Button TextureRect ColorRect Panel PanelContainer VBoxContainer HBoxContainer LineEdit
RichTextLabel MarginContainer CenterContainer ScrollContainer TextureButton NinePatchRect ProgressBar HSlider VSlider
CheckBox CheckButton OptionButton ItemList GridContainer TabContainer Container ReferenceRect SpinBox TextEdit
VideoStreamPlayer AspectRatioContainer FlowContainer HFlowContainer VFlowContainer BoxContainer SubViewportContainer
ViewportContainer TextureProgressBar LinkButton MenuButton ColorPickerButton Tree GraphEdit HSeparator VSeparator""".split())
PROP_CONTROLE = {"size": "rect_size", "position": "rect_position", "global_position": "rect_global_position",
                 "scale": "rect_scale"}


def renomear_codigo(c, avisos):
    for k, v in TIPOS.items():
        if k in c:
            c = re.sub(r"\b%s\b" % k, v, c)
    for k, v in FUNCOES.items():
        if k in c:
            if k in SO_GLOBAIS:
                c = re.sub(r"(?<![\.\w])%s\s*\(" % k, v + "(", c)
            else:
                c = re.sub(r"\b%s\s*\(" % k, v + "(", c)
    for k in G4_FUNCOES:
        c = re.sub(r"(?<![\.\w])%s\s*\(" % k, "G4.%s(" % k, c)
    c = COR_CONST.sub(lambda m: "Color." + m.group(1).lower(), c)
    c = re.sub(r"\bTime\.get_ticks_msec\(", "OS.get_ticks_msec(", c)
    c = re.sub(r"\bTime\.get_ticks_usec\(", "OS.get_ticks_usec(", c)
    c = re.sub(r"\bTime\.get_unix_time_from_system\(", "OS.get_unix_time(", c)
    c = re.sub(r"\bTime\.", "G4.", c)
    c = re.sub(r"\bJSON\.parse_string\(", "parse_json(", c)
    c = re.sub(r"\bJSON\.stringify\(", "G4.json_texto(", c)
    c = re.sub(r"\bFileAccess\.(READ|WRITE|READ_WRITE|WRITE_READ)\b", r"File.\1", c)
    c = re.sub(r"\bFileAccess\.open\(", "G4.abrir(", c)
    c = re.sub(r"\bFileAccess\.file_exists\(", "G4.existe(", c)
    c = re.sub(r"\bFileAccess\.get_file_as_string\(", "G4.ler_texto(", c)
    c = re.sub(r"\bDirAccess\.get_files_at\(", "G4.arquivos_em(", c)
    c = re.sub(r"\bDirAccess\.get_directories_at\(", "G4.pastas_em(", c)
    c = re.sub(r"\bDirAccess\.dir_exists_absolute\(", "G4.pasta_existe(", c)
    c = re.sub(r"\bDirAccess\.make_dir_recursive_absolute\(", "G4.criar_pasta(", c)
    c = re.sub(r"\bDirAccess\.open\(", "G4.abrir_pasta(", c)
    c = re.sub(r"\bDirAccess\.remove_absolute\(", "G4.apagar(", c)
    c = re.sub(r"\bDirAccess\.rename_absolute\(", "G4.renomear(", c)
    c = re.sub(r"\bDirAccess\.copy_absolute\(", "G4.copiar(", c)
    c = re.sub(r"\bDirAccess\b", "Directory", c)
    c = re.sub(r"\bProjectSettings\.get_setting\(", "G4.config(", c)
    c = re.sub(r"\bDisplayServer\.", "G4.", c)
    c = re.sub(r"\bThemeDB\.fallback_font\b", "G4.fonte()", c)
    c = re.sub(r"\bThemeDB\.fallback_font_size\b", "16", c)
    c = re.sub(r"\bThemeDB\.get_default_theme\(\)", "G4.tema()", c)
    c = re.sub(r"\bTextServerManager\.get_primary_interface\(\)", "G4.servidor_texto()", c)
    c = re.sub(r"\bVector2\.from_angle\(", "G4.from_angle(", c)
    c = re.sub(r"\bString\.chr\(", "char(", c)
    c = re.sub(r"\bCallable\(", "funcref(", c)
    c = re.sub(r"\bOfflineMultiplayerPeer\.new\(\)", "null", c)
    c = re.sub(r"\.multiplayer_peer\b", ".network_peer", c)
    c = re.sub(r"\.path_join\(", ".plus_file(", c)
    c = re.sub(r"\.intersection\(", ".clip(", c)
    c = re.sub(r"\.remove_at\(", ".remove(", c)
    c = re.sub(r"\.orthogonal\(\)", ".tangent()", c)
    c = re.sub(r"\.is_valid_int\(", ".is_valid_integer(", c)
    c = re.sub(r"\bInput\.get_vector\(", "G4.vetor(", c)
    c = re.sub(r"\bInput\.get_axis\(", "G4.eixo(", c)
    c = re.sub(r"\bEngine\.max_fps\b", "Engine.target_fps", c)
    c = re.sub(r"\bget_window\(\)\.get_final_transform\(\)", "G4.transformada_final(get_viewport())", c)
    c = re.sub(r"\.get_screen_center_position\(\)", ".get_camera_screen_center()", c)
    c = re.sub(r"^(\s*)([\w\.\[\]]*?)\.?texture_(filter|repeat)\s*=\s*.*$", r"\1pass  # texture_\3 (Godot 4): no 3 o filtro é da textura", c)
    c = re.sub(r"\.expand_mode\s*=\s*TextureRect\.EXPAND_IGNORE_SIZE", ".expand = true", c)
    c = re.sub(r"\.expand_mode\s*=\s*TextureRect\.\w+", ".expand = false", c)
    c = re.sub(r"\.get_image\(\)", ".get_data()", c)
    c = re.sub(r"\.unicode_at\(", ".ord_at(", c)
    c = re.sub(r"\.set_pixel\(", ".set_pixel(", c)
    c = re.sub(r"\bcustom_minimum_size\b", "rect_min_size", c)
    c = re.sub(r"\bpivot_offset\b", "rect_pivot_offset", c)
    c = re.sub(r"\bOS\.get_cmdline_user_args\(\)", "G4.args_usuario()", c)
    c = re.sub(r"\bmultiplayer\.peer_connected\b", "multiplayer.network_peer_connected", c)
    c = re.sub(r"\bmultiplayer\.peer_disconnected\b", "multiplayer.network_peer_disconnected", c)
    c = re.sub(r"\bVector4i\(", "G4.v4i(", c)
    c = re.sub(r"\bColor\.from_string\(", "G4.cor_de_texto(", c)
    c = re.sub(r"\bColor\.html\(", "Color(", c)
    c = re.sub(r"\bENetConnection\.", "G4.", c)
    c = re.sub(r"\bImage\.create\(", "G4.imagem(", c)
    c = re.sub(r"\bImage\.create_empty\(", "G4.imagem(", c)
    c = re.sub(r"\bImage\.create_from_data\(", "G4.imagem_de_dados(", c)
    c = re.sub(r"\bImageTexture\.create_from_image\(", "G4.textura(", c)
    c = re.sub(r"\.lerp\(", ".linear_interpolate(", c)
    c = re.sub(r"\.horizontal_alignment\b", ".align", c)
    c = re.sub(r"\.vertical_alignment\b", ".valign", c)
    c = re.sub(r"\bprocess_mode\b", "pause_mode", c)
    c = re.sub(r"\.keycode\b", ".scancode", c)
    c = re.sub(r"\.physical_keycode\b", ".physical_scancode", c)
    c = re.sub(r"\bget_window\(\)", "get_viewport()", c)
    c = re.sub(r"\bEngine\.get_main_loop\(\)", "Engine.get_main_loop()", c)
    c = re.sub(r"\bawait\s+get_tree\(\)\.process_frame\b", 'yield(get_tree(), "idle_frame")', c)
    c = re.sub(r"\bawait\s+get_tree\(\)\.physics_frame\b", 'yield(get_tree(), "physics_frame")', c)
    return c


# ---------------------------------------------------------------- utilidades de parênteses


def fechar(texto, i):
    """i aponta para '(' / '[' / '{'; devolve o índice do fechamento (ignora strings)."""
    pares = {"(": ")", "[": "]", "{": "}"}
    pilha = []
    j = i
    n = len(texto)
    while j < n:
        ch = texto[j]
        if ch in "\"'":
            k = j + 1
            while k < n and texto[k] != ch:
                k += 2 if texto[k] == "\\" else 1
            j = k + 1
            continue
        if ch in pares:
            pilha.append(pares[ch])
        elif pilha and ch == pilha[-1]:
            pilha.pop()
            if not pilha:
                return j
        j += 1
    return -1


def dividir_args(s):
    """Divide 'a, f(b, c), [d, e]' no nível 0."""
    partes = []
    prof = 0
    atual = ""
    i = 0
    while i < len(s):
        ch = s[i]
        if ch in "\"'":
            k = i + 1
            while k < len(s) and s[k] != ch:
                k += 2 if s[k] == "\\" else 1
            atual += s[i:k + 1]
            i = k + 1
            continue
        if ch in "([{":
            prof += 1
        elif ch in ")]}":
            prof -= 1
        if ch == "," and prof == 0:
            partes.append(atual)
            atual = ""
        else:
            atual += ch
        i += 1
    if atual.strip():
        partes.append(atual)
    return partes


EXPR_ANTES = r"((?:[A-Za-z_][\w]*|\)|\])(?:(?:\.[A-Za-z_]\w*)|(?:\([^()]*\))|(?:\[[^\[\]]*\]))*)"


def expr_antes(texto, fim):
    """Expressão simples imediatamente antes de texto[fim] (ex.: 'a.b[1].c()'). Devolve (inicio)."""
    j = fim
    prof = 0
    while j > 0:
        ch = texto[j - 1]
        if ch in ")]":
            prof += 1
        elif ch in "([":
            if prof == 0:
                break
            prof -= 1
        elif prof == 0 and not (ch.isalnum() or ch in "_."):
            break
        j -= 1
    return j


# ---------------------------------------------------------------- transformações em texto inteiro (linha lógica)


def trocar_max_min(linha):
    """max(a, b, c) -> max(max(a, b), c) (no Godot 3 max/min só aceitam 2 argumentos)."""
    for nome in ("max", "min"):
        pos = 0
        while True:
            m = re.compile(r"(?<![\.\w])%s\(" % nome).search(linha, pos)
            if not m:
                break
            a = m.end() - 1
            b = fechar(linha, a)
            if b < 0:
                break
            args = dividir_args(linha[a + 1:b])
            if len(args) > 2:
                novo = "%s(%s, %s)" % (nome, args[0].strip(), args[1].strip())
                for x in args[2:]:
                    novo = "%s(%s, %s)" % (nome, novo, x.strip())
                linha = linha[:m.start()] + novo + linha[b + 1:]
                pos = m.start() + 1
            else:
                pos = m.end()
    return linha


def trocar_call_deferred(linha):
    pos = 0
    while True:
        m = re.compile(r"\b([\w\.]*?)(\w+)\.call_deferred\(").search(linha, pos)
        if not m:
            return linha
        a = m.end() - 1
        b = fechar(linha, a)
        if b < 0:
            return linha
        args = linha[a + 1:b].strip()
        if args and args[0] in "\"'":   # obj.call_deferred("metodo") já é a forma do Godot 3
            pos = m.end()
            continue
        obj = m.group(1)[:-1] if m.group(1) else ""
        novo = '%scall_deferred("%s"%s)' % ((obj + ".") if obj else "", m.group(2), (", " + args) if args else "")
        linha = linha[:m.start()] + novo + linha[b + 1:]
        pos = m.start() + len(novo)


def metodo_como_valor(linha, funcoes, estatica, caminho):
    """No Godot 4 um método pode ser valor (Callable): "x.cb = metodo" -> "x.cb = funcref(self, "metodo")"."""
    if not funcoes or re.match(r"^\s*(static\s+)?func\s", linha):
        return linha
    segs, _ = segmentar(linha, False)
    obj = 'load("%s")' % caminho if estatica else "self"
    novos = []
    for tp, tx in segs:
        if tp == "c":
            def troca(m):
                return 'funcref(%s, "%s")' % (obj, m.group(1))
            tx = re.sub(r"(?<![\.\w\"'])(%s)\b(?!\s*\()(?!\s*[:=](?!=))" % "|".join(sorted(funcoes, key=len, reverse=True)),
                        troca, tx)
        novos.append((tp, tx))
    return juntar(novos)


def props_controle(linha, info, locais):
    segs, _ = segmentar(linha, False)
    novos = []
    for tp, tx in segs:
        if tp == "c":
            for nome in info["controles"]:
                if nome in tx:
                    tx = re.sub(r"(?<![\.\w])(%s)\.(size|position|global_position|scale)\b" % re.escape(nome),
                                lambda m: m.group(1) + "." + PROP_CONTROLE[m.group(2)], tx)
            if info["e_controle"]:
                tx = re.sub(r"(?<![\.\w\"'])(size|position|global_position|scale)\b(?!\s*\()",
                            lambda m: m.group(1) if m.group(1) in locais else PROP_CONTROLE[m.group(1)], tx)
        novos.append((tp, tx))
    return juntar(novos)


def timer_tempo_real(linha):
    """get_tree().create_timer(T, a, b, true) -> G4.timer_real(T): o 4º argumento do Godot 4 (ignore_time_scale) não
    existe no 3; sem ele o timer anda na escala de Engine.time_scale (hitstop/câmera lenta esticavam as esperas)."""
    pos = 0
    while True:
        m = re.compile(r"(?:\bget_tree\(\)|\b[\w\.]+)\.create_timer\(").search(linha, pos)
        if not m:
            return linha
        a = m.end() - 1
        b = fechar(linha, a)
        if b < 0:
            return linha
        args = [x.strip() for x in dividir_args(linha[a + 1:b])]
        if len(args) >= 4 and args[3] == "true":
            novo = "G4.timer_real(%s)" % args[0]
            linha = linha[:m.start()] + novo + linha[b + 1:]
            pos = m.start() + len(novo)
        else:
            pos = m.end()


# ---- igualdade de Dictionary: no Godot 3 "==" compara identidade, no 4 compara conteúdo
def _operando_esq(texto, fim):
    """Início do operando à esquerda de texto[fim]: volta pulando parênteses e strings até um delimitador
    (vírgula, abre-parêntese, =, <, >, !, :) ou uma palavra-chave (and, or, not, if, elif, while, return, in, else)."""
    j = fim
    prof = 0
    while j > 0:
        ch = texto[j - 1]
        if ch in "\"'":
            k = j - 2
            while k >= 0 and texto[k] != ch:
                k -= 1
            j = max(k, 0)
            continue
        if ch in ")]}":
            prof += 1
        elif ch in "([{":
            if prof == 0:
                break
            prof -= 1
        elif prof == 0:
            if ch in ",=<>!:":
                break
            if ch in " \t" and re.search(r"(?:^|\W)(and|or|not|if|elif|while|return|in|else)$", texto[:j - 1]):
                break
        j -= 1
    return j


def _operando_dir(texto, ini):
    j = ini
    prof = 0
    while j < len(texto):
        ch = texto[j]
        if ch in "\"'":
            k = j + 1
            while k < len(texto) and texto[k] != ch:
                k += 2 if texto[k] == "\\" else 1
            j = k + 1
            continue
        if ch in "([{":
            prof += 1
        elif ch in ")]}":
            if prof == 0:
                break
            prof -= 1
        elif prof == 0:
            if ch in ",:#":
                break
            if re.match(r"\s+(and|or|if|else)\b", texto[j:]):
                break
        j += 1
    return j


def _parece_dict(expr, globais, info):
    e = expr.strip()
    if e.startswith("{") or e == "{}":
        return True
    m = re.search(r"([A-Za-z_]\w*)\s*\([^()]*\)\s*$", e)
    if m and m.group(1) in globais.get("funcs_dict", ()):
        return True
    m = re.search(r"(?:^|\.)([A-Za-z_]\w*)$", e)
    if m and m.group(1) in globais.get("vars_dict", ()):
        return True
    return False


def igualdade_dict(linha, globais, info):
    if "==" not in linha and "!=" not in linha:
        return linha
    pos = 0
    while True:
        m = re.compile(r"\s*(==|!=)\s*").search(linha, pos)
        if not m:
            return linha
        e0 = _operando_esq(linha, m.start())
        d1 = _operando_dir(linha, m.end())
        esq, dir_ = linha[e0:m.start()], linha[m.end():d1]
        if esq.strip() and dir_.strip() and (_parece_dict(esq, globais, info) or _parece_dict(dir_, globais, info)):
            novo = "%sG4.igual(%s, %s)" % ("not " if m.group(1) == "!=" else "", esq.strip(), dir_.strip())
            pre = linha[:e0]
            linha = pre + novo + linha[d1:]
            pos = len(pre) + len(novo)
        else:
            pos = m.end()


def cortar_args(linha, nome, maximo):
    """nome(a, b, c, d) -> nome(a, b) quando o Godot 3 aceita menos argumentos (ex.: create_timer)."""
    pos = 0
    while True:
        m = re.compile(r"\b%s\(" % nome).search(linha, pos)
        if not m:
            return linha
        a = m.end() - 1
        b = fechar(linha, a)
        if b < 0:
            return linha
        args = dividir_args(linha[a + 1:b])
        if len(args) > maximo:
            novo = ", ".join(x.strip() for x in args[:maximo])
            linha = linha[:a + 1] + novo + linha[b:]
        pos = m.end()


def trocar_set_transform(linha):
    """draw_set_transform(pos, rot) -> draw_set_transform(pos, rot, Vector2.ONE) (no 3 a escala é obrigatória)."""
    pos = 0
    while True:
        m = re.compile(r"\bdraw_set_transform\(").search(linha, pos)
        if not m:
            return linha
        a = m.end() - 1
        b = fechar(linha, a)
        if b < 0:
            return linha
        args = dividir_args(linha[a + 1:b])
        if len(args) == 2:
            linha = linha[:b] + ", Vector2.ONE" + linha[b:]
        elif len(args) == 1:
            linha = linha[:b] + ", 0.0, Vector2.ONE" + linha[b:]
        pos = m.end()


def trocar_rpc(linha, funcoes=()):
    pos = 0
    while True:
        m = re.compile(r"\b([\w\.]*?)(\w+)\.(rpc|rpc_id)\(").search(linha, pos)
        if not m:
            return linha
        a = m.end() - 1
        b = fechar(linha, a)
        if b < 0:
            return linha
        args = dividir_args(linha[a + 1:b])
        local = not m.group(1) and m.group(2) in funcoes
        if args and args[0].strip()[:1] in ("\"", "'") and m.group(3) == "rpc" and not local:
            pos = m.end()
            continue
        obj = (m.group(1)[:-1] + ".") if m.group(1) else ""
        if m.group(3) == "rpc_id":
            partes = [args[0].strip(), '"%s"' % m.group(2)] + [x.strip() for x in args[1:]]
        else:
            partes = ['"%s"' % m.group(2)] + [x.strip() for x in args]
        novo = "%s%s(%s)" % (obj, m.group(3), ", ".join(partes))
        linha = linha[:m.start()] + novo + linha[b + 1:]
        pos = m.start() + len(novo)


def strings_multilinha(texto):
    """Godot 4 aceita "..." atravessando linhas; o Godot 3 não. Troca as aspas dessas strings por três aspas."""
    out = []
    i = 0
    n = len(texto)
    while i < n:
        ch = texto[i]
        if ch == "#":
            j = texto.find("\n", i)
            j = n if j < 0 else j
            out.append(texto[i:j])
            i = j
            continue
        if texto.startswith('"""', i):
            j = texto.find('"""', i + 3)
            j = n if j < 0 else j + 3
            out.append(texto[i:j])
            i = j
            continue
        if ch in "\"'":
            j = i + 1
            while j < n and texto[j] != ch:
                j += 2 if texto[j] == "\\" else 1
            s = texto[i:j + 1]
            if "\n" in s and ch == '"':
                s = '"""' + s[1:-1] + '"""'
            out.append(s)
            i = j + 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def inteiro_inline(linha):
    """roundi(x) -> int(round(x)), floori -> int(floor()), ceili -> int(ceil()): conta inline em vez de chamar o
    autoload G4 (chamada de autoload custa caro no Godot 3, e estas aparecem nos laços por inimigo)."""
    for nome, f in (("roundi", "round"), ("floori", "floor"), ("ceili", "ceil")):
        pos = 0
        while True:
            m = re.compile(r"(?<![\.\w])%s\(" % nome).search(linha, pos)
            if not m:
                break
            b = fechar(linha, m.end() - 1)
            if b < 0:
                break
            novo = "int(%s(%s))" % (f, linha[m.end():b])
            linha = linha[:m.start()] + novo + linha[b + 1:]
            pos = m.start() + len(novo)
    return linha


def abs_inteiro(linha):
    """No Godot 3 abs/max/min/clamp/round/floor/ceil/sign devolvem float; ao lado de % ou de operador de bits o
    Godot 4 tinha inteiro. Envolve a chamada em int() quando ela está à esquerda OU à direita desses operadores."""
    ops_dir = re.compile(r"^(%|&(?!&)|\^|\|(?!\|)|<<|>>)")
    ops_esq = re.compile(r"(%|&(?!&)|\^|\|(?!\|)|<<|>>)\s*$")
    pos = 0
    while True:
        m = re.compile(r"(?<![\.\w])(abs|max|min|clamp|round|floor|ceil|sign)\(").search(linha, pos)
        if not m:
            return linha
        b = fechar(linha, m.end() - 1)
        if b < 0:
            return linha
        depois = linha[b + 1:].lstrip()
        antes = linha[:m.start()]
        ja_int = antes.rstrip().endswith("int(")
        if not ja_int and (ops_dir.match(depois) or ops_esq.search(antes)):
            novo = "int(%s)" % linha[m.start():b + 1]
            linha = linha[:m.start()] + novo + linha[b + 1:]
            pos = m.start() + len(novo)
        else:
            pos = m.end()


def trocar_cor_alfa(linha):
    pos = 0
    while True:
        m = re.compile(r"(?<![\.\w])Color\(").search(linha, pos)
        if not m:
            return linha
        a = m.end() - 1
        b = fechar(linha, a)
        if b < 0:
            return linha
        args = dividir_args(linha[a + 1:b])
        if len(args) == 2:
            novo = "G4.cor(%s, %s)" % (args[0].strip(), args[1].strip())
            linha = linha[:m.start()] + novo + linha[b + 1:]
            pos = m.start() + len(novo)
        else:
            pos = m.end()


def dobrar_preload(texto):
    """preload(PASTA + "x.png") -> preload("res://.../x.png") quando PASTA é const string do arquivo."""
    consts = dict(re.findall(r'(?m)^const\s+(\w+)\s*(?::\s*String)?\s*:?=\s*("[^"]*")\s*(?:#.*)?$', texto))

    def troca(m):
        partes = [x.strip() for x in m.group(1).split("+")]
        vals = []
        for x in partes:
            if x in consts:
                vals.append(consts[x][1:-1])
            elif re.match(r'^"[^"]*"$', x):
                vals.append(x[1:-1])
            else:
                return 'load(%s)' % m.group(1)
        return 'preload("%s")' % "".join(vals)
    return re.sub(r"\bpreload\(([^()]*\+[^()]*)\)", troca, texto)


def trocar_metodo_por_g4(linha, metodo, g4nome):
    """X.metodo(args) -> G4.g4nome(X, args)."""
    pos = 0
    while True:
        i = linha.find("." + metodo + "(", pos)
        if i < 0:
            return linha
        ini = expr_antes(linha, i)
        alvo = linha[ini:i]
        if not alvo or alvo == "G4":
            pos = i + 1
            continue
        a = i + len(metodo) + 1
        b = fechar(linha, a)
        if b < 0:
            return linha
        dentro = linha[a + 1:b]
        novo = "G4.%s(%s%s)" % (g4nome, alvo, (", " + dentro) if dentro.strip() else "")
        linha = linha[:ini] + novo + linha[b + 1:]
        pos = ini + len(novo)


def trocar_join(linha):
    """"sep".join(x) -> PoolStringArray(x).join("sep")."""
    def troca(m):
        return m.group(0)
    pos = 0
    while True:
        m = re.compile(r"(\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*')\.join\(").search(linha, pos)
        if not m:
            return linha
        a = m.end() - 1
        b = fechar(linha, a)
        if b < 0:
            return linha
        novo = "PoolStringArray(%s).join(%s)" % (linha[a + 1:b], m.group(1))
        linha = linha[:m.start()] + novo + linha[b + 1:]
        pos = m.start() + len(novo)


def trocar_emit_connect(linha, avisos):
    # X.sinal.emit(args) -> X.emit_signal("sinal", args); sinal.emit(args) -> emit_signal("sinal", args)
    pos = 0
    while True:
        m = re.compile(r"\b(\w+)\.emit\(").search(linha, pos)
        if not m:
            break
        sinal, s0 = m.group(1), m.start(1)
        a = m.end() - 1
        b = fechar(linha, a)
        if b < 0:
            break
        args = linha[a + 1:b]
        if s0 > 0 and linha[s0 - 1] == ".":
            ini = expr_antes(linha, s0 - 1)
            pre = linha[ini:s0 - 1] + "."
        else:
            ini, pre = s0, ""
        novo = '%semit_signal("%s"%s)' % (pre, sinal, (", " + args) if args.strip() else "")
        linha = linha[:ini] + novo + linha[b + 1:]
        pos = ini + len(novo)
    # X.sinal.connect(f) / X.connect("sinal", f) / sinal.connect(f) (+ disconnect, is_connected)
    for verbo in ("connect", "disconnect", "is_connected"):
        pos = 0
        while True:
            m = re.compile(r"\b(\w+)\.%s\(" % verbo).search(linha, pos)
            if not m:
                break
            nome, s0 = m.group(1), m.start(1)
            a = m.end() - 1
            b = fechar(linha, a)
            if b < 0:
                break
            args = [x.strip() for x in dividir_args(linha[a + 1:b])]
            if nome == "G4" or not args:
                pos = m.end()
                continue
            if args[0][:1] in "\"'":
                # forma com string: obj.connect("sinal", callable, flags)
                if len(args) < 2:
                    pos = m.end()
                    continue
                ini = expr_antes(linha, s0) if s0 > 0 and linha[s0 - 1] == "." else s0
                pre = linha[ini:m.end() - len(verbo) - 1]           # "obj." completo
                sinal_txt, alvo_fn, extras = args[0], args[1], args[2:]
            else:
                if s0 > 0 and linha[s0 - 1] == ".":
                    ini = expr_antes(linha, s0 - 1)
                    pre = linha[ini:s0 - 1] + "."
                else:
                    ini, pre = s0, ""
                sinal_txt, alvo_fn, extras = '"%s"' % nome, args[0], args[1:]
            binds = "[]"
            mb = re.match(r"^(.*)\.bind\((.*)\)$", alvo_fn)
            if mb:
                alvo_fn, binds = mb.group(1), "[" + mb.group(2) + "]"
            ml = re.match(r"^G4\.ligar\(funcref\((.*),\s*(\"\w+\")\),\s*\[(.*)\]\)$", alvo_fn)
            mfr = re.match(r"^funcref\((.*),\s*(\"\w+\")\)$", alvo_fn)
            if ml or mfr:
                mm = ml or mfr
                partes = [sinal_txt, mm.group(1).strip(), mm.group(2)]
                if verbo == "connect":
                    if ml:
                        partes.append("[" + ml.group(3) + "]")
                    elif extras:
                        partes.append("[]")
                    partes += extras
                novo = "%s%s(%s)" % (pre, verbo, ", ".join(partes))
                linha = linha[:ini] + novo + linha[b + 1:]
                pos = ini + len(novo)
                continue
            if alvo_fn.startswith("func") or not re.match(r"^[\w\.\[\]\(\)]+$", alvo_fn):
                avisos.append("%s com lambda/callable complexo: %s" % (verbo, linha.strip()[:90]))
                pos = m.end()
                continue
            mc = re.match(r"^Callable\((.*),\s*(\"\w+\")\)$", alvo_fn)
            if mc:
                obj, met = mc.group(1), mc.group(2)
            elif "." in alvo_fn:
                obj, met = alvo_fn.rsplit(".", 1)
                met = '"%s"' % met
            else:
                obj, met = "self", '"%s"' % alvo_fn
            partes = [sinal_txt, obj, met]
            if verbo == "connect" and (extras or binds != "[]"):
                partes.append(binds)
                partes += extras
            novo = "%s%s(%s)" % (pre, verbo, ", ".join(partes))
            linha = linha[:ini] + novo + linha[b + 1:]
            pos = ini + len(novo)
    return linha


def trocar_await(linha, avisos):
    if "await" not in linha:
        return linha
    m = re.search(r"\bawait\s+", linha)
    if not m:
        return linha
    resto = linha[m.end():]
    # await G4.timer_real(t).timeout  /  await get_tree().create_timer(t).timeout
    mt = re.match(r"(G4\.timer_real\(.*\))\.timeout\b", resto) or re.match(r"(.*?\.create_timer\(.*\))\.timeout\b", resto)
    if mt:
        return linha[:m.start()] + 'yield(%s, "timeout")' % mt.group(1) + resto[mt.end():]
    # await X.sinal (termina num identificador sem parênteses)
    ms = re.match(r"([\w\.\[\]\(\)]+)\.(\w+)\s*$", resto.rstrip())
    if ms and not resto.rstrip().endswith(")"):
        return linha[:m.start()] + 'yield(%s, "%s")' % (ms.group(1), ms.group(2))
    # await chamada(...) -> yield(G4.co(chamada(...)), "completed")
    ini = m.end()
    j = ini
    while j < len(linha) and (linha[j].isalnum() or linha[j] in "_.$"):
        j += 1
    if j < len(linha) and linha[j] == "(":
        b = fechar(linha, j)
        if b > 0:
            chamada = linha[ini:b + 1]
            return linha[:m.start()] + 'yield(G4.co(%s), "completed")' % chamada + linha[b + 1:]
    msig = re.match(r"(\w+)\s*$", resto.rstrip())
    if msig:
        return linha[:m.start()] + 'yield(self, "%s")' % msig.group(1)
    avisos.append("await não traduzido: " + linha.strip()[:90])
    return linha.replace("await ", "yield(G4.co(") + '), "completed")  # G4?'


# ---------------------------------------------------------------- tipos: remover anotações (sem perda no 3.x)

RE_VAR = re.compile(r"^(\s*(?:static\s+)?(?:onready\s+)?(?:export(?:\([^)]*\))?\s+)?(?:var|const)\s+\w+)\s*(:=|:\s*)(.*)$")


def tirar_tipo_var(c):
    m = RE_VAR.match(c)
    if not m:
        return c
    cab, sep, resto = m.group(1), m.group(2), m.group(3)
    if sep.strip() == ":" and not resto.strip():
        return c                                   # "var x:" de padrão de match
    if sep == ":=":
        return "%s = %s" % (cab, resto.lstrip())
    # resto = "Tipo = valor" ou "Tipo" (ou "Tipo = valor: set = ..." tratado em outro lugar)
    # Tipos primitivos ficam: no Godot 3 a variável tipada converte float <-> int na atribuição, como no Godot 4
    # (sem isso, coordenadas de Vector2i, que viram Vector2, quebram "%" e índices).
    mt = re.match(r"^(int|float|bool|String)\s*(=\s*(.*))?$", resto.strip())
    if mt and not cab.lstrip().startswith("const"):
        return "%s: %s%s" % (cab, mt.group(1), (" = " + mt.group(3)) if mt.group(2) else "")
    prof = 0
    for i, ch in enumerate(resto):
        if ch in "([{":
            prof += 1
        elif ch in ")]}":
            prof -= 1
        elif ch == "=" and prof == 0:
            return "%s = %s" % (cab, resto[i + 1:].lstrip())
        elif ch == ":" and prof == 0:      # var x: int: set = ...
            return cab + resto[i:]
    return cab


def tirar_tipos_func(c):
    m = re.match(r"^(\s*(?:static\s+)?func\s+\w+\s*)\((.*)\)\s*(->\s*[^:]+)?:\s*(.*)$", c)
    if not m:
        return c
    params = []
    for p in dividir_args(m.group(2)):
        p = p.strip()
        mp = re.match(r"^(\w+)\s*(?::=\s*(.*)|:\s*([^=]+?)(?:\s*=\s*(.*))?|=\s*(.*))?$", p, re.S)
        if not mp:
            params.append(p)
            continue
        nome = mp.group(1)
        padrao = mp.group(2) or mp.group(4) or mp.group(5)
        tipo = (mp.group(3) or "").strip()
        if tipo in ("int", "float", "bool", "String"):
            nome += ": " + tipo        # o Godot 3 converte o argumento (float -> int) como o Godot 4 fazia
        params.append(nome + (" = " + padrao.strip() if padrao is not None else ""))
    resto = m.group(4)
    return "%s(%s):%s" % (m.group(1).rstrip(), ", ".join(params), (" " + resto) if resto else "")


def tirar_tipos_resto(c):
    c = re.sub(r"\bfor\s+(\w+)\s*:\s*[\w\[\]]+\s+in\b", r"for \1 in", c)
    c = re.sub(r"\b(Array|Dictionary)\s*\[[^\[\]]*\]", r"\1", c)            # Array[int] -> Array
    c = re.sub(r"\bas\s+(Array|Dictionary)\b", r"as \1", c)
    ms = re.match(r"^(\s*signal\s+\w+\s*)\(", c)
    if ms:
        a = ms.end() - 1
        b = fechar(c, a)
        if b > 0:
            args = ", ".join(re.sub(r"\s*:.*$", "", x.strip()) for x in dividir_args(c[a + 1:b]))
            c = ms.group(1) + "(" + args + ")" + c[b + 1:]
    return c


# ---------------------------------------------------------------- arquivo


def converter_arquivo(texto, info, globais, avisos):
    texto = strings_multilinha(texto.replace("\r\n", "\n"))
    texto = renomear_reservados(texto)
    texto = lambdas.icar(texto, info["caminho"], avisos)
    texto = dobrar_preload(texto)
    linhas = texto.replace("\r\n", "\n").split("\n")
    saida = []
    em_tripla = False
    sv = info["static_vars"]
    estatica = False
    locais = set()
    for linha in linhas:
        segs, prox = segmentar(linha, em_tripla)
        pura = linha.strip()
        mfn = re.match(r"^(static\s+)?func\s+\w+\s*\((.*?)\)", linha)
        if mfn:
            estatica = bool(mfn.group(1))
            locais = set(re.findall(r"(?:^|,)\s*(\w+)", mfn.group(2)))
        elif re.match(r"^\s*(static\s+)?func\s", linha):
            locais = set()
        elif linha.strip() and not linha.startswith(("\t", " ", "#")):
            estatica = False
        locais |= set(re.findall(r"\bvar\s+(\w+)", linha)) | set(re.findall(r"\bfor\s+(\w+)\s+in\b", linha))
        if not em_tripla:
            if pura.startswith("@tool"):
                linha = linha.replace("@tool", "tool", 1)
            elif pura.startswith("@onready"):
                linha = linha.replace("@onready", "onready", 1)
            elif pura.startswith("@export"):
                linha = re.sub(r"@export(_\w+)?(\([^)]*\))?", "export", linha, count=1)
            elif re.match(r"@(rpc|warning_ignore|icon|static_unload|abstract)\b", pura):
                linha = re.sub(r"^(\s*)@\w+(\([^)]*\))?\s*", r"\1", linha)
                if not linha.strip():
                    saida.append("# (anotação do Godot 4 removida)")
                    em_tripla = prox
                    continue
            segs, prox = segmentar(linha, em_tripla)
        novos = []
        for tipo, t in segs:
            if tipo == "c":
                t = renomear_codigo(t, avisos)
            novos.append((tipo, t))
        linha = juntar(novos)
        comentario = ""
        if not em_tripla:
            sg, _ = segmentar(linha, False)
            if sg and sg[-1][0] == "#":
                comentario = sg[-1][1]
                linha = juntar(sg[:-1]).rstrip()
                if not linha.strip():
                    saida.append(juntar(sg))
                    em_tripla = prox
                    continue
        if not em_tripla:
            # transformações que olham a linha toda (precisam ver strings como argumentos)
            linha = tirar_tipo_var(linha)
            linha = tirar_tipos_func(linha)
            linha = tirar_tipos_resto(linha)
            linha = trocar_emit_connect(linha, avisos)
            linha = trocar_await(linha, avisos)
            linha = trocar_max_min(linha)
            linha = re.sub(r"\.sort_custom\(funcref\(([^()]+|load\(\"[^\"]+\"\)),\s*(\"\w+\")\)\)", r".sort_custom(\1, \2)", linha)
            if ".sort_custom(G4.ligar(" in linha:
                linha = trocar_metodo_por_g4(linha, "sort_custom", "ordenar")
            linha = re.sub(r"\.call\((?=\s*[^\s\"')])", ".call_func(", linha)
            linha = re.sub(r"\.call\(\)", ".call_func()", linha)
            linha = re.sub(r"\.callv\((?=\s*[^\s\"'])", ".call_funcv(", linha)
            linha = trocar_cor_alfa(linha)
            linha = inteiro_inline(linha)
            linha = abs_inteiro(linha)
            linha = trocar_call_deferred(linha)
            linha = trocar_rpc(linha, info["funcoes"])
            linha = metodo_como_valor(linha, info["funcoes"] - locais, estatica, info["caminho"])
            if globais.get("so_funcoes") and info["objs"]:
                linha = re.sub(r"(?<![\w\.\"'])(%s)\.(%s)\b(?=\s*[,)])" % ("|".join(sorted(info["objs"])), globais["so_funcoes_re"]),
                               lambda m: 'funcref(%s, "%s")' % (m.group(1), m.group(2)), linha)
            linha = trocar_set_transform(linha)
            linha = timer_tempo_real(linha)
            linha = cortar_args(linha, "create_timer", 2)
            linha = trocar_metodo_por_g4(linha, "move_child", "mover_filho") if ".move_child(" in linha and "-1)" in linha else linha
            linha = igualdade_dict(linha, globais, info)
            linha = props_controle(linha, info, locais)
            linha = re.sub(r"^(\s*)([\w\.\[\]]+)\.skew\s*[-+*/]?=\s*(.+)$", r"\1G4.nada(\2, \3)  # skew do Godot 4", linha)
            linha = re.sub(r"[\w\.\[\]]+\.skew\b", "(0.0)", linha)
            for nome in info["pools"]:
                linha = re.sub(r"(?<![\.\w])%s\.clear\(\)" % re.escape(nome), nome + ".resize(0)", linha)
            for nome in info["callables"]:
                linha = re.sub(r"(?<![\w])(%s)\.call\(" % re.escape(nome), r"\1.call_func(", linha)
            linha = re.sub(r'("(?:[^"\\]|\\.)*")\.contains\(', r"G4.contains(\1, ", linha)
            linha = re.sub(r"(\w+\(\)(?:\.\w+\(\))*)\s*\*\s*(get_viewport_rect\(\)|get_rect\(\))", r"\1.xform(\2)", linha)
            linha = trocar_join(linha)
            for met, g4 in (("contains", "contains"), ("pick_random", "pick_random"), ("angle_to_point", "angle_to_point"),
                            ("slice", "slice"), ("repeat", "repetir"), ("filter", "filtrar"), ("map", "mapear"),
                            ("any", "algum"), ("all", "todos"), ("reduce", "reduzir"), ("count", "contar"),
                            ("add_theme_font_size_override", "tamanho_fonte"), ("draw_string", "texto_em"),
                            ("draw_string_outline", "texto_contorno_em"), ("get_string_size", "medir"),
                            ("get_center", "centro"), ("has_area", "tem_area"), ("merged", "merged"),
                            ("set_pixel", "px_set"), ("get_pixel", "px_get"), ("set_pixelv", "px_setv"),
                            ("get_pixelv", "px_getv"), ("draw_multiline_string", "texto_multilinha_em")):
                if "." + met + "(" in linha:
                    linha = trocar_metodo_por_g4(linha, met, g4)
            # draw_string(...) sem objeto = self
            linha = re.sub(r"(?<![\.\w])draw_string\(", "G4.texto_em(self, ", linha)
            linha = re.sub(r"(?<![\.\w])draw_string_outline\(", "G4.texto_contorno_em(self, ", linha)
            linha = re.sub(r"(?<![\.\w])draw_multiline_string\(", "G4.texto_multilinha_em(self, ", linha)
            # ImageTexture.update(img) do Godot 4 -> set_data(img) (CanvasItem.update() não tem argumentos)
            linha = re.sub(r"\.update\((?=\s*[^\s)])", ".set_data(", linha)
            # static var -> dicionário compartilhado _SV
            ms = re.match(r"^(\s*)static\s+var\s+(\w+)\s*(?:=\s*(.*))?$", linha)
            if ms:
                nome = ms.group(2)
                saida.append("%s# static var %s -> _SV.%s (Godot 3 não tem static var)" % (ms.group(1), nome, nome))
                em_tripla = prox
                continue
            if sv:
                segs2, _ = segmentar(linha, False)
                segs2 = [(tp, re.sub(r"(?<![\.\w])(%s)\b" % "|".join(sv), r"_SV.\1", tx) if tp == "c" else tx)
                         for tp, tx in segs2]
                linha = juntar(segs2)
            # acesso de fora a static var: Alias.var -> Alias._SV.var
            for alias, nomes in globais["sv_por_alias"].get(info["caminho"], {}).items():
                segs2, _ = segmentar(linha, False)
                segs2 = [(tp, re.sub(r"\b%s\.(%s)\b" % (re.escape(alias), "|".join(nomes)), alias + r"._SV.\1", tx)
                          if tp == "c" else tx) for tp, tx in segs2]
                linha = juntar(segs2)
            # Alias._SV.nome = valor  (de fora): o Godot 3 tentaria regravar a constante _SV no script
            msv = re.match(r"^(\s*)(\w+\._SV)\.(\w+)\s*(=|\+=|-=|\*=|/=)\s*(.+)$", linha)
            if msv:
                ind, dic, nome, op, val = msv.groups()
                if op != "=":
                    val = "%s.%s %s (%s)" % (dic, nome, op[0], val)
                linha = '%sG4.sv_def(%s, "%s", %s)' % (ind, dic, nome, val)
            if re.search(r"\bfunc\s*\(", linha) and not re.match(r"^\s*(static\s+)?func\s+\w", linha):
                avisos.append("lambda: " + linha.strip()[:90])
                linha += "  # G4? lambda"
            if re.search(r"\bsuper\b", linha):
                avisos.append("super: " + linha.strip()[:90])
                linha += "  # G4? super"
        if estatica and not em_tripla:
            linha = re.sub(r'(\bconnect\("[^"]+",\s*)self(\s*,)', r'\1load("%s")\2' % info["caminho"], linha)
        if comentario:
            linha = linha + "  " + comentario
        saida.append(linha)
        em_tripla = prox
    texto = "\n".join(saida)
    if sv:
        # o dicionário fica no topo, depois do extends/class_name
        valores = ", ".join('"%s": %s' % (k, v) for k, v in sv.items())
        bloco = "const _SV = {%s}   # static vars do Godot 4 (const Dictionary é mutável no 3.x)" % valores
        texto = texto.rstrip("\n") + "\n\n\n" + bloco + "\n"
    return texto


def shaders_godot3(texto):
    """Shaders canvas_item em strings: no Godot 3 o COLOR do fragment começa só com a cor do vértice (sem a textura).
    Se o fragment não amostra TEXTURE, a textura é aplicada no começo (senão "COLOR.rgb = branco" vira retângulo)."""
    def corrigir(m):
        s = m.group(0)
        if "canvas_item" not in s or "texture(TEXTURE" in s or "blend_mul" in s:
            return s
        return re.sub(r"(void\s+fragment\s*\(\s*\)\s*\{)", r"\1 COLOR *= texture(TEXTURE, UV);", s, count=1)
    return re.sub(r'"""shader_type[\s\S]*?"""|"shader_type(?:[^"\\]|\\.)*"', corrigir, texto)


ONLINE_AUTOLOADS = ("scripts/hordas/salas.gd", "scripts/hordas/chat.gd", "scripts/hordas/voz.gd", "scripts/hordas/rede.gd")


def info_por_rel(rel):
    return "res://" + rel


def marcos_de_abertura(texto, caminho_res):
    """Insere G4.marca("<script>:<função>") como 1ª linha de _init/_enter_tree/_ready de nível 0 (diagnóstico de queda na
    abertura no Vita) e, nos autoloads online, o corte de segurança G4.modo(8)."""
    rel = caminho_res.replace("res://", "")
    nome = rel.split("/")[-1]

    def troca(m):
        corpo = "\tG4.marca(\"%s:%s\")\n" % (nome, m.group(1))
        if m.group(1) == "_ready" and rel in ONLINE_AUTOLOADS:
            corpo += "\tif G4.modo(8):\n\t\treturn  # online fora da v1 no Vita (kikiu_modo.txt)\n"
        return m.group(0) + corpo
    return re.sub(r"(?m)^func (_init|_enter_tree|_ready)\([^)]*\):[ \t]*(?:#[^\n]*)?\n", troca, texto)


def coletar_info(caminho_res, texto):
    info = {"caminho": caminho_res, "static_vars": {}, "aliases": {},
            "funcoes": set(re.findall(r"(?m)^(?:static\s+)?func\s+(\w+)", texto)), "controles": set()}
    cls = "|".join(sorted(CONTROLES, key=len, reverse=True))
    for m in re.finditer(r"\bvar\s+(\w+)\s*(?::\s*(%s)\b|:?=\s*(%s)\.new\()" % (cls, cls), texto):
        info["controles"].add(m.group(1))
    info["pools"] = set(re.findall(r"\bvar\s+(\w+)\s*(?::\s*Packed\w+Array\b|:?=\s*Packed\w+Array\()", texto))
    info["callables"] = set(re.findall(r"\bvar\s+(\w+)\s*:\s*Callable\b", texto)) | \
        set(re.findall(r"\bfunc\s+\w+\s*\([^)]*?\b(\w+)\s*:\s*Callable\b", texto))
    # objetos de script conhecidos: aliases de preload, autoloads e variáveis criadas com Alias.new()
    aliases = set(re.findall(r'(?m)^const\s+(\w+)\s*(?::\s*\w+)?\s*:?=\s*preload\("res://[^"]+\.gd"\)', texto))
    info["objs"] = aliases | set(AUTOLOADS) | set(
        re.findall(r"\b(\w+)\s*:?=\s*(?:%s)\.new\(" % "|".join(aliases), texto) if aliases else [])
    # variável de laço sobre lista de Controls: "for c in [_tela, _topo]:"
    for m in re.finditer(r"\bfor\s+(\w+)\s+in\s+\[([^\]]+)\]", texto):
        itens = [x.strip() for x in m.group(2).split(",")]
        if any(x in info["controles"] for x in itens):
            info["controles"].add(m.group(1))
    me = re.search(r"(?m)^extends\s+(\w+)", texto)
    info["e_controle"] = bool(me and me.group(1) in CONTROLES)
    for linha in texto.replace("\r\n", "\n").split("\n"):
        ms = re.match(r"^static\s+var\s+(\w+)\s*(?::\s*[^=]+)?(?:(?::)?=\s*(.*))?$", linha.strip())
        if ms and not linha.startswith((" ", "\t")):
            valor = (ms.group(2) or "null").split("#")[0].strip() or "null"
            info["static_vars"][ms.group(1)] = renomear_codigo(valor, [])
        ma = re.match(r'^\s*const\s+(\w+)\s*(?::\s*\w+)?\s*:?=\s*preload\("(res://[^"]+\.gd)"\)', linha)
        if ma:
            info["aliases"][ma.group(1)] = ma.group(2)
    return info


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    orig, dest = sys.argv[1], sys.argv[2]
    manual = os.path.join(AQUI, "..", "jogo_vita_manual")
    os.makedirs(dest, exist_ok=True)
    scripts = {}
    for raiz, _, arqs in [w for pasta in ("scripts", "testes") for w in os.walk(os.path.join(orig, pasta))]:
        for a in arqs:
            if a.endswith(".gd"):
                p = os.path.join(raiz, a)
                res = "res://" + os.path.relpath(p, orig).replace("\\", "/")
                scripts[res] = open(p, encoding="utf-8").read()
    proj4 = os.path.join(orig, "project.godot")
    if os.path.exists(proj4):
        em = False
        for l in open(proj4, encoding="utf-8").read().split("\n"):
            if l.startswith("["):
                em = l.strip() == "[autoload]"
            elif em and "=" in l:
                AUTOLOADS.append(l.split("=")[0].strip())
    infos = {res: coletar_info(res, t) for res, t in scripts.items()}
    sv_por_script = {res: list(i["static_vars"].keys()) for res, i in infos.items() if i["static_vars"]}
    globais = {"sv_por_alias": {}}
    todas_funcs = set()
    todas_vars = set()
    for t in scripts.values():
        todas_funcs |= set(re.findall(r"(?m)^\s*(?:static\s+)?func\s+(\w+)", t))
        # só membros de classe (nível 0): parâmetros com o mesmo nome de uma função não impedem a troca
        todas_vars |= set(re.findall(r"(?m)^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:var|const|signal)\s+(\w+)", t))
    so = sorted(todas_funcs - todas_vars - {"new", "get", "set", "call", "free"}, key=len, reverse=True)
    globais["funcs_dict"] = set()
    globais["vars_dict"] = set()
    for t in scripts.values():
        globais["funcs_dict"] |= set(re.findall(r"func\s+(\w+)\s*\([^)]*\)\s*->\s*Dictionary", t))
        globais["vars_dict"] |= set(re.findall(r"\bvar\s+(\w+)\s*:\s*Dictionary\b", t))
        globais["vars_dict"] |= set(re.findall(r"\bvar\s+(\w+)\s*:?=\s*\{", t))
    globais["so_funcoes"] = so
    globais["so_funcoes_re"] = "|".join(re.escape(x) for x in so)
    for res, i in infos.items():
        m = {}
        for alias, alvo in i["aliases"].items():
            if alvo in sv_por_script:
                m[alias] = sv_por_script[alvo]
        if m:
            globais["sv_por_alias"][res] = m
    relatorio = {}
    for res, texto in sorted(scripts.items()):
        avisos = []
        novo = converter_arquivo(texto, infos[res], globais, avisos)
        rel = res[len("res://"):]
        alvo = os.path.join(dest, rel)
        os.makedirs(os.path.dirname(alvo), exist_ok=True)
        mp = os.path.join(manual, rel)
        if os.path.exists(mp):
            shutil.copy(mp, alvo)
            avisos = ["(arquivo manual)"]
        else:
            if rel in ajustes_vita.AJUSTES:
                novo = ajustes_vita.AJUSTES[rel](novo, avisos)
            novo = shaders_godot3(novo)
            if rel.startswith("scripts/"):
                novo = marcos_de_abertura(novo, info_por_rel(rel))
            open(alvo, "w", encoding="utf-8", newline="\n").write(novo)
        relatorio[rel] = avisos
    shutil.copy(os.path.join(AQUI, "g4.gd"), os.path.join(dest, "g4.gd"))
    json.dump(relatorio, open(os.path.join(dest, "conversao.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    n = sum(len(v) for v in relatorio.values())
    print("%d scripts convertidos, %d avisos (ver conversao.json)" % (len(relatorio), n))


if __name__ == "__main__":
    main()
