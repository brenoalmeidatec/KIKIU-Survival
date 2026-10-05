# K.I.K.I.U: personagens, armas, builds, cartas, equipamentos visuais, transformações e descobertas

> **Texto do Breno, copiado na íntegra (2026-10-05).** Nenhuma regra foi resumida ou removida.
> Vale para o jogo de horda (K.I.K.I.U, `jogos/hordas`). O jogo da Cairu (`jogos/cairu`) não muda: lá o personagem "Breno" continua existindo.
> Acompanhamento em 3 issues ligadas: arquitetura (seções 1 a 15), dragão (seções 8, 9, 10, 13, 25, 26) e descobertas do mundo (seções 16 a 31).

---

Quero que você implemente/estruture no meu jogo um novo sistema de personagens, armas, builds, cartas, equipamentos visuais e transformações.

O jogo é inspirado no gênero de sobrevivência por hordas, no estilo Vampire Survivors/Vampire Survival: o personagem se movimenta pelo mapa, enfrenta grandes quantidades de inimigos, coleta recursos/experiência, escolhe melhorias através de cartas e, ao final, pode enfrentar inimigos ou chefes mais fortes.

O projeto ainda está em desenvolvimento. Atualmente, considere que teremos aproximadamente 10 personagens jogáveis, mas esse número deve ser facilmente expandível no futuro.

## 1. PERSONAGEM PRINCIPAL — HAZAKI

Existe atualmente um personagem chamado “Breno”.

Altere o nome desse personagem para:

HAZAKI

Não quero mais nenhuma referência ao nome “Breno” no sistema do personagem. O identificador interno também deve ser preparado para trabalhar com “Hazaki”.

Hazaki será um personagem especial com uma identidade própria baseada em:

* Samurai
* Artes marciais
* Poderes elementais/mágicos
* Armas de fogo
* Energia/Aura
* Transformação em dragão

As habilidades exclusivas dele devem ser acessíveis SOMENTE ao Hazaki.

## 2. SISTEMA DE ARMAS EXCLUSIVAS

Cada personagem do jogo deverá poder possuir aproximadamente 5 armas/habilidades exclusivas próprias.

Porém, existe uma regra muito importante:

Durante uma partida, o jogador poderá equipar no máximo 2 armas exclusivas do personagem.

Exemplo:

Hazaki possui 5 armas exclusivas:

1. Poder Elemental de Mago
2. Katana Samurai
3. Duas Desert Eagles
4. Arte Marcial
5. Aura de Energia

Se o jogador encontrar a Katana e posteriormente encontrar a Aura, poderá equipar as duas.

Depois disso, as outras armas exclusivas do Hazaki não poderão ser escolhidas naquela partida.

As armas exclusivas devem aparecer através do mesmo sistema de cartas aleatórias usado pelas demais armas.

IMPORTANTE:

* As armas exclusivas devem ser identificadas internamente como character_exclusive.
* Cada arma deve possuir um characterId.
* Uma arma exclusiva do Hazaki nunca deve aparecer para outro personagem.
* O sistema deve ser facilmente extensível para criar armas exclusivas dos outros personagens futuramente.
* O limite de 2 armas exclusivas deve ser configurável.

## 3. ARMAS EXCLUSIVAS DO HAZAKI

### 3.1 Poder Elemental do Mago

Uma habilidade baseada em magia elemental.

Ela deve começar relativamente simples e evoluir conforme recebe upgrades.

Pode trabalhar com elementos como:

* Fogo
* Raio
* Gelo
* Energia

O sistema pode fazer com que os elementos sejam alternados ou combinados conforme os upgrades.

Exemplo de evolução:

Nível inicial:

* Pequenos projéteis mágicos.

Níveis superiores:

* Mais projéteis.
* Maior dano.
* Maior velocidade.
* Explosão no impacto.
* Combinação elemental.
* Área de efeito.

A aparência deve ser visualmente impactante, mas sem poluir excessivamente a tela.

---

### 3.2 Katana Samurai

A principal arma de combate corpo a corpo do Hazaki.

O Hazaki deve sacar uma katana e realizar ataques rápidos.

Quero uma sensação de samurai extremamente ágil.

Possíveis evoluções:

* Golpes mais rápidos.
* Maior alcance.
* Cortes em arco.
* Corte em múltiplos inimigos.
* Dash seguido de corte.
* Corte de energia à distância.
* Ataque circular.
* Golpe extremamente poderoso com cooldown maior.

Quando a Katana estiver equipada, o personagem deve realmente aparecer segurando a katana.

---

### 3.3 Duas Desert Eagles

Hazaki utiliza duas Desert Eagles simultaneamente.

Ele deve atirar utilizando as duas armas.

O sistema deve tratar isso como uma única arma/habilidade exclusiva.

Possíveis evoluções:

* Mais velocidade de disparo.
* Mais dano.
* Tiros perfurantes.
* Ricochete.
* Tiros explosivos.
* Disparos simultâneos em vários alvos.
* Munição energética em níveis superiores.

As duas pistolas devem aparecer visualmente nas mãos do personagem quando a habilidade estiver equipada.

---

### 3.4 Arte Marcial

Uma arma/habilidade sem arma física.

Hazaki luta utilizando apenas os próprios punhos e técnicas de artes marciais.

Não deve existir espada, arma ou objeto nas mãos.

A ideia é que o personagem execute:

* Socos
* Chutes
* Combos
* Golpes rápidos
* Investidas
* Ataques circulares
* Impactos de energia

Conforme evolui, os golpes devem ficar mais fortes e visualmente mais impressionantes.

Exemplo de evolução:

Nível inicial:

* Soco curto contra inimigos próximos.

Níveis avançados:

* Combo automático.
* Chutes circulares.
* Onda de impacto.
* Dash.
* Golpes em área.
* Explosões de energia causadas pelos golpes.

---

### 3.5 AURA

A Aura será uma das habilidades mais especiais do Hazaki.

Quero uma transformação visual de energia ao redor do personagem, inspirada na sensação de uma transformação de anime em que o personagem libera uma quantidade enorme de energia.

NÃO copie visualmente nenhum personagem específico de outra obra.

Crie uma identidade visual própria para o Hazaki.

Quando ativada:

* Uma aura energética aparece ao redor do corpo.
* A energia deve circular o personagem.
* Pode existir um círculo/onda de energia expandindo ao redor dele.
* O personagem pode realizar uma animação de expansão de poder.
* Inimigos próximos podem receber dano ou ser empurrados.
* A aura pode pulsar periodicamente.
* Quanto maior o nível, mais intensa e complexa fica a energia.

Quero uma sensação de:

“Agora o Hazaki ficou muito mais poderoso.”

A habilidade deve ser visualmente marcante.

## 4. ARMAS GLOBAIS

Além das armas exclusivas, existirão armas globais.

Essas armas podem ser utilizadas por qualquer personagem.

Exemplos de armas globais:

* Machado arremessável
* Arco
* Bumerangue
* Lança
* Adaga
* Projéteis mágicos genéricos
* Bombas
* Orbes
* Correntes
* Outras armas tradicionais de jogos de sobrevivência por hordas

As armas globais não pertencem a nenhum personagem específico.

Estrutura conceitual:

global

ou

character_exclusive

O sistema de seleção deve saber diferenciar os dois tipos.

## 5. SISTEMA DE CARTAS

As armas devem aparecer através de cartas aleatórias.

Quando o jogador sobe de nível ou recebe uma oportunidade de upgrade:

* O jogo apresenta cartas.
* Cada carta representa uma arma, habilidade ou upgrade.
* As cartas são aleatorizadas.
* O sistema deve respeitar as regras de compatibilidade do personagem.

Para Hazaki:

* Cartas de armas globais podem aparecer normalmente.
* Cartas exclusivas do Hazaki podem aparecer.
* Cartas exclusivas de outros personagens NÃO podem aparecer.
* Depois que Hazaki atingir o limite de 2 armas exclusivas, nenhuma outra arma exclusiva dele deve aparecer.

IMPORTANTE:

O sistema deve evitar oferecer cartas impossíveis de usar.

## 6. SISTEMA DE EQUIPAMENTOS VISUAIS

Quero que as armas e equipamentos não sejam apenas estatísticas.

Eles devem aparecer VISUALMENTE no personagem.

Por exemplo:

Se existir uma carta:

“Armadura do Samurai”

e o jogador escolher essa carta:

O Hazaki deve realmente vestir a armadura.

Não quero apenas:

+20 Defesa

Quero que o personagem mude visualmente.

Sistema modular de equipamentos

Crie o personagem utilizando partes/equipamentos modulares.

Exemplo:

* Cabeça
* Cabelo
* Rosto
* Pescoço
* Peitoral
* Braços
* Mãos
* Pernas
* Pés
* Arma direita
* Arma esquerda
* Acessórios
* Aura
* Efeitos especiais

Assim, diferentes equipamentos podem ser combinados.

Exemplo:

O personagem encontra:

Cabeça do Guerreiro

Equipou.

Depois encontra:

Armadura Samurai

Equipou.

Resultado:

O personagem aparece utilizando simultaneamente:

* Cabeça do Guerreiro
* Armadura Samurai

Não deve substituir automaticamente a cabeça quando a armadura for equipada.

Cada equipamento deve ocupar seu próprio slot/categoria.

## 7. COMPATIBILIDADE VISUAL

Esse sistema precisa evitar combinações visualmente quebradas.

Se o jogador combinar:

* Cabeça A
* Peitoral B
* Braço C
* Arma D

o jogo deve tentar fazer com que tudo pareça pertencer ao mesmo personagem.

Evitar:

* Equipamentos atravessando o corpo.
* Mãos aparecendo dentro das armas.
* Cabeças flutuando.
* Armaduras desconectadas do corpo.
* Escalas diferentes.
* Cores extremamente incompatíveis.
* Equipamentos posicionados incorretamente.

O sistema deve ser pensado como um sistema modular de personagens.

## 8. SISTEMA DE TRANSFORMAÇÃO — DRAGÃO

Hazaki terá uma transformação exclusiva.

Ele poderá se transformar em um dragão inspirado na ideia de um dragão oriental lendário, com aparência própria.

Não quero copiar exatamente Shenlong ou qualquer personagem protegido.

A inspiração é:

* Dragão oriental
* Corpo alongado
* Escamas
* Energia sobrenatural
* Presença poderosa
* Elemento místico

A transformação deve ser exclusiva do Hazaki.

Quando ativada:

1. O personagem realiza uma animação de transformação.
2. O corpo humano desaparece/substitui-se progressivamente.
3. O dragão aparece.
4. O jogador passa a controlar o dragão.
5. A aparência das habilidades muda para combinar com a forma de dragão.

O dragão não precisa ser gigantesco.

Ele deve ser grande o suficiente para ficar claro que o personagem se transformou em um dragão, mas continuar funcionando bem na gameplay.

## 9. ARMAS/HABILIDADES DO DRAGÃO

Quando estiver transformado, o Hazaki terá habilidades próprias da forma de dragão.

Baforada de fogo

O dragão dispara uma poderosa rajada de fogo pela boca.

Pode evoluir para:

* Maior alcance.
* Maior largura.
* Maior dano.
* Queimadura.
* Explosão.
* Cone maior.

Garras

Ataques físicos utilizando as garras.

Podem atingir vários inimigos próximos.

Energia dracônica

O dragão pode disparar ou liberar energia sobrenatural.

Pode ser:

* Projétil.
* Onda.
* Explosão.
* Ataque em área.

Rugido do Dragão

Uma habilidade de área.

O dragão ruge e libera uma onda de energia capaz de:

* Causar dano.
* Empurrar inimigos.
* Atordoar inimigos mais fracos.

Investida

O dragão avança rapidamente pelo mapa, causando dano aos inimigos atingidos.

## 10. TRANSFORMAÇÃO NÃO DEVE QUEBRAR O SISTEMA DE ARMAS

As armas humanas do Hazaki devem ser tratadas separadamente das habilidades da forma de dragão.

Ao transformar:

* O equipamento visual humano deve ser ocultado temporariamente.
* As habilidades do dragão entram em funcionamento.
* Ao retornar à forma humana, os equipamentos anteriores devem voltar exatamente como estavam.

Exemplo:

Antes da transformação:

Hazaki:

* Cabeça do Guerreiro
* Armadura Samurai
* Katana
* Aura

Transforma-se:

Forma Dragão:

* Modelo do dragão
* Baforada
* Garras
* Energia
* Rugido

Retorna:

Hazaki volta a aparecer com:

* Cabeça do Guerreiro
* Armadura Samurai
* Katana
* Aura

## 11. ARQUITETURA EXPANSÍVEL

Não quero que esse sistema seja construído especificamente de forma “hardcoded” apenas para Hazaki.

Preciso que a arquitetura permita futuramente:

Character:

* Hazaki
* Personagem 2
* Personagem 3
* Personagem 4
* …
* Personagem 10+

Cada personagem poderá possuir:

* Nome
* ID
* Modelo
* Animações
* Armas exclusivas
* Transformações
* Equipamentos exclusivos
* Habilidades passivas
* Efeitos visuais

Exemplo conceitual:

Character
→ Hazaki

Weapons
→ Global Weapons
→ Hazaki Exclusive Weapons

Transformations
→ Hazaki Dragon Transformation

O sistema deve ser orientado para dados/configuração sempre que possível, evitando duplicação de código.

## 12. REGRA PRINCIPAL DA GAMEPLAY

Durante uma partida:

Máximo de 2 armas exclusivas do personagem.

Todas as outras armas podem ser globais.

Exemplo:

Hazaki possui:

* Katana
* Aura

Essas são suas duas armas exclusivas.

A partir daí ele pode continuar pegando:

* Machado
* Arco
* Bumerangue
* Lança
* Adaga
* etc.

Mas NÃO pode pegar:

* Poder Elemental
* Desert Eagles
* Arte Marcial

porque já atingiu o limite de duas armas exclusivas.

## 13. TRANSFORMAÇÃO

A transformação em dragão deve ser considerada uma mecânica especial separada do limite de armas exclusivas.

Ela não deve contar como uma terceira arma exclusiva.

O jogador pode possuir suas duas armas exclusivas e ainda desbloquear/usar a transformação do dragão, conforme as regras de progressão definidas pelo jogo.

## 14. OBJETIVO FINAL

Quero que o resultado tenha uma sensação de progressão muito forte.

O jogador deve começar com Hazaki relativamente simples e, durante a partida, ir construindo uma versão cada vez mais poderosa dele.

Exemplo:

Hazaki começa com aparência normal.

Depois:

→ encontra Katana
→ visualmente equipa a Katana

→ encontra Armadura Samurai
→ veste a armadura

→ encontra Cabeça do Guerreiro
→ equipa a cabeça sem remover a armadura

→ encontra Aura
→ começa a liberar energia ao redor do corpo

→ desbloqueia transformação
→ transforma-se em dragão

→ dragão recebe fogo, garras, energia e rugido

A evolução deve ser tanto:

mecânica + estatística + visual.

Não quero que os equipamentos sejam apenas números.

Quero que o jogador consiga OLHAR para o personagem e perceber imediatamente quais equipamentos, armas e poderes ele possui.

## 15. IMPORTANTE SOBRE IMPLEMENTAÇÃO

Antes de modificar grandes partes do projeto:

1. Analise a arquitetura atual.
2. Identifique como personagens são armazenados.
3. Identifique como armas são armazenadas.
4. Identifique como cartas/upgrades são gerados.
5. Identifique como equipamentos visuais são renderizados.
6. Identifique como animações funcionam.
7. Identifique como transformações poderiam ser implementadas.
8. Reutilize sistemas existentes sempre que possível.

Não reescreva sistemas que já funcionam sem necessidade.

Implemente esse sistema de maneira modular e preparada para expansão.

Se alguma parte da arquitetura atual não suportar corretamente esse sistema, adapte a arquitetura antes de implementar a funcionalidade.

Priorize:

* Código limpo
* Modularidade
* Escalabilidade
* Performance
* Fácil criação de novos personagens
* Fácil criação de novas armas
* Fácil criação de novas transformações
* Compatibilidade com o sistema de cartas existente
* Compatibilidade com o sistema de equipamentos existente

Ao finalizar, explique de forma objetiva:

