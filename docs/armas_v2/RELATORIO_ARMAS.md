# Relatório das armas da v2

Cada arma tem uma ficha com o que faz, os 4 níveis, as fusões, a esquemática (gatilho, alvo, trajetória, área, dano por nível, status, limites e a sequência de animação) e o que mudou em relação ao PR #192. As fusões têm ficha própria (`fusao_<id>.md`). O pacote de prompts para os sprites está em `PACOTE_ALISSON.md`.

As 5 primeiras armas são as originais da v2 (leva 3). As outras 45 vieram do PR #192. Os 5 tipos novos (projétil, nuvem, anel de choque, meteoro e aliado) estão implementados em `v2/armas_novas.gd`.

## Armas

| # | Arma | Tipo | Ficha |
|---|---|---|---|
| 1 | Lâminas Rodopiantes | órbita | [laminas.md](laminas.md) |
| 2 | Aura de Fogo | aura | [aura_fogo.md](aura_fogo.md) |
| 3 | Corvos Famintos | corvos | [corvos.md](corvos.md) |
| 4 | Raio em Cadeia | raio | [raio.md](raio.md) |
| 5 | Runa Explosiva | runa | [runa.md](runa.md) |
| 6 | Flechas Sombrias | projétil | [flechas_sombrias.md](flechas_sombrias.md) |
| 7 | Adagas Voadoras | projétil | [adagas_voadoras.md](adagas_voadoras.md) |
| 8 | Lança de Geada | projétil | [lanca_geada.md](lanca_geada.md) |
| 9 | Estrelas de Sombra | projétil | [estrelas_sombra.md](estrelas_sombra.md) |
| 10 | Bola de Fogo | projétil | [bola_fogo.md](bola_fogo.md) |
| 11 | Dardos Peçonhentos | projétil | [dardos_peconhentos.md](dardos_peconhentos.md) |
| 12 | Raio Solar | projétil | [raio_solar.md](raio_solar.md) |
| 13 | Bumerangue de Ferro | projétil | [bumerangue_ferro.md](bumerangue_ferro.md) |
| 14 | Bolas de Chumbo | projétil | [bolas_chumbo.md](bolas_chumbo.md) |
| 15 | Nuvem Venenosa | nuvem | [nuvem_veneno.md](nuvem_veneno.md) |
| 16 | Nevoeiro Gelado | nuvem | [nevoeiro_gelado.md](nevoeiro_gelado.md) |
| 17 | Cinzas Vulcânicas | nuvem | [cinzas_vulcanicas.md](cinzas_vulcanicas.md) |
| 18 | Fumaça Sonolenta | nuvem | [fumaca_sonolenta.md](fumaca_sonolenta.md) |
| 19 | Chuva Ácida | nuvem | [chuva_acida.md](chuva_acida.md) |
| 20 | Nevasca | nuvem | [nevasca.md](nevasca.md) |
| 21 | Nuvem de Esporos | nuvem | [nuvem_espora.md](nuvem_espora.md) |
| 22 | Cortina de Sangue | nuvem | [cortina_sangue.md](cortina_sangue.md) |
| 23 | Névoa Espectral | nuvem | [nevoa_espectral.md](nevoa_espectral.md) |
| 24 | Onda de Choque | anel de choque | [onda_choque.md](onda_choque.md) |
| 25 | Pulso Sagrado | anel de choque | [pulso_sagrado.md](pulso_sagrado.md) |
| 26 | Anel Gelado | anel de choque | [anel_gelado.md](anel_gelado.md) |
| 27 | Grito de Guerra | anel de choque | [grito_guerra.md](grito_guerra.md) |
| 28 | Terremoto | anel de choque | [terremoto.md](terremoto.md) |
| 29 | Martelo do Trovão | anel de choque | [martelo_trovao.md](martelo_trovao.md) |
| 30 | Rajada de Vento | anel de choque | [rajada_vento.md](rajada_vento.md) |
| 31 | Anel de Espinhos | anel de choque | [anel_espinhos.md](anel_espinhos.md) |
| 32 | Anel Lunar | anel de choque | [anel_luar.md](anel_luar.md) |
| 33 | Meteoro Flamejante | meteoro | [meteoro_flamejante.md](meteoro_flamejante.md) |
| 34 | Chuva de Pedras | meteoro | [chuva_pedras.md](chuva_pedras.md) |
| 35 | Cometa Gelado | meteoro | [cometa_gelado.md](cometa_gelado.md) |
| 36 | Estrelas Cadentes | meteoro | [estrelas_cadentes.md](estrelas_cadentes.md) |
| 37 | Cometa Negro | meteoro | [cometa_negro.md](cometa_negro.md) |
| 38 | Fogo do Céu | meteoro | [fogo_do_ceu.md](fogo_do_ceu.md) |
| 39 | Pedras Vulcânicas | meteoro | [pedras_vulcanicas.md](pedras_vulcanicas.md) |
| 40 | Raio Meteórico | meteoro | [raio_meteorico.md](raio_meteorico.md) |
| 41 | Chuva de Espinhos | meteoro | [chuva_espinhos.md](chuva_espinhos.md) |
| 42 | Lobo Espiritual | aliado | [lobo_espirito.md](lobo_espirito.md) |
| 43 | Espírito Raposa | aliado | [espirito_raposa.md](espirito_raposa.md) |
| 44 | Guardião de Pedra | aliado | [guardiao_pedra.md](guardiao_pedra.md) |
| 45 | Fantasma da Mata | aliado | [fantasma_mata.md](fantasma_mata.md) |
| 46 | Serpente Ardente | aliado | [serpente_ardente.md](serpente_ardente.md) |
| 47 | Espírito Urso | aliado | [espirito_urso.md](espirito_urso.md) |
| 48 | Golem de Barro | aliado | [golem_barro.md](golem_barro.md) |
| 49 | Dragãozinho | aliado | [dragao_filhote.md](dragao_filhote.md) |
| 50 | Esqueleto Guerreiro | aliado | [esqueleto_guerreiro.md](esqueleto_guerreiro.md) |

