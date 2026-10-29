# Pacote de agentes e skills do KIKIU

Adaptação do [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) (MIT, cópia da licença em `.claude/LICENSE-Claude-Code-Game-Studios.txt`) para o jogo KIKIU. Escolhemos só o que serve ao projeto e ajustamos para Godot 4.4.1, GDScript, português e a divisão de trabalho do `CLAUDE.md` da raiz.

Contexto que todo agente lê: [`docs/kikiu.md`](docs/kikiu.md).

## O que tem aqui

**Agentes** (`agents/`, todos com bloco "Contexto KIKIU" no início):

| Agente | Modelo | Para quê |
|---|---|---|
| `technical-artist` | Opus 5.5 | Shaders, VFX, pipeline de arte e ligação de arte no motor |
| `art-director` | Opus 5.5 | Direção visual, consistência de estilo |
| `godot-specialist` | Sonnet 5.5, médio | Padrões de cena, sinais, nós, recursos no Godot |
| `godot-gdscript-specialist` | Sonnet 5.5, médio | Qualidade do GDScript, tipagem, desempenho |
| `godot-shader-specialist` | Sonnet 5.5, médio | Shaders `.gdshader`, materiais, pós-processo |
| `gameplay-programmer` | Sonnet 5.5, médio | Mecânicas em código, a partir do design |
| `lead-programmer` | Sonnet 5.5, médio | Arquitetura de código e revisão de PR |
| `performance-analyst` | Sonnet 5.5, médio | Perfil, gargalos, medição antes e depois |
| `qa-tester` | Sonnet 5.5, médio | Casos de teste, checklist de regressão, relato de bug |
| `systems-designer` | Sonnet 5.5, médio | Fórmulas e números de sistemas |
| `game-designer` | Sonnet 5.5, médio | Loop, progressão e regras do jogador |

**Skills** (comandos com barra, em `skills/`):

| Comando | Para quê |
|---|---|
| `/code-review` | Revisa o diff ou um PR por bugs de correção e limpeza |
| `/smoke-check` | Roda os testes e a checagem rápida antes de mandar para revisão |
| `/perf-profile` | Mede desempenho e aponta o gargalo |
| `/bug-report` | Escreve um relatório de bug no padrão do time |
| `/bug-triage` | Organiza uma lista de bugs por prioridade |
| `/hotfix` | Fluxo para corrigir bug grave na versão publicada |

**Regras** (`rules/`, aplicadas por caminho de arquivo): gameplay (`v2/**/*.gd`), shaders, cenas (`.tscn`/`.tres`), dados JSON, testes, UI.

**Docs** (`docs/`): `kikiu.md` (contexto e divisão de trabalho), `technical-preferences.md`, `coding-standards.md`, `automation-modes.md`, `config-resolution.md`.

**Referência do Godot** (`../docs/engine-reference/godot/`): notas sobre a API. Foram escritas para a 4.7. Confira na 4.4.1 antes de usar.

**Permissões** (`settings.json`): só a lista de bloqueio de comandos destrutivos (`rm -rf`, `git push --force`, `git reset --hard`, `git clean -f`, `sudo`, leitura de `.env`).

## O que ficou de fora e por quê

- **Hooks** (`hooks/`, `statusline`, `settings` de hooks): não entraram. Alguns bloqueiam commit e push, e não sabemos o efeito deles sobre o fluxo de três agentes que já existe no repo. Podem entrar depois, um de cada vez, se o Breno pedir.
- **Agentes de direção e produção** (`producer`, `creative-director`, `technical-director`): o time do KIKIU é pequeno e a decisão está com o Alisson e o Breno. Algumas skills (como `/hotfix`) citam o `producer` para aprovar; nesse caso, peça a aprovação ao Breno.
- **Agentes de Unity, Unreal, C# e GDExtension:** não usamos essas engines.
- **Mapas, níveis, `level-designer`, `world-builder`:** ficam com o Alisson, conforme o `CLAUDE.md`.
- **Skills de sprint, estúdio e gate** (`gate-check`, `sprint-plan`, `create-epics`, etc.): dependem de `production/` e `design/`, que o KIKIU não tem. Podem ser adotadas depois, se o time quiser essa estrutura.
- **Tradução dos agentes para português:** o corpo dos agentes continua em inglês. O bloco "Contexto KIKIU" faz as respostas e documentos saírem em português.

## Como usar

- Digite a barra e o comando no Claude Code aberto na raiz do repo, por exemplo `/code-review` com um PR ou branch.
- Os agentes são chamados pelo nome quando o Claude decide que a tarefa é deles (por exemplo, `technical-artist` para shader). Dá para pedir também: "use o agente performance-analyst para medir o frame".
- Os modelos ficam no campo `model:` de cada agente. Se o custo ficar alto, troque `claude-opus-5-5` por `claude-sonnet-5-5` no agente de arte.
- Se algo citar `production/`, `design/` ou `src/`, o agente deve pedir confirmação antes de criar pastas novas.
