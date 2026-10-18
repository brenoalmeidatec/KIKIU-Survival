# Chefes da Floresta: ficha técnica visual

Base: folha de referência enviada pelo Breno em 18/10 (Vornak, Nythrax e Maltherion). Tudo aqui é provisório e ajustável; valores de jogo são iniciais.

Estilo comum: modelo 3D low-poly no Blender, câmera isométrica, render leve (Eevee ou Workbench, sem Cycles), depois sprites pixelados em 8 direções com pós-processo pixel art (poucas cores, contorno escuro de 1 px, alinhado pelo chão). Os três chefes são do mesmo universo: madeira, raízes, energia colorida e névoa.

## Vornak, o Devorador de Raízes (mini-chefe 1)

- **Silhueta:** corpo largo e baixo de tronco e raízes, braços grandes que tocam o chão, galhada na cabeça.
- **Cor:** verde-musgo escuro na madeira, verde-neon nas raízes e nos olhos.
- **Escala:** maior que o herói (~39 px), mas o mais baixo dos três.
- **Mecânicas:** enraíza o jogador (imobiliza por alguns segundos); regenera vida ao absorver árvores e raízes próximas; segunda forma mais agressiva e rápida em 40% de vida.
- **Ataques:**
  1. Raízes Corrompidas: surge do chão e prende o jogador (aviso no chão antes).
  2. Golpe de Raízes: ataque em área à frente, com raízes que empurram.
  3. Absorção de Vida: regenera ao se aproximar de árvores mortas (pode ser interrompido).
  4. Segunda Forma: raízes mais longas, combinações e novas áreas perigosas.

## Nythrax, o Lobo do Véu Negro (mini-chefe 2)

- **Silhueta:** lobo grande e magro, em pose de caça; precisa continuar lendo como lobo em todos os quadros.
- **Cor:** sombra escura com energia azul-violeta; olhos e garras brilhantes; partes que se desfazem em névoa.
- **Escala:** maior que o Vornak no corpo, mas mais leve visualmente.
- **Mecânicas:** some na névoa por um tempo; cria ilusões para confundir; fica mais rápido e mais forte conforme a vida diminui (fase de caça abaixo de 35%).
- **Ataques:**
  1. Investida Sombria: pose de preparo, indicador de direção, avanço reto rápido, rastro espectral.
  2. Névoa Ocultante: se desfaz em névoa e reaparece em outro ponto, com sinal visual para antecipar.
  3. Golpe em Arco: salto e garras em área ao redor.
  4. Ilusões Espectrais: cópias temporárias; só o Nythrax real causa dano principal; sem cópias infinitas.

## Maltherion, o Rei do Bosque Profanado (chefe principal)

- **Silhueta:** o maior dos três; galhada enorme como coroa, troncos e raízes como membros; fissuras com energia roxa.
- **Cor:** madeira escura e corrompida, com roxo-violeta intenso que cresce conforme a vida cai.
- **Mecânicas:** invoca criaturas corrompidas (lobos e raízes) com limite; controla o terreno (raízes em pontos fixos, zonas de dano, bloqueio temporário de passagens); fase final libera toda a energia da floresta.
- **Ataques:**
  1. Raízes Gigantes: surgem do chão em pontos marcados, com zona de dano.
  2. Invocação de Criaturas: chama lobos e criaturas corrompidas para lutar ao lado.
  3. Garras Sombrias: golpe de grande alcance em área frontal, animação pesada.
  4. Tempestade de Raízes: raízes em sequência por áreas diferentes do mapa.
  5. Coração da Floresta (fase 3): preparo longo e reconhecível, energia convergindo, áreas de perigo, onda, recuperação para contra-ataque.
- **Fases (números da mensagem do Breno; a folha mostra 70-100, 30-70 e 0-30):**
  - Fase 1, Guardião Corrompido: 100% a 70%.
  - Fase 2, Rei Desperto: 70% a 30%.
  - Fase 3, Coração Profanado: 30% a 0%.
- **Arena viva:** a parte do mapa (áreas, passagens, plataformas) é do Alisson. O chefe só cuida de raízes, zonas de dano e árvores destrutíveis como objetos dele; isso fica para o fim.

## Ordem de trabalho

1. Vornak como protótipo: modelo, rig, ataque de raízes e sistema de raízes.
2. Nythrax reaproveitando vida, dano e estados do Vornak; movimento próprio (investida e névoa).
3. Maltherion com arena viva, invocações e três fases.

## Plano do Vornak em etapas

1. Modelo base no Blender: tronco, raízes e braços em blocos, escala contra o herói de 39 px.
2. Silhueta e cor conferidas com a folha, em câmera isométrica de baixa resolução.
3. Rig simples (ossos de braço, cabeça e raízes) com nomes organizados.
4. Animações: idle, andar, Attack_01 (raízes), Attack_02 (golpe no chão), Hit, Stagger, Death.
5. Prévia no Blender: GIF ampliado 4x e loop tocando no Blender, para o Breno aprovar antes de qualquer coisa ir ao jogo.
6. Código Godot (depois da aprovação do modelo): estados Idle, Telegraph, Attack, Recovery, Stagger e Dead; ataques com aviso, janela, área, dano, recarga e recuperação, em parâmetros ajustáveis.

## Valores iniciais (ajustáveis)

| Chefe | Vida | Aviso antes do golpe | Recarga entre golpes |
|---|---|---|---|
| Vornak | 1100 | 0,8 s | 2,5 s |
| Nythrax | 1600 | 0,5 s (investida) | 2,0 s |
| Maltherion | 9000 | 1,0 s (raízes) / 2,0 s (Coração) | 3,0 s |

A vida do Vornak e do Maltherion vem dos chefes da v1 (1100 e 9000), que o LOGBOOK já chama de chute; a do Nythrax é chute inicial meu. Nada disso foi testado no jogo.
