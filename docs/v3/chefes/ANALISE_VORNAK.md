# Vornak: análise do modelo e das animações (18/10, noite)

Feita a partir das folhas em 8 direções (128 px por quadro) e do comparativo com a folha dos três chefes. Pontos por impacto no jogo, do mais importante para o menos.

## 1. Legibilidade em 1x (o mais importante)
- **Figura pequena no quadro:** com o enquadramento que cabe o ataque 4 e a morte, o chefe ocupa cerca de 50 a 60 px de 128. Em 1x ele lê como um arbusto, e o rosto e os cipós somem.
- **Detalhe verde perdido:** os cipós e os olhos são pequenos demais para aparecer em 1x. O que se vê é uma massa escura.
- **Contraste:** marrom-escuro sobre fundo claro. Em 1x a silhueta se confunde com o chão.

## 2. Silhueta e postura
- A postura ainda é mais baixa e curvada que a da folha; a arte é mais ereta e alta.
- A cabeça grande e a galhada em coroa encostam no topo do quadro quando o chefe ergue os braços.

## 3. Consistência de tamanho
- O tamanho é o mesmo entre os clipes (câmera única). Isso está certo; o custo é o ponto 1.

## 4. Movimento
- Pés não ficam plantados: o chefe balança e a base se desloca nos ciclos de andar e correr. Não corrigido.
- Timing dos ataques: os quadros de impacto estão com 1 quadro; o pedido era segurar 1 a 2 quadros a mais no golpe. Não corrigido.
- Movimento secundário com atraso: aplicado só no idle, ataque 1 e grito.

## 5. Pixel art
- Contorno escuro de 1 px e paleta de 24 cores: está dentro do pedido.
- Pixels soltos: aparecem nas bordas das folhas e dos cipós finos. Não corrigido.

## O que foi corrigido nesta rodada
- Enquadramento único que cabe o ataque 4 e a morte nas 8 direções (commit 91027baf).

## Próximo passo sugerido (decisão do Breno)
- **Quadro de 192 px** em vez de 128, com a figura maior dentro do quadro. Custa mais memória no jogo e re-render de todos os clipes.
- Ou manter 128 px e aceitar a figura menor, cortando o ataque 4 e a morte com menos folga.
