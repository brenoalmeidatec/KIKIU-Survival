# ⚔️ K.I.K.I.U — guia técnico

Apresentação do jogo no [README principal](../../README.md). Aqui fica o que é preciso para abrir, testar e gerar o executável.

## 🚀 Como rodar

1. 📥 Baixe o **Godot 4.4.1 (padrão, não .NET)**: <https://godotengine.org/download/archive/4.4.1-stable/>
2. 📂 Clone o repositório.
3. ➕ No gerenciador de projetos do Godot, clique em **Importar** e escolha `jogos/hordas/projeto/project.godot`.
4. ⏳ Na primeira vez o Godot importa imagens e sons (demora um pouco). Depois, **F5** roda o jogo.

O **F5** e o executável abrem o título da **v2**, `v2/menu_principal.tscn`. Jogar leva ao santuário (`v2/altar.tscn`) e de lá à partida (`v2/mundo.tscn`). A apresentação da v2 usa **960×540**, com shader sharp bilinear no mundo; o renderer é *Compatibility*. A configuração base de 640×360 do projeto atende também o legado e não é a resolução de apresentação da v2.

## 📌 V2 disponível, legado e roadmap

**V2 na main:** combate solo com golpe principal no clique, combo, esquiva e corrida com fôlego; cartas, golpes automáticos e evoluções; elites, baús, mini-chefes e chefe final; HUD, minimapa, pausa, opções, música e sons; santuário com almas, melhorias permanentes e conquistas. A lista de mapas disponível está em `projeto/v2/mapas.gd` (Floresta e Laboratório nesta versão). O [guia da v2](projeto/v2/LEIA-ME.md) descreve os módulos, os controles e os testes atuais.

**Legado v1, pausado:** `KIKIU.exe -- --v1` abre o jogo antigo. Os argumentos `--bot`, `--online`, `--sair`, `--print_tela`, `--cena` e `--prototipo` também selecionam a v1. Seus testes e ferramentas continuam no repositório para compatibilidade; uma descrição de recurso da v1 não comprova que ele esteja portado para a v2. A v1 usa a base 640×360.

**Roadmap:** online cooperativo e duelo entre amigos, regiões/andares da visão completa e outros sistemas ainda precisam de portabilidade, integração e validação na v2. Os épicos #134 e #152 e o painel #196 acompanham isso. PR aberto (novos heróis, mapas, exploração ou interface) é trabalho em revisão, não recurso já disponível na main. Não use os comandos online abaixo como demonstração de online na v2.

## 🧪 Testes automáticos

Cada cena em `projeto/testes/` é um teste que roda sozinho e imprime `falhas=0` quando passa:

```bash
godot --headless --path jogos/hordas/projeto res://testes/rolamento.tscn
```

**V2:** rode as cenas `v2_*` afetadas pela mudança (por exemplo `v2_combate`, `v2_meta`, `v2_esc` e `v2_menu`). Entrada real da janela é coberta por `v2_esc`; os comandos e as medições específicas da v2 estão em `projeto/v2/LEIA-ME.md`.

**Ferramentas do legado v1:** um robô joga sozinho para medir desempenho e pegar erros de script:

```bash
# um robô joga sozinho, mais rápido, e mostra os números a cada 5 s
godot --headless --path jogos/hordas/projeto -- --bot --heroi=nicao --sair=700 --rapido=4

# online com 2 instâncias na mesma máquina (abra o anfitrião primeiro)
godot --headless --path jogos/hordas/projeto -- --online=host --bot --heroi=nicao --sair=300 --rapido=4
godot --headless --path jogos/hordas/projeto -- --online=join --endereco=127.0.0.1:7777 --bot --heroi=lucas --sair=300 --rapido=4
```

Outras opções (`--fase`, `--build`, `--estresse`, `--imortal`, `--print_tela`...) estão comentadas no começo de `projeto/scripts/hordas/main.gd` (as de foto, junto da função `_print_tela`). A animação dos heróis (respiração, passo, golpe, recuo e queda) se ajusta em `projeto/dados/animacao.json` (a `_ajuda` explica cada chave); `--print_tela=animacao --heroi=X --cena=parado|andar|golpe|dano|morte --seq=...` tira uma tira de recortes pra conferir. A abertura cinematográfica da fase (tarjas, câmera, queda do herói, título da região; pula com Enter/Esc) se ajusta em `projeto/dados/entrada.json`; `--entrada` força nos robôs e `--print_tela=entrada --fase=N --seq=...` captura os instantes.

