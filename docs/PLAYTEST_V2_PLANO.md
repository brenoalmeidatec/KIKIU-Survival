# Robô de playtest da v2: avaliação e próximos passos (2026-10-16)

Avaliação só de leitura da branch `alisson/robo-playtest` (PR #302, issue #301). Nada foi rodado: o Godot não está na nuvem.
Uma rodada de agentes levantou os fatos (Haiku), montou o plano (Sonnet) e procurou furos nele (Sonnet).

## Estado
- A branch não está atrás da `main` (0 commits). Lint, formatação e ortografia passam no CI; o job `testes` estava rodando na leitura.
- **O hash do save real já existe em parte.** `testes/v2_playtest.gd` (`_retrato_real`, ~:65-79) tira md5 de `Meta.caminho_save`,
  índice e slots de personagens, `Config.arquivo` (`opcoes.cfg`) e os `.json` da v1, cada um com `.tmp` e `.bak`, antes e depois
  de 3 partidas. Arquivo ausente vira `SEM_ARQUIVO`.
- **Falta:** a guarda no lote do runner (`ferramentas/playtest_v2.py`, que roda N processos em paralelo e o `--janela`) e um
  teste negativo que prove que a guarda acusa quando o save muda.
- Já feitos, mas ainda listados como pendentes no PR e no LOGBOOK: `--log-file` por partida (py:168), `--audio-driver Dummy` (py:166),
  `plural()` (py:157). `SCRIPT ERROR` já é contado (py:222, :319, :519).
- "Dano por arma", do escopo da #301, não existe em lugar nenhum.

## Riscos achados
- O desvio do save (`mundo.gd:156-162`) troca só `Meta.caminho_save`. `Personagens.iniciar`/`ativar` (`personagens.gd:141`, `:150`)
  reescrevem esse caminho; hoje o robô não os chama, mas o hash é a rede de segurança.
- `opcoes.cfg` não é desviado (é compartilhado com a v1); o robô não grava nele hoje.
- Partida morta por timeout deixa `user://playtest/meta_<pid>.cfg` órfão. Limpar órfãos de **qualquer** pid apagaria o de um lote
  rodando em paralelo: limpe só arquivos com mais de 1 hora, no início do lote.
- `user://` no Windows: `%APPDATA%\kikiu\` (o `project.godot` usa `use_custom_user_dir` desde a migração de 2026-10-23; antes era `%APPDATA%\Godot\app_userdata\K.I.K.I.U\`, e o jogo copia a antiga no primeiro boot).

## Próximos passos
Na nuvem (sem Godot):
1. Guarda no runner: retrato (sha256) dos arquivos regulares da raiz de `user://` antes e depois do lote inteiro, só no Windows
   (fora dele, pula com aviso). Diferença: seção "SAVE REAL ALTERADO" no relatório, saída com código 4 (livre hoje) e
   `--sem-guarda-save` para depurar. Se mudou, comparar o mtime e avisar que o jogo real pode estar aberto.
2. Teste Python sem Godot em `testes/`: byte alterado, arquivo criado e apagado acusam; mudança em `playtest/` e `logs/` não acusa.
3. Arrumar: `return` depois dos `quit()` do roteiro, limpeza de órfãos com mais de 1 hora, atualizar LOGBOOK, corpo do PR e
   `docs/PLAYTEST_V2.md` (documentar o código 4).

No PC do Alisson (Godot 4.4.1):
4. Ver se a raiz de `user://` muda sozinha só por abrir o jogo (falso positivo possível com `opcoes.cfg`).
5. Rodar a suíte v2 e provar as mutações M1/M6: apagar a linha `Meta.caminho_save = ...` em `mundo.gd` tem que fazer falhar
   `v2_playtest.gd` e a guarda Python.
6. Rodar a matriz 3x4x2 com o runner (plural certo, JSON válido, hash inalterado, zero `SCRIPT ERROR`) e medir os picos de quadro
   com e sem `--playtest`.
7. Tirar o #302 do rascunho com 5 e 6 verdes.

Fora do escopo de "PR pronto": dano por arma, perfis `--humano=...`, pré-carregamento contra os picos e o equilíbrio (Breno, #137).
