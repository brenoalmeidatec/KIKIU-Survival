"""Estudo independente de modelagem. Não importa nem altera o jogo."""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
random.seed(26)
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def mat(name, color, metal=0, rough=.65, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    return m

stone = [mat('Basalto %d' % i, (.095+i*.014, .13+i*.015, .145+i*.018)) for i in range(5)]
soil = mat('Terra escura', (.047, .062, .058))
edge = mat('Corte do diorama', (.035, .055, .075), .15)
red = mat('Tecido vermelho queimado', (.43, .025, .045))
red_light = mat('Vermelho iluminado', (.67, .045, .055))
red_dark = mat('Dobras do tecido', (.24, .012, .025))
charcoal = mat('Calça azul carvão', (.026, .044, .064))
leather = mat('Couro castanho', (.105, .052, .035))
hair = mat('Cabelo quase preto', (.018, .023, .031))
skin = mat('Pele', (.57, .31, .17))
skin_lit = mat('Rosto iluminado', (.72, .43, .24))
steel = mat('Aço azulado', (.22, .34, .41), .8, .3)
silver = mat('Fio polido', (.67, .8, .86), .9, .21)
gold = mat('Latão antigo', (.43, .265, .08), .75, .38)
leaves = [mat('Folhagem %d' % i, (.024+i*.012, .085+i*.023, .052+i*.008)) for i in range(5)]
bark = mat('Casca de árvore', (.065, .047, .038))
moss = mat('Musgo', (.13, .23, .067))
violet = mat('Magia violeta', (.39, .055, .95), .15, .3, 6)
cyan = mat('Reflexo frio', (.08, .65, 1), .3, .3, 3)
fire = mat('Chama âmbar', (1, .28, .025), 0, .4, 7)
fire_core = mat('Núcleo da chama', (1, .8, .27), 0, .4, 9)
eye = mat('Olho', (.016, .012, .009))

def assign(obj, material):
    obj.data.materials.append(material)
    return obj

def box(name, loc, scale, material, bevel=.035, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot: o.rotation_euler = rot
    assign(o, material)
    if bevel:
        b = o.modifiers.new('Arestas trabalhadas', 'BEVEL')
        b.width = bevel
        b.segments = 1
        o.modifiers.new('Normais', 'WEIGHTED_NORMAL')
    return o

def ico(name, loc, scale, material, sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    return assign(o, material)

def segment(name, a, b, r1, r2, material, vertices=8):
    d = Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=d.length, location=(Vector(a)+Vector(b))/2)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    return assign(o, material)

def mesh(name, verts, faces, material):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    return assign(o, material)

def line(name, points, radius, material, cyclic=False):
    c = bpy.data.curves.new(name, 'CURVE')
    c.dimensions = '3D'
    c.bevel_depth = radius
    c.bevel_resolution = 1
    s = c.splines.new('POLY')
    s.points.add(len(points)-1)
    for p, co in zip(s.points, points): p.co = (*co, 1)
    s.use_cyclic_u = cyclic
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    return assign(o, material)

def light(name, loc, color, energy, size=1, kind='AREA', target=(0,0,0)):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = color
    if kind == 'AREA': data.shape = 'DISK'; data.size = size
    else: data.shadow_soft_size = size
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    o.location = loc
    if kind == 'AREA': o.rotation_euler = (Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    return o

# Base de pedra e caminho irregular.
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=4.05, depth=.42, location=(0,0,-.19))
base = assign(bpy.context.object, edge)
base.name = 'Base independente — não é mapa do jogo'
b = base.modifiers.new('Borda chanfrada', 'BEVEL'); b.width=.12; b.segments=2
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=3.97, depth=.12, location=(0,0,.04))
assign(bpy.context.object, soil)
for ix in range(-6,7):
    for iy in range(-6,7):
        x,y=ix*.6,iy*.6
        if x*x+y*y > 3.75**2: continue
        if random.random() < .12: continue
        box('Laje irregular', (x+random.uniform(-.055,.055),y+random.uniform(-.045,.045),.12+random.uniform(-.025,.025)),
            (random.uniform(.46,.56), random.uniform(.45,.56), .16), random.choice(stone), .045, (0,0,random.uniform(-.075,.075)))
for i in range(42):
    x,y=random.uniform(-3.5,3.5),random.uniform(-3.5,3.5)
    if x*x+y*y<13:
        ico('Musgo entre as pedras',(x,y,.22),(.11,.14,.035),moss)

# Herói original modelado para este estudo, olhando para -Y.
H = -0.75
def P(x,y,z): return (x,y+H,z)
box('Bota esquerda',P(-.26,-.18,.37),(.36,.61,.34),leather,.065)
box('Bota direita',P(.29,.13,.37),(.36,.58,.34),leather,.065)
segment('Canela esquerda',P(-.25,-.08,.5),P(-.3,.05,1.02),.16,.185,charcoal)
segment('Coxa esquerda',P(-.3,.05,1.02),P(-.17,.05,1.59),.19,.22,charcoal)
segment('Canela direita',P(.29,.17,.5),P(.39,.24,1.02),.16,.185,charcoal)
segment('Coxa direita',P(.39,.24,1.02),P(.19,.05,1.59),.19,.22,charcoal)
box('Faixa da bota esquerda',P(-.26,-.04,.62),(.34,.31,.08),steel,.015)
box('Faixa da bota direita',P(.29,.19,.62),(.34,.31,.08),steel,.015)
body=[P(-.31,-.2,1.48),P(.31,-.2,1.48),P(.31,.19,1.48),P(-.31,.19,1.48),
      P(-.43,-.23,2.3),P(.43,-.23,2.3),P(.43,.2,2.3),P(-.43,.2,2.3)]
mesh('Casaco vermelho',body,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7),(0,3,2,1)],red)
mesh('Aba do casaco esquerda',[P(-.31,-.21,1.75),P(-.02,-.24,1.75),P(-.08,-.3,1.15),P(-.4,-.23,1.22)],[(0,1,2,3)],red_light)
mesh('Aba do casaco direita',[P(.02,-.24,1.75),P(.31,-.21,1.75),P(.4,-.1,1.22),P(.08,-.29,1.15)],[(0,1,2,3)],red_dark)
box('Cinto',P(0,-.015,1.72),(.69,.48,.14),leather,.025)
box('Fivela pequena',P(.03,-.27,1.72),(.15,.035,.12),gold,.012)
line('Gola cruzada',[P(-.24,-.245,2.28),P(.08,-.26,1.84)],.035,red_light)
line('Costura lateral',[P(.29,-.235,2.26),P(.22,-.25,1.86)],.018,red_dark)
segment('Braço esquerdo',P(-.4,0,2.21),P(-.61,-.1,1.95),.21,.155,red)
segment('Antebraço esquerdo',P(-.61,-.1,1.95),P(-.53,-.38,1.76),.15,.115,leather)
box('Proteção esquerda',P(-.57,-.22,1.87),(.25,.25,.29),steel,.035, (.45,0,-.2))
ico('Mão esquerda',P(-.52,-.42,1.73),(.13,.13,.14),skin,2)
segment('Braço direito',P(.4,0,2.22),P(.66,-.17,2.07),.2,.16,red_light)
segment('Antebraço direito',P(.66,-.17,2.07),P(.83,-.43,2.05),.15,.115,leather)
box('Proteção direita',P(.73,-.29,2.06),(.24,.27,.25),steel,.03,(0,.3,.5))
ico('Mão na katana',P(.84,-.45,2.06),(.13,.13,.13),skin_lit,2)
segment('Pescoço',P(0,0,2.27),P(0,0,2.53),.13,.14,skin,10)
ico('Cabeça facetada',P(0,-.015,2.73),(.32,.275,.37),skin_lit,2)
ico('Orelha esquerda',P(-.3,-.015,2.71),(.065,.07,.095),skin,1)
ico('Orelha direita',P(.3,-.015,2.71),(.065,.07,.095),skin,1)
ico('Cabelo — volume',P(0,.05,2.94),(.35,.29,.24),hair,2)
for i in range(9):
    a=i*2.399
    root=P(math.cos(a)*.22,math.sin(a)*.16+.04,2.98)
    tip=P(math.cos(a)*.39,math.sin(a)*.33+.05,3.19+random.uniform(-.05,.13))
    segment('Mecha de cabelo',root,tip,.105,0,hair,4)
