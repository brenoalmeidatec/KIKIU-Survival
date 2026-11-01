# Mecha do LightWolf (folha final por script, LW-7)

Robô blindado azul com orelhas de lobo, visor ciano, pods de mísseis nos ombros e canhões nos antebraços, feito por script a partir da referência `notas/artes_chatgpt/A15_lightwolf_mecha_ref.png` (três vistas). As poses do mecha não têm arma de mão: o osso `marreta` permanece por compatibilidade do rig, sem geometria.

O render nativo usa **128×192 px por quadro**, 38 colunas por 8 direções, PPU 24,5 e escala do modelo 1,03. A âncora é `pe_y=120`: a margem inferior de render permite o rolamento sem deslocar os pés. A região do retrato `[27, 42, 74, 84]` é provisória e deve ser conferida na HUD. Os nomes dos arquivos, animações e a estrutura do JSON seguem o contrato usado pelo jogo.

O `gerar.py` usa luz de recorte fria de trás e de cima, além de contraste entre as áreas claras, azuis e as juntas escuras. O render não usa casca de contorno: `montar_folha.py` acrescenta um contorno escuro **externo de 1 px por quadro** no albedo, sem amostrar quadros vizinhos. A normal recebe a mesma máscara alfa e normal neutra `(128, 128, 255)` no contorno. Não há redimensionamento ou recorte posterior dos quadros nativos.

```text
blender -b -t 6 -P gerar.py   # quadros/<anim>/... e lightwolf_mecha_rig.blend
python montar_folha.py        # lightwolf_mecha_final_{albedo,normal}.png, .json e prévia x3
python medir.py --todos       # todas as animações, todas as direções e os quatro lados
python medir.py rolamento     # uma animação específica
```

`medir.py` inclui o contorno na silhueta medida; informa as margens esquerda, direita, superior e inferior e termina com erro se algum quadro estiver vazio, ausente ou tocar uma borda. Execute a medição depois de cada render completo. Em seguida copie `lightwolf_mecha_final_albedo.png`, `_normal.png` e `.json` para `projeto/prototipos/cara_nova/sprites/` como `lightwolf_mecha_albedo.png`, `_normal.png` e `.json`.

As poses incluem parado, andar, combo de dois tiros (um para cada canhão, com clarão ciano no quadro de disparo), escudo, dano, rolamento e morte. O clarão é geometria emissiva controlada pela animação de combo. A inspeção do retrato, das animações e da leitura em jogo deve ser feita após a montagem e registrada no PR.
