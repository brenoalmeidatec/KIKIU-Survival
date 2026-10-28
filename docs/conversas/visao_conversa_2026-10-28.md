# Visão da conversa de 28/10/2026 (para o Alisson)

Resumo filtrado da conversa do Breno com o Claude. Tudo aqui são **ideias e decisões ditas pelo Breno**, a confirmar. A transcrição completa fica em `docs/conversas/conversa_2026-10-28.md`.

## Visão
- **Nicho:** survival + Souls + Undertale. O jogo não vai ser um Resident Evil. A ideia é pegar o nicho e fazer bem produzido e elaborado.
- **Referências:** Vampire Survivors (estrutura de horda e auto-ataque), Undertale (a alma no meio do boneco e o combate), bullet hell tipo Touhou (dano só no ponto), Odin Sphere (história contada por personagem), Nightreign (fases que mudam conforme o chefe final), Path of Exile 2 (árvore de habilidades), Balatro (desbloqueios).
- **Aparência:** top-down na jogabilidade, com a ilusão de isométrico nos movimentos dos inimigos.
- **Diferencial:** combate que pune erro (soulslike) sem virar só dar parry.

## Lore
- **Heróis sem memória.** Não sabem quem são, de onde vêm, o que fazem ali nem onde estão.
- **Entropia da Miséria.** Entidade cósmica que destruiu o mundo deles e os conceitos da realidade. Não restou nada além da vontade dos heróis.
- **"Eu não aceito".** A essência de cada herói resiste ao fim. Aparece como um foguinho no meio de cada boneco. É a força de vontade que faz eles levantarem.
- **Resgate.** O personagem principal escolhe um herói no começo e vai resgatando os outros. Cada resgate libera a história daquele herói.
- **Memórias liberam poderes.** Ao resgatar as memórias, os heróis reaprendem o que são e liberam poderes.
- **Sem tutorial.** No máximo uma descrição de flavor. Exemplo: "a frieza dessa espada não me é estranha", e aí o golpe congela.
- **Cutscenes só mais tarde.** No começo ninguém deve saber que existe uma história.
- **Tom do mundo.** Pós-apocalipse, com terra e rochas voando, como se algo tivesse abstraído a matéria.
- **Lore espalhada.** Estátuas que o jogador examina e fragmentos que ele acha. Tem que variar muito, para não ficar óbvio.

## Combate
- **Só o ponto tem hitbox.** Personagem e inimigos são pontos no meio do boneco. O corpo é só representação visual.
- **Ataque manual por padrão.** O jogador aperta o botão para atacar.
- **Auto-ataque é opção (padrão desligado).** Quem ativa não ataca clicando. Se o jogador esquivar, o próximo auto-ataque tem um delay.
- **Ataques de cima e invocações** rodam automaticamente de qualquer jeito, por serem fora do controle do jogador.
- **Parry.** Recupera estamina, empurra o inimigo e causa dano forte. O frame exato ainda vai ser definido.
- **Aviso de cor:** amarelo = dá para parry ou esquivar (pisca amarelo antes do golpe). Vermelho = só dá para esquivar (pisca vermelho).
- **Área azul do chefe:** o golpe de área fica azul antes de acertar. Se o jogador estiver dentro dela e der parry no momento azul, o chefe fica stunado.

## Chefes
- **Todo chefe é "devorador de alguma coisa"**, são servos da entidade e as estruturas que causaram o apocalipse (arquétipos).
- **Lobo:** devorador da carne (lobo das trevas, sorrateiro e sombrio, ideia original da floresta).
- **Aranha:** devoradora da estabilidade (surgiu no lugar do lobo, a confirmar em qual fase fica).
- **Devorador das raízes (floresta):** chefe final da floresta. A morte da natureza, com as raízes ficando maiores.
- **Devorador da visão (cidade):** chefe final da fase da cidade, aparece pelos olhos.
- **Chefes subchefes** também têm o ponto e o golpe de área.

## Fases
- **Fases que mudam conforme o chefe final.** Inspiração: Nightreign. A mesma fase volta em outra sequência, com algumas coisas diferentes, e cada sequência tem um chefe diferente. O jogador volta várias vezes.
- **Inimigos cada vez mais temáticos,** conforme se aproxima do chefe.
- **Ilhas flutuantes:** o personagem pula de uma ilha para outra. Tem borda. Inimigos voadores e pedaços de ilha caindo do espaço.
- **Cidade com olhos:** estrelas no céu que ficam vermelhas conforme as waves avançam, e viram olhos. Indício visual do chefe final.
- **Seletor de mapa psicodélico,** também para facilitar a geração de imagem por IA.

## Progressão
- **Árvore de habilidades estilo Path of Exile 2.** Cada personagem tem a sua. Só dá para aumentar algumas skills.
- **Subir de nível aumenta a probabilidade** da habilidade aparecer. Não garante.
- **Fusões de habilidades** (ex.: upgrade 3).
- **Desbloqueios estilo Balatro.** Um fragmento ou estátua libera arma ou habilidade, a não ser que o jogador cumpra outra condição.

## Próximos passos
- Aprofundar a história fase a fase. O rascunho ainda é inicial.
- Definir as mecânicas: auto-ataque, árvore de habilidades, fusões e desbloqueios.
- Definir a janela do parry (frame), o tempo do aviso amarelo e vermelho, e a área azul do chefe.
- Confirmar qual chefe fica em qual fase (lobo e aranha, em especial).
- Arte, animação e direção: com o Alisson.

## Ideias de outra fonte (a confirmar)
- **Remote Play Together** (Steam, citado pelo coordenador como exemplo): o jogo roda no PC do Breno, e o amigo joga com controle pela internet sem instalar.
