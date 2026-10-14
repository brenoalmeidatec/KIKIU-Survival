# Santuário — estudo de layout, 14/10/2026

Estudo visual do Codex do Alisson, solicitado por Alisson. Não implementado no jogo, não é captura de viewport nem build testável. Arte própria gerada com a ferramenta embutida imagegen; conceito-salao.png é a fonte original, sem edição. Composição 16:9 visando leitura futura em 960x540; imagem de conceito em resolução maior.

## Direção confirmada
Referência: https://github.com/brenoalmeidatec/KIKIU-Survival/pull/242
Decisão Breno: https://github.com/brenoalmeidatec/KIKIU-Survival/pull/242#issuecomment-6169533044
JOGAR → escolher/criar personagem → salão explorável → expedição → retorno ao salão. Progresso por personagem segundo o PR. O estudo anterior de página com abas fica superado por esta direção. Integração do #242 e sistemas pertencem ao Claude do Alisson.

## Composição proposta
Entrada inferior; centro livre; estações nas laterais; acesso às expedições ao fundo. O portal central da arte representa a zona de saída: na implementação preservar os portais de mapas do #242, sem reduzir destinos a um único mapa. Espelho perto da entrada representa acesso à aparência; criação inicial fica em tela própria.

| Objeto proposto | Melhoria atual representada |
|---|---|
| Fonte com raízes | Vigor da mata / vida |
| Bigorna na forja | Gume de herança / dano |
| Pedras de percurso | Passos de caçador / velocidade |
| Braseiro de descanso | Fôlego de corredor |
| Urna coletora | Ímã de almas |
| Astrolábio | Olho para o raro |
| Roda do destino | Segunda chance / rerrolagem de cartas, NÃO esquiva |
| Altar violeta | Almas abundantes |
| Boneco de treino | Treino de guerreiro / velocidade de ataque |

Esses objetos são uma proposta de representação dos nove upgrades existentes, não novas regras. #242 agrupa melhorias em ESTÁTUAS, ALTAR e CÓDICE e deixa forja futura: alinhar distribuição com esse fluxo antes de implementação. A bigorna proposta não cria crafting.

UI: saldo discreto; nome e interação apenas perto do objeto; ao interagir abre painel compacto com nível, efeito atual→próximo e custo. Caminhos e aproximação devem ficar livres. Arte conceitual contém paredes baixas que precisam ser validadas como passagens reais no blockout; não usar a imagem inteira como colisão pronta.

## Ideias futuras — não implementadas
- Relicário com espaços vazios preenchidos por descobertas únicas.
- Monumento de conclusão restaurado após terminar o jogo.
- Provas de habilidades específicas podem restaurar nichos opcionais; requisito explícito quando descoberto.
- Relíquias podem aparecer em algumas partidas; após coleta confirmada, sair do sorteio do respectivo progresso persistente.
- Progresso online fica para fase posterior: decidir conta versus personagem e regras de anfitrião/visitante com Claude. Não prometer sincronização existente.
- Não condicionar upgrades básicos a zerar o jogo; reservar exigências avançadas a expansões opcionais e troféus.

## Prompt de produção utilizado (resumo fiel)
Salão compacto de pedra dark fantasy em pixel art 2.5D top-down ortográfico, 16:9, centro amplo livre, pequeno cavaleiro para escala. Seis alcovas laterais: fonte de raízes com cristal de vida, forja/bigorna, boneco e percurso, astrolábio/roda, altar violeta/urna, pedestais de relíquias parcialmente vazios. Portal no fundo e espelho na entrada. Ardósia/índigo, musgo, tochas âmbar e almas violetas com brilho localizado. UI mínima SANTUÁRIO, saldo ilustrativo240, interação contextual FORJA, marca ESTUDO DE LAYOUT. Sem grade de cartões, painéis laterais, setas ou personagens de franquias.

## Validação
Inspeção visual do conceito gerado: composição, caminhos centrais, distinção dos objetos e UI discreta. Nenhum código do repositório alterado, nenhum teste Godot executado para este estudo. Sem PR, merge ou alteração do atalho nesta entrega.
