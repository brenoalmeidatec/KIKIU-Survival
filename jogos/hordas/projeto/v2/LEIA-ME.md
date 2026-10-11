# v2: a base jogável do mundo (primeira leva)

A v2 cresce sobre o protótipo 2.5D (`prototipos/cara_nova.*`, congelado como referência). A v1 (`main.tscn`, `arena.gd`) está pausada.

Rodar: `godot --path jogos/hordas/projeto res://v2/mundo.tscn` (ou `-- --v2` no jogo). Opções após `--`: `--fotos=PASTA --seq=2.0 --pos=x,y --nome=foto`, `--medir`, `--sombra=baixa|media|alta`, `--particulas=nenhuma|poucas|medias|muitas`, `--sem_vsync`, `--sem_normal`, `--rotulo`. Modo livre: WASD ou analógico anda, o mouse mira, clique esquerdo golpeia (segurar repete o combo), Espaço esquiva, Shift corre (gasta o mesmo fôlego), 1/2/3 trocam a sombra, F1 esconde a depuração, Esc sai.

| Arquivo | O que faz |
|---|---|
| `mundo.gd/.tscn` | Monta tudo e roda a ordem do quadro. `mover(ator, desejado)` é o ponto único de movimento (colisão + área andável). `avancar(dt)` é um passo do mundo (os testes usam passos fixos). |
| `apresentacao.gd` | SubViewport 960x540 + shader sharp bilinear; devolve à janela o modo de escala ao sair. |
| `camera_mundo.gd` | Segue o herói com suavização, presa nos limites do mapa, posição arredondada em pixel inteiro. |
| `cenario.gd` | Carrega `dados/v2_floresta.json`: chão, decalques, objetos (com normal map, sombra e colisão) e luzes dos objetos. Decalques e objetos ficam em blocos de 160 px; bloco fora da tela (+200 px) fica escondido. |
| `luzes.gd` | PointLight2D com orbe e partículas. Luz fora da tela fica desligada; as ligadas alimentam as sombras. |
| `sombras.gd` | Sombra por cisalhamento (modos baixa, média e alta, opção "sombras" da aba Gráficos). Só ator na tela (+96 px) tem sombra. |
| `atmosfera.gd` | Vaga-lumes, folhas, fogo e faíscas; quantidade pela opção "particulas_sim". Fogo fora da tela fica parado. |
| `ator.gd`, `heroi.gd`, `monstro.gd`, `sprites.gd`, `entrada.gd` | Herói (8 direções, mira no mouse, tocha), monstros (vagam e perseguem) e as folhas de sprites. `Heroi.atacar()` é o gancho do golpe (ação `atacar`), vazio. |
| `combate.gd`, `efeitos.gd`, `orbes.gd`, `progresso.gd`, `diretor.gd`, `telas.gd`, `audio.gd` | Combate e laço de jogo (leva 2): golpe de katana no clique (combo de 3), hit-stop, flash, empurrão, números de dano, tremor, partículas e luz do corte (tudo em pool), vida e morte dos monstros (pool que renasce), orbes de XP, nível com escolha de 1 entre 3 melhorias, combo de abates, diretor de ondas fora da tela e telas simples (escolha, resultado, depuração com F1). Números em `dados/v2_combate.json`. Sons em `assets/audio/v2/`, gerados por `fonte_audio/gerar_v2_sfx.py`. |
| `roteiro.gd` | Opções de medição e fotos: `--imortal --robo --estresse=N --roteiro=combate|correr`. |
| `colisao.gd` | Grade estática, círculo contra elipse, deslizando (outro agente, PR #170). |
| `medir_fps.sh`, `fps.txt` | Mede o fps parado no santuário (sombra média e alta, 3 repetições, sem V-Sync). |

Dados: `dados/v2_floresta.json` (mapa 2880x1620). Foi montado por `fonte_arte/gerar_v2_floresta.py` (semente fixa) como ponto de partida; depois disso o JSON é a fonte e pode ser editado à mão.

Testes: `testes/v2_mundo.tscn` (`v2_mundo falhas=0`) e `testes/v2_combate.tscn` (`v2_combate falhas=0`).
