# Ícones da E por herói (#387, item 2)

Fontes próprias geradas com ImageGen integrado do Codex em 21/10/2026, no estilo dos ícones Q da #360. Cada PNG contém uma única célula, sem texto ou moldura. Os prompts completos, incluindo a revisão de Lucas para melhorar a redução, estão em `PROMPTS.md`.

| Fonte | Ação | Motivo |
|---|---|---|
| `nicao.png` | Investida de Escudo | Escudo de aço escuro avançando, rastro verde e impacto frontal. |
| `lucas.png` | Salto das Adagas | Bota recuando no arco verde enquanto três adagas seguem para a frente. A quantidade é ilustrativa. |

As fontes RGBA ampliadas ficam intactas. A receita existente do Q recorta pelo alfa acima do limiar, centraliza em quadrado, reduz para 30 px, binariza o alfa e acrescenta contorno escuro. A paleta compartilhada tem 64 cores.

```powershell
python jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py habilidade_e
```

Saída: `jogos/hordas/projeto/assets/v2/habilidade_e/{nicao,lucas}.png`, 32×32, filtro nearest no jogo. O HUD procura a arte pela identidade do herói; a Ruptura do Hazaki e o escudo secundário preservam os ícones existentes. Os dados e as animações das habilidades não mudam.

Licença: arte própria gerada no Codex, sob a licença do projeto; sem material ou atribuição de terceiros. Registro acrescentado ao fim de `docs/LICENCAS_ARTE.md`.