**Gráficos do legado v1 (#150):** Opções > Gráficos abre a aba com perfis (Baixo, Médio, Alto ou Personalizado), "Detectar automaticamente" e duas seções, CPU (simulação) e GPU (visual); código em `projeto/scripts/hordas/tela_graficos.gd` e `projeto/cenas/tela_graficos.tscn`.

**Desempenho do legado v1:** Opções > Gráficos (perfil baixo/médio/alto ou personalizado, com seções CPU e GPU; valores em `projeto/dados/graficos.json`, API em `Config.g(chave)`, `Config.g_definir`, `Config.g_aplicar_perfil`; `--perfil=baixo` em teste). Bancadas com janela e sem V-Sync: `godot --path jogos/hordas/projeto res://testes/bench_horda.tscn -- --perfil=baixo` (500 bichos, determinística; confira `logica=1.00`) e `res://testes/bench_inicio.tscn` (primeiros quadros). Resultados em `docs/PERF_2026-10-07.md` e, do desenho dos inimigos em lote (MultiMesh), `docs/PERF_2026-10-10.md`. Limite de inimigos vivos: `dados/fase.json` (`limite_vivos` 250, `limite_vivos_pror` 350 na prorrogação e no Enxame Final), vale o menor com o da aba Gráficos (`max_inimigos`).

## 📦 Gerar o executável (.exe)

Executáveis e zips **não** ficam no Git. No Godot: **Projeto › Exportar › Windows Desktop** (o preset já está em `projeto/export_presets.cfg`; precisa dos modelos de exportação do 4.4.1).

**Instalador de uma vez:** `./gerar_instalador.sh` (nesta pasta) gera o `.exe` e o instalador Windows e deixa tudo em `build/` (fora do Git): `build/KIKIU.exe` e `build/instalador/KIKIU-Setup-<versão>-<commit>.exe`. Antes, instale o Inno Setup 6 (`winget install --id JRSoftware.InnoSetup -e`) e os modelos de exportação do 4.4.1 em `%APPDATA%/Godot/export_templates/4.4.1.stable/`. Caminhos de outra máquina: variáveis `GODOT` e `ISCC`. O instalador é por usuário (sem administrador), com atalhos no menu Iniciar e opcional na área de trabalho, e tem o ícone e a arte do jogo (veja abaixo).

**Ícone e detalhes do `.exe` (rcedit):** o ícone do escudo e os metadados do arquivo (nome do produto, versão, empresa) entram no `.exe` pelo **rcedit** (`application/modify_resources=true` no preset). Sem ele a exportação **não falha**: o Godot só mostra um aviso ("Modificação de Recursos: não foi possível iniciar o executável rcedit") e entrega um `.exe` com o ícone do Godot. O `gerar_instalador.sh` confere antes e avisa em letras grandes. Para instalar: baixe o `rcedit-x64.exe` em <https://github.com/electron/rcedit/releases>, guarde num lugar fixo (por exemplo `C:/Dev/Tools/rcedit/`) e aponte o Godot pra ele em **Editor › Configurações do editor › Exportar › Windows › rcedit**. Os números `product_version` e `file_version` do preset (`export_presets.cfg`) são fixos: ao subir o `application/config/version`, atualize-os junto.

**Arte do instalador:** `instalador/gerar_arte.sh` regenera os quatro BMP do assistente. Quem monta a cena é o `instalador/gerar_arte.gd` (Godot, com o Hazaki em camadas, monstros, piso e árvores da Floresta Sombria, brasas, luz e a fonte do jogo); o ffmpeg só converte os PNG em BMP 24 bits. As prévias ficam em `prints/instalador_*.png`.

**Versão no jogo:** cada exportação, até pelo editor, escreve `projeto/dados/versao.json` (data e commit), pelo addon `projeto/addons/kikiu_versao`. Por isso o título, as Opções e o menu de pausa mostram `Versão 0.1.0 · 07/10/2026 · 20bf57a` (um `+` depois do commit = havia mudança sem commit). Sem git no PATH o arquivo anterior fica como está; sem arquivo (rodando pelo editor e sem exportar) aparece `· dev`. O número da versão é o `application/config/version` do `project.godot`: sobe à mão quando o Breno disser. O `gerar_versao.sh` continua valendo, mas já não é preciso rodá-lo antes de exportar.

## 📂 Estrutura

| Pasta | O que é |
|---|---|
| `projeto/v2/` | Código do jogo ativo e apresentação 960×540; guia em `v2/LEIA-ME.md`. |
| `projeto/scripts/hordas/` | Legado v1 e serviços compartilhados (autoloads). `armas/` contém os tipos de arma da v1. |
| `projeto/dados/*.json` | Todo o conteúdo: heróis, raças, classes, armas, monstros, regiões, duelo. Mudar o jogo quase sempre é mexer só aqui; cada arquivo explica os campos no `_ajuda`. |
| `projeto/assets/` | Imagens e sons já prontos para o jogo. |
| `projeto/testes/` | Testes automáticos (uma cena por assunto). |
| `fonte_arte/` | Geradores da arte. `modelos3d/` monta heróis, monstros e cenários no Blender e renderiza em pixel art. |
| `fonte_audio/` | Scripts que geram e preparam as músicas. |
| `LEIA-ME.txt` | Regras e controles em texto (parte dele ainda descreve o tema antigo). |

## 🎨 Arte: do 3D ao pixel art

A arte sai de **modelos 3D renderizados como pixel art** no Blender 4.5 LTS: render no tamanho final sem antialiasing, sombreado em faixas, paleta fixa, luz de borda e contorno de 1 px, com a mesma luz das sombras do jogo.

<p align="center">
  <img src="../../docs/imagens/cavaleiro.png" alt="Cavaleiro: 4 direções x 9 quadros de animação" width="600"><br>
  <sub>4 direções × 9 quadros, gerado por <code>fonte_arte/modelos3d/cavaleiro.py</code></sub>
</p>

```bash
blender -b -P jogos/hordas/fonte_arte/modelos3d/cavaleiro.py
```

No legado v1, os monstros de 5 vistas (`horror.py`, `floresta.py`, `pantano.py`, `deserto.py`, `gelo.py`, `reino.py`) saem com um ciclo de andar de 6 quadros mais o branco de dano; o jogo anda o ciclo pela distância percorrida. Quadros por folha, inclinação, quique, aperto de golpe e preparo de investida ficam em `projeto/dados/animacao_monstros.json`. Para regerar: `blender -b -P jogos/hordas/fonte_arte/modelos3d/<regiao>.py` (as 6 regiões podem rodar em paralelo; atualiza `dados/quadros_monstros.json`).

Técnicas e referências em [`docs/VISUAL_KIKIU.md`](../../docs/VISUAL_KIKIU.md); o resto da documentação está no [índice de `docs/`](../../docs/README.md).
