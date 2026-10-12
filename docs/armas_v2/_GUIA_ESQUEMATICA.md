# Guia: esquemática e pacote de sprite (para os agentes)

Repositório (só leitura, exceto onde indicado): /home/claude/kikiu-survival/jogos/hordas/projeto
Dados das armas: dados/v2_cartas.json (seções "golpes", "modificadores", "evolucoes").
Código dos tipos novos: v2/armas_novas.gd (projetil, nuvem, anel, meteoro, aliado).
Código das antigas: v2/armas.gd (orbita, aura, corvos, raio, runa; ondas e lança da katana).
Código de evolução: v2/cartas.gd (evoluir, _checar_evolucoes) e v2/armas.gd (adicionar_evoluida).

## Regras gerais
- Os números têm que bater com o código e com os dados. Se não baterem, a esquemática segue o CÓDIGO e você registra a diferença em "Mudanças".
- O jogo é 2.5D: o chão é uma elipse achatada (y vale 62% do x, constante ACHATA). Distâncias em px do mundo (a tela é 960x540).
- "Dano por nível": dano base do nível 1, somado ao que cada nível acrescenta (campo "niveis"), e multiplicado pelo bônus da raridade (campo "bonus_arma" da raridade: comum 0%, raro +18%, épico +40%, lendário +80%). O multiplicador de dano do herói (m_dano) é 1,0 por padrão; diga isso.
- Limites de desempenho (constantes do código): golpes novos dividem um pool de 48 slots (armas_novas.gd, MAX). Corvos 16, runas 14, ondas 8, raios 6 (armas.gd).
- Não invente mecânica que o código não tem. Se um efeito não existe no código, escreva "não existe hoje".
- Pode escrever em /mnt/project-files/docs/armas_v2/ (pasta compartilhada: releia 10 s depois de escrever). Não edite nada no repositório, não rode git.
- Não use nomes de modelos de IA em nenhum texto.

## Formato da seção "Esquemática" (acrescente ao fim da ficha <id>.md, depois de "Pontos de atenção")
## Esquemática
- **Gatilho:** quando dispara e a recarga em s (nível 1 e como cai por nível).
- **Alvo:** como escolhe (o inimigo mais perto dentro de X px, ou um sorteado, ou o próprio herói).
- **Trajetória e alcance:** em px (e a velocidade, se houver).
- **Área:** forma (círculo ou faixa) e tamanho em px.
- **Dano por nível:** tabela Nível | Dano | Como muda (com o multiplicador de raridade explicado uma vez).
- **Como aplica:** uma vez por inimigo, por tique (intervalo em s), por perfuração (quantos inimigos), ou por explosão.
- **Efeitos de status:** empurrão (px), atordoamento (s), lentidão (fração e s), queimadura (dano por s e s). Se não houver, escreva "nenhum".
- **Limites na tela:** quantos existem ao mesmo tempo no máximo.
- **Sequência de animação (quadro a quadro, a 60 fps):** fases (antecipação, disparo, viagem, impacto, fim) com duração em s e quantos quadros cada uma, e o tamanho do sprite em px.

## Formato do pacote (arquivo _pacote/<id>.md, só para o Alisson)
# <Nome> (<id>)
- **Resumo visual (2 linhas):** o que aparece e como se move.
- **Paleta:** 3 a 5 cores, com nomes e códigos hex.
- **Sprite:** tamanho de cada quadro em px e quantos quadros em linha (ex.: 16x16 px, 6 quadros, sheet de 96x16 px).
- **Prompt para o GPT (em inglês, pronto para colar):** um parágrafo que descreve o sprite e pede pixel art top-down 2.5D coerente com o estilo do jogo, fundo transparente, sprite sheet com N quadros em uma linha, tamanho exato, sem texto, sem moldura. Use as cores e o tamanho acima.
