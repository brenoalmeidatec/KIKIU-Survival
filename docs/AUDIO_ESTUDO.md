# Estudo de áudio da v2 (2026-10-12)

Pergunta do Alisson: "já temos sons de livre uso?" Resposta curta: **a música sim (CC BY 4.0, Kevin MacLeod, com crédito); os efeitos NÃO são de terceiros: são 100% sintetizados por código nosso, sem licença externa**. Não há nenhum sample CC0 baixado. Nada foi baixado neste estudo.

## Estado real (origin/main)
- **Música:** 7 OGG em `jogos/hordas/projeto/assets/audio/musica/`, todos Kevin MacLeod, CC BY 4.0, registrados em `docs/LICENCAS_AUDIO.md` (crédito já aparece em Ajustes > Áudio). A v2 usa 4: santuário `menu`, partida `minijogo_tenso`, chefe `chefe`, resultado `fim` (`dados/v2_musica.json`, `v2/trilha.gd`).
- **Efeitos da v2:** 26 WAV (22050 Hz, mono, ~0,9 MB no total) em `assets/audio/v2/`, gerados por `jogos/hordas/fonte_audio/gerar_v2_sfx.py` (numpy: pulso, triângulo, ruído, filtros), que reaproveita o sintetizador de `jogos/cairu/fonte_audio/gerar_audio.py`. Tocados por `v2/audio.gd` (10 AudioStreamPlayer reaproveitados). Sem licença de terceiros, mas soam "8-bit/retrô", não dark fantasy.
- **UI:** `Som.ui("cursor"/"confirmar")` do autoload `Som`, com WAV sintetizados da v1 em `assets/audio/efeitos/` (13 arquivos, também por código).
- Fonte Press Start 2P é OFL; irrelevante aqui.

## Eventos sonoros da v2
| Evento | Som hoje | Origem |
|---|---|---|
| Golpe da katana (corte 1 e 2, estocada) | `corte1`, `corte2`, `estocada` | sintetizado |
| Acerto / crítico | `impacto` / `critico` | sintetizado |
| Morte de inimigo (grande = mais grave) | `morte` | sintetizado |
| Esquiva | `esquiva` | sintetizado |
| Coleta de alma/XP | `orbe` (tom sobe) | sintetizado |
| Dano no herói / fôlego baixo / derrota | `dano_heroi`, `ofego`, `derrota` | sintetizado |
| Subir de nível / evolução | `nivel`, `evolucao` | sintetizado |
| Carta (abrir, virar, escolher) | `carta`, `escolher` | sintetizado |
| Baú (cai, abre) | `bau_cai`, `bau` | sintetizado |
| Chefe (entrada, golpes), elite, onda, aviso | `chefe`, `elite`, `onda`, `aviso` | sintetizado |
| Armas secundárias | `fogo`, `raio`, `corvo`, `runa`, `runa_poe` | sintetizado |
| Vitória | `vitoria` | sintetizado |
| UI (cursor, confirmar) | `Som.ui` | sintetizado (v1) |
| **Escudo novo** | nenhum (a branch `alisson/v2-ruptura` ainda não está na main; não há chamada a `audio.tocar` para escudo) | nenhum |
| **Ruptura nova** | nenhum (idem) | nenhum |
| Música | 4 faixas MacLeod | real, CC BY 4.0 |

Nenhum evento tem som real de terceiros. Escudo e Ruptura precisam de som novo: dá para reaproveitar `chefe`/`runa` provisoriamente, mas o ideal é um som próprio.