1. O que foi alterado.
2. Quais arquivos/sistemas foram modificados.
3. Como funciona o limite de 2 armas exclusivas.
4. Como o sistema identifica armas globais e exclusivas.
5. Como funciona o sistema modular de equipamentos.
6. Como a transformação do Hazaki funciona.
7. Como adicionar futuramente outro personagem com suas próprias 5 armas exclusivas e transformação.

## 16. SISTEMA DE DESCOBERTA E HABILIDADES ESPECIAIS

Não quero que todas as habilidades e poderes do jogo sejam obtidos através das cartas.

Algumas habilidades extremamente especiais devem possuir métodos próprios de desbloqueio durante a partida.

A ideia é criar momentos de exploração, risco, RNG e descoberta.

O jogador deve sentir:

“Será que nessa partida eu vou conseguir encontrar isso?”

e não:

“Em toda partida eu simplesmente pego essa habilidade quando chegar no nível X.”

---

## 17. TRANSFORMAÇÃO DO DRAGÃO — DESBLOQUEIO POR SANTUÁRIOS

A transformação de dragão do Hazaki NÃO deve aparecer como uma carta comum.

Ela deve ser uma habilidade especial que precisa ser descoberta durante a partida.

Uma possibilidade é criar Santuários do Dragão espalhados pelo mapa.

Porém, NÃO quero que eles apareçam obrigatoriamente em todas as partidas.

O sistema deve trabalhar com RNG.

Exemplo:

Uma partida pode ter:

* 0 santuários
* 1 santuário
* 2 santuários
* 3 santuários

dependendo da seed/RNG da partida.

A chance pode ser configurável.

Isso significa que haverá partidas em que o jogador simplesmente não conseguirá desbloquear a transformação do dragão.

Isso é intencional.

---

## 18. SANTUÁRIOS

Os santuários devem parecer estruturas especiais no mapa, diferentes dos elementos normais.

Podem possuir:

* Arquitetura oriental.
* Pedras antigas.
* Símbolos de dragão.
* Energia flutuando.
* Partículas.
* Uma aura misteriosa.
* Um pequeno altar.

Quando o Hazaki se aproxima, o santuário pode apresentar uma interação:

“Investigar Santuário”

ou

“Canalizar Energia”

O jogador precisa interagir para ativá-lo.

Porém, encontrar um santuário NÃO significa necessariamente conseguir a transformação imediatamente.

---

## 19. SISTEMA DE FRAGMENTOS

Uma opção preferível é utilizar um sistema de fragmentos.

Cada Santuário do Dragão encontrado concede um:

Fragmento Dracônico

Exemplo:

Santuário 1:
→ Fragmento da Escama

Santuário 2:
→ Fragmento da Essência

Santuário 3:
→ Fragmento do Espírito

Quando o jogador conseguir os três:

Transformação do Dragão desbloqueada.

Isso cria uma pequena jornada dentro da própria partida.

---

## 20. RNG DOS SANTUÁRIOS

Os santuários devem ser gerados de maneira procedural/RNG.

Não coloque necessariamente os três santuários em todas as partidas.

Exemplo de configuração:

DRAGON_SANCTUARY_COUNT
0 = possível
1 = possível
2 = possível
3 = possível

A distribuição deve ser configurável.

Também pode existir uma regra de segurança para evitar uma experiência frustrante demais.

Por exemplo:

* Chance baixa de aparecer.
* Se aparecer, localização aleatória.
* Distância mínima entre santuários.
* Não aparecer diretamente ao lado do jogador.
* Não aparecer sempre no mesmo ponto do mapa.

---

## 21. SANTUÁRIOS COMO OBJETIVOS DE EXPLORAÇÃO

Os santuários devem incentivar o jogador a sair da rota normal.

Isso é importante.

O jogador está lutando contra hordas e coletando experiência.

De repente, aparece uma indicação sutil de que existe algo estranho em determinada região do mapa.

O jogador pode decidir:

“Vou continuar evoluindo meu personagem ou vou procurar o santuário?”

Isso cria uma decisão real.

Se o jogador for atrás do santuário:

* Pode encontrar inimigos mais fortes.
* Pode perder tempo de farm.
* Pode ficar cercado.
* Pode encontrar recompensas adicionais.
* Pode descobrir uma área secreta.

O objetivo não deve ser apenas “andar até o ponto”.

---

