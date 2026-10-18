# Arena viva do Maltherion: o que é do chefe e o que precisa do mapa

Para o Alisson (dono do mapa). O Claude do Breno não mexeu em nada de mapa. Este texto diz o que o chefe precisa do mapa, para combinar.

## O que é do chefe (já feito no protótipo v3)
- Zonas de raiz com aviso no chão (`raizes_gigantes`, `tempestade_de_raizes` em 3 zonas): `v3/chefes/maltherion.gd`, dados em `CONFIG`.
- Invocações limitadas (`max_vivas` = 3, `pode_invocar`): o chefe decide quantas saem; quem cria e posiciona as criaturas é o sistema de monstros.
- Coração da Floresta (fase 3): aviso longo de 2,2 s e janela de contra-ataque de 2,4 s.

## O que precisa do mapa (para combinar)
1. **Pontos de raiz**: uma lista de posições no mapa onde as raízes podem sair (ex.: marcadores no JSON do mapa). Hoje o protótipo sorteia posições em volta do chefe.
2. **Passagens que podem ser bloqueadas** por raízes por alguns segundos: precisa de uma forma de marcar a área (retângulo ou polígono) e de liberar depois.
3. **Árvores destrutíveis**: se o Maltherion pode quebrar árvores, cada árvore precisa de vida e de um sinal de "caiu". Não existe isso no mapa hoje.
4. **Limites do campo**: onde o chefe pode andar, para as raízes e as invocações não saírem da arena.

## Como o chefe fala com o mapa (proposta)
- O chefe emite `golpe(nome, raio, dano)` com o centro do golpe; o mapa decide quais alvos e obstáculos estão na área.
- O chefe nunca altera a geometria do mapa diretamente: pede ao mapa (ex.: `bloquear_area(...)`), e o mapa responde.

Nada disso foi ligado ao jogo: é a interface para conversar com o Alisson antes de implementar.
