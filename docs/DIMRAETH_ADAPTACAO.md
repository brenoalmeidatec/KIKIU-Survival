# Dimraeth → K.I.K.I.U: o que adaptar (#68)

Pesquisa do Claude do Alisson (notebook), 2026-10-06. Não copiamos arte, sprites nem sons: a ideia é aprender o que funciona e refazer no nosso estilo (cavaleiros no caos, dark fantasy, pixel art feito no Blender).

## O que o Dimraeth é (conferido)
- Action-RPG **top-down** em pixel art desenhado à mão, da Mudtek, em acesso antecipado desde 15/09/2026. Combate "souls-lite": **stamina** que paga ataque, bloqueio e esquiva, e também funciona como postura (dá pra desequilibrar e ser desequilibrado); inimigos **telegrafam** os ataques; posicionamento importa.
- A esquiva é um **rolamento que cobre bastante distância**. Tem bloqueio com bônus pro bloqueio perfeito e resposta "apertada" (tight responsiveness).
- **Ambientação:** a **luz dinâmica** muda o clima, e a floresta vai de convidativa a ameaçadora. Cavernas sombrias passam incerteza; há florestas viçosas e ambientes "corrompidos". Mesmo com muita magia explodindo, a tela fica legível graças às **marcas de telegrafia** e às animações claras.

Fontes: [análise da GameCritix](https://gamecritix.co.uk/dimraeth-review/), [impressões do Wand Report](https://report.wand.com/previews/dimraeth-early-access-impressions), [análise da Insert Coins](https://insertcoins.press/en/articles/dimraeth-test), [TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Dimraeth).

## O que entra no K.I.K.I.U
O K.I.K.I.U é um survivors (centenas de inimigos), não um souls. Então adaptamos o **sentimento**, sem travar o ritmo da horda.

### Ambientação, por região (vai junto da arte das regiões, #64)
- **A luz conta a história da região.** Cada região tem sua cor de luz e de sombra (`ambiente` no `dados/regioes.json`). A luz **escurece andar a andar** até o chefe: a fase 1 é convidativa e a fase do chefe é ameaçadora, como a floresta deles.
- **Clima e partículas por região:** vaga-lumes e folhas caindo (floresta), névoa baixa e chuva (pântano), areia ao vento e calor tremendo (deserto), neve e nevasca (gelo), cinzas e brasas (reino sombrio). Leve, com teto de partículas (500 inimigos na tela).
- **Vida no mapa:** bichos que fogem do herói, um tipo por região (já existe o sistema de `vida` dos cenários).
- **Poças de luz:** tochas, cristais e fogueiras com luz própria, que o escuro do Reino Sombrio já sabe usar.

### Movimento e combate (PR próprio)
- **Rolamento de esquiva** no lugar do dash: rola de verdade (animação), cobre mais distância, é invencível no meio e tem uma pequena recuperação no fim (compromisso).
- **Fôlego (stamina leve):** em vez de uma recarga fixa, 2 cargas de rolamento que voltam com o tempo, mostradas embaixo da vida. Dá pra encadear duas esquivas e depois é preciso respirar.
- **Telegrafia:** a investida das elites e dos chefes e os tiros em anel mostram antes uma marca no chão (linha ou círculo vermelho), pra ler a horda mesmo no caos.
- **Câmera:** segue com suavidade e **olha um pouco à frente** pra onde o herói anda; aproxima de leve na entrada do chefe e treme só em golpe forte (já existe).
- **Postura:** o golpe que quebra a defesa de um chefe faz ele cambalear (já existe atordoado); podemos ligar isso a uma barra de postura do chefe mais à frente.
