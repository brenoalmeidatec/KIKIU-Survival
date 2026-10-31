# Ritmo por nível e recursos de recuperação (#371)

`dados/v2_ritmo.json` contém todas as curvas e probabilidades. O módulo `ritmo.gd`
usa pool fixo de quatro posições, criado na montagem: dois corações, um ímã e um
Guardião de Pedra curandeiro. As imagens são reutilizadas dos ícones de cartas e
da folha direcional do aliado já registrado em `docs/LICENCAS_ARTE.md`; o guardião
usa o quadro parado 2 da primeira linha, com pé e tamanho da ficha `Andante`.
Um coração acima da cabeça e o anel verde indicam aliado. Não há dano nem navegação.
A cura no chão é representada por coração; não foi criada arte de fruta.

Para nível `n`, cada curva aplica `1 + min(por_nivel * max(n-1, 0), teto)`:

| Regra | Por nível | Teto | Nível 20 |
|---|---:|---:|---:|
| Raio de coleta | 2,5% | +75% | 1,475× |
| Dano do Q | 3,5% | +100% | 1,665× |
| Raio/largura/alcance do Q | 1,25% | +35% | 1,2375× |
| Taxa e limite de inimigos | 0,5% | +15% | 1,095× |
| Chance do ímã | 2% | +50% | 1,38× |

Coleta compõe o bônus das cartas; densidade compõe dificuldade e Pesadelo,
preservando o teto técnico do diretor. A carga, duração e quantidade de projéteis
do Q permanecem as anteriores. Cada disparo copia seu bloco de dados e captura
os fatores uma vez; subir de nível durante o disparo não aumenta o mesmo Q.
O catálogo e os modificadores do herói não são alterados. Há três caminhos
mecânicos (Hazaki, Nicão e Lucas); Matheus reutiliza o arquétipo no #394, cuja
cobertura visual continua separada.

A cura por nível vale 80% da base anterior (12% → 9,6% da vida máxima).
Coração cura 8% da vida máxima, tem chance base 0,8% por abate, intervalo mínimo
8 s, até dois no chão e duração 20 s. Para fração de vida `v`, coração e curandeiro
multiplicam a chance por `1 + 3*(1-v)^2`: menos vida aumenta a oferta.
O curandeiro tem chance base 0,1%, intervalo 90 s, até um por vez, duração 12 s,
raio 64 px e cura contínua de 2%/s até 12% da vida máxima. Só a cura efetiva gasta
esse orçamento; vida cheia não o consome. O ímã tem chance base 0,15%, intervalo
35 s e duração 25 s. Ao coletar, atrai somente almas dentro da parte visível da
TextureRect, respeitando crop, câmera e zoom. Não cria XP nem coleta fora da tela.

Esses números são uma hipótese conservadora de partida, não balanço humano
aprovado. Os limites evitam cascatas de drops, cura ilimitada e crescimento de
pool durante o combate. Contadores de oferta, coleta, cura efetiva e almas
atraídas aparecem no JSON do robô. As curvas não alteram a política da IA;
esta branch herda os consertos de borda e vigia do #397, aplicados também à
referência da comparação. Os dois lados usam `--playtest_q`, mesmas sementes,
mapas e dificuldade; o [resumo histórico e o anexo de evidências](../../../../docs/qa/ritmo371/README.md) registram dados e limites.
O RNG de drops é próprio: com `--semente`, deriva `semente+371`; sem ela, randomiza.
Pausa congela duração/intervalos, término esconde itens e reinício limpa contadores.

`v2_ritmo` cobre curvas/tetos, RNG, pool, cura/aliado, pausa, expiração, reinício,
crop 16:9/4:3/ultrawide com transformação de câmera e acertos reais de todos os
caminhos do Q nos níveis 1, 20 e 500, inclusive onda e rodada final.
A cena usa fixture explícita antes de montar o Mundo nesta base empilhada sobre
#390. A proteção anterior ao autoload Config depende da integração do #391;
o APPDATA local de QA é exclusivo. A prova de isolamento completo está no #391.

## Velocidade da partida (1,25x)

`velocidade_partida` em `dados/v2_ritmo.json` (hoje 1,25) acelera o relógio do **mundo**:
`combate.passo_tempo` multiplica o dt do mundo e o do herói local, então monstros, herói,
armas, recargas, ondas, XP e o tempo de partida andam 25% mais rápido por segundo real. Não se
usa `Engine.time_scale`, porque ele aceleraria também a interface, os tweens de UI e a pausa.
Ficam em tempo real: a tela de cartas e o baú (o dt do mundo já é 0), a pausa, o menu, o
resultado, o áudio (sem mudança de tom) e os contadores de hit-stop e câmera lenta (a câmera
lenta multiplica o fator, não o sobrescreve). Nos testes (`modo_teste`) o fator é 1,0 para os
tempos medidos em segundos não mudarem; `v2_velocidade` prova o 1,25 numa partida de verdade.
Dano, cura e XP por evento não mudam: o que muda é quantos eventos cabem por segundo real.
