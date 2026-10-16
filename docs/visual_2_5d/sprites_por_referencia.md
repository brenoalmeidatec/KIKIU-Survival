# Sprites animados a partir de uma referência do Breno

Processo aprovado pelo Breno em 15/10/2026, no Lobo Espiritual (`lobo_espirito`). Ele vale para as próximas sprites animadas.
Script de exemplo: `jogos/hordas/fonte_arte/blender_lobo/gerar_lobo_corre.py`.

## O que não funcionou (não repetir)
- Modelo 3D montado com primitivas e animado por código: o Breno achou duro e "não parece um lobo".
- Recortar o sprite antigo em pedaços e girar as partes: ilegível.
- Desenhar o bicho do zero por script: "muito fofinho" e sem fisionomia.

## O que funcionou
1. **A referência do Breno é a fonte da arte.** Ele manda uma folha com as poses (no lobo, 16 poses em grade 4x4). Guardar a imagem ao lado do script.
2. **Recorte por célula.** Apagar o número do canto, o fundo e a grade do chão por luminância (abaixo de um limiar é fundo).
3. **Alinhar os quadros.** Na horizontal, por um ponto fixo do corpo (o focinho). Na vertical, pelo chão (a pata mais baixa), para o corpo subir e descer na corrida. Alinhar pela cabeça faz o bicho "deslizar".
4. **Cor do jogo.** Trocar a cor da referência pela pedida (o lobo ficou branco, com 3 tons), mantendo o volume.
5. **Pixel art limpo na escala do jogo.** Suavizar um pouco antes de reduzir, reduzir por bloco (o lobo usou 4:1: tem a altura do herói, uns 39 px, e é mais comprido), tirar pixel solto, filtro de maioria 3x3 nos tons e contorno escuro de 1 px.
6. **Ordem do ciclo.** Referência gerada por IA não vem em ordem de passada. Medir a diferença entre os quadros (pernas e corpo) e montar o ciclo de menor salto. No lobo, os saltos caíram 35% e a corrida passou a ler como corrida.
7. **Detalhes por anatomia, pixel a pixel.** Olho amendoado no "stop" (onde a testa encontra o focinho), canto de trás mais alto, pálpebra escura e brilho no meio; trufa escura na ponta do focinho; linha do lábio fina saindo de baixo da trufa até embaixo da frente do olho. Conferir num zoom de 12x da cabeça antes de mostrar.
8. **Efeitos que o bicho deixa.** Rastro de espíritos soltando da cauda e fiapos no chão ficando para trás, em ciclo fechado com os quadros.
9. **Mostrar antes de levar ao jogo.** GIF ampliado 4x, sem suavizar, a uns 11 quadros por segundo, com um chão andando para trás na prévia; e a mesma sequência tocando no Blender (plano com a sequência de imagens, filtro Closest). Só levar ao jogo depois do ok do Breno.

## No jogo
Folha com os quadros em linha em `assets/v2/armas/`. O desenho do golpe pega o quadro pela fase do item e espelha para o lado em que ele anda
(`v2/armas_novas.gd`, `_desenhar_lobo`). O pé do bicho fica na posição do item no chão.
