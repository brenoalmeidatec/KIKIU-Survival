# Corpo dos golpes: preparo e recuperação

Refs #304 e #342. Base de produto: `68bf0230bde1f69652bae947017309d65fa9a0f9` (PR #394, dependência desta frente).

O envelope anterior começava recuado dois pixels, voltava a zero antes do acerto e saltava para a frente quando `_punch` era ativado. O novo envelope usa a fase já existente do golpe: posição zero no início, −2 px na metade da antecipação, +3 px em `acerto_em`, zero ao terminar. Cada trecho usa smoothstep, com velocidade zero nas junções. A escala vai de (1,1) até o teto existente (1,10;0,93) e volta a (1,1). Só o vetor final é arredondado; o filtro nearest permanece. Não há relógio ou estado extra para vazar para o próximo combo, E/Q, rolamento, escudo ou morte.

O avanço físico, a animação da folha, o relógio de acerto e o disparo dos efeitos continuam nos mesmos trechos. A recuperação volta a zero antes do próximo preparo. O rastro da katana e os efeitos da marreta/adagas são os existentes; nenhuma arte, pool ou regra de combate foi criada aqui. `alcance_ima` não foi alterado.

## Comparação por passos reais

`testes/fotos/contrato_golpes.tscn` monta personagens ativos, inclusive **Matheus com mecânica Hazaki e folha matheus**, e avança o mundo real com inimigo vivo (1 milhão HP, peso alto para mantê-lo alcançável). Semente 7; sem crítico, diretor, movimento ou entrada de usuário. Segura ataque por três golpes e acompanha três segundos, tanto em 60 quanto em 120 Hz. APPDATA de QA separado, nunca o perfil real.

O mesmo harness foi executado antes de editar produção e depois. `contrato.json` registra os oito casos, hashes dos traços iguais e cada evento de dano com passo e hit-stop. Foram comparados exatamente, por passo: posição física do herói e inimigo, estado, índice/tempo/duração/acerto do golpe, quantidade de golpes, fôlego, HP, acertos corpo a corpo/adagas, adagas ativas e pausa local; também RNG final, coluna da folha e todos os contadores FX. **Todos iguais** (180 passos por caso a 60 Hz; 360 a 120 Hz). Apenas posição e escala desenhadas do corpo mudaram.

Para reproduzir, copie somente o harness `.gd/.tscn` para a base (sem o helper visual novo), rode cada referência com `--saida=antes.json` ou `--saida=depois.json`, e execute `python ferramentas/comparar_golpes.py antes.json depois.json resumo.json`. Toda execução Godot neste notebook deve passar pelo wrapper `godot_fila.ps1`; use APPDATA temporário próprio. O comparador aborta se encontrar qualquer diferença contratada.

## Capturas

Os oito GIFs desta pasta vêm dos helpers isolados `matheus_gif` (`--ativo=breno` e `--ativo=matheus`) e `heroi_gif` (`--heroi=nicao` e `--heroi=lucas`), sempre `--cena=combo`. Mesmos passos e semente antes/depois. Cada quadro representa dois passos de 1/60 s; GIF em 30 fps aproximados, resolução nativa, paleta 128 cores sem dithering. O PNG de contato preserva cores completas e usa nearest 2×. Os helpers têm alvos que se movem com empurrão, enquanto o contrato usa peso alto; são provas complementares.

| Visual | Antes | Depois |
| --- | --- | --- |
| Hazaki/Breno | [GIF](breno_antes.gif) | [GIF](breno_depois.gif) |
| Matheus | [GIF](matheus_antes.gif) | [GIF](matheus_depois.gif) |
| Nicão | [GIF](nicao_antes.gif) | [GIF](nicao_depois.gif) |
| Lucas | [GIF](lucas_antes.gif) | [GIF](lucas_depois.gif) |

![Quadros reais do combo](quadros.png)

`v2_golpes_visuais` prova rastro visível e pausa curta em acertos reais corpo a corpo, ondas da pancada e adagas ativas com cauda no impacto. **Separação da evidência:** `contrato.json` compara só o envelope do commit `dd10ad2` com a base. Nesse primeiro commit o Lucas ainda preservava zero hit-stop. O PNG de contato e os GIFs dos outros três personagens mostram esse envelope; o GIF `lucas_depois.gif` foi atualizado para incluir a etapa seguinte abaixo.

