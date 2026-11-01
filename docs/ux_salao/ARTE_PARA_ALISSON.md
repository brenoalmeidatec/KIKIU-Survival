# Arte que falta para o salão (pedido ao Alisson)

Nada de arte de terceiros neste PR. A sala usa **formas desenhadas em código** como marcador, e o herói é o sprite que já existe
(`prototipos/cara_nova/sprites/hazaki_samurai`). Os arquivos de arte do Alisson não foram alterados. Quando estas peças
ficarem prontas, o `v2/salao.gd` troca o desenho pela textura (ver "Onde entra" em cada peça).

Tamanhos sugeridos na tela de 960 x 540 px, em pixel art com a mesma escala do herói (32 x 44 px no quadro, desenhado a 2x).
Mantenha as cores do tema da v2 (pedra fria, dourado `#FFDB6B` nos destaques, roxo `#CCA8FF` para almas).

| # | Peça | Tamanho sugerido | Onde entra hoje (marcador) | Prompt para o GPT Astra |
|---|---|---|---|---|
| 1 | Estátuas (estrutura de atributos) | 72 x 70 px, base incluída | `salao.gd`, `_desenhar_estrutura`, bloco de pedra com topo | "Pixel art, 72x70 px, fundo transparente, visão 3/4 de cima. Um pedestal de pedra cinza-azulada com a estátua de um guerreiro de pé, em repouso, com uma luz dourada fraca na base. Estilo de jogo de ação 2.5D escuro, contorno preto de 1 px, sem texto. Mesma paleta de pedra fria." |
| 2 | Altar (ímã, almas, raridade) | 72 x 70 px | `_desenhar_estrutura` com a cor roxa; brilho em `_pintar_chamas` | "Pixel art, 72x70 px, fundo transparente, visão 3/4 de cima. Um altar baixo de pedra com um cristal roxo flutuando em cima, pequenas partículas roxas saindo. Estilo de jogo de ação 2.5D escuro, contorno preto de 1 px, sem texto. Paleta roxa #CCA8FF para o cristal." |
| 3 | Códice (estante com livro aberto) | 72 x 70 px | `_desenhar_estrutura` com a cor marrom | "Pixel art, 72x70 px, fundo transparente, visão 3/4 de cima. Um atril de madeira escura com um livro grande aberto, páginas claras e uma fita dourada marcando a página. Estilo de jogo de ação 2.5D escuro, contorno preto de 1 px, sem texto." |
| 4 | Portal da Floresta | 76 x 100 px (arco) | `_desenhar_portal`, cor verde | "Pixel art, 76x100 px, fundo transparente. Um arco de pedra musgosa com um buraco de luz verde-floresta no centro, folhas caindo perto da base. Estilo 2.5D escuro, contorno preto de 1 px, sem texto." |
| 5 | Portal do Laboratório | 76 x 100 px (arco) | `_desenhar_portal`, cor azul-petróleo | "Pixel art, 76x100 px, fundo transparente. Um arco de metal e pedra com um buraco de luz azul-petróleo no centro, e um pequeno painel com luzes na lateral. Estilo 2.5D escuro, contorno preto de 1 px, sem texto." |
| 6 | Portal da Cidade | 76 x 100 px (arco) | `_desenhar_portal`, cor laranja | "Pixel art, 76x100 px, fundo transparente. Um arco de tijolo com um buraco de luz laranja no centro, uma placa de rua vazia no topo. Estilo 2.5D escuro, contorno preto de 1 px, sem texto legível." |
| 7 | Portal das Ruínas da Floresta | 76 x 100 px (arco) | `_desenhar_portal`, cor azul-acinzentada | "Pixel art, 76x100 px, fundo transparente. Um arco de pedra quebrada coberto de trepadeira, com um buraco de luz azul-acinzentada no centro. Estilo 2.5D escuro, contorno preto de 1 px, sem texto." |
| 8 | Portal fechado (com cadeado) | 76 x 100 px | `_desenhar_portal` com `COR_TRAVADO` e cadeado desenhado | "Pixel art, 76x100 px, fundo transparente. O mesmo arco de pedra, agora fechado por uma grade de ferro escura e um cadeado grande no centro. Estilo 2.5D escuro, contorno preto de 1 px, sem texto." |
| 9 | Piso e parede do salão (tiles) | piso 32x32, parede 32x32 | `_pintar_cenario` (retângulos e linhas) | "Pixel art, tiles de 32x32 px, repetíveis. Piso de pedra cinza-escura com juntas finas, e uma parede de tijolos de pedra com faixa de rodapé. Estilo 2.5D escuro, sem sombras fortes, sem texto." |
| 10 | Tocha animada (4 quadros) | 20 x 40 px | `_pintar_chamas`, duas tochas | "Pixel art, 4 quadros de 20x40 px em uma folha horizontal, fundo transparente. Uma tocha de ferro com fogo laranja que balança de leve entre os quadros. Estilo 2.5D escuro, sem texto." |

## Observações

- **Retratos dos amigos:** Brendan (rosto do Breno, desde o PER-1), Nicão, Lucas, João, Matheus, Beto, Lukako e Fábio já têm `rosto.png` na pasta deles; o salão e a escolha usam esses. Quem não tiver rosto cai no corpo do herói, mas hoje todos têm.
- **Figura andando:** no salão, o personagem é o samurai (`hazaki_samurai`), porque é o único sprite de herói que a v2 tem hoje. O retrato é o do amigo escolhido. Até os outros heróis terem sprite na v2, a figura andando não muda por personagem.
- **Pontos de atenção:** o chão e a parede são desenhados em código hoje; quando os tiles (peça 9) entrarem, troque o `_pintar_cenario` por um `TileMap` ou por um `TextureRect` repetido, e remova as linhas de perspectiva.
- **Cores:** os tons vêm do tema atual da v2 (`COR_*` em `v2/salao.gd`). Quando a paleta única do PR #217 entrar, as cores estão centralizadas no topo do arquivo para trocar de uma vez.