for x,z in [(-.2,2.89),(-.02,2.94),(.17,2.91)]:
    mesh('Franja',[P(x-.12,-.19,z+.15),P(x+.1,-.2,z+.09),P(x-.025,-.285,z-.13)],[(0,1,2)],hair)
box('Olho esquerdo',P(-.11,-.27,2.74),(.073,.025,.037),eye,.007)
box('Olho direito',P(.115,-.268,2.74),(.073,.025,.037),eye,.007)
line('Sobrancelha esquerda',[P(-.17,-.267,2.8),P(-.065,-.28,2.785)],.018,hair)
line('Sobrancelha direita',[P(.065,-.28,2.785),P(.17,-.267,2.8)],.018,hair)
ico('Nariz',P(0,-.292,2.675),(.048,.057,.065),skin,1)
line('Boca',[P(-.06,-.259,2.59),P(.055,-.259,2.59)],.012,leather)
segment('Gola do lenço',P(0,0,2.37),P(0,0,2.51),.23,.2,red_light,10)
mesh('Lenço ao vento',[P(-.13,.12,2.46),P(-.55,.25,2.56),P(-1.08,.15,2.67),P(-1.54,.35,2.5),P(-1.15,.32,2.42),P(-.6,.34,2.37)],[(0,1,5),(1,2,4,5),(2,3,4)],red_light)
mesh('Face escura do lenço',[P(-.13,.125,2.45),P(-.6,.345,2.37),P(-1.15,.325,2.42),P(-1.54,.355,2.5)],[(0,1,2,3)],red_dark)
# Bainha à esquerda e lâmina desenhada em geometria.
segment('Bainha',P(-.34,.1,1.72),P(-.77,.52,.91),.07,.053,hair,6)
segment('Terminal da bainha',P(-.75,.5,.96),P(-.79,.54,.88),.06,.06,gold,6)
hand=Vector(P(.84,-.45,2.06)); direction=Vector((1.05,.25,.20)).normalized()
handle_a=hand-direction*.23; handle_b=hand+direction*.18
segment('Cabo da katana',handle_a,handle_b,.05,.05,hair,8)
for i in range(5):
    c=handle_a+direction*(.055+i*.065)
    segment('Trança do cabo',c,c+direction*.025,.054,.054,gold,8)