## Fontes de livre uso propostas (licença conferida na página de cada uma em 2026-10-12)
| Pacote | Link | Licença | Tamanho | Serve para |
|---|---|---|---|---|
| Kenney Impact Sounds (130 arquivos OGG) | https://kenney.nl/assets/impact-sounds | CC0 | pequeno (~poucos MB, a página não informa) | acerto, crítico, morte, baú cai, escudo bloqueando, Ruptura (graves) |
| Kenney RPG Audio (50 arquivos: foley, passos, armas) | https://kenney.nl/assets/rpg-audio | CC0 | ~poucos MB (não informado) | golpe da katana (lâmina/cloth), esquiva, carta, baú, coleta |
| Kenney Interface Sounds (100 arquivos) | https://kenney.nl/assets/interface-sounds | CC0 | ~poucos MB (não informado) | UI, cursor, confirmar, escolher carta |
| Kenney UI Audio / Digital Audio / Music Jingles | https://kenney.nl/assets/ui-audio , /digital-audio , /music-jingles | CC0 (padrão Kenney; conferir na hora do download) | pequenos | UI, jingles de nível/vitória |
| RPG Sound Pack (artisticdude, 95 WAV) | https://opengameart.org/content/rpg-sound-pack | CC0 | 12,5 MB | espadas, golpes, moedas, portas, magias, baú, nível |
| 100 CC0 SFX (rubberduck, 100 arquivos) | https://opengameart.org/content/100-cc0-sfx | CC0 | 2,9 MB | metal, gongo, sinos, batidas, "weird" para chefe/Ruptura (comentário relata arquivos com erro: testar) |
| 63 Digital sound effects (Kenney) | https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc | CC0 | 1,1 MB | raio/runa (magia) com pitch baixo; fora do clima, só como matéria-prima |
| 512 Sound Effects 8-bit (SubspaceAudio) | https://opengameart.org/content/512-sound-effects-8-bit-style | CC0 | 20,6 MB | mantém o estilo retrô atual se quisermos, não dark fantasy |
| Freesound (CC0 filtrado) | https://freesound.org/search/?f=license%3A%22Creative+Commons+0%22 | CC0 só nos arquivos marcados; CC BY/BY-NC existem no mesmo site, conferir cada um | por arquivo (KB) | sons pontuais: lâmina sendo sacada, vidro/escudo quebrando, grito de corvo, trovão |
| Sonniss GDC Game Audio Bundle | https://sonniss.com/gameaudiogdc | NÃO é CC0: licença própria royalty-free, uso comercial livre, sem crédito, mas proíbe revender os arquivos soltos, dizer que são seus e (na edição de 2024) treinar IA. Ler o texto da edição baixada | 27,5 GB (2024) a 44 GB+ (2023) | qualidade profissional (golpes, ambiente, chefe); baixar só os arquivos que usaremos |

Não consegui abrir o texto da licença do Sonniss (só descrições de terceiros): confirmar no site antes de usar.

## Recomendação por evento
- **Katana, esquiva:** Kenney RPG Audio (lâmina/foley) misturado com `whoosh` já existente; alternativa artisticdude (espadas).
- **Acerto, crítico, morte, baú cai:** Kenney Impact Sounds (variações aleatórias, pitch levemente variado como `audio.gd` já faz).
- **Coleta de alma/XP, carta, nível, baú abre:** Kenney Interface/RPG Audio ou RPG Sound Pack (moedas/magias); manter o `orbe` sintetizado de tom crescente costuma funcionar bem e é nosso.
- **Chefe, aviso, elite:** 100 CC0 SFX (gongo, metal) e/ou Freesound CC0 grave/trovão; Sonniss se quisermos qualidade de estúdio.
- **Escudo (bloqueio/quebra) e Ruptura:** Impact Sounds (metal/vidro) + camada grave; Freesound para "quebra de escudo".
- **UI:** Kenney Interface Sounds.
- **Música:** manter MacLeod (CC BY, já creditado); se quiser CC0, OpenGameArt tem trilhas CC0 sombrias, a pesquisar à parte.

## Como adotar (quando o Alisson autorizar o download)
1. Baixar cada ZIP numa pasta limpa fora do repo (`aria2c -x 16 -s 16 -k 1M`; `curl.exe` se não houver), validar tamanho.
2. Escolher só os arquivos usados, converter para OGG/WAV, nomear pelo evento em `assets/audio/v2/` (o `audio.gd` já carrega `nome.wav`; OGG exigiria ajustar `_stream`).
3. Registrar cada pacote/arquivo em `docs/LICENCAS_ARTE.md` (tabela Registro) e `docs/LICENCAS_AUDIO.md`, com o `LICENSE.txt`/página como prova.
4. Manter o sintetizador como plano B para o que não tiver substituto.
