# Molduras do HUD — componentes separados

Arte própria gerada no Codex,15/10/2026, seguindo pedra e ferro escuros do santuário e referência2.5D. São três folhas-fonte sobre fundo branco, sem texto. Cada PNG mede **1254×1254**, grade **3×3**, células **418×418**. Não há recorte ou integração nesta entrega.

| Folha | Uso |
|---|---|
| retrato.png | Moldura do retrato do herói, cantos ornamentados discretos |
| barras.png | Moldura neutra compartilhada pelas barras de vida e fôlego |
| habilidades.png | Moldura neutra compartilhada pelos slots E e Q |

Todas seguem a mesma grade, da esquerda para a direita e de cima para baixo:

| Célula | Linha | Coluna | Peça |
|---|---|---|---|
| 1 | 1 | 1 | Canto superior esquerdo |
| 2 | 1 | 2 | Borda superior |
| 3 | 1 | 3 | Canto superior direito |
| 4 | 2 | 1 | Borda esquerda |
| 5 | 2 | 2 | Preenchimento escuro opcional do centro |
| 6 | 2 | 3 | Borda direita |
| 7 | 3 | 1 | Canto inferior esquerdo |
| 8 | 3 | 2 | Borda inferior |
| 9 | 3 | 3 | Canto inferior direito |

Coordenadas de cada célula: x=(coluna−1)×418, y=(linha−1)×418. As peças ficam soltas dentro das células, com branco ao redor. A célula não é o retângulo final da peça: recortar também a margem branca. O tamanho final de HUD não foi especificado; não confundir418px da célula-fonte com espessura de borda em jogo.

**Montagem pelo Claude:** remover o branco e reduzir/quantizar na escala do HUD. Ajustar espessuras e conexões dos cantos com as faixas; usar o trecho central das bordas e descartar os pequenos arremates das pontas para repetição. A geração não garante emenda perfeita pixel a pixel. Testar montagem de9-slice antes de importar: retrato quadrado, barra longa e slot quadrado. Centro opcional deve ficar atrás do retrato/ícone/barra, nunca cobri-los. Cantos preservam escala, faixas esticam/repetem em um eixo, centro em dois.

Vida usa Paleta.VIDA#b9212d e fôlego Paleta.FOLEGO#4aa3d9 no preenchimento desenhado pelo jogo; não pintei essas cores na moldura para evitar ambiguidade com XP. E/Q usam o mesmo conjunto visual, sem letra ou habilidade embutida. Estados disponível/recarga/desabilitado continuam a cargo do código existente. Material frio e pequenos reflexos quentes são decoração, não estado.

Para o Claude do Alisson: só fontes; recorte, adequação da paleta,9-slice, código, testes e integração são seus. Não houve alteração de layout ou de arquivos do projeto. Prompts e revisão do retrato em PROMPTS.md.
