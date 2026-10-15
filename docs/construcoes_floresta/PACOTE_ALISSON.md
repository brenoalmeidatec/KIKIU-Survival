# Pacote de construções da floresta (para o Alisson)

**Status:** rascunho para o Breno revisar. Ainda não foi enviado ao Alisson. Só vai depois que o Breno disser "manda".

Este pacote tem 17 construções. Cada uma tem uma ficha com o que é, os números, o balanceamento, a nota de desempenho e o prompt de arte para o GPT Astra. A lista de balanceamento está em `BALANCEAMENTO.md`.

## Sugestão para o primeiro mapa médio (7 construções)

As 7 entram no mapa médio primeiro, nesta ordem de rota:

| Ordem na rota | Construção | Minuto | Por quê entra agora |
|---|---|---|---|
| 1 | Cabana do Lenhador (`cabana_lenhador`) | 1 a 3 | Dá a primeira carta cedo, com custo de vida e 2 lobos |
| 2 | Árvore Anciã Oca (`arvore_ancia`) | 1 a 5 | Sem carta e sem custo de horda: ensina o jogador a guardar almas |
| 3 | Fogueira de Acampamento (`fogueira_acampamento`) | 2 a 6 | Buff de dano com custo de 4 s parado e anel de 6 monstros |
| 4 | Totem de Madeira (`totem_madeira`) | 2 a 3 | Antes do mini-chefe 1 (cavaleiro rubro, 3 min): XP em troca de vida dos monstros |
| 5 | Armadilha de Troncos (`armadilha_troncos`) | 2 a 7 | No corredor, sem carta: dano de corredor |
| 6 | Poço Antigo (`poco_antigo`) | 3 a 8 | Carta única, com custo de barra de XP e chance de espectro |
| 7 | Torre de Vigia (`torre_vigia`) | 4 a 9 | Informação antes do mini-chefe 2 (aranha, 6 min) |

Valor de cartas do primeiro mapa: 1,8 (cabana) + 0,8 (poço) = 2,6, abaixo de um baú (3). Ver `BALANCEAMENTO.md`.

## Próximas ondas (não entram no primeiro mapa)

- **Onda 2:** `toca_urso`, `ninho_aranhas`, `ruinas_runas`, `colmeia`, `represa_riacho`.
- **Onda 3 (depende de código e arte novos):** `acampamento_goblins` (precisa de goblin), `espantalho_guarda` (precisa de alvo de desvio).
- **Integrar, não criar (decisão pendente do Breno):** mercador ambulante (vira o mercador existente com 2 cartas), altar amaldiçoado (vira opção do santuário), ponte quebrada (vira o atalho da alavanca).

## Prompt-base de estilo (cole antes de cada prompt)

> Pixel art for a 2.5D top-down dark forest survival game, 960x540 view. Clean hard pixels, no anti-aliasing, no gradients outside the palette, lit from the upper left, soft colored glow allowed as a separate light layer. Muted greens, browns and moonlit blue-grey, with warm orange only for fire and lanterns. Transparent background. No text, no labels, no borders, no ground shadow. Each sprite sheet is one horizontal row of equal frames with the exact size given.

## Como exportar e onde salvar

1. Gere a imagem com o tamanho exato do sprite sheet da ficha (largura = quadro x quadros, altura = quadro).
2. Exporte em PNG com fundo transparente, sem redimensionar. Se o gerador mudar o tamanho, recorte ou reduza para o tamanho exato, sem suavizar.
3. Salve como `<id>.png` (o id está no título de cada ficha) na pasta `jogos/hordas/projeto/assets/v2/construcoes/`. Se a pasta não existir, crie junto com o arquivo.
4. Não mexa no código: o Claude do projeto liga os sprites às construções depois que você entregar.

## Lista das 17 fichas (com link para o prompt de arte)

| Construção | Ficha | Tamanho do sprite principal | Animação |
|---|---|---|---|
| Cabana do Lenhador | [cabana_lenhador.md](cabana_lenhador.md) | 96 x 64 px | fumaça, 6 quadros de 16 px |
| Fogueira de Acampamento | [fogueira_acampamento.md](fogueira_acampamento.md) | 48 x 40 px (2 quadros) | chama, 6 quadros de 16 x 24 px |
| Poço Antigo | [poco_antigo.md](poco_antigo.md) | 40 x 40 px (2 quadros) | água, 4 quadros de 40 x 16 px |
| Mercador Ambulante | [mercador_ambulante.md](mercador_ambulante.md) | sem arte (integrado) | nenhuma |
| Torre de Vigia | [torre_vigia.md](torre_vigia.md) | 32 x 96 px | sino, 4 quadros de 8 px |
| Totem de Madeira | [totem_madeira.md](totem_madeira.md) | 40 x 64 px (2 quadros) | brilho, 4 quadros de 16 px |
| Armadilha de Troncos | [armadilha_troncos.md](armadilha_troncos.md) | 48 x 32 px (2 quadros) | queda, 4 quadros de 48 x 16 px |
| Toca do Urso | [toca_urso.md](toca_urso.md) | 80 x 56 px (2 quadros) | respiração, 4 quadros de 32 px |
| Ninho de Aranhas | [ninho_aranhas.md](ninho_aranhas.md) | 48 x 48 px (2 quadros) | teia, 4 quadros de 48 x 16 px |
| Árvore Anciã Oca | [arvore_ancia.md](arvore_ancia.md) | 64 x 96 px (2 quadros) | brilho, 4 quadros de 16 px |
| Ruínas com Runas | [ruinas_runas.md](ruinas_runas.md) | 96 x 80 px (2 quadros) | runas, 4 quadros de 24 px |
| Altar Amaldiçoado | [altar_amaldicoado.md](altar_amaldicoado.md) | sem arte (integrado) | chama, 4 quadros de 16 px |
| Ponte Quebrada | [ponte_quebrada.md](ponte_quebrada.md) | 96 x 48 px (2 quadros) | tábuas, 4 quadros de 96 x 12 px |
| Represa do Riacho | [represa_riacho.md](represa_riacho.md) | 96 x 64 px (2 quadros) | água, 4 quadros de 96 x 16 px |
| Acampamento de Goblins | [acampamento_goblins.md](acampamento_goblins.md) | 48 x 48 px (1 quadro) | fogueira, 4 quadros de 16 px (goblin: ficha à parte) |
| Espantalho de Guarda | [espantalho_guarda.md](espantalho_guarda.md) | 32 x 64 px (2 quadros) | palha, 4 quadros de 16 px |
| Colmeia | [colmeia.md](colmeia.md) | 40 x 40 px (2 quadros) | nuvem, 4 quadros de 48 px |

## Pontos para o Breno decidir antes de mandar

1. Mercador ambulante: integrar ao mercador existente (recomendado) ou criar NPC novo?
2. Altar amaldiçoado: opção do santuário (recomendado) ou objeto separado?
3. Ponte quebrada: atalho da alavanca (recomendado) ou ponte separada?
4. Acampamento de goblins: aprovar a arte de goblin como inimigo novo?
5. Espantalho de guarda: aprovar o código de alvo de desvio?
6. Medir almas por minuto antes de fechar a conta de almas (não há medição hoje).