segment('Guarda da katana',handle_b-direction*.025,handle_b+direction*.025,.135,.135,gold,8)
blade_start=handle_b+direction*.06; blade_tip=blade_start+direction*1.45
side=Vector((0,0,1)).cross(direction).normalized()
verts=[blade_start-side*.045,blade_start+side*.045,blade_tip+side*.06,blade_tip+direction*.12,blade_start+Vector((0,0,.025))]
mesh('Lâmina da katana',[tuple(v) for v in verts],[(0,1,4),(1,2,3,4),(0,4,3)],silver)
line('Dorso da lâmina',[tuple(blade_start+side*.045),tuple(blade_tip+side*.06)],.018,steel)
line('Fio azul refletido',[tuple(blade_start-side*.045),tuple(blade_tip+direction*.12)],.009,cyan)

# Portal de pedra e magia em anéis, ao fundo.
px,py,pz=1.6,1.6,1.86
for i in range(15):
    a=(i+.5)*math.pi/15
    x,z=px+math.cos(a)*1.3,pz+math.sin(a)*1.3
    box('Aduela do portal',(x,py,z),(.3,.55,.35),stone[(i+1)%5],.045,(0,-a,0))
for x in (px-1.3,px+1.3):
    for j in range(4):
        box('Pilar do portal',(x,py,.42+j*.37),(.34,.55,.35),stone[j%5],.035)
    box('Base do portal',(x,py-.04,.29),(.67,.85,.26),stone[2],.04)
