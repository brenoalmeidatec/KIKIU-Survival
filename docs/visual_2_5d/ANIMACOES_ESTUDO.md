# Estudo: animações, bloom/pixel shader e Blender MCP + BlenderKit

Data: 2026-10-12. Estudo só de documentação, nenhum código do jogo foi alterado. Contexto: v2 top-down 2.5D, mundo num SubViewport 960x540, herói de ~39 px, horda em lote via MultiMesh, objetos vindos de folhas do GPT (`gerar_objetos.py`) e de renders do Blender 4.5. Máquinas-alvo: Iris Xe (notebook), i5-3470 com vídeo fraco (perfil Baixo) e RTX 3060.

## 1. Como animar herói e inimigos

Lista do que falta. **Herói:** andar, combo de katana em 3 golpes, rolamento/esquiva, morte e escudo. **Inimigos:** andar e morrer.

### Comparação

| | (a) Folha de sprite do GPT | (b) 3D rigado no Blender → 8 direções → pixel art | (c) Procedural sobre o sprite parado |
|---|---|---|---|
| **Custo inicial** | Baixo por folha, mas alto em retrabalho | Alto uma vez (modelo, rig, ações e script de render) | Muito baixo (tweens e um shader) |
| **Custo por animação nova** | Médio: gerar, recortar e corrigir a folha | Baixo: uma ação nova e re-render em lote | Muito baixo |
| **Qualidade** | Quadro bonito isolado, mas **sem consistência** entre quadros (o personagem "muda" de um quadro para outro, a proporção varia e as 8 direções não batem) | Consistente em todas as direções, com normal map grátis no mesmo render. Precisa de downscale BOX, paleta e contorno para não parecer "3D borrado" | Ótima para *juice* (impacto, peso, flash, morte). Não substitui ciclo de pernas nem golpe de espada legível |
| **Risco** | Alto: as IAs de imagem ainda erram contagem de quadros, alinhamento e loop. Também há a questão de licença e estilo da saída | Médio: a curva de rig/animação é o gargalo. Com Rigify, ou com rig e animações livres de terceiros (ver item 3), cai bastante | Baixo |
| **Peso em runtime** | Atlas por direção. Na horda funciona com `INSTANCE_CUSTOM_DATA` no MultiMesh para escolher o quadro | Igual a (a) | Quase zero. Na horda vai no vertex shader (bob e squash por instância) |

### Recomendação: combinação (b) + (c), com (a) só para efeitos

1. **Já, em 1 PR, (c) para tudo:** bob e squash/stretch ao andar (seno pela velocidade), *anticipation* + *lunge* + *hit-stop* (2–4 quadros congelados) no ataque, flash branco ao tomar dano (uniform no shader que já existe), morte por *dissolve*/queda + partículas. Na horda, faça isso no vertex shader do MultiMesh com a fase por instância (custo de CPU zero). Isso já dá vida e não joga nada fora depois.
2. **Arcos de golpe da katana como VFX separado**, um sprite de "rastro" de luz (o *smear*) por golpe do combo 1-2-3. Pode sair de folha do GPT, de partícula ou de malha simples. Esse é o lugar onde (a) funciona bem: é efeito, não personagem, e erro de consistência ali não aparece.
3. **(b) para o herói:** um rig só (Rigify ou rig livre registrado), com as ações andar, golpe 1/2/3, rolamento, escudo e morte. Um script do Blender em linha de comando renderiza 8 direções × N quadros com câmera ortográfica a 45°, gerando cor + normal, e passa pelo pipeline de downscale/paleta que já existe. Use poucos quadros: andar 6, cada golpe 4–5, rolamento 6, morte 6–8. Isso entra na fase **V4**.
4. **(b) para os inimigos:** só andar (4–6 quadros) e, se der, morrer. A morte pode continuar procedural (dissolve) para economizar atlas. Use 4 direções espelhadas (que dão 8) para inimigos comuns e 8 reais para elite e chefe.
5. **(c) continua por cima de (b):** hit-stop, flash e squash valem para os sprites animados também.

A ordem 1 → 2 → 3 → 4 entrega melhora visível já na primeira semana e deixa o investimento caro (o rig) para quando a direção da V4 estiver travada.

## 2. Bloom e pixel shader no perfil Alto sem pesar no Iris Xe

O custo de pós-processamento é proporcional aos **pixels processados**. Como o mundo é 960x540 (0,5 Mpx), qualquer efeito aplicado **dentro do SubViewport, antes do upscale**, é barato até para o Iris Xe.

**Bloom.** A opção mais simples é o glow do `WorldEnvironment` com `glow_enabled`, poucos níveis (1–3, os mais baixos), `hdr_threshold` ~1.0 e modo *Additive/Screen*. No 2D, o Godot 4.4 aplica o glow quando o canvas do viewport usa HDR 2D (`use_hdr_2d`). Ative **só** no viewport do mundo, não no HUD. Se o glow nativo pesar ou "lavar" o pixel art, troque por bloom manual: copie o viewport em ¼ de resolução (240x135), faça threshold + blur de 2 passes e some de volta. Fica em 3 passes minúsculos, custo desprezível.

