# Licenças de música e efeitos sonoros do K.I.K.I.U

Todas as músicas do jogo (`jogos/hordas/projeto/assets/audio/musica/*.ogg`) são de **Kevin MacLeod (incompetech.com)**, licença **Creative Commons Attribution 4.0 (CC BY 4.0)** — https://creativecommons.org/licenses/by/4.0/ . Uso comercial e modificação são permitidos desde que se dê crédito e se diga o que foi alterado (feito abaixo e na tela de Créditos do jogo).

Fonte da licença: https://incompetech.com/music/royalty-free/faq.html (a loja usa CC BY 4.0 para todo o catálogo; o MP3 original traz `comment=ISRC: ... incompetech.com`). Os MP3 vêm de `https://incompetech.com/music/royalty-free/mp3-royaltyfree/<Título>.mp3`; a página de cada faixa é `https://incompetech.com/music/royalty-free/index.html?isrc=<ISRC>`.

Texto de atribuição pedido pelo autor, por faixa: "*Título* Kevin MacLeod (incompetech.com) Licensed under Creative Commons: By Attribution 4.0 https://creativecommons.org/licenses/by/4.0/"

| Arquivo do jogo | Momento | Título original | ISRC / página | Mudanças (todas nossas) |
|---|---|---|---|---|
| `menu.ogg` | menu e créditos | Oppressive Gloom | USUAN1100885 | corte 0–185 s, laço, ganho -2 dB, OGG |
| `minijogo_tenso.ogg` | fases (andares pares) | Crypto | USUAN1600013 | corte 0–190 s, laço, ganho -2 dB, OGG |
| `minijogo_tenso_b.ogg` | fases (andares ímpares) | Giant Wyrm | USUAN1600035 | corte 0–185 s, laço, ganho +2,5 dB, OGG |
| `chefe.ogg` | chefes | Ignosi | USUAN1100450 | corte 0–180 s, laço, ganho +4,5 dB com limitador suave nos picos, OGG |
| `minijogo_retro.ogg` | duelo PvP | Crusade | USUAN1100884 | corte 0–185 s, laço, ganho -6 dB, OGG |
| `fim.ogg` | fim de partida | Wounded | USUAN1100586 | corte 0–185 s, laço, ganho -2 dB, OGG |
| `horror.ogg` | fase 6 (Catacumbas) | Long Note Four | USUAN1100467 | trecho de 120 s a 270 s (de 10 min), laço, ganho +7,5 dB, OGG |

Páginas: `https://incompetech.com/music/royalty-free/index.html?isrc=` + o ISRC da tabela.

## Onde cada faixa toca na v2
A v2 não trouxe música nova: reaproveita as faixas acima, que já estavam no repositório com a licença registrada. A escolha vive em `jogos/hordas/projeto/dados/v2_musica.json` (momento → arquivo) e é feita por `v2/trilha.gd`; o teste `testes/v2_musica.tscn` falha se um momento apontar para um arquivo que não existe **ou que não está nesta lista de licenças**. Trocar uma faixa = editar o JSON e registrar a nova aqui (CC0 de preferência; CC BY só com a linha na tabela acima).

| Momento na v2 | Arquivo | Título original |
|---|---|---|
| santuário (tela inicial e a pausa dele) | `menu.ogg` | Oppressive Gloom |
| partida (a floresta) | `minijogo_tenso.ogg` | Crypto |
| chefe (mini-chefes aos 3 e 6 min e o chefe dos 10 min) | `chefe.ogg` | Ignosi |
| resultado (derrota ou vitória) | `fim.ogg` | Wounded |

Crédito dentro do jogo (a atribuição que a CC BY pede): a tela **Ajustes > Áudio** da pausa (ESC, e o botão Ajustes do santuário) mostra no rodapé "Música: Kevin MacLeod (incompetech.com), Licença Creative Commons Atribuição 4.0 (CC BY 4.0)". A v1 tem o mesmo crédito na tela de Créditos dela.

Volume: o slider Música daquela tela grava em `user://opcoes.cfg` (chave `musica`) e move o bus de áudio `Musica` (criado por `scripts/hordas/som.gd`, saída no Master). Os efeitos seguem no Master e têm o slider deles.

## O que foi feito nos arquivos
`jogos/hordas/fonte_audio/preparar_musica_cc.py` refaz tudo a partir dos MP3: corta o trecho, funde o fim no começo com crossfade de potência igual (4 s; 3 s no chefe; 6 s no horror) para o laço não estalar, ajusta o ganho a um RMS alvo (-19 a -24 dBFS), limita suavemente os picos acima de -1,5 dBFS e converte para OGG Vorbis estéreo 44,1 kHz, qualidade 4. Nenhuma outra edição (sem camadas, sem instrumentos acrescentados, sem efeitos).

Os MP3 originais não estão no repositório; baixe-os do link acima para refazer.

## Plano B
As faixas sintetizadas por código (sem licença de terceiros) estão no histórico do Git (commit anterior a "músicas de licença aberta") e o gerador continua em `jogos/hordas/fonte_audio/gerar_musica.py`.

