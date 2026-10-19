# Auditoria do combate da v2 (19/10/2026)

Feita antes de mexer no código, no repositório `kikiu-survival`, branch `main` em `5b89bdc`. Só a v2 (`jogos/hordas/projeto/v2/`); a v1 está pausada.

## O projeto
- **Godot 4.4.1**, GDScript, renderizador Compatibility (no PC do trabalho roda em ANGLE sobre uma Intel HD de 3ª geração, o mesmo nível da máquina de testes).
- Mundo interno de **640x360**, filtro de textura *nearest* por padrão (`project.godot`).
- A v2 é 2D por dentro: o chão é um plano achatado (y vale 62% do x, `ACHATA = 0.62`) e os personagens são folhas de sprites em 8 direções.
  Não há 3D na v2 (o 3D com shader pixelizado é só dos chefes da v3, fora deste trabalho).

## Onde está cada coisa
| Parte | Arquivo | Como funciona |
|---|---|---|
| Herói | `v2/heroi.gd` (estende `v2/ator.gd`) | Não é `CharacterBody2D`: anda por `mundo.mover` com a colisão própria de `v2/colisao.gd`. Estados `LIVRE, GOLPE, ESQUIVA, MORTO, CARGA`. |
| Katana (golpe principal) | `heroi._iniciar_golpe` / `heroi._golpe`, `combate.golpe_comecou` / `combate.golpear`, dados em `dados/v2_combate.json > golpe.passos` | Combo de 3 (corte, corte, estocada). Cada passo tem `duracao`, `acerto_em` (fração em que o dano sai), `avanco` (lunge), `alcance`, `arco`, `empurrao`, `atordoa`, `hit_stop`, `tremor`. O dano sai **uma vez**, no quadro `acerto_em`, num cone (`combate.golpear`). |
| Visual da katana | `heroi._coluna_atual` (folha `animacoes.combo` do Blender, `quadros_por_golpe`), `efeitos.gd` (`FOLHA_CORTE`, 16 quadros 128x128 do Blender) | **Já é animação de verdade:** o corpo do herói troca de quadro pelo progresso do golpe e o rastro do corte é uma folha de 16 quadros. |
| Golpes secundários antigos | `v2/armas.gd` | Lâminas que orbitam, aura de fogo, corvos, raio em cadeia e runa. Desenho em código e sprites. |
| Golpes secundários novos | `v2/armas_novas.gd` | Projétil, nuvem, anel, meteoro, aliado, torre e granada. Um **pool fixo de 64 dicionários** (sem nó por golpe); a recarga é `st.recarga / velocidade de ataque`. |
| Invocações | `v2/andante.gd`, `v2/golem.gd` | Folhas de 8 direções com andar, ataque e impacto no quadro certo (`*_dir.png` + `*_dir.json`). Já animadas. |
| Monstros | `v2/monstro.gd`, `v2/horda.gd` | Hurtbox = o `raio` do corpo no plano achatado. |
| Dano | `combate.ferir(m, dano, dir, empurrao, atordoa, cor, numero, critico)` | Tira vida, empurra, atordoa, pisca e mostra o número. |
| Cartas | `v2/cartas.gd`, `dados/v2_cartas.json` | Stats do herói somam em `h.m_dano`, `h.m_vel_ataque`, `h.m_area`, `h.m_critico`; cada golpe é recalculado da **base + níveis** em `armas.definir_golpe` (não acumula errado). |

**Hitbox e hurtbox:** não há `Area2D`. Tudo é geometria: cone para a katana, distância no plano achatado para tiro, anel e meteoro, elipse para nuvem. Cada item guarda a lista `hit` de quem já acertou (um acerto por monstro por item). **Cooldown:** `a.t` de cada golpe, dividido pela velocidade de ataque. **Knockback:** o `empurrao` de `ferir`. **Efeitos:** `efeitos.gd` (partículas e números em pool) e o pool de partículas de `armas_novas.gd`.

## A causa do problema
O herói e as invocações já tinham quadros de animação. O que o Breno via "deslizando" eram os **golpes secundários de `armas_novas.gd`**, que usam **uma imagem parada por arma** (`assets/v2/armas/*.png`, índice `indice.json`):

- `armas_novas._sprite()` desenha o PNG inteiro **girado para o ângulo do voo** (projétil) ou **com a ponta para baixo deslizando até o chão** (meteoro, `_queda`).
- `armas_novas._area()` **estica o mesmo PNG até o raio** do golpe (nuvem e anel), com transparência.
- O aliado simples flutua com um seno; as lâminas (`armas._sprite_antigo`) são o mesmo PNG girando em órbita; os corvos usam o mesmo PNG com escala que respira.

E não havia fases: o tiro nascia **já voando e já com hitbox**, sem carga nem origem visível; o "impacto" era só o número de dano (nenhum efeito tocava no ponto do acerto); o anel e a nuvem feriam desde o primeiro instante; o meteoro acabava num círculo que esmaece.

Lacunas das cartas encontradas na mesma passada:
- O **crítico** (Olho de falcão, "+% de chance de crítico") só valia para a katana.
- **Velocidade de ataque** sem teto: com muitas cartas o preparo de qualquer golpe tenderia a zero.
- Não existia **ricochete** em nenhuma arma.
- "Arco largo" diz "+% de área **do corte**" e não chega a anel, nuvem e meteoro. Isso é desenho do jogo, não defeito: ficou como está.

## O que foi decidido
- **Técnica (etapa 2):** as armas secundárias são independentes do herói (B do pedido), então ganharam **folhas próprias com quadros novos** (tiras horizontais em `assets/v2/armas_anim/`), desenhadas pixel a pixel por código, com a imagem parada só como referência. Sem 3D, sem `AnimatedSprite2D` por item: o jogo desenha centenas de golpes num nó só (`draw_texture_rect_region`), e trocar isso por nós custaria FPS no PC fraco.
- **Controlador (etapa 3):** o sistema de golpes de `armas_novas.gd` **foi estendido**, não duplicado. Cada item ganhou a fase (`fk`: PREPARO ou ATIVO) e o tempo do preparo (`ft`); o impacto e a marca vão para um pool fixo de efeitos (`x_*`, 48 vagas).
- A katana já tinha o fluxo preparo → acerto → recuperação → combo; ganhou só a leitura pública `heroi.fase_golpe()`.
