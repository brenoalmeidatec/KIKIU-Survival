# Retratos dos chefes — fontes da #349

Arte própria gerada no Codex com imagegen, em 20/10/2026. Entrega de imagens-fonte; recorte, redução, limpeza do alfa e ligação no jogo ficam com o Claude do Alisson.

## Grade e identificação

Cada PNG é uma folha **1 × 1**: uma única célula ocupando a imagem inteira, com um único ícone ou busto. Sem texto ou grade desenhados.

| Arquivo | Célula | Fonte | Conteúdo |
|---|---|---|---|
| `cavaleiro_rubro.png` | linha 1, coluna 1 | 1254 × 1254, RGBA | Cavaleiro Rubro (`mini1`): elmo fechado, penacho/capa vermelhos e ombreiras pontudas. |
| `rainha_tecela.png` | linha 1, coluna 1 | 1254 × 1254, RGBA | Rainha Tecelã (`mini2`): aranha de quitina escura, olhos verdes e coroa de teias; não é uma rainha humana. |
| `rei_espantalho.png` | linha 1, coluna 1 | 1254 × 1254, RGBA | Rei Espantalho (`chefe`): rosto de estopa, palha, coroa dourada com joias magenta e corvos. |

## Integração pelo Claude

- Referência de estilo: `docs/imagens/referencia_2_5d.webp`; pixel art dark fantasy, sombras frias e luz quente pontual.
- As fontes ampliadas foram mantidas intactas. Há resíduos quase transparentes (alfa de 1 a 8) nas bordas produzidos pelo gerador; limpar na etapa de recorte. O conteúdo visível está inteiro e separado das bordas.
- Não usar a caixa de todos os pixels com alfa > 0 para recortar automaticamente: os resíduos podem ocupar a tela inteira.
- Validar a leitura no tamanho final, preservar a silhueta e usar filtro adequado ao pipeline pixel art do projeto. A leitura final ainda não foi conferida dentro do jogo.
- Nenhum arquivo de código, dado de habilidade, teste ou asset já integrado foi alterado.
- Destino: bustos do HUD dos chefes; dimensionamento final fica com a integração.
- Identidades consultadas no PR #353, commit `4d9962ecbb0e84b0db6a674de42458d47ee3755a`.
