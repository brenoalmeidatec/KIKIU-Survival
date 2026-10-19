# Vornak: sons por animação

Roteiro para gerar ou procurar os áudios depois. Cada item diz o que soa, em que quadro começa (12 fps; quadro 1 = início do clipe), a duração e as camadas. Os tempos são do clipe de animação em `sprites/vornak_sprites.json`. Nada aqui foi gravado ainda.

## Parado (idle, 24 quadros, 2 s em loop)
- **Respiração grave:** um sopro de madeira que range, em loop, no quadro 1 e no 12. Camada: rangido de tronco baixo, volume baixo.
- **Folhas caindo:** farfalhar leve a cada 8 quadros. Camada: folhagem seca, muito baixa.
- **Presença:** zumbido verde fraco e constante, só para o jogador perceber o chefe.

## Andar (walk, 25 quadros, 2 s)
- **Passos:** um impacto surdo de raiz no chão nos quadros 1, 13 (pé esquerdo e direito). Camada: terra e raiz batendo, com eco curto.
- **Rangido:** rangido de tronco a cada passo, um pouco atrás do impacto (3 quadros).

## Correr (run, 17 quadros, 1,4 s)
- **Passos rápidos:** impactos a cada 4 quadros, mais secos e fortes. Mesma camada do andar, mais alta.
- **Respiração forçada:** sopro de madeira contínuo, do quadro 1 ao 17.

## Ataque 1, raízes corrompidas (attack_01, 60 quadros, 5 s)
- **Antecipação (quadros 1 a 11):** rangido de madeira que sobe de tom, com zumbido verde. Começa no quadro 4.
- **Marca no chão (quadro 9):** tom curto de energia verde ao aparecer o anel no chão, como um sinal.
- **Golpe (quadro 22):** pancada grave de braço no chão. Começa no quadro 22, dura 0,4 s. Camada: impacto de terra, graves fortes.
- **Raízes saindo (quadros 23 a 31):** terra rachando, uma por uma, cada raiz com um estalo seco de madeira. Duração total 0,8 s.
- **Recuperação (quadros 40 a 56):** rangido de raiz recolhendo, decrescendo.

## Ataque 2, golpe de raízes (attack_02, 17 quadros, 1,4 s)
- **Armado (quadros 1 a 4):** rangido de tronco torcendo.
- **Varredura (quadro 5 a 8):** assobio de ar com estalo de madeira, do fim do arco. Começa no quadro 5.
- **Impacto (quadro 8):** onda de terra e raízes no chão, com eco baixo.

## Ataque 3, absorção de vida (attack_03, 23 quadros, 1,9 s)
- **Puxada (quadros 1 a 10):** som de sucção baixa, subindo, com zumbido verde.
- **Brilho (quadro 9):** tom alto e curto de energia convergindo.
- **Fim (quadro 18):** suspiro de madeira e silêncio de meio segundo.

## Ataque 4, segunda forma (attack_04_segunda_forma, 23 quadros, 1,9 s)
- **Preparação (quadros 1 a 8):** rugido grave começando, com eco de floresta.
- **Varredura pesada (quadros 9 a 14):** dois golpes de madeira em sequência, mais grossos que o ataque 1.
- **Impacto (quadro 14):** terra rachando em volta do chefe, com cauda de eco longa.

## Grito (grito, 36 quadros, 3 s)
- **Preparação (quadros 1 a 10):** inspiração funda, com rangido de tronco arqueando.
- **Rugido (quadros 10 a 22):** rugido grave com eco de floresta, sustentado. Começa no quadro 10. Camada 1: rugido grave; camada 2: madeira range; camada 3: eco longo.
- **Tremor (quadros 16 a 22):** o rugido treme (vibrato) enquanto a cabeça balança.
- **Volta (quadros 22 a 36):** rugido cai de volume e termina em rangido de galhos.

## Sofrer dano (hit, 7 quadros)
- **Estalo:** um estalo seco de madeira, no quadro 1. Duração 0,3 s.

## Transição de fase (phase_transition, 25 quadros, 2 s)
- **Mudança:** rugido crescente com zumbido verde, do quadro 1 ao 12.
- **Pico:** pancada grave e tremor de terra no quadro 12, com eco.
- **Calma:** silêncio com zumbido baixo até o quadro 25.

## Habilidade (ability, 21 quadros, 1,7 s)
- **Absorção:** sopro de sucção baixo e contínuo.
- **Ruído verde:** pulsos de zumbido verde a cada 4 quadros, do quadro 4 ao 17.

## Morte (death, 25 quadros, 2 s)
- **Queda:** madeira estalando e tombando, do quadro 1 ao 14.
- **Afundar:** terra cedendo, com rangido longo, do quadro 14 ao 25.
- **Silêncio:** último zumbido verde se apagando no quadro 25.

## Notas para quem gravar
- Camadas separadas facilitam misturar depois: grave, rangido, terra, zumbido verde, eco.
- Volume: o grito e o ataque 4 mais altos; passos e respiração baixos.
- Não usar som de animal real; o chefe é de madeira e energia.

## Na Godot 3D (protótipo `v3/godot/cena_3d/`)
Os tempos acima continuam valendo: os clipes do glb são os mesmos da rodada anterior (12 fps, quadro 1 = início). A lista abaixo é a dos ganchos por evento de combate (`vornak_combate.gd`); o áudio que foi de fato ligado (por quadro do clipe) está na seção "Sons sintetizados ligados na Godot 3D". Ganchos:

| Evento (sinal ou estado) | Som | Quando acontece na Godot |
|---|---|---|
| `estado_mudou("aviso")` com `raizes` | antecipação + tom da marca no chão | início do Attack_01; o indicador de 2 anéis aparece junto |
| `estado_mudou("impacto")` com `raizes` | golpe no chão + raízes saindo | quadro 22 do Attack_01 (0,9 s depois do início do aviso, com o clipe reescalado) |
| `estado_mudou("impacto")` com `golpe` | varredura + onda de terra | quadro 8 do Attack_02 |
| `estado_mudou("impacto")` com `absorcao` | brilho de energia convergindo | quadro 9 do Attack_03 |
| `estado_mudou("impacto")` com `raizes_longas` | terra rachando, eco longo | quadro 14 do Attack_04_Segunda_Forma |
| `estado_mudou("impacto")` com `tempestade` (fase 2) | pulsos de zumbido verde | quadro 12 da Ability |
| `estado_mudou("recupera")` | rangido de raiz recolhendo | resto do clipe do ataque |
| `heroi_atingido` | estalo de acerto no herói (camada nova) | uma vez por golpe |
| `chefe_atingido` em `andar` | estalo seco de madeira (Hit) | cada golpe do herói |
| `estado_mudou("stagger")` | madeira cedendo, grave | 150 de dano em 3 s |
| `estado_mudou("transicao")` | mudança + pico (Phase_Transition) e depois o rugido do Grito | ao cair abaixo de 40% da vida |
| `estado_mudou("morto")` | queda + afundar + zumbido se apagando | vida em 0 |
| Walk/Run em `andar` | passos nos quadros 1 e 13 (walk) ou a cada 4 (run) | ligados à posição da animação, não ao estado |

Novidade do 3D: a energia (fendas, olhos, boca) pulsa com a curva de intensidade de cada clipe (`assets/3d/vornak_energia.json`); o zumbido verde pode seguir essa mesma curva.

## Sons sintetizados ligados na Godot 3D (rodada de 19/10)

Sete sons próprios, gerados por script (sem arquivo de terceiros): `docs/v3/chefes/sintetizar_sons_vornak.py` (Python + numpy, semente fixa). Saída em `v3/godot/assets/audio/vornak/`, WAV mono 16 bits 22050 Hz.

| Arquivo | Como é feito | Duração |
|---|---|---|
| `passo.wav` | senoide caindo de 90 para 45 Hz + ruído de terra passa-baixa, eco curto | 0,59 s |
| `rugido.wav` | senoides de 55, 82, 110 e 165 Hz com tremor de 7 Hz + ruído rouco, eco de floresta (4 repetições) | 3,12 s |
| `estalo_madeira.wav` | ruído passa-alta com queda de 12 ms + "toc" de 420 Hz | 0,30 s |
| `terra_rachando.wav` | ruído grave com envelope longo + 26 estalos curtos aleatórios | 1,40 s |
| `zumbido_energia.wav` | senoide de 180 Hz + harmônicos, pulsando a 6 Hz | 1,00 s |
| `golpe_chao.wav` | pancada grave de 85 para 35 Hz + estouro de ruído + poeira, eco | 1,26 s |
| `succao_absorcao.wav` | ruído com passa-baixa subindo de 200 para 2600 Hz e volume crescente, corte seco | 1,30 s |

Ligação: mapa de tempo `MAPA_SONS` em `cena_3d/vornak_3d.gd` (animação -> quadro do clipe -> som). O som toca quando a posição do clipe passa pelo quadro, então segue sozinho a reescala do combate (aviso mais rápido ou mais lento). Volume por som em `SONS` (rugido e golpe no chão mais altos, passos e zumbido baixos). 8 vozes `AudioStreamPlayer` em rodízio.

| Clipe | Quadro -> som |
|---|---|
| Walk | 1 e 13 -> passo |
| Run | 1, 5, 9, 13 -> passo |
| Attack_01 | 4 -> zumbido (antecipação, com a marca no chão); 22 -> golpe no chão; 23 -> terra rachando; 25 e 28 -> estalo (raízes saindo) |
| Attack_02 | 5 -> estalo (varredura); 8 -> golpe no chão (onda de terra) |
| Attack_03 | 1 -> sucção; 9 -> zumbido (brilho) |
| Attack_04_Segunda_Forma | 1 -> rugido; 9 e 12 -> estalo; 14 -> terra rachando |
| Ability | 1 -> sucção; 4 -> zumbido |
| Hit | 1 -> estalo |
| Stagger | 1 -> estalo; 4 -> golpe no chão |
| Phase_Transition | 1 -> zumbido; 12 -> golpe no chão + terra rachando |
| Grito | 10 -> rugido |
| Death | 1 -> estalo; 14 -> terra rachando |

Ficou de fora: respiração, rangido de tronco, folhas, assobio de ar, estalo de acerto no herói e o zumbido de presença do Idle (sons sem síntese própria ainda). No Attack_01 o trecho da recuperação foi cortado (ver `VORNAK_COMBATE.md`), então o "rangido de raiz recolhendo" não teria onde tocar. O teste confere que os 7 arquivos carregam e que cada som foi disparado (contador `contador_sons`); no headless não há saída de áudio, então o som em si não foi ouvido no teste.

## Nota da rodada de 18/10 (noite)
- O ataque 1 tem 2 quadros a mais no impacto (quadro 44 da fonte segurado), o ataque 2 tem 2 a mais no impacto (quadro 8), e o ataque 4 tem 2 a mais no impacto (quadro 14). A duração desses clipes sobe um pouco; o roteiro acima segue válido, com o impacto um pouco mais longo.
