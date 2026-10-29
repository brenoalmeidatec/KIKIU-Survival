# Preferências técnicas do KIKIU

Preferências que os agentes seguem quando uma decisão técnica não está escrita em outro lugar. Complementa `.claude/docs/kikiu.md` e o `CLAUDE.md` da raiz.

## Engine e linguagem

- **Engine:** Godot 4.4.1 (portátil, instalado fora do repo na pasta de ferramentas de cada máquina).
- **Linguagem:** GDScript com tipagem estática em todo código novo (`var x: int`, retornos tipados).
- **Cena:** `.tscn` por cena, com scripts ao lado. Nada de lógica de jogo em `_process` que pode ser evento ou sinal.
- **Versão do Godot:** a pasta `docs/engine-reference/godot/` foi escrita para a 4.7. O KIKIU roda a **4.4.1**. Antes de usar uma API citada nessa pasta, confirme que ela existe na 4.4.1 (ou peça para testar no Godot da máquina).

## Visual e desempenho

- Estilo 2.5D pixelado na v2 (ver `jogos/hordas/projeto/v2/` e `docs/visual_2_5d/README.md`).
- Alvo de desempenho: rodar bem no PC do Breno (CPU i5-3470). Poucas luzes, poucas partículas, sprites reduzidos à escala do jogo.
- Medir FPS e tempo de quadro antes e depois de qualquer mudança que afete desempenho.

## Dados e configuração

- Números de gameplay em `jogos/hordas/projeto/dados/*.json`. Código lê o dado, não tem número mágico.
- Save e opções seguem o padrão já usado em `v2/`.

## Testes

- Testes ficam em `jogos/hordas/projeto/testes/`. O que muda de comportamento ganha teste ou prova de execução (captura de tela ou log) no PR.
- Parse check não é prova de que funciona. Para mudança visível, rode o jogo e guarde a evidência fora do repo.
