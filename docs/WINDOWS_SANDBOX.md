# Windows Sandbox: a regra e como instalar

Decisão do Alisson, 08/11/2026: **tudo o que não exige aceleração gráfica roda dentro do Windows Sandbox** (no Windows em
português: "Área Restrita do Windows"). A regra vale para todos que mexem no repositório: o Alisson, o Breno, o Isac, o Claude do
Alisson (PC e notebook), o Claude do Breno e o Codex. A mesma regra está resumida no `CLAUDE.md`, no `AGENTS.md` e no
`CONTRIBUTING.md`; quem mudar uma muda as outras.

A Sandbox é um Windows descartável que abre em segundos: o que roda lá dentro não instala nada, não grava nada e não lê nada
do seu Windows além do que você entregar, e tudo some quando ela fecha. Para nós isso resolve três coisas de uma vez: teste e
ferramenta não sujam a máquina (nem o `%APPDATA%`, nem o save do jogo), arquivo baixado da internet (pack de arte, zip, build
de outra pessoa) é aberto longe dos seus arquivos, e o que muda fica só numa pasta de saída que você escolhe.

## O que vai na Sandbox e o que fica no Windows de verdade

| Na Sandbox (obrigatório) | No Windows de verdade (exige GPU ou credencial) |
|---|---|
| Testes do Godot em `--headless` (todas as cenas de `testes/`) | Jogar, inclusive pelo atalho "KIKIU (teste)" |
| Robô de playtest em `--headless` (#301) | O editor do Godot |
| Scripts das `ferramentas/` (Python, PowerShell) que não usam git | Capturas com janela, `--write-movie`, fotos para PR |
| Abrir arquivo baixado antes de usar: pack de arte, som, fonte, zip, build | Blender (o pipeline de heróis e monstros) |
| Rodar código de PR de outro agente antes de revisar | `git`, `gh` e qualquer coisa que use senha ou token |

Regras de bolso:

- **Credencial nunca entra na Sandbox.** Commit, push, `gh` e login ficam no Windows de verdade. A Sandbox recebe o repositório só
  para leitura e devolve logs.
- **Só uma Sandbox por vez** (limite do Windows). Partidas em paralelo do robô rodam como vários processos dentro de **uma**
  Sandbox (`-Comando` com `start /b`), com `-MemoriaMB` maior. No notebook, a Sandbox conta como uma vaga da fila do Godot.
- **Exceções, sempre ditas no PR:** Windows Home (não tem Sandbox), Sandbox quebrada na máquina, ou algo que precisa de GPU.
  Escreva "rodado no Windows de verdade porque ..." no PR. O CI do GitHub já roda isolado e não muda.

## Como usar

O script `ferramentas/sandbox/sandbox.ps1` faz tudo: monta o arquivo `.wsb`, abre a Sandbox, copia o projeto e as `ferramentas/`
para `C:\trabalho` lá dentro (a mesma estrutura do repositório), roda o `--import`, roda os testes ou o seu comando, grava os logs e fecha a Sandbox sozinho.
Rode da raiz do repositório:

```powershell
# testes (nomes das cenas de jogos/hordas/projeto/testes, sem .tscn)
powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Testes v2_martelo,v2_teia_lento

# um comando qualquer, rodado em C:\trabalho\jogos\hordas\projeto (%GODOT% é o Godot de lá dentro)
powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Comando "%GODOT% --headless --path . res://testes/v2_combate.tscn"

# Python: entregue a pasta de um Python do seu Windows (só leitura); ela entra no PATH lá dentro. Exemplo: o robô de playtest
powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Ferramentas C:\Python312 -Comando "python C:\trabalho\ferramentas\playtest_v2.py --herois hazaki --mapas floresta --sementes 1"

# só abrir, com o projeto copiado, para mexer à mão (não fecha sozinha)
powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Janela
```

O que o script entrega lá dentro: o repositório em `C:\kikiu\repo` (só leitura), a pasta do Godot em `C:\kikiu\godot` (só
leitura), cada `-Ferramentas` em `C:\kikiu\ferramenta0`, `1`... (só leitura) e a saída em `C:\kikiu\saida`, a **única** pasta que
volta para o seu Windows. Na saída ficam `resumo.txt` (uma linha por teste com `falhas=N`), um `.log` por teste, `import.log`,
`comando.log`, `dentro.log`, a pasta `saida_playtest` (o relatório do robô, quando ele roda) e `fim.txt` (código de saída: 0 passou, 1 falhou). O script devolve o mesmo código, então dá para
encadear.

Opções: `-Godot` (o `Godot_v4.4.1-stable_win64_console.exe`; padrão: a variável `KIKIU_GODOT` ou `E:\Dev\Godot_4.4.1`),
`-Saida` (padrão: `%TEMP%\kikiu_sandbox\<data-hora>`), `-Rede` (liga a internet lá dentro; desligada por padrão),
`-MemoriaMB` (padrão 6144) e `-LimiteMin` (padrão 40). A Sandbox abre **sem placa de vídeo** (`VGpu` desligada), sem rede,
sem área de transferência, sem microfone, câmera e impressora.

Tempo medido no PC (08/11/2026): cerca de 1 minuto para 2 testes (abrir, copiar o projeto em 11 s, importar em 30 s, testar).
Rode vários testes numa chamada só para pagar a abertura uma vez.

## Instalar no Windows 11

**Precisa de:** Windows 11 **Pro, Enterprise, Education, Pro Education ou SE** (o **Home não tem** Sandbox), processador
AMD64 (ou Arm64 a partir do 22H2), **virtualização ligada**, pelo menos 4 GB de RAM (8 recomendados), 1 GB livre em disco e 2
núcleos.

1. **Confira a edição:** Configurações > Sistema > Sobre > "Edição". Se for Home, a Sandbox não existe: veja as exceções acima.
2. **Confira a virtualização:** abra o Gerenciador de Tarefas (Ctrl+Shift+Esc) > Desempenho > CPU e veja "Virtualização:
   Habilitado". Se estiver "Desabilitado", ligue no firmware: Configurações > Sistema > Recuperação > Inicialização avançada >
   Reiniciar agora > Solução de problemas > Opções avançadas > Configurações de Firmware UEFI > Reiniciar. Lá, ative a opção
   de virtualização do processador (Intel: "Intel Virtualization Technology", VT-x ou VMX; AMD: "SVM Mode" ou AMD-V). Mude só isso.
3. **Ative a Sandbox:** no menu Iniciar, procure **"Ativar ou desativar recursos do Windows"**, marque **"Área Restrita do
   Windows"**, clique em OK e reinicie quando pedir. Ou, num PowerShell **como Administrador**:

   ```powershell
   Enable-WindowsOptionalFeature -FeatureName "Containers-DisposableClientVM" -All -Online
   ```

4. **Abra uma vez à mão:** menu Iniciar > "Área Restrita do Windows". No Windows 11 24H2 a primeira abertura atualiza a
   Sandbox pela Microsoft Store (30 s a 2 min, precisa de internet). Depois disso existe também a linha de comando `wsb`
   (`wsb --version` mostra a versão), que o nosso script não exige.
5. **Teste o nosso script:** `powershell -ExecutionPolicy Bypass -File ferramentas\sandbox\sandbox.ps1 -Testes v2_martelo`
   tem que terminar com `v2_martelo: falhas=0` e "Terminou com código 0".

## Instalar no Windows 10

**Precisa de:** Windows 10 **Pro, Enterprise, Education ou Pro Education**, **versão 1903 ou mais nova** (o Home não tem
Sandbox), virtualização ligada e o mesmo hardware do Windows 11.

1. **Confira a edição e a versão:** tecla Windows + R, digite `winver` e dê Enter. A janela mostra a edição e a "Versão" (ex.:
   22H2). Abaixo de 1903, atualize pelo Windows Update antes.
2. **Confira a virtualização:** Gerenciador de Tarefas > Desempenho > CPU > "Virtualização: Habilitado". Desabilitado: entre no
   firmware por Configurações > Atualização e Segurança > Recuperação > Inicialização avançada > Reiniciar agora > Solução de
   problemas > Opções avançadas > Configurações de Firmware UEFI, e ligue a virtualização como no Windows 11.
3. **Ative a Sandbox:** "Ativar ou desativar recursos do Windows" > marque **"Área Restrita do Windows"** > OK > reinicie. Ou o
   mesmo comando de PowerShell como Administrador do Windows 11.
4. **Abra uma vez à mão** pelo menu Iniciar e teste o script como no passo 5 do Windows 11. No Windows 10 não existe o `wsb`,
   e o nosso script não precisa dele: ele abre o arquivo `.wsb` e espera o `fim.txt`.

**Atenção:** o suporte do Windows 10 acabou em 14/10/2025. As atualizações de segurança estendidas (ESU) para uso doméstico
vão até 12/10/2027 e exigem o Windows 10 22H2 atualizado. Quem puder, passe para o Windows 11.

## Problemas comuns

- **"Área Restrita do Windows" não aparece ou está cinza:** a edição é Home, a versão é antiga ou a virtualização está
  desligada. Confira os passos 1 e 2.
- **"No hypervisor was found":** a Sandbox só funciona com o Hyper-V do Windows; VirtualBox ou VMware antigos atrapalham. Dentro
  de uma máquina virtual, o host precisa liberar a virtualização aninhada
  (`Set-VMProcessor -VMName <nome> -ExposeVirtualizationExtensions $true`).
- **"Já existe uma sandbox aberta":** o Windows abre uma por vez. Feche a outra (ou, no Windows 11 24H2, `wsb list` e
  `wsb stop --id <id>`).
- **Erro 0x80070005 ao abrir um `.wsb` feito à mão:** não mapeie pasta direto na Área de Trabalho da Sandbox; o script usa
  `C:\kikiu\...`.
- **A pasta de saída tem que existir no seu Windows** e o caminho tem que ser absoluto (o script cria e resolve sozinho).
- **Máquina com política de grupo** (de empresa ou escola) pode bloquear pasta mapeada ou a escrita nela; aí vale a exceção.
- **Pasta mapeada sem "só leitura" grava de verdade no seu Windows**, e a gravação fica depois que a Sandbox fecha. Por isso o
  script só deixa a pasta de saída com escrita.

## O que foi conferido

No PC do Alisson (Windows 11 Pro 24H2), em 08/11/2026: o Godot 4.4.1 em `--headless` roda na Sandbox limpa, sem placa de vídeo
e sem instalar nada (`v2_martelo`, `v2_teia_lento` e `v2_corvo_vila` com `falhas=0`). Uma falha volta como código 1, o Python
3.12 entra pela pasta mapeada e a Sandbox se fecha sozinha no fim. O robô de playtest venceu uma partida (Hazaki, Floresta, semente 1) em 46 s reais lá
dentro; **numa de duas tentativas ele travou** e a Sandbox fechou sem gravar o `fim.txt` (causa não achada). Se o script
passar do `-LimiteMin`, rode de novo e anote no `LOGBOOK.md`. **Não conferido:** Windows 10 de verdade (os passos vêm da
documentação da Microsoft) e o Godot com janela dentro da Sandbox, que fica no Windows de verdade de qualquer jeito.

Fontes (Microsoft Learn, conferidas em 08/11/2026): visão geral e edições
(learn.microsoft.com/windows/security/application-security/application-isolation/windows-sandbox/), instalação e requisitos
(.../windows-sandbox/windows-sandbox-install), arquivo `.wsb` (.../windows-sandbox/windows-sandbox-configure-using-wsb-file),
linha de comando `wsb` (.../windows-sandbox/windows-sandbox-cli), ligar a virtualização
(support.microsoft.com, "Enable virtualization on Windows") e o fim do suporte do Windows 10 (support.microsoft.com, "Windows 10
support has ended").
