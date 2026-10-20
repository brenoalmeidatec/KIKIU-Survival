# Especiais Q por herói — fontes da #349

Arte própria gerada no Codex com imagegen, em 20/10/2026. Entrega de imagens-fonte; recorte, redução, limpeza do alfa e ligação no jogo ficam com o Claude do Alisson.

## Grade e identificação

Cada PNG é uma folha **1 × 1**: uma única célula ocupando a imagem inteira, com um único ícone ou busto. Sem texto ou grade desenhados.

| Arquivo | Célula | Fonte | Conteúdo |
|---|---|---|---|
| `hazaki.png` | linha 1, coluna 1 | 1254 × 1254, RGBA | Hazaki — Corte Relâmpago (`investida`): katana, avanço ciano e corte cruzado. |
| `nicao.png` | linha 1, coluna 1 | 1254 × 1254, RGBA | Nicão — Terremoto (`terremoto`): marreta, impacto laranja e onda no chão. |
| `lucas.png` | linha 1, coluna 1 | 1254 × 1254, RGBA | Lucas — Tempestade de Adagas (`chuva`): cinco adagas em espiral violeta. Quantidade ilustrativa, não regra de dano. |

## Integração pelo Claude

- Referência de estilo: `docs/imagens/referencia_2_5d.webp`; pixel art dark fantasy, sombras frias e luz quente pontual.
- As fontes ampliadas foram mantidas intactas. Há resíduos quase transparentes (alfa de 1 a 8) nas bordas produzidos pelo gerador; limpar na etapa de recorte. O conteúdo visível está inteiro e separado das bordas.
- Não usar a caixa de todos os pixels com alfa > 0 para recortar automaticamente: os resíduos podem ocupar a tela inteira.
- Validar a leitura no tamanho final, preservar a silhueta e usar filtro adequado ao pipeline pixel art do projeto. A leitura final ainda não foi conferida dentro do jogo.
- Nenhum arquivo de código, dado de habilidade, teste ou asset já integrado foi alterado.
- Destino esperado: ícones de carta de 32 × 32 e variante de 16 × 16 conforme o pipeline atual. Os PNGs entregues são fontes de 1254 × 1254, não os recortes finais nesses tamanhos.
- Identidades consultadas no PR #351, commit `6cc550db8c11c61d870a7681da4cd80cc20ba1b6`. Não substituir o Q dos três heróis pelo mesmo ícone genérico.