points=[(px+1.08*math.cos(a),py-.29,pz+1.08*math.sin(a)) for a in [2*math.pi*i/96 for i in range(96)]]
line('Aro de energia',points,.032,violet,True)
for phase in (0,2.6):
    pts=[]
    for i in range(110):
        a=i*.11+phase; r=.1+i*.0074
        pts.append((px+math.cos(a)*r,py-.27+math.sin(i*.12)*.08,pz+math.sin(a)*r))
    line('Redemoinho do portal',pts,.013,violet)
for i in range(28):
    a=random.random()*math.tau;r=random.uniform(.9,1.3)
    ico('Centelha do portal',(px+math.cos(a)*r,py-.35+random.uniform(-.2,.2),pz+math.sin(a)*r),(.022,.022,.04),violet)
light('Portal ilumina pedras',(px,py-.6,1.65),(.48,.065,1),180,1.1,'POINT')
for j in range(3):
    box('Degrau do portal',(px,py-.2-j*.5,.25-j*.035),(1.65,.47,.14),stone[2+j%2],.055)

# Ruína quebrada e árvores emoldurando a cena.
for x,y,h in [(-2.1,1.25,2.5),(-3.0,.7,1.4)]:
    box('Base da ruína',(x,y,.33),(.85,.85,.3),stone[1],.045)
    for j in range(int(h/.42)):
        box('Pedra da coluna',(x+random.uniform(-.025,.025),y,.6+j*.41),(.54,.57,.39),random.choice(stone),.045,(0,0,random.uniform(-.04,.04)))
    ico('Topo fraturado',(x-.03,y,.4+h),(.4,.36,.19),stone[2])
    line('Runa iluminada',[(x-.11,y-.295,1.0),(x+.03,y-.295,1.15),(x-.08,y-.295,1.28),(x+.11,y-.295,1.4)],.018,cyan)
box('Verga tombada',(-2.65,1.28,.46),(1.45,.5,.45),stone[1],.05,(0,.18,.4))

def tree(x,y,height):
    segment('Tronco retorcido',(x,y,.2),(x-.18,y+.1,height*.64),.28,.15,bark,7)
    segment('Tronco superior',(x-.18,y+.1,height*.64),(x+.09,y,height),.15,.05,bark,7)
    for a in (.2,2.1,3.8,5):
        root=(x-.1,y,height*.57)
        tip=(x+math.cos(a)*.95,y+math.sin(a)*.8,height*.87)
        segment('Galho',root,tip,.12,.035,bark,6)
        ico('Copa facetada',tip,(.8,.7,.46),random.choice(leaves),2)
    ico('Copa alta',(x+.05,y,height),(.88,.74,.57),random.choice(leaves),2)
    for a in range(5):
        end=(x+math.cos(a*1.25)*.6,y+math.sin(a*1.25)*.5,.19)
        segment('Raiz',(x,y,.48),end,.13,.035,bark,5)
tree(-2.8,2.15,3.6)
tree(3.0,2.6,2.6)
for x,y in [(-3,-1.5),(2.9,-1.2),(-1.6,2.75),(.1,3.1),(-2.8,-.8)]:
    for j in range(5):
        ico('Arbusto',(x+random.uniform(-.4,.4),y+random.uniform(-.3,.3),.35+random.random()*.23),(.4,.35,.28),random.choice(leaves),1)
for i in range(130):
    a=random.uniform(0,math.tau); r=random.uniform(2.3,3.7)
    x,y=math.cos(a)*r,math.sin(a)*r
    h=random.uniform(.14,.35)
    for j in range(3):
        ang=j*2.09+random.random();dx,dy=math.cos(ang),math.sin(ang)
        mesh('Folha de capim',[(x-dy*.025,y+dx*.025,.2),(x+dy*.025,y-dx*.025,.2),(x+dx*.12,y+dy*.12,.2+h)],[(0,1,2)],random.choice(leaves))

