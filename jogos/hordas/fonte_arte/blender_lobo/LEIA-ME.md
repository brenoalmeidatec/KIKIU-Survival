# Lobo Espiritual (folha de 8 direções, andar e mordida)

```
blender -b -P gerar_lobo.py                    # a folha final
blender -b -P gerar_lobo.py -- previa <png>    # prévia para ajustar o modelo (a = só andar, t = só ataque)
blender -b -P gerar_lobo.py -- diag            # sem render: o chão e as patas em cada quadro
```

Gera `projeto/assets/v2/armas/lobo_espiritual_dir.png` (16 colunas x 5 linhas de 80x85: andar 0-7, ataque 8-15, mordida no 12; linhas frente,
3/4 frente, perfil, 3/4 costas, costas) e o `.json` ao lado com o pé, a passada medida em pixels por vista e o alcance do focinho. O jogo usa a
ficha `lobo_espirito` de `projeto/v2/andante.gd` (os números do `.json` copiados no código; o `.json` não vai na exportação) e o teste
`testes/v2_andante` confere que os dois batem. Mesmo esquema do Urso e da Raposa (`../blender_urso/`, `../blender_raposa/`).

O lobo é branco-azulado, de pelo gelado, juba arrepiada, olhos de brilho frio e a cauda em chama fria, na cor da referência do Breno
(`referencia_run_breno.png`, 15/10/2026). A translucidez e o rastro vêm do código (alfa e efeitos do `andante.gd`).

`gerar_lobo_corre.py` é o caminho antigo (corrida de perfil recortada da referência do Breno, só olhava para a direita e não tinha ataque). O jogo
não usa mais a folha que ele gera, mas `projeto/assets/v2/armas/lobo_espiritual_corre.png` (a corrida que o Breno aprovou em 15/10/2026) continua versionada
de propósito: trocar o perfil dela pelo render 3D de `gerar_lobo.py` depende do OK do Breno (pergunta fechada na issue, padrão = usar o 3D, que tem
ataque e as 5 vistas). Só depois do OK dá para apagar o PNG. Ficou como exemplo do processo por referência (`docs/visual_2_5d/sprites_por_referencia.md`).

Legibilidade (revisão): a cauda é uma chama curta e grossa que muda de comprimento por vista (`CAUDA_VISTA`) e cai para o lado de frente e de costas
(`CAUDA_LADO`), a cabeça é 30% maior (`CABECA`), o peito, a juba e as patas são mais largos, e o céu da boca é escuro para a mordida aparecer de frente.
