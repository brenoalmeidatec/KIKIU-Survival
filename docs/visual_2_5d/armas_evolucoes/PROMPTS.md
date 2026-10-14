# Folhas das armas antigas e evoluções

Arte própria gerada no Codex do Alisson com a ferramenta imagegen embutida, em 14/10/2026. Sem material de terceiros. As três fontes PNG estão no diretório do gerador. Abaixo está a especificação normalizada dos prompts; os prompts de geração expandiram os detalhes de materiais e silhuetas descritos aqui.

## Direção comum

Pixel art 2.5D top-down dark fantasy, câmera superior em três quartos, pixels em degraus e volumes sombreados em grupos definidos. Silhueta legível após redução a 16–54 px. Sem texto, grade, rótulos, moldura, marca-d'água ou cenário. Objetos completos e separados; partículas próximas ao objeto. Evoluções preservam a arma base, com material e energia reforçados. Nada tocando a borda. Não é imagem promocional.

## Projéteis — fundo branco

Uma folha com exatamente 11 objetos em linhas 4/4/3; projéteis apontando à direita, rastro à esquerda. Aço escuro com contorno claro, luz superior esquerda. Ordem:

1. Lâmina curva básica de aço prateado, cabo de couro vermelho.
2. Mesma lâmina evoluída, fio dourado e fita estreita de brasas.
3. Projétil de pata de urso solar, garras e rastro âmbar.
4. Flecha sombria evoluída, ponta roxa dupla e contorno prateado.
5. Bola pesada de ferro/chumbo rachado com cauda de fogo.
6. Pedra vulcânica evoluída, rocha escura e fissuras de lava.
7. Cometa duplo de gelo, dois núcleos cristalinos conectados ao mesmo rastro.
8. Disco bumerangue de ferro reforçado, três lâminas e esteira de meteoro.
9. Cometa negro evoluído, fogo violeta e borda vermelho/laranja.
10. Lança da tempestade primordial, gelo azul com estrela violeta e filamentos elétricos âmbar.
11. Meteoro do juízo final, rocha de lava com fogo laranja e raios violetas.

## Aliados — fundo branco

Uma folha com exatamente sete figuras em linhas 3/2/2, corpos inteiros e pés na base. Sem sombra no fundo. Ordem:

1. Corvo básico preto voando, asas abertas e penas cinza-prata.
2. Mesmo corvo evoluído com pontas das asas ciano e raios dourados.
3. Filhote de dragão vermelho evoluído com longa cauda de serpente flamejante.
4. Lobo espectral azul correndo, juba prateada e cauda fantasma semelhante à raposa.
5. Guerreiro esqueleto evoluído, capuz verde-oliva, armadura musgosa, tecido vermelho, espada de ferro e aura fantasma verde.
6. Colosso de pedra, ombros largos e punhos grandes, musgo/flores vermelhas e fissuras âmbar.
7. Guardião lobo de almas, ombros de urso, cauda fluida e manto espectral violeta, anatomia clara de lobo.

## Áreas — fundo preto aditivo

Uma folha com exatamente 12 efeitos em três linhas de quatro; sem personagens. Anéis elípticos com centro vazio e névoas com fumaça que sobe, não poças. Brilho restrito às bordas, sem preencher a área inteira. Ordem:

1. Aura básica de fogo, elipse baixa de chamas laranja.
2. Raio básico horizontal ciano, núcleo branco e poucos ramos.
3. Runa básica violeta, losango geométrico dentro de elipse, sem letras.
4. Círculo rúnico evoluído, mesmo losango e três sigilos satélites.
5. Ventania glacial, meia-lua ciano-esverdeada aberta à direita, pequenos cristais na borda.
6. Nevasca congelante, névoa azul volumosa com cristais e flocos.
7. Cinzas ácidas, fumaça carvão, brasas laranja e gotas verde-lima.
8. Estrondo, duas elipses finas de ouro claro com faíscas vermelhas.
9. Terra partida, pedras ocre em anel quebrado com fissuras laranja.
10. Peste negra, fumaça violeta com névoa e gotas verde-lima.
11. Juramento sagrado, anel branco/dourado de espinhos e chamas espirituais violetas.
12. Furacão glacial, ciclone baixo de cristais azul-ciano com olho escuro vazio.

## Recorte e consumo

`python jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py armas` recorta, reduz com BOX, quantiza sem dither e gera normais para as folhas claras. A folha de aliados usa componentes completos sem fundir caixas sobrepostas; as fontes anteriores preservam o agrupamento padrão. Os 69 PNG antigos permaneceram byte a byte iguais.

`armas.gd` usa os IDs existentes apenas no desenho; `armas_novas.gd` já resolve as evoluções pelo índice. Raio preserva as três linhas e acrescenta um stamp de arte; Ventania lê o estado evoluído existente. Nenhum pool, dano, alvo, colisão, recarga ou movimento foi alterado. A aura mantém o shader existente com detalhe de arte de baixa intensidade.

Os dez prints antes/depois nesta pasta são do viewport Godot 960x540, perfil Médio, em cinco cenários reproduzíveis. Não são capturas da área de trabalho. A prancha completa está em `jogos/hordas/prints/v2_armas_sprites.png`.
