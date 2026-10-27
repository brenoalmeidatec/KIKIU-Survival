# Mapas novos da v2 (laboratório e cidade): como são feitos e onde parou

**Estado em 2026-10-12: o laboratório está FECHADO** (branch `claude/v2-mapa-laboratorio`, PR "v2: mapa Laboratório", aguardando o OK do Alisson):
seleção no santuário, mapa, luzes, minimapa, partículas, colisão, teste `v2_mapas` com falhas=0, bateria completa, fps medido contra a floresta
(tabela no PR) e build exportado conferido. A **cidade ainda não foi começada** (ela parte da branch do laboratório).

Acabamento da arte (fechamento): tom do piso e do ambiente igualados ao da floresta (`mapa.chao.ganho` 2,2, `dessat` 0,3, ambiente `16232d`: o
primeiro laboratório saía bem mais claro e mais azul que a floresta); piso com desgaste em Python (`detalhar_piso` em `def_laboratorio.py`, ligado
por `processar_piso` do gerador: brilho por placa, quinas, grão, riscos, ferrugem, manchas; as manchas redondas do Blender viram sujeira
picotada); `restos_cobaia` refeito (carcaça de rato com costelas, caveira e rabo; a primeira versão parecia uma tartaruga); três objetos novos para
a variedade das bordas (`porta_blindada`, `duto_ventilacao`, `estante_amostras`); bordas por TEMAS (`TEMAS` em `def_laboratorio.py`: cada trecho de 480 px
no norte e no sul e de 380 px no oeste e no leste tem os seus equipamentos e uma luz fraca da cor dele, tipos `borda_*` sem orbe), o que também
ilumina as fileiras altas do sul, que a câmera vê de frente e ficavam pretas; decalques de chão ao longo das bordas.

## O pipeline (igual ao do herói: Blender -> pixel art), em dois passos

1. **Blender** (`modelos3d/mapas_v2.py` + `modelos3d/mapa_<mapa>.py`): cada objeto é montado com as peças do `pixel3d.py` (caixa, cilindro,
   esfera), renderizado no Cycles a 4x e reduzido, na escala do herói (1 m = 32 px na horizontal; câmera ortográfica a 45 graus, então 1 m
   de altura = 22,6 px). Sai o albedo, **o normal map de verdade** (passe de normal no espaço da câmera, não o domo estimado da floresta) e
   a origem do objeto, em `fonte_arte/mapas_v2/brutos/<mapa>/` (fora do Git, regenerável). O piso (azulejo de 16 m = 512 px) também.
   ```
   blender -b -P jogos/hordas/fonte_arte/modelos3d/mapas_v2.py -- laboratorio            # tudo (o piso leva ~5 min: Cycles 2048x2048)
   blender -b -P jogos/hordas/fonte_arte/modelos3d/mapas_v2.py -- laboratorio mesa_lab   # só um objeto (ou "piso")
   ```
   Blender portátil em `C:\Dev\Tools\Blender\blender-4.5.14-windows-x64\blender.exe`.
2. **Python** (`gerar_v2_mapas.py` + `mapas_v2/def_<mapa>.py`): alfa binário, contorno escuro de 1 px, paleta curta (40 cores por objeto),
   pé e elipses de colisão (pegada em metros: `{"col": "caixa", "w": m, "d": m}`), atlas, decalques (Pillow, `kit_decalques.py`), piso achatado
   por sen 45 (o `def_<mapa>.py` pode trazer `detalhar_piso(img)`, que pinta desgaste no azulejo antes da paleta), e o JSON do mapa
   (`dados/v2_<mapa>.json`, mesmo formato da floresta + `mapa.pastas`, `minimapa` e `atmosfera`). O Python no Windows grava CRLF: troque
   por LF (`sed -i 's/\r$//'`) nos JSON gerados antes de commitar.
   ```
   python jogos/hordas/fonte_arte/gerar_v2_mapas.py laboratorio --previa prev.png      # prévia do mapa inteiro sem luz
   godot --headless --path jogos/hordas/projeto --import                                  # depois de gerar, para o Godot importar os PNG
   ```
   Saída: `projeto/assets/v2/mapas/<mapa>/` (enfeites, normal, cenario.json, decalques, piso) e `projeto/dados/v2_<mapa>.json`.
   Os `.import` não vão ao Git (como o resto); o Godot os gera.

Prévia dos brutos do Blender com régua de escala: `python mapas_v2/previa_brutos.py <mapa> saida.png [nomes] [--esc=3] [--normal]`.

