# Fusões — quatro fontes de arte

Especificação: docs/armas_v2/FUSOES_ARTE_ALISSON.md. Arte própria gerada no Codex, 15/10/2026. Arquivos RGBA com transparência real. Cada arquivo tem grade **1×1**, uma única peça central e margem externa; não é atlas nem animação.

| Arquivo / célula única | Fonte real | Alvo após integração | Conteúdo |
|---|---|---|---|
| moldura.png | 2172×724 | 600×200; borda 12 px | Painel violeta escuro, filete duplo dourado e cantos ornamentados; sem palavra FUSÃO |
| halo.png | 1254×1254 | 48×48 | Núcleo branco, anel e quatro brilhos periféricos; base tingível |
| ventania.png | 1774×887 | 64×32 | Onda ciano com cauda dupla à esquerda e três faixas internas |
| icone.png | 1254×1254 | 16×16, mostrado em 2× | Dois caminhos dourados unidos em uma ponta para cima |

As dimensões da especificação são os alvos de uso, não as dimensões produzidas pelo gerador. Fontes originais sem recorte, redução ou quantização. O corpo da moldura não ocupa o canvas inteiro: não reduzir o canvas diretamente para600×200. Recortar e montar pelo9-slice, preservando cantos, ajustando o centro e a margem final de12px. Conferir encaixe e espessura na integração. O halo e a onda têm alfa parcial; evitar remoção por cor que destrua os brilhos claros. O ícone precisa de redução e conferência real em16×16: o contorno final de1px ainda é responsabilidade do pipeline.

**Cor:** a especificação desta entrega pede ouro #f1b10e; v2/paleta.gd usa FUSAO #ff73d9 e OURO #ffdb6b. A imagem segue o documento específico das fusões. Nenhuma constante foi alterada: harmonização semântica/tint e validação de leitura ficam com o Claude.

Para o Claude do Alisson: recortar, adequar à paleta/tamanhos, montar a moldura, aplicar tint ao halo e integrar. Estas fontes não alteram regras, áudio ou cartas. Quantização e inspeção em tamanho de jogo ainda pendentes. Prompts exatos em PROMPTS.md.
