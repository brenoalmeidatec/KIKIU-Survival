"""Modelagem + materiais em bandas + render nativo baixo + escala nearest no Blender."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parent
source = (OUT.parent / 'criar_estudo.py').read_text(encoding='utf-8')
source = source.split('# Luz de estúdio suave')[0]
source = source.replace('# Herói original modelado', 'hero_before = set(bpy.data.objects)\n# Herói original modelado')
source = source.replace('# Portal de pedra e magia', 'hero_objects = set(bpy.data.objects) - hero_before\n# Portal de pedra e magia')
# Recria a mesma geometria de estudo, sem carregar recursos do jogo.
exec(compile(source, str(OUT.parent / 'criar_estudo.py'), 'exec'))
OUT = Path(__file__).resolve().parent

def linear(v):
    return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4

def rgb(c):
    return tuple(linear(max(0,min(1,v))) for v in c)+(1,)

def toon_color(name, old):
    if 'Basalto' in name: return (.37, .42, .47)
    if 'Terra' in name: return (.14, .19, .17)
    if 'Corte' in name: return (.10, .14, .20)
    if 'Folhagem' in name: return (.19, .33, .23)
    if 'Musgo' in name: return (.35, .42, .16)
    if 'Casca' in name: return (.25, .18, .17)
    if 'vermelho queimado' in name: return (.73, .15, .20)
    if 'Vermelho iluminado' in name: return (.91, .24, .19)
    if 'Dobras' in name: return (.44, .10, .20)
    if 'Carvão' in name or 'carvão' in name: return (.18, .24, .34)
    if 'Cabelo' in name: return (.12, .16, .24)
    if 'Couro' in name: return (.34, .21, .17)
    if 'Pele' in name: return (.73, .42, .25)
    if 'Rosto' in name: return (.91, .59, .35)
    if 'Aço' in name: return (.37, .57, .66)
    if 'Fio polido' in name: return (.75, .90, .95)
    if 'Latão' in name: return (.70, .47, .21)
    if 'Olho' in name: return (.025, .035, .06)
    return tuple(old[:3])

# Quatro degraus por material, com sombras frias, sem gradiente de iluminação.
for material in list(bpy.data.materials):
    if not material.use_nodes: continue
    old = tuple(material.diffuse_color)
    material.node_tree.nodes.clear()
    n = material.node_tree.nodes
    links = material.node_tree.links
    output = n.new('ShaderNodeOutputMaterial')
    emission = n.new('ShaderNodeEmission')
    links.new(emission.outputs[0], output.inputs['Surface'])
    if material.name in ['Magia violeta','Reflexo frio','Chama âmbar','Núcleo da chama']:
        colors = {'Magia violeta':(.72,.32,1), 'Reflexo frio':(.30,.84,1),
                  'Chama âmbar':(1,.42,.09), 'Núcleo da chama':(1,.90,.47)}
        emission.inputs['Color'].default_value = rgb(colors[material.name])
        emission.inputs['Strength'].default_value = 1
        continue
    base = toon_color(material.name, old)
    geo = n.new('ShaderNodeNewGeometry')
    dot = n.new('ShaderNodeVectorMath'); dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = Vector((-.5,-.7,.8)).normalized()
    links.new(geo.outputs['Normal'],dot.inputs[0])
    remap = n.new('ShaderNodeMath'); remap.operation='MULTIPLY_ADD'
    remap.inputs[1].default_value=.48;remap.inputs[2].default_value=.5
    links.new(dot.outputs['Value'],remap.inputs[0])
    ao = n.new('ShaderNodeAmbientOcclusion');ao.samples=32
    ao.inputs['Distance'].default_value=.22
    mul = n.new('ShaderNodeMath');mul.operation='MULTIPLY'
    links.new(remap.outputs[0],mul.inputs[0]);links.new(ao.outputs['AO'],mul.inputs[1])
    ramp = n.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='CONSTANT'
    dark=tuple(v*.37+t for v,t in zip(base,(.015,.023,.047)))
    shade=tuple(v*.65+t for v,t in zip(base,(.015,.018,.035)))
    hi=tuple(min(1,v*1.15+t) for v,t in zip(base,(.08,.065,.025)))
    for i,(pos,color) in enumerate([(0,dark),(.30,shade),(.55,base),(.79,hi)]):
        el=ramp.color_ramp.elements[i] if i<2 else ramp.color_ramp.elements.new(pos)
        el.position=pos;el.color=rgb(color)
    links.new(mul.outputs[0],ramp.inputs[0]);links.new(ramp.outputs['Color'],emission.inputs['Color'])
    material.diffuse_color=rgb(base)

# Casca invertida: contorno geométrico do herói, visto somente pelo verso.
outline=bpy.data.materials.new('Contorno azul quase preto')
outline.use_nodes=True
n=outline.node_tree.nodes;n.clear();links=outline.node_tree.links
out=n.new('ShaderNodeOutputMaterial');mix=n.new('ShaderNodeMixShader')
geo=n.new('ShaderNodeNewGeometry');transparent=n.new('ShaderNodeBsdfTransparent')
black=n.new('ShaderNodeEmission');black.inputs['Color'].default_value=rgb((.035,.05,.085))
links.new(geo.outputs['Backfacing'],mix.inputs[0])
links.new(transparent.outputs[0],mix.inputs[1]);links.new(black.outputs[0],mix.inputs[2])
links.new(mix.outputs[0],out.inputs['Surface'])
outline_objects=[]
for original in list(hero_objects):
    if original.type!='MESH' or len(original.data.polygons)<6 or original.name.startswith(('Olho','Sobrancelha','Boca')): continue
    obj=original.copy();obj.data=original.data.copy();obj.name='Contorno — '+original.name
    bpy.context.collection.objects.link(obj)
    obj.data.materials.clear();obj.data.materials.append(outline)
    # Uma casca externa, sem a superfície interna coplanar de Solidify.
    for vertex in obj.data.vertices:
        vertex.co += vertex.normal*.035
    obj.data.update()
    obj.visible_shadow=False
    outline_objects.append(obj)
hero_objects.update(outline_objects)

scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.device='CPU'
scene.cycles.samples=1;scene.cycles.use_denoising=False
scene.cycles.pixel_filter_type='BOX';scene.cycles.filter_width=.01
scene.cycles.max_bounces=3;scene.cycles.transparent_max_bounces=16
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.render.dither_intensity=0
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
scene.view_settings.exposure=0;scene.view_settings.gamma=1
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=rgb((.045,.07,.105))
scene.world.node_tree.nodes['Background'].inputs[1].default_value=1
bpy.ops.object.camera_add(location=(8,-13,10))
camera=bpy.context.object;camera.name='Câmera pixel art'
camera.data.type='ORTHO';scene.camera=camera
scene.use_nodes=True;n=scene.node_tree.nodes;n.clear();links=scene.node_tree.links
rl=n.new('CompositorNodeRLayers')
scale=n.new('CompositorNodeScale');scale.space='RELATIVE'
scale.interpolation='NEAREST'
links.new(rl.outputs['Image'],scale.inputs['Image'])
comp=n.new('CompositorNodeComposite');links.new(rl.outputs['Image'],comp.inputs[0])
native=n.new('CompositorNodeOutputFile');native.base_path=str(OUT)
native.format.file_format='PNG';native.format.color_mode='RGBA'
links.new(rl.outputs['Image'],native.inputs[0])
enlarged=n.new('CompositorNodeOutputFile');enlarged.base_path=str(OUT)
enlarged.format.file_format='PNG';enlarged.format.color_mode='RGBA'
links.new(scale.outputs[0],enlarged.inputs[0])

def shot(loc,target,ortho,w,h,factor,name):
    camera.location=loc
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=ortho
    scene.render.resolution_x=w;scene.render.resolution_y=h;scene.render.resolution_percentage=100
    scale.inputs['X'].default_value=factor;scale.inputs['Y'].default_value=factor
    native.file_slots[0].path=name+'_nativo_'
    enlarged.file_slots[0].path=name+'_ampliado_'
    scene.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render()
    src=OUT/(name+'_nativo_0001.png')
    if src.exists(): src.replace(OUT/(name+'_nativo.png'))
    src=OUT/(name+'_ampliado_0001.png')
    if src.exists(): src.replace(OUT/(name+'.png'))

scene['estudo']='Pixel art renderizada no Blender; quatro tons por material, contorno geométrico, resolução nativa baixa, nearest. Não aplicado ao jogo.'
scene['autoria']='Codex do Alisson, 15/10/2026'
shot((8,-13,10),(0,0,1.30),11.6,320,252,4,'diorama_pixel')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'kikiu_pixel_art.blend'))

for obj in bpy.data.objects:
    if obj not in hero_objects and obj.type!='CAMERA':obj.hide_render=True
scene.render.film_transparent=True
shot((4,-9,4.8),(.3,-.55,1.77),4.7,128,128,6,'heroi_pixel')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'heroi_pixel_art.blend'))
print('PIXEL_ART_BLENDER_CONCLUIDA',flush=True)