## O que mudou no jogo (pouco, por dados)
- `v2/mapas.gd` (novo): lista de mapas, escolha gravada em `[config] mapa` do save da meta (`Meta.caminho_save`), `--mapa=<id>` abre direto.
- `v2/mundo.gd`: lê o JSON do mapa escolhido (`id_mapa`; nos testes o padrão é a floresta). `v2/cenario.gd`: `mapa.pastas` troca as pastas da arte.
  `v2/minimapa.gd`: `minimapa` do JSON (cores por nome). `v2/atmosfera.gd`: `atmosfera` do JSON (cor, quantidade, tamanho e velocidade das partículas).
  `v2/altar.gd`: botão `< MAPA >` ao lado de ENTRAR (clique ou Enter troca; o texto de ENTRAR acompanha).
- `export_presets.cfg`: `assets/v2/mapas/*/*.json` entrou no `include_filter` (senão o build exportado não acharia o `cenario.json` dos mapas novos).
- Teste novo: `testes/v2_mapas.tscn` (lista e escolha, nomes dos atlas, herói e zonas fora de colisão, 2 s andando nas 4 direções, santuário).

## O que falta (em ordem)
1. **Laboratório:** feito (veja o estado acima). Só falta o OK do Alisson para mesclar o PR.
2. **Prompts do ChatGPT (imagegen)** para o Alisson gerar folhas de referência mais ricas: ainda **não foram escritos**. A ideia: mesma convenção da
   floresta (`prototipos/cara_nova/objetos/gerar_objetos.py`: fundo branco, objetos em grade, uma folha por tema), e o `gerar_v2_mapas.py` ganhar a
   leitura de folhas (`agrupar` do `gerar_objetos.py`) no lugar dos brutos do Blender quando a folha existir.
3. **Cidade:** `modelos3d/mapa_cidade.py` (prédios, postes, carros, caçambas, bancos, hidrantes, barricadas, barril de fogo; piso de asfalto com calçada),
   `mapas_v2/def_cidade.py` (colisão, decalques de faixa e bueiro, layout em ruas e quarteirões, luzes de poste a sódio e neon), linha em `Mapas.LISTA`
   (`{"id": "cidade", "nome": "CIDADE", "entrar": "ENTRAR NA CIDADE", "dados": "v2_cidade"}`) e o PR da cidade (a partir da branch do laboratório).
4. (Feito) `mapas.gd` e a seleção de mapa estão na tabela de `v2/LEIA-ME.md`.

Dicas de quem fez: os mapas têm de ser **abertos** (o monstro persegue em linha reta e prende em parede comprida: paredes só em trechos com abertura, ou nas bordas,
que ficam fora da área andável); a colisão do `colisao.gd` aceita qualquer `ry`, mas formas encostadas deixam uma quina côncava onde o resolver trava.

## Cidade integrada (2026-10-13)

A Cidade da PR #211 integra a seleção junto de Floresta, Laboratório e Ruínas da Floresta. Fonte e regras próprias em `LEIA-ME_CIDADE.md`; assets e os 177 objetos/85 luzes preservados. Ruínas da Floresta é o nome exibido do id `medio`, sem regenerar o mapa nem mudar progresso salvo.

## Laboratório por salas (18/10/2026)
O desenho do laboratório agora segue `docs/laboratorio/PLANTA_PROPOSTA.md`: 9 salas em grade 3x3, quatro corredores de 160 px, uma receita por sala em `def_laboratorio.py`. Para mexer em onde as coisas ficam, mude o gerador e rode `python jogos/hordas/fonte_arte/gerar_v2_mapas.py laboratorio --so-mapa [--previa x.png]` (sem refazer atlas nem piso, então sem Blender; troque CRLF por LF no JSON gerado). Confira com `testes/v2_mapas` e `testes/v2_laboratorio_colisao`.

## Torre do Alquimista e Vila Amaldiçoada (26/10/2026, #429)
O Laboratório (id `laboratorio`) virou **Torre do Alquimista** e a Cidade (id `cidade`) virou **Vila Amaldiçoada**, no clima dark fantasy da Floresta, do Santuário e das Ruínas. Os **ids internos, os nomes dos objetos, as pegadas de colisão, a planta e as posições do JSON ficaram iguais** (conferido por comparação: `objetos`, `decalques`, `nascimento` idênticos e a `colisao` dos 27 e dos 41 tipos também); mudaram a arte (Blender), os decalques, o piso, as luzes, o ambiente e os nomes visíveis (`v2/mapas.gd`, conquistas em `dados/v2_meta.json`). Torre: `modelos3d/mapa_laboratorio.py` e `mapas_v2/def_laboratorio.py`. Vila: `modelos3d/mapa_cidade.py` (junta `vila_pecas.py`, `vila_casas.py` e `vila_piso.py`), `mapas_v2/medidas_cidade.py` (medidas e luzes) e `mapas_v2/def_cidade.py`. Regerar com o Blender 4.5: `blender -b -P jogos/hordas/fonte_arte/modelos3d/mapas_v2.py -- <laboratorio|cidade>` e depois `python -X utf8 jogos/hordas/fonte_arte/gerar_v2_mapas.py <laboratorio|cidade>`.