## 22. SANTUÁRIO COM DESAFIO

Alguns santuários podem exigir uma condição antes de serem ativados.

Exemplos:

Santuário do Combate

Ao interagir:

* Uma pequena arena é criada.
* Inimigos aparecem.
* O jogador precisa sobreviver durante alguns segundos.
* Depois o santuário libera o fragmento.

Santuário do Sacrifício

O jogador precisa abrir mão de alguma coisa:

* Vida temporária.
* Ouro.
* Uma recompensa.
* Uma escolha de carta.

Em troca recebe o fragmento.

Santuário da Prova

O jogador precisa derrotar um mini-chefe.

Isso pode fazer com que cada partida seja diferente.

---

## 23. NÃO REPETIR SEMPRE A MESMA EXPERIÊNCIA

É extremamente importante evitar que o sistema vire:

“Santuário → aperta botão → pega transformação.”

Quero que existam variações.

Um santuário pode:

* Ser protegido por inimigos.
* Ser um mini-desafio.
* Exigir exploração.
* Exigir uma escolha.
* Exigir derrotar um mini-chefe.
* Estar escondido.
* Aparecer em uma área perigosa.
* Exigir encontrar outro elemento antes.

O sistema deve usar RNG para determinar a variação.

---

## 24. TRANSFORMAÇÃO COMO RECOMPENSA RARA

A transformação do dragão deve ser poderosa, mas não deve transformar todas as partidas em uma experiência igual.

Ela deve ser uma espécie de:

“momento especial da run.”

O jogador não deve ter garantia de encontrar a transformação.

E mesmo quando encontrar, pode não conseguir completar todos os requisitos.

Isso cria histórias diferentes para cada partida.

Exemplo:

Run A

Nenhum santuário apareceu.

Resultado:
→ Hazaki nunca se transformou.

Run B

Apareceu um santuário.

Resultado:
→ Hazaki encontrou um fragmento, mas não conseguiu completar a transformação.

Run C

Apareceram três santuários.

Resultado:
→ O jogador explorou o mapa, conseguiu os três fragmentos e desbloqueou o Dragão.

Run D

Apareceram três santuários, mas um estava protegido por um mini-chefe.

Resultado:
→ O jogador decidiu arriscar e conseguiu uma transformação extremamente poderosa.

---

## 25. EVITAR SPAM DA TRANSFORMAÇÃO

A transformação não deve ser uma habilidade que o jogador ativa continuamente.

Depois de desbloqueada, ela deve possuir algum tipo de recurso ou condição de ativação.

Algumas possibilidades:

Energia Dracônica

O jogador acumula energia durante a partida.

A transformação consome essa energia.

Quanto mais tempo permanecer transformado:

→ mais energia consome.

Ao acabar:

→ Hazaki volta automaticamente à forma humana.

---

Medidor de Fúria Dracônica

O jogador precisa preencher uma barra realizando determinadas ações:

* Derrotar inimigos.
* Fazer combos.
* Sobreviver.
* Coletar determinados itens.

Quando a barra estiver cheia:

TRANSFORMAÇÃO DISPONÍVEL

Depois de usar:

→ a barra volta para zero.

---

Sistema híbrido

Minha recomendação é utilizar:

Fragmentos + Medidor de Energia.

Os santuários desbloqueiam permanentemente a possibilidade de transformação DURANTE AQUELA RUN.

Depois disso, o jogador ainda precisa carregar a Energia Dracônica para transformar.

Assim:

Encontrar santuários ≠ transformação infinita.

---

## 26. DURAÇÃO DA TRANSFORMAÇÃO

A transformação deve ser temporária.

Exemplo:

15–30 segundos, dependendo dos upgrades.

Durante esse período:

* Hazaki vira dragão.
* As habilidades humanas são substituídas pelas habilidades dracônicas.
* O jogador fica extremamente poderoso.
* A velocidade/dano podem aumentar.
* As habilidades do dragão possuem efeitos próprios.

Depois:

→ volta à forma humana.

Isso cria um verdadeiro momento de explosão de poder.

---

## 27. RNG DE OUTRAS ARMAS ESPECIAIS

Não quero que apenas a transformação tenha esse sistema.

Criar uma arquitetura chamada:

Rare Discoveries

ou

World Discoveries

para permitir futuramente outras descobertas especiais.

Exemplos:

Espada Lendária

Pode existir um altar raro no mapa.

O jogador precisa encontrá-lo e derrotar um guardião.

Armadura Amaldiçoada

Pode aparecer em uma masmorra rara.

Ao equipá-la:

→ ganha grande poder.

Mas também:

→ recebe uma desvantagem.

Arma Celestial

Pode aparecer através de um evento raro.

NPC Misterioso

Pode aparecer aleatoriamente.

O jogador pode trocar recursos por uma habilidade rara.

Portal Dimensional

Pode aparecer em determinadas partidas.

Pode levar para uma pequena área especial.

---

## 28. SISTEMA DE EVENTOS ALEATÓRIOS

Criar um sistema geral de eventos que possa escolher eventos diferentes para cada partida.

Exemplo:

WORLD_EVENT_POOL
DragonSanctuary
CursedShrine
LegendaryWeaponAltar
MysteryNPC
TreasureRoom
MiniBoss
DimensionalPortal
SecretArena

Cada evento deve possuir:

* Chance de aparecer.
* Condições.
* Localização.
* Recompensa.
* Dificuldade.
* Cooldown.
* Regras específicas.

Isso permite adicionar conteúdo posteriormente sem precisar alterar o sistema principal.

---

## 29. RNG COM PROTEÇÃO CONTRA REPETIÇÃO

Apesar de querer bastante RNG, NÃO quero um RNG completamente caótico.

O sistema deve possuir mecanismos para reduzir repetições ruins.

Por exemplo:

Se uma determinada descoberta apareceu várias vezes recentemente, sua chance pode diminuir.

Se nenhuma descoberta especial apareceu durante uma partida muito longa, determinadas probabilidades podem aumentar.

Isso cria um:

RNG controlado / weighted RNG

em vez de puro acaso.

O jogador deve sentir que cada partida é diferente, mas não que o jogo está simplesmente “roubando” dele.

---

## 30. PRINCÍPIO DE DESIGN

Quero seguir este princípio:

Cartas = progressão comum.

Exploração = descobertas especiais.

Santuários/eventos = momentos raros.

Transformações = momentos extremamente poderosos.

RNG = variedade entre partidas.

O objetivo é fazer com que o jogador nunca saiba exatamente qual será a build final.

Uma partida pode terminar com:

Katana + Aura + Machado + Arco.

Outra:

Desert Eagles + Arte Marcial + Bumerangue.

Outra:

Katana + Aura + Transformação Dracônica.

Outra:

Arte Marcial + Arco + Lança e nenhuma transformação.

Isso deve ser intencional.

A construção da run deve ser diferente a cada partida.

---

## 31. SISTEMA PREPARADO PARA EXPANSÃO

Não implementar o sistema pensando exclusivamente no Dragão.

Criar uma estrutura genérica para:

DiscoverableAbility

com propriedades semelhantes a:

id
name
characterId
rarity
spawnChance
requiredFragments
unlockCondition
activationType
duration
cooldown
energyCost
reward

Assim, futuramente outro personagem poderá possuir uma transformação completamente diferente.

Exemplo:

Hazaki:
→ Dragão

Personagem 2:
→ Forma Demoníaca

Personagem 3:
→ Forma Colossal

Personagem 4:
→ Invocação

Personagem 5:
→ Armadura Especial

Sem precisar criar um sistema novo para cada personagem.

---

## OBJETIVO

Quero que o jogo tenha uma sensação de descoberta.

Não quero que o jogador simplesmente fique seguindo uma lista fixa de:

“Pegue carta A → pegue carta B → pegue carta C → transforme.”

Quero que cada partida conte uma história diferente.

O jogador deve pensar:

“Será que apareceu o santuário?”

“Será que vale a pena ir atrás?”

“Será que consigo pegar os três fragmentos?”

“Será que o mini-chefe vai me matar?”

“Será que nessa run eu vou conseguir virar o dragão?”

E quando finalmente conseguir:

a transformação deve parecer um acontecimento especial da partida.

O sistema deve priorizar variedade, exploração, RNG controlado, decisões do jogador e momentos de recompensa memoráveis.