# Lanterna e braseiro: luz quente contra a luz fria do portal.
lx,ly=-1.9,-1.6
box('Pé do braseiro',(lx,ly,.3),(.5,.5,.24),stone[1],.04)
segment('Haste de ferro',(lx,ly,.4),(lx,ly,1.08),.055,.055,steel)
segment('Taça do braseiro',(lx,ly,1.04),(lx,ly,1.24),.12,.27,steel)
for dx,dy,h in [(0,0,.55),(.11,.03,.34),(-.1,-.04,.4)]:
    ico('Chama exterior',(lx+dx,ly+dy,1.28+h*.35),(.12,.1,h*.6),fire,1)
ico('Chama central',(lx,ly-.03,1.4),(.065,.065,.22),fire_core,1)
light('Braseiro âmbar',(lx,ly,1.5),(1,.35,.08),115,.5,'POINT')
for i in range(12):
    ico('Brasa',(lx+random.uniform(-.23,.23),ly+random.uniform(-.18,.18),random.uniform(1.6,2.15)),(.013,.013,.024),fire)
for x,y in [(-2,-.4),(2.9,-2.1),(.3,2.8)]:
    for j in range(3):
        xx,yy=x+random.uniform(-.15,.15),y+random.uniform(-.15,.15)
        segment('Cogumelo — caule',(xx,yy,.22),(xx,yy,.39),.025,.021,stone[3],6)
        ico('Cogumelo — chapéu',(xx,yy,.4),(.12,.1,.065),cyan,1)

# Luz de estúdio suave mantém os materiais legíveis.
light('Luz principal',(0,-5,8),(1,.8,.62),650,6,target=(0,0,1))
light('Recorte azul',(-4,3,6),(.24,.48,1),650,5,target=(0,0,1.5))
light('Preenchimento',(5,-2,4),(.5,.7,1),220,5,target=(0,0,1))
scene=bpy.context.scene
scene.world.color=(.045,.055,.08)
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.055,.085,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.32
scene.render.engine='CYCLES'
scene.cycles.device='CPU'
scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.cycles.max_bounces=5
scene.render.resolution_x=1400
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
scene.view_settings.exposure=-.45
scene.use_nodes=True
nodes=scene.node_tree.nodes
nodes.clear()
rl=nodes.new('CompositorNodeRLayers')
glare=nodes.new('CompositorNodeGlare');glare.glare_type='FOG_GLOW';glare.quality='HIGH';glare.threshold=2
comp=nodes.new('CompositorNodeComposite')
scene.node_tree.links.new(rl.outputs['Image'],glare.inputs['Image'])
scene.node_tree.links.new(glare.outputs['Image'],comp.inputs[0])
bpy.ops.object.camera_add(location=(8,-13,10))
camera=bpy.context.object
camera.name='Câmera — diorama 3D'
camera.data.type='ORTHO'
def shot(loc,target,scale,path):
    camera.location=loc
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=scale
    scene.render.filepath=str(OUT/path)
    bpy.ops.render.render(write_still=True)
scene.camera=camera
camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=11.6
scene['estudo']='Estudo original independente; não aplicado ao KIKIU. Modelagem procedural no Blender, sem imagegen.'
scene['autoria']='Codex do Alisson, 15/10/2026'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'kikiu_estudo.blend'))
shot((8,-13,10),(0,0,1.30),11.6,'diorama.png')
shot((5,-10,5),(0,-.7,1.65),5.4,'heroi_detalhe.png')
# Restaura a visão geral como câmera inicial do arquivo editável.
camera.location=(8,-13,10)
camera.rotation_euler=(Vector((0,0,1.30))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=11.6
scene.render.filepath=str(OUT/'diorama.png')
scene.render.resolution_x=1400
scene.render.resolution_y=1100
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'kikiu_estudo.blend'))
print('ESTUDO_BLENDER_CONCLUIDO',len(bpy.data.objects),'objetos',flush=True)