## Fusões

| Fusão | Peças (nível 3 cada, ou o que estiver indicado) | O que vira | Ficha |
|---|---|---|---|
| Anel de Brasas | aura_fogo (nv 3) + laminas (nv 3) | Seis lâminas em brasa giram dentro de um anel de fogo. | [fusao_anel_de_brasas.md](fusao_anel_de_brasas.md) |
| Revoada de Trovões | corvos (nv 3) + raio (nv 3) | Sete corvos elétricos: cada bicada solta um raio no vizinho. | [fusao_revoada_de_trovoes.md](fusao_revoada_de_trovoes.md) |
| Círculo Rúnico | runa (nv 3) + explode (nv 2) | Muitas runas, estouros enormes, e quem sobra fica lento. | [fusao_circulo_runico.md](fusao_circulo_runico.md) |
| Ventania Cortante | onda (nv 2) + fura (nv 2) | A onda fica enorme e a estocada solta três lanças em leque. | [fusao_ventania.md](fusao_ventania.md) |
| Dragão de Brasa | dragao_filhote (nv 3) + serpente_ardente (nv 3) | Três espíritos de brasa perseguem o inimigo mais perto e ferem ao tocar. | [fusao_dragao_de_brasa.md](fusao_dragao_de_brasa.md) |
| Caçada Espiritual | lobo_espirito (nv 3) + espirito_raposa (nv 3) | Lobo e raposa espirituais caçam juntos o inimigo mais perto. | [fusao_cacada_espiritual.md](fusao_cacada_espiritual.md) |
| Urso Solar | espirito_urso (nv 3) + raio_solar (nv 3) | Feixes dourados atravessam até quatro inimigos em linha reta. | [fusao_urso_solar.md](fusao_urso_solar.md) |
| Exército Esquecido | esqueleto_guerreiro (nv 3) + fantasma_mata (nv 3) | Esqueletos e fantasmas saem juntos e perseguem o inimigo mais perto. | [fusao_exercito_esquecido.md](fusao_exercito_esquecido.md) |
| Colosso de Pedra | golem_barro (nv 3) + guardiao_pedra (nv 3) | Um colosso de pedra e barro, lento e pesado, bate forte a cada segundo. | [fusao_colosso_de_pedra.md](fusao_colosso_de_pedra.md) |

As cinco fusões novas (dragão de brasa, caçada espiritual, urso solar, exército esquecido e colosso de pedra) foram aprovadas pelo Breno e estão implementadas. O balanço fino ainda não foi feito: os números são os da primeira versão.

## Mudanças e correções (desde o PR #192)

- O projétil mirava a partir do centro do herói e errava; agora mira do ponto de saída (corrigido no código).
- A lentidão das nuvens e de alguns golpes é a duração em segundos por tique (o monstro fica lento por esse tempo a cada pulso), não uma fração. As fichas foram corrigidas para isso.
- O anel gelado agora aplica lentidão no nível 4 (`lento_s`), que antes só estava no texto.
- O bumerangue não volta: o código não tem volta. A descrição e o texto do nível 5 foram corrigidos.
- Pedras vulcânicas: o nível 4 subia o alcance, que o meteoro não usa; agora sobe o raio.
- Raio meteórico: o texto do nível 5 diz que sobe a quantidade de raios por queda.
- Ventania: quando as 8 ondas estão ocupadas, a nova sobrescreve a que falta menos para acabar (antes sobrescrevia a primeira).
- Anel de Brasas: a aura agora leva o bônus de raridade, como a órbita.
- Pendências de design: a lança da ventania e a onda têm peças sem ficha própria; o campo `cor` da ventania não é lido pelo código; 10 ícones se repetem entre armas diferentes; o efeito de gelo e a queimadura de algumas armas descritas no arte não existem no código.