## Efeitos sonoros da v2 (Kenney, CC0)
Os sons de combate e de interface da v2 que eram sintetizados agora vêm de **Kenney (kenney.nl)**, licença **CC0 1.0** (domínio público: uso comercial, modificação e redistribuição livres, sem crédito obrigatório). Cada zip traz um `License.txt` com a licença; os zips não estão no repositório. Baixados em 2026-10-12:
- Impact Sounds: https://kenney.nl/assets/impact-sounds
- RPG Audio (coleção de Kenney Vleugels): https://kenney.nl/assets/rpg-audio
- Interface Sounds: https://kenney.nl/assets/interface-sounds

Mudanças (todas nossas, nos 21 arquivos): cortado o silêncio das pontas (abaixo de -46 dB do pico, com 2 ms antes e 15 ms depois), fade de 6 ms no fim, convertido para WAV mono de 44,1 kHz (16 bits) e normalizado para RMS -18 dBFS, com teto de pico em -1 dBFS (sem clipe). Nada além disso. Para refazer: baixar os zips, extrair os `.ogg` listados, converter para WAV e normalizar com esses parâmetros.

| Arquivo em `assets/audio/v2/` | Evento na v2 | Pacote e arquivo original |
|---|---|---|
| `corte1.wav` | katana, 1º corte | RPG Audio, `knifeSlice.ogg` |
| `corte2.wav` | katana, 2º corte | RPG Audio, `knifeSlice2.ogg` |
| `estocada.wav` | katana, estocada | RPG Audio, `drawKnife2.ogg` |
| `impacto.wav` | acerto comum | Impact Sounds, `impactMetal_medium_002.ogg` |
| `critico.wav` | acerto crítico | Impact Sounds, `impactMetal_heavy_001.ogg` |
| `morte.wav` | morte de monstro; banir carta | Impact Sounds, `impactSoft_heavy_001.ogg` |
| `esquiva.wav` | esquiva | RPG Audio, `cloth2.ogg` |
| `orbe.wav` | orbe de XP | Impact Sounds, `impactGlass_light_002.ogg` |
| `dano_heroi.wav` | dano no herói; rerrolar ou banir falhou | Impact Sounds, `impactPunch_medium_001.ogg` |
| `nivel.wav` | subir de nível; carta rara | Impact Sounds, `impactBell_heavy_000.ogg` |
| `evolucao.wav` | evolução de arma | Impact Sounds, `impactBell_heavy_002.ogg` |
| `carta.wav` | carta virada | RPG Audio, `bookFlip2.ogg` |
| `escolher.wav` | escolha de carta ou melhoria | RPG Audio, `bookPlace1.ogg` |
| `bau.wav` | baú abre | RPG Audio, `creak2.ogg` |
| `bau_cai.wav` | baú cai | Impact Sounds, `impactWood_heavy_001.ogg` |
| `ui_cursor.wav` | cursor do santuário (menu fora da partida) | Interface Sounds, `click_002.ogg` |
| `ui_confirmar.wav` | confirmar no santuário | RPG Audio, `metalLatch.ogg` |
| `escudo_bloqueio.wav` | **não ligado**: escudo bloqueia | Impact Sounds, `impactPlate_medium_002.ogg` |
| `escudo_perfeito.wav` | **não ligado**: bloqueio perfeito | Impact Sounds, `impactBell_heavy_004.ogg` |
| `ruptura_carga.wav` | **não ligado**: Ruptura carregando | Impact Sounds, `impactPlate_heavy_004.ogg` |
| `ruptura_solta.wav` | **não ligado**: Ruptura solta | Impact Sounds, `impactGlass_heavy_004.ogg` |

Os quatro "não ligados" esperam a branch `alisson/v2-ruptura` (ainda não está na `main`).

**Ficou sintetizado nesta etapa:** `chefe`, `aviso`, `elite`, `onda`, `fogo`, `raio`, `corvo`, `runa`, `runa_poe`, `ofego`, `derrota` e `vitoria`, em `assets/audio/v2/`. O chefe continua assim porque nenhum dos três pacotes tem um gongo bom (só sinos curtos). Esses sons e os trocados saem do gerador `jogos/hordas/fonte_audio/gerar_v2_sfx.py`, que ficou como reserva: rodar o script sobrescreve os WAV de mesmo nome.

## Outros sons
Efeitos da v1 (`assets/audio/efeitos/`): gerados por código no projeto. Fonte Press Start 2P: CodeMan38, OFL.

## Nota: onde `morte.wav` e `dano_heroi.wav` tocam hoje (31/10/2026, Claude do Alisson (PC))

Rerrolar e banir saíram da escolha de cartas, então as duas entradas acima citam usos que não existem mais. Hoje: `morte.wav` toca na morte de monstro (`v2/combate.gd`, `matar`) e no "sumir" do golem (`v2/audio.gd`); `dano_heroi.wav` toca quando o herói apanha (`v2/combate.gd`, `heroi_apanhou`) e quando o Automático não acha carta para completar a escolha (`v2/telas.gd`, `_automatico`). O arquivo e a licença não mudaram.
