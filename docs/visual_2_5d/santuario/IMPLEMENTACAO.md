# Santuário explorável — implementação visual

Direção aprovada por Breno no #260, implementada sobre o contrato do #242. A branch deste trabalho parte do #242 para entregar apenas o diff visual ao Claude da integração; não mescla sistemas por conta própria.

## Arte e layout
- Fundo de pedra960x540; centro livre, três estações laterais e quatro portais. Estátuas reúne fonte de vigor e bigorna; altar tem cristal, astrolábio e urna; códice tem livro e pedestais de relíquias. São as mesmas categorias do #242, não novas regras.
- Estátuas180,330; altar780,300; códice780,425. Portais180/380/580/780,188. Desenho e pontos de interação usam as mesmas posições de apresentação; limites, velocidade, alcance e condições originais permanecem.
- A arte é cenografia2D estática. Não introduz colisões ou novas áreas bloqueadas; o retângulo caminhável do #242 foi preservado. Relíquias/restauração/provas e persistência online seguem futuras.
- Texturas carregadas uma vez em salao_visual.gd, sem nó ou carga de recurso por objeto/quadro. Só herói e poucos halos são redesenhados. Fallback em código quando falta textura.
- Rodapé com Ajustes e Voltar; prompt contextual limitado ao viewport. Painel com lista rolável, nome completo e efeito atual/próximo/custo/saldo. Sem diminuir a fonte para caber.
- Cores/fontes leem v2/paleta.gd, cópia idêntica da fonte única do #250; reconciliar o arquivo na integração, não manter duas paletas.

## Fontes reproduzíveis
Arte própria Codex/imagegen embutido,14/10/2026; sem assets externos adicionados. Fontes em jogos/hordas/fonte_arte/santuario_v2/. Rodar python gerar.py nessa pasta (Pillow). Wrapper usa agrupar/recortar/escalar(BOX)/binarizar/contorno/quantizar sem dither do pipeline existente gerar_objetos.py. Três estações e cinco estados de portal recortados automaticamente; fundo reduzido para960x540. O portal fechado é um estado visual: nenhuma condição nova foi configurada para os mapas.

## Prompts utilizados
1. Fundo de produção16:9 pixel art dark fantasy2.5D top-down ortográfico. Parede fria no terço superior com quatro recessos alinhados, piso livre abaixo, mosaico de árvore discreto central, tapete inferior, musgo nas bordas e tochas na parede. Sem personagens/props/UI/texto/obstáculos no retângulo caminhável.
2. Folha transparente com três estações conectadas, em linha com grandes intervalos: estátua de guerreiro+fonte de raízes/cristal vermelho+bigorna; altar violeta com cristal em astrolábio+urna; livro em atril com dois pedestais de relíquia. Mesma câmera2.5D, pedra fria, metais envelhecidos, silhueta legível, sem texto ou grade.
3. Folha transparente com cinco portais em linha, separados: pedra musgosa/verdeFloresta; metal/petróleoLaboratório; tijolo/âmbarCidade; ruína/lavandaRuínas; grade/cadeadofechado. Mesma escala/câmera, glow contido, sem UI/texto ou cenário.

## Validação
Capturas são do viewport real Godot4.4.1,960x540, janela oculta, não da área de trabalho. Antes é o salão original do #242; depois usa as mesmas condições e saves temporários. Resultados e medição finais registrados no PR e LOGBOOK. O estudo imagem do #260 não é apresentado como captura do jogo.

## Reprodução da conferência visual e medição
O harness opcional em qa/visual_harness.tscn fica fora do CI. Abra com caminho absoluto e --path jogos/hordas/projeto, --resolution960x540 --audio-driverDummy, sem --headless (precisa de GPU). Passe -- --prints=PASTA_ABSOLUTA --variante=depois. A pasta de destino deve existir. Para antes, salve o conteúdo de git show9f79acc:jogos/hordas/projeto/v2/salao.gd em PASTA_ABSOLUTA/salao_antes.gd e use --variante=antes. O harness reutiliza o restante do projeto e troca apenas o script visual de baseline; não equivale a comparar duas builds completas.

Medição exploratória com VSync desligado,3s parado e3s andando, renderer OpenGL/IrisXe. Antes825,22/838,86FPS, depois1788,48/1958,60FPS. Há grande variação por aquecimento e carga concorrente; esses números não prometem ganho de FPS. Contagem da mesma sala:45→35 draw calls e675→204 objetos renderizados. CSV e saídas brutas preservados em qa/.

Testes locais4.4.1: v2_salao_visual, v2_salao, v2_menu, v2_morte, v2_meta, v2_santuario: código0/falhas=0/sem SCRIPT ERROR. Novo teste visual e harness final encerram sem avisos. Testes antigos têm avisos de recursos ao encerrar; mesmos avisos de v2_salao reproduzidos no baseline. Meta/morte incluem falhas de escrita/corrupção deliberadas. Não afirmar que todos os outros avisos foram reproduzidos no baseline.

Limites do teste: clique/A enviados ao handler da sala; não valida todo o roteamento de eventos do sistema operacional. Mapas atuais abertos; condição de bloqueio conferida sinteticamente, sem configurar requisito novo. Não há novo save online nem colisão de mobiliário neste trabalho visual.