Para não perder legibilidade, faça brilhar só o que é emissivo (portal, magia, olhos, tochas): use cores acima de 1.0 (com HDR 2D) nesses sprites e deixe o resto abaixo do threshold.

**Pixel shader (look).** Os efeitos baratos que combinam com a referência:
- Quantização/posterize para a `paleta.json` com dither ordenado 4x4 (Bayer), uma leitura de textura e alguns ALU.
- Vinheta e color grading leve por LUT 16³ ou 32³.
- Contorno de 1 px já assado no sprite, não em runtime.

Tudo isso num único `ColorRect` com shader no SubViewport (um passe).

**Perfis.** O Baixo não liga nada disso. O Médio liga flash/dissolve e vinheta. O Alto liga glow (ou bloom manual), quantização com dither e LUT. **Meça no Iris Xe** (perfil Alto, horda cheia) antes de travar. Isto é estimativa, não medição.

## 3. Dica do Blender MCP + BlenderKit

**O MCP oficial existe.** O Blender Lab publicou um MCP server (v1.0.0 em 27/04/2026, v1.0.3 em 11/09/2026, segundo um comparativo de terceiros). O projeto fica em `projects.blender.org/lab/blender_mcp`, com documentação em `blender.org/lab/mcp-server`. A instalação é feita pelo repositório de extensões do Lab dentro do Blender, mais a configuração do cliente MCP. **Não confirmei os passos na página oficial nem a versão mínima do Blender**: a dica fala em Blender 5.2.2 e nós usamos o 4.5, então isso precisa ser conferido antes. Atenção também a um ponto: existem vários projetos não oficiais com o mesmo nome (por exemplo o `blender-mcp` do PyPI, MIT, que é comunitário), com protocolos diferentes. Misturar o add-on oficial com o servidor comunitário faz todas as chamadas falharem.

**Licença do BlenderKit.** Os assets têm só duas licenças: **CC0** (livre total) e **Royalty Free** (uso comercial sem crédito obrigatório, mas **proibido revender ou redistribuir o asset em si**). O FAQ deles permite vender jogos feitos com os modelos "se não puderem ser extraídos facilmente". No nosso pipeline, o que vai para o jogo é **sprite já renderizado e quantizado**, não o `.blend`/`.glb`. Pela regra de `LICENCAS_ARTE.md` ("só o resultado cozido vai ao Git, nunca o arquivo-fonte cru"), isso se encaixa: **CC0 pode entrar livre**, e **RF pode entrar só como sprite cozido**, com o arquivo-fonte fora do Git e registro na tabela, conferindo a licença na página de cada asset no dia. Existem também assets pagos (plano Full), e esses **não** podem entrar sem o OK do Breno. O download exige conta, então quem tem conta baixa, e só com o OK do Alisson.

**Ajuda o nosso pipeline?** Ajuda **parcialmente**:
- **Objetos de mapa** (ruínas, lanternas, pedras, árvores): é o melhor uso. Asset CC0 pronto + nosso script de render 45° + downscale economiza muito em relação a modelar do zero.
- **Personagens:** o ganho é menor. Assets prontos raramente batem com o estilo dos nossos heróis, e "deixar o Opus rigar e animar" via MCP ainda é a parte mais arriscada (rig automático erra pesos, e animação feita por chamadas de ferramenta sai dura). O caminho seguro é: rig com Rigify (manual ou via script), animação de base vinda de fonte livre ou feita à mão, e o MCP/Claude cuidando do que é **repetitivo**: montar câmera, iluminar, renderizar as 8 direções em lote e exportar cor + normal.
- **A "prévia 480p antes do final"** é uma boa prática e combina com o nosso downscale, já que o destino é ~39 px. A prévia pode ser em resolução até menor.
- **Não é obrigatório usar o MCP:** o `blender.exe --background --python script.py` que já usamos faz o mesmo render em lote de forma determinística, sem dependência nova. O MCP vale para a parte **exploratória** (montar e ajustar uma cena conversando). Recomendo testar só depois de confirmar a compatibilidade de versão, e com OK do Alisson para a instalação.

## Fontes
- [Comparativo do Blender MCP oficial (StraySpark, 2026)](https://www.strayspark.studio/blog/official-blender-mcp-server-comparison-2026)
- [blender-mcp no PyPI (comunitário)](https://pypi.org/project/blender-mcp)
- [Licenças do BlenderKit](https://www.blenderkit.com/docs/licenses/)
- [FAQ de licenças do BlenderKit](https://www.blenderkit.com/docs/licenses/licensing-faq/)
- [FAQ geral do BlenderKit](https://www.blenderkit.com/faq-frequently-asked-questions/)