Os processos concluíram com código 0; os helpers e testes emitiram avisos de recursos/RID no encerramento já presentes na base. Não houve `SCRIPT ERROR`. Capturas não são benchmark de FPS nem avaliação subjetiva por controle físico.

## Micro hit-stop do Lucas (conserto separado)

O primeiro acerto de cada arremesso principal pede **14 ms** no relógio existente do combate: global no solo; conserva a separação local de tempo do coop. O cooldown de **100 ms simulados** fica congelado em menus e hit-stop. Todas as lâminas/perfurações do mesmo grupo consomem juntas a elegibilidade no primeiro acerto, mesmo se o cooldown negar a pausa. Assim uma adaga sobrevivente não causa uma segunda pausa tardia. Q, chuva e projéteis secundários não são elegíveis. Os dois vetores de metadados têm tamanho fixo do pool (96); reiniciar limpa grupos/cooldown, sem lista crescente de impactos.

`v2_adagas_impacto` atravessa colisões reais com várias lâminas e alvos, verifica uma única pausa, ausência sem alvo vivo, cooldown, pausa de menu, Q real, chuva, reinício e o limite do pool. `contrato_impacto.json` compara o envelope com esta etapa: seis casos dos outros personagens continuam exatamente iguais por passo; Lucas preserva dano por evento, RNG, fôlego e posição física final, mas muda os passos/tempos dos eventos, como esperado. Reproduza com o comparador acrescentando `--impacto-lucas`.

`cadencia_lucas.json` guarda as 12 medições de combate real, mesmo código com a configuração de pausa desligada/ligada, alvo vivo a 30 px, semente 7, oito combos medidos depois de oito de aquecimento. O dano dos oito combos ficou **igual entre desligado/ligado em cada par** (463–472 entre cenários de Hz/velocidade diferentes). A pausa de 14 ms ocupa um quadro a 60 Hz e dois a 120 Hz. Em velocidade 3×, o cooldown permite só dois impactos por combo; não há uma pausa por adaga.

O contador `hit_stops` no JSON inclui aquecimento e medição. A comparação desligado/ligado usa a mesma implementação e desliga somente o dado `hit_stop`, isolando a alteração de tempo; o contrato anterior preservado em `dd10ad2` também compara a implementação antiga com o envelope sem nenhuma pausa nova.

O card usa **Combo estimado** para as adagas. O modelo reproduz os instantes nominais de arremesso, cooldown e arredondamento real do relógio de cada passo. Nas 12 medições próximas, erro observado menor que 10⁻¹² s; o teste permite no máximo um quadro por combo para diferenças de chegada/quantização. A distância, o movimento dos alvos e errar arremessos podem alterar o ciclo real e o DPS, portanto esta estimativa não promete um DPS universal. O cálculo tem cache de **uma entrada** por parâmetros de tempo/velocidade/dados; consultas repetidas do Status não repetem a simulação. O teste prova reutilização e invalidação de todos os parâmetros relevantes.

| Hz | Velocidade | Ciclo antes → depois (s) | DPS antes → depois | Variação DPS |
| --- | --- | --- | --- | --- |
| 60 | 1.0× | 0.8833 → 0.9333 | 66.08 → 62.54 | -5.36% |
| 60 | 1.5× | 0.6167 → 0.6667 | 94.66 → 87.56 | -7.50% |
| 60 | 3.0× | 0.3833 → 0.4167 | 153.26 → 141.00 | -8.00% |
| 120 | 1.0× | 0.8417 → 0.8917 | 68.76 → 64.91 | -5.61% |
| 120 | 1.5× | 0.5917 → 0.6417 | 98.66 → 90.97 | -7.79% |
| 120 | 3.0× | 0.3583 → 0.3917 | 164.65 → 150.64 | -8.51% |

Validação local: `v2_adagas_impacto`, `v2_golpes_visuais`, `v2_status`, `v2_herois`, `v2_combate`, `v2_combate_fases`, `animacao_heroi`, `v2_ruptura`, `v2_especial`, `v2_habilidade` e `v2_escudo`, todos com `falhas=0`; os contratos acima também passaram. `gdformat -l 160 --check` completo limpo, 331 scripts (base: 327). Importação final Godot 4.4.1 sem erro de script. Sem medição nova de FPS.
