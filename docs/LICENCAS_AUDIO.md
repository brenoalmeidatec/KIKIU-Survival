# Licenças das músicas do K.I.K.I.U

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

## O que foi feito nos arquivos
`jogos/hordas/fonte_audio/preparar_musica_cc.py` refaz tudo a partir dos MP3: corta o trecho, funde o fim no começo com crossfade de potência igual (4 s; 3 s no chefe; 6 s no horror) para o laço não estalar, ajusta o ganho a um RMS alvo (-19 a -24 dBFS), limita suavemente os picos acima de -1,5 dBFS e converte para OGG Vorbis estéreo 44,1 kHz, qualidade 4. Nenhuma outra edição (sem camadas, sem instrumentos acrescentados, sem efeitos).

Os MP3 originais não estão no repositório; baixe-os do link acima para refazer.

## Plano B
As faixas sintetizadas por código (sem licença de terceiros) estão no histórico do Git (commit anterior a "músicas de licença aberta") e o gerador continua em `jogos/hordas/fonte_audio/gerar_musica.py`.

## Outros sons
Efeitos sonoros: gerados por código no projeto. Fonte Press Start 2P: CodeMan38, OFL.
