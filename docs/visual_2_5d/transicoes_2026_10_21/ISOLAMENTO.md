# Fixture e executor de v2_transicoes (#389)

O teste agora prepara AmbienteV2 no `_init`, mantém Config, Meta e índice/slots legados sob `Ambiente.raiz`, e remove a árvore inteira antes de imprimir o resultado. `_exit_tree` oferece a limpeza de fallback. Os caminhos continuam no sandbox para callbacks tardios. O runner sobrevive às trocas de `current_scene`; a última cena é liberada e os callbacks são drenados antes da limpeza. Uma falha retorna código 1.

Dependência incorporada por merge normal: #391 f3119e0, merge 785eba6. O guard de Config roda antes de recarregar e preserva os helpers GIF; o catálogo mantém `reduzir_animacoes`. Nenhum trecho de produção de transições ou pausa foi alterado neste conserto, e os métodos que verificam frames intermediários, interrupção, Container, resize e mouse permanecem iguais aos de b0b7ed8.

## Reprodução

Em um ambiente com Godot 4.4.1, passe ao executor um wrapper que encaminhe os argumentos ao Godot e preserve seu código de saída. A pasta QA deve ser separada dos dados reais:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ferramentas/teste_transicoes_isoladas.ps1 -AppDataQA <pasta-QA> -FilaGodot <wrapper-da-fila.ps1>
```

O executor cria uma subpasta nova, 12 arquivos sintéticos protegidos (opções migráveis, índice, slot, progresso e respectivos .bak/.tmp) e resíduos ocultos de uma fixture interrompida. Verifica hashes/tamanhos, a raiz efetivamente usada pelo Godot, ausência da fixture e ausência de arquivos extras. `-SemResiduos` omite o resíduo prévio e permite reproduzir o diretório vazio criado pelo autoload no teste antigo.

## Evidência

`isolamento_fixture.json` guarda os hashes e resultados sanitizados, sem caminhos da máquina ou conteúdo de perfil real:

- RED no teste antigo, depois de incorporar #391: teste informava falhas=0/código 0, mas sobrava o diretório vazio `testes_v2/v2_transicoes`. Os 12 arquivos protegidos permaneceram iguais.
- GREEN: falhas=0/código 0, 12 arquivos iguais, nenhum arquivo extra e fixture inteira removida, incluindo resíduo oculto preexistente.
- Falha intencional: uma asserção falsa foi inserida temporariamente antes do resultado final. Godot retornou 1, informou falhas=1, manteve os 12 arquivos protegidos e limpou a fixture. A fonte foi restaurada byte a byte em `finally`; a asserção não faz parte do produto.
- Cenas afetadas executadas serialmente: v2_transicoes, v2_pausa, v2_controle_nav e v2_escala_ui, todas falhas=0. Formatação global: 328 scripts limpos.

Limite: hashes antes/depois comprovam o estado persistido final; não constituem rastreamento de cada operação de escrita transitória. O perfil utilizado é sintético, incluindo opções que provocariam migração cedo sem o guard. Não foi lido, copiado ou restaurado perfil de jogador. A primeira coleta RED e a coleta final usam o mesmo conjunto lógico de sentinelas; a codificação do executor inicial diferia em textos acentuados, por isso os hashes entre essas coletas podem diferir, embora cada coleta tenha sua comparação antes/depois exata.

## Compatibilidade com #390

A integração 8ff3b69 contém a escolha de dificuldade: abrir o portal mantém o santuário e mostra o modal antes da confirmação. O teste reconhece essa capacidade por `has_method("_confirmar_dificuldade")`, verifica a cena e o modal visível e envia `_tecla(KEY_ENTER)` real. Não chama a confirmação privada. A verificação de chegada à partida continua incondicional, tanto sem #390 quanto com ela.

`compatibilidade_dificuldade.json` registra as duas execuções reais do mesmo candidato: standalone #389 e worktree QA própria detached em 8ff3b69. Ambas encerraram código 0/falhas=0, com 12 sentinelas intactas, zero extras e fixture removida. Os controles v2_pausa, v2_controle_nav e v2_escala_ui passaram novamente na integração. O executor final usa `--quit-after 18000` como limite de segurança; exige marcador falhas=0, portanto atingir o limite sem concluir não passa. O import dessa QA terminou naturalmente código 0. Há avisos de recursos/ObjectDB no encerramento do fluxo de cenas, sem SCRIPT ERROR; essa verificação não demonstra ausência de vazamentos de recursos.
