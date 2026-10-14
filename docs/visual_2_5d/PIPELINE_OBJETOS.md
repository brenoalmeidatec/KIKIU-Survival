# Objetos de mapa: a rotina atual basta, ou a dica "Opus + Blender MCP + BlenderKit" é superior?

Data: 2026-10-12. Pergunta do Alisson. **Veredito: a rotina atual resolve; a dica não é superior, é uma fonte opcional de modelos.** Não há nada para baixar ou instalar agora.

## 1. O que temos hoje (duas trilhas, a segunda é a que vale daqui pra frente)
| | Trilha A: folha do GPT | Trilha B: modelo no Blender |
|---|---|---|
| Entrada | `fonte_vegetacao.webp` etc. (várias peças por imagem) | Script Python por objeto (`pixel3d.py`: caixa, cilindro, esfera, rampas de cor) |
| Ferramenta | `jogos/hordas/prototipos/cara_nova/objetos/gerar_objetos.py` (Pillow): fundo por flood fill, recorte, filtro BOX para o tamanho do jogo, alfa binário, quantização a 40 cores sem dithering, normal map **estimado** (domo pela distância à borda + luminância), `cenario.json` | `modelos3d/mapas_v2.py` + `mapa_<mapa>.py` (branches `claude/v2-mapa-laboratorio` e `alisson/v2-mapa-cidade`): `blender -b -t 6 -P ... -- cidade` |
| Câmera/luz | nenhuma (a imagem já vem pintada) | ortográfica a 45 graus, 1 m = 32 px, render a 4x e média, céu forte + sol fraco |
| Normal map | estimado | **de verdade** (passe de normal no espaço da câmera) |
| Consistência | média: cada folha tem a mão do GPT, escalas variam | alta: mesma câmera, escala e luz em tudo |
| Tempo | minutos por folha, mais retrabalho | ~30 s por objeto no Cycles (piso: ~4 min) depois de escrito o script |
| Licença | saída do GPT, sem fonte de terceiros | 100% nossa |

A trilha B já **é** um render em lote com câmera, luz, escala e normal padronizados; o que a dica promete ("Opus arruma, posiciona, ilumina e renderiza") o `mapas_v2.py` já faz por script, de forma determinística e sem dependência nova. Estado na cidade: 41 objetos + piso prontos, conferidos no tamanho do jogo.

## 2. Comparação com a dica
| Eixo | Rotina atual (trilha B) | Dica (MCP + BlenderKit) |
|---|---|---|
| Qualidade no nosso tamanho | Objetos de 20 a 150 px: o que decide é silhueta, paleta e contorno, e isso o pós-processo faz igual para qualquer fonte. Modelos simples (caixas) resolvem bem em 40 px | Modelos prontos têm detalhe que **some** na redução (BOX para ~40-150 px); só ajudam em silhuetas orgânicas (árvore, estátua) |
| Consistência de estilo | Alta (mesma mão, mesma rampa) | Baixa: cada autor tem escala, malha e material próprios; precisa normalizar tamanho/material e quase sempre recolorir para a paleta dark fantasy |
| Tempo por objeto | Escrever o script (o custo está aí) + 30 s de render | Buscar, conferir licença, baixar (conta), importar, ajustar escala/material: parecido ou pior para objeto simples; melhor só para forma orgânica difícil |
| Custo de tokens | Script único reutilizável; render em lote não gasta tokens | Cada ajuste "conversado" via MCP gasta tokens (ida e volta, screenshots); o lote por script é mais barato |
| Licença | Nossa | CC0 livre; Royalty Free só como sprite cozido, fonte fora do Git, registro em `LICENCAS_ARTE.md`, conferir a licença na página do asset no dia. Plano pago (Full) precisa do OK do Breno |
| Dependências novas | Nenhuma (Blender 4.5.14 portátil já está em `C:\Dev\Tools\Blender`) | Conta no BlenderKit (quem tem conta baixa), add-on BlenderKit, MCP oficial do Blender Lab (versão mínima do Blender **não confirmada**; a dica cita 5.2.2, nós usamos 4.5), cuidado com MCPs comunitários homônimos |

Conclusão: o ganho da dica está só em **achar o modelo** de algo difícil de modelar por caixas. O render, a luz e o downscale já estão resolvidos. O MCP não acrescenta nada que `blender -b -P` não faça.

## 3. Melhorias baratas feitas neste PR
1. `ferramentas/conferir_objeto.py` (Pillow + numpy, sem Blender): checklist automático para um sprite ou uma pasta de brutos (alfa binário, <= 40 cores, contorno escuro de 1 px, sem pixel solto, não cortado, normal do mesmo tamanho e unitária). Evita olhar a olho o que máquina confere.
2. Este documento com o checklist e o plano de contingência.

## 4. Checklist por objeto novo (trilha B)
- [ ] Pegada em metros e altura anotadas em `medidas_<mapa>.py`; sprite com origem no centro da pegada, no chão.
- [ ] Renderizado só por `mapas_v2.py` (câmera 45 graus, 1 m = 32 px, `-t 6`, um Blender por vez). Nada de render manual.
- [ ] Cores só das rampas de `pixel3d.py`; luz de borda um degrau acima.
- [ ] `python ferramentas/conferir_objeto.py <pasta_brutos>/` sem FALHA.
- [ ] Prévia com régua e herói de 41 px (`previa_brutos.py ... --final --heroi`) e com luz (`--luz`) olhadas.
- [ ] Sombra projetada: vem do normal map + luz dinâmica do jogo; não pintar sombra no albedo (só oclusão nas frestas).
- [ ] Se veio de modelo de terceiro: linha em `docs/LICENCAS_ARTE.md` e arquivo-fonte fora do Git.

## 5. Plano de contingência (só se aparecer um objeto que não dá para modelar por caixas)
Nada disso é feito agora. **Pedir OK do Alisson antes de cada passo marcado (OK).**
1. **Primeiro tentar sem instalar nada:** baixar o `.glb`/`.blend` CC0 direto do site (BlenderKit, Poly Haven, Kenney, Quaternius: Poly Haven/Kenney/Quaternius não exigem conta) para uma pasta fora do Git, p. ex. `fonte_arte/mapas_v2/terceiros/` (no `.gitignore`). (OK: arquivo, fonte e tamanho informados antes de baixar.)
2. Importar no `mapas_v2.py` com uma função `importar(caminho, altura_m)` (bpy.ops.import_scene.gltf, escala para a altura em `medidas`, material trocado pelas rampas do `pixel3d.py`) e renderizar como qualquer objeto.
3. Só se o fluxo conversado fizer falta: **BlenderKit** = conta gratuita em blenderkit.com (quem tem a conta faz o login; o Claude não entra em contas), add-on pelo Blender 4.5 (Preferências, Extensões), ~poucos MB mais cada asset baixado (OK). Filtrar licença CC0 (livre) ou Royalty Free (sprite cozido); plano pago não sem o Breno.
4. **MCP oficial do Blender Lab** (`projects.blender.org/lab/blender_mcp`): conferir antes no site oficial a versão mínima do Blender e os passos; se exigir 5.x, baixar o Blender 5.x portátil (~400 MB, zip, em pasta própria, ao lado do 4.5, sem trocar o 4.5 do pipeline) (OK). Configurar o cliente MCP é mudança de configuração persistente (OK).
5. Registrar tudo em `LICENCAS_ARTE.md` e no `LOGBOOK.md`.

Critério para ligar o passo 3 em diante: mais de ~5 objetos orgânicos travados, ou um objeto cujo script passou de 1 hora de relógio sem silhueta aceitável.
