# Mecha do LightWolf (folha final por script, LW-7)

Robô blindado azul com orelhas de lobo, visor ciano, pods de mísseis nos ombros e canhões nos antebraços, feito por script a partir da referência `notas/artes_chatgpt/A15_lightwolf_mecha_ref.png` (três vistas). As poses do mecha não têm arma de mão: o osso `marreta` permanece por compatibilidade do rig, sem geometria.

O render nativo usa **128×192 px por quadro**, 44 colunas por 8 direções (as 6 últimas, desde 05/11, são o `andar_tiro`), PPU 24,5 e escala do modelo 1,03. A âncora é `pe_y=120`: a margem inferior de render permite o rolamento sem deslocar os pés. A região do retrato `[27, 42, 74, 84]` é provisória e deve ser conferida na HUD. Os nomes dos arquivos, animações e a estrutura do JSON seguem o contrato usado pelo jogo.

O `gerar.py` usa luz de recorte fria de trás e de cima, além de contraste entre as áreas claras, azuis e as juntas escuras. O render não usa casca de contorno: `montar_folha.py` acrescenta um contorno escuro **externo de 1 px por quadro** no albedo, sem amostrar quadros vizinhos. A normal recebe a mesma máscara alfa e normal neutra `(128, 128, 255)` no contorno. Não há redimensionamento ou recorte posterior dos quadros nativos.

```text
blender -b -t 6 -P gerar.py   # quadros/<anim>/... e lightwolf_mecha_rig.blend
python montar_folha.py        # lightwolf_mecha_final_{albedo,normal}.png, .json e prévia x3
python medir.py --todos       # todas as animações, todas as direções e os quatro lados
python medir.py rolamento     # uma animação específica
```

`medir.py` inclui o contorno na silhueta medida; informa as margens esquerda, direita, superior e inferior e termina com erro se algum quadro estiver vazio, ausente ou tocar uma borda. Execute a medição depois de cada render completo. Em seguida copie `lightwolf_mecha_final_albedo.png`, `_normal.png` e `.json` para `projeto/prototipos/cara_nova/sprites/` como `lightwolf_mecha_albedo.png`, `_normal.png` e `.json`.

O `andar_tiro` (05/11, pedido do Alisson: animação de andar atirando) junta as pernas do `andar`, quadro a quadro e na mesma fase, com os braços na mira do quadro 0 do combo; o giro do quadril é desfeito no torso, então cabeça e canhões não balançam de lado, só sobem e descem com o apoio. Fica nas 6 últimas colunas (38 a 43), sem mexer nas 38 de antes (a remontagem conferida é idêntica pixel a pixel). O `gerar.py` grava em `quadros/<anim>/bocas.json` o centro projetado das bocas por quadro e direção; o `montar_folha.py` confere que esse método reproduz a tabela `bocas_projeteis.canhoes` no combo 0 (até 3 px) e grava em `animacoes.andar_tiro.desvio_boca[quadro][linha][lado]` os px inteiros a somar à boca arredondada da tabela. O jogo (`v2/heroi.gd`, `desvio_boca`) soma esse desvio no clarão de boca e no nascimento da bolinha, para os dois ficarem no cano também andando.

As poses incluem parado, andar, combo de dois tiros (um para cada canhão, com clarão ciano no quadro de disparo), escudo, dano, rolamento e morte. O clarão é geometria emissiva controlada pela animação de combo. A inspeção do retrato, das animações e da leitura em jogo deve ser feita após a montagem e registrada no PR.

O acabamento dos tiros mantém cabeça, cabine e pés estáveis: só o braço que dispara recua. A folha usa `corpo_fixo_ao_atirar` para evitar o deslocamento e a deformação do corpo no ataque; a pose de mira continua entre os tiros. `poses_habilidades.misseis = "parado"` impede que a E simule disparos dos canhões. O modo de reduzir piscadas usa poses sem clarão.

O projétil da E tem imagem procedural própria de 24×9 px (ogiva, corpo, aletas e exaustão), separada da bala básica. A explosão usa oito quadros preparados uma vez e 16 vagas fixas, sem nó por impacto; no perfil Baixo há menos quadros e tamanho menor. Reduzir piscadas mantém fumaça escura fixa com fade, agrupa impactos próximos e descarta apenas o visual quando as vagas protegidas estão cheias. O tiro básico tem um rastro curto, sem halo e faíscas redundantes. Essas mudanças preservam a contagem, a cadência, o alcance, o dano e a sequência de RNG do combate.

`bocas_projeteis` guarda as posições projetadas dos dois canhões e dos dois pods nas oito direções. O centro da imagem e o rastro começam nessas bocas e convergem para a trajetória lógica em até 60 px ou 0,2 s; a sombra continua no chão. Um alvo próximo encurta essa distância até a entrada no seu círculo de colisão, antes do impacto. A previsão usa uma lista visual separada na mesma visita aos monstros; não amplia os candidatos físicos, não muda o dano e não consome RNG. O limite só diminui durante o voo, e o primeiro acerto encerra o deslocamento também em perfuração e ricochete. Reutilizar a vaga restaura o limite padrão. Um alvo que surge já sobreposto ao projétil não oferece voo anterior para antecipação; nesse caso o desenho acompanha o contato imediatamente.

A convergência encurtada é linear. Se a boca já estiver além do contato ou um alvo tardio exigir voltar no desenho, o voo fica oculto até alcançar novamente a última posição aceita; corpo, rastro e sombra usam a mesma decisão. O clarão na arma e o impacto continuam, mesmo sem espaço para um voo visível. A trajetória física e seus instantes de dano permanecem iguais. Esse controle acompanha somente projéteis com bocas projetadas, não modifica estado durante o desenho e reinicia o referencial quando ocorre um ricochete real.
