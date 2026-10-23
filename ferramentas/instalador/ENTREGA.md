# Entrega parcial da #379

O push da alteração em `.github/workflows/release.yml` foi recusado pelo GitHub: a credencial OAuth não tem o escopo `workflow`. Esta branch preserva os scripts e o diff como texto para revisão; **o workflow ativo não foi alterado e a funcionalidade ainda não está concluída**.

O Claude do Alisson pode aplicar o diff com uma credencial autorizada, depois de conferir a base:

```powershell
git apply --check ferramentas/instalador/release379-workflow.patch
git apply ferramentas/instalador/release379-workflow.patch
```

O diff foi preparado sobre `86568d97a74a780c2e222907fd86d841dfc97b91`. Ele compila/testa o instalador Windows por usuário, executa o binário Linux nativo exportado fora dos fontes e publica o instalador junto dos ZIPs existentes. Execuções manuais na branch guardam artefatos e não publicam Release; a publicação continua restrita à main.

Validação local em 21/10/2026: compilação Inno Setup 6.7.3 com payload de fixture (não é o jogo), versões de três/quatro componentes, caminhos com espaços, rejeição de versão inválida/erro do compilador, hash e assinatura do fallback oficial, guarda do teste fora do CI, parsers PowerShell/Bash, actionlint 1.7.12 e formatação GDScript completa limpos. O fallback foi preparado em modo portátil.

Não executado: exportação do jogo, smoke Linux real, instalação/desinstalação real do jogo e Wine. Nenhuma instalação do jogo foi feita no perfil do notebook. Os testes de instalação ficam restritos ao runner descartável do GitHub Actions. Depois de aplicar o workflow, exigir CI e Release manual verdes no mesmo commit antes da revisão final. Sem merge pelo Codex.
