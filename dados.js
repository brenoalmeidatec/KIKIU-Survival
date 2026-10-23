window.MAPA = {
  "data": "2026-10-08",
  "projeto": "KIKIU-Survival (brenoalmeidatec/KIKIU-Survival) — foco no K.I.K.I.U em jogos/hordas/projeto (Godot 4.4.1)",
  "commit_referencia": {
    "ref": "origin/main",
    "hash": "748e0c8",
    "titulo": "Armas universais (#115), cenários das 4 regiões (#112) e fonte/cartas (#98) (#120)",
    "quando": "2026-10-08 00:16 -0300"
  },
  "primeira_execucao": false,
  "comparacao": "Comparado com estado.anterior.json (mesmo commit da main, 748e0c8; a main não andou). Mudou só o Port PS Vita, no marco da noite de 2026-10-08: template próprio do Vita compilado com módulo C++ (HordaVita, VitaHW) e patches do motor; conversor GDScript 4 -> 3 gera o jogo inteiro da main (88/88 scripts, partidas inteiras no PC, 41/48 testes no Godot 3); 4 pacotes .vpk prontos pro Alisson testar de manhã. Decisão nova: como levar a horda (inimigos.gd) pra C++.",
  "partes": [
    {
      "id": "combate",
      "nome": "Combate e armas",
      "resumo": "Armas automáticas que crescem com o nível, 11 evoluções, 10 armas com elemento e agora 50 armas universais com 8 variações. Limite de 5 slots com no máximo 2 únicas, ascensão, reforja e fusões; a cura só aparece quando não sobra outra melhoria. Faltam os ícones das armas universais e uma mecânica própria pras fusões.",
      "status": "em andamento",
      "evidencia": "#108, #117 e #120 (748e0c8) na main; #115 aberta; suíte 46/46",
      "mudou": null,
      "nota": "As 50 armas e as fusões nunca foram jogadas por uma pessoa; o equilíbrio entra na conferência da #63."
    },
    {
      "id": "heroi",
      "nome": "Herói criado, preparo e elementos",
      "resumo": "Herói criado completo: 13 raças com gancho, classe, atributos, defeito, cores, até 6 heróis salvos, morte permanente. Preparo com mochila, comidas, consumíveis e amuletos, e baú pessoal. Elementos (fogo, gelo, raio, veneno) com reações e a poça de gelo.",
      "status": "concluída",
      "evidencia": "#77, #78, #86, #88, #89 e #90; #72 fechada; testes criacao2, PREPARO e RACAS",
      "mudou": null,
      "nota": "Os números das raças e elementos são palpite; ficam pra conferência jogando (padrão: manter)."
    },
    {
      "id": "mundo",
      "nome": "Mundo, regiões e mapa",
      "resumo": "5 regiões × 5 fases com chefe, santuários, eventos e luz que escurece até o chefe. Mapa em ramificação com a arte de cada região e abertura cinematográfica. Agora as 5 regiões têm cenários diferentes por andar.",
      "status": "concluída",
      "evidencia": "#64, #68 e #96 fechadas; #101, #107, #113 e #120 (748e0c8); testes mapa, abertura e variantes",
      "mudou": null
    },
    {
      "id": "fase",
      "nome": "Fase viva, estilo Hades (#112)",
      "resumo": "Na main: prorrogação que esquenta, portal de saída com transição, missão do chefe com 4 tipos, sala da loja por jogador (refeita no #119, com luz de velas, lareira e partículas) e cenários por andar nas 5 regiões. Falta só a loja obrigatória entre fases.",
      "status": "em andamento",
      "evidencia": "#113, #114, #118, #119 (f55e512) e #120 (748e0c8) na main; testes prorrogacao, variantes, missao_chefe e loja_sala",
      "mudou": null,
      "nota": "A loja ainda só aparece quando o mapa sorteia o nó. Fragmentos, pilares e altar seguem desenhados por código. Online da missão e da loja fica pro fim."
    },
    {
      "id": "corrida",
      "nome": "Profundidade e equilíbrio",
      "resumo": "Todo o código da corrida está entregue: especial, Calor, conjuntos, objetivos, santuários, dádivas, cartas e legibilidade. O que falta pra fechar a #63 é calibrar jogando, decidir a música do duelo e os objetivos dos andares 3, 5 e 7.",
      "status": "em andamento",
      "esperando": null,
      "evidencia": "#66, #67, #86, #89, #91 e #117 na main; #63 aberta; #79 fechada",
      "mudou": null,
      "nota": "Gárgula e Fantasma quase não disparam no robô; Ciclone de Aço fraca. As 50 armas novas e as fusões entram na mesma conferência."
    },
    {
      "id": "online",
      "nome": "Online e multiplayer",
      "resumo": "Até 6 pessoas sem servidor pago: lobby, salas, chat de texto e voz, herói criado, mochila conferida pelo anfitrião, elementos e raças. Portal, missão e loja só rodam no anfitrião; falta mandar o estado aos clientes.",
      "status": "travada",
      "esperando": "A vez dele: o Alisson decidiu que online fica por último, depois de todo o refino do jogo solo (2026-10-07).",
      "evidencia": "#13 e #55 fechadas; #92; LOGBOOK 'prioridade: multiplayer por último'",
      "mudou": null,
      "nota": "Pendências no marco m12."
    },
    {
      "id": "arte_som",
      "nome": "Arte, animação e som",
      "resumo": "Pixel art a partir de 3D nas 5 regiões, animações fluidas e 7 faixas com crossfade. Sala da loja refeita com arte do Blender, luz e partículas (#119). Fonte Jacquard 12, raridade escrita uma vez só e textos das dádivas (#98). Faltam ícones de 3 dádivas e das armas universais.",
      "status": "em andamento",
      "evidencia": "#119 (f55e512) e #120 (748e0c8); #98 e #116 abertas; #6 sem resposta desde 2026-10-05",
      "mudou": null,
      "nota": "Pergunta ao Breno sobre onde estão os arquivos dos pacotes; padrão: redesenho próprio."
    },
    {
      "id": "distribuicao",
      "nome": "Desempenho, janela e distribuição",
      "resumo": "Qualidade gráfica automática, engasgo do começo reduzido, janela maximizada, versão no título e instalador Windows. O fps com 500 inimigos foi medido com a máquina ocupada (~8 ms de processamento mediano, sem otimização segura achada); falta medir com a máquina parada. O atualizador depende de um repositório público de versões.",
      "status": "travada",
      "esperando": "O Breno criar o repositório público KIKIU-Releases (#106).",
      "evidencia": "#109, #110 e #111 na main; #94 (medição de proc_ms); #106 aberta",
      "mudou": null,
      "nota": "A medição com a máquina parada não depende de ninguém."
    },
    {
      "id": "vita",
      "nome": "Port PS Vita",
      "resumo": "Template próprio do Vita compilado (WSL 'vita-build', VitaSDK 2026.08) com módulo C++: HordaVita (horda num draw call) e VitaHW (touch frontal e traseiro, acelerômetro, clocks, bateria), mais patches do motor (L/R, touch). Um conversor GDScript 4 -> 3 gera o jogo inteiro da main (exportar_jogo.sh): 88/88 scripts carregam, partidas inteiras rodam no PC e 41/48 testes passam no Godot 3. Quatro .vpk prontos pro teste no aparelho.",
      "status": "em andamento",
      "esperando": null,
      "status_detalhe": "em andamento: jogo convertido roda no PC; aguardando teste no Vita",
      "evidencia": "PR #87 (rascunho), cfeaa91 na branch alisson/vita-piloto; 813138d (partidas inteiras no Godot 3), 9c47e97 (41/48 testes), 6194c89 (log de fps); jogos/hordas-vita/STATUS.md e PLANO_BACKPORT.md",
      "mudou": "Do build do template em curso pra jogo convertido rodando no PC: template com C++ compilado, conversor automático pronto e 4 .vpk gerados (KIKU00001 a 00004). Falta ver no aparelho.",
      "nota": "Pacotes: kikiu_piloto_cpp.vpk (KIKU00002, piloto com C++), kikiu_diag.vpk (KIKU00003, diagnóstico), kikiu_piloto.vpk (KIKU00001) e kikiu_vita.vpk (KIKU00004, o jogo de verdade, log de fps em ux0:data/kikiu_vita_log.txt). Os 7 testes que falham no Godot 3 são online, medição de tempo e skew. No jogo convertido a horda tem teto de 60 inimigos vivos até ir pra C++. Fora dos marcos do jogo principal."
    }
  ],
  "marcos": [
    {
      "id": "m1",
      "nome": "Horda jogável com os amigos",
      "status": "concluído",
      "proposto": true
    },
    {
      "id": "m2",
      "nome": "Online completo",
      "status": "concluído",
      "proposto": true
    },
    {
      "id": "m3",
      "nome": "Mundo em 5 regiões",
      "status": "concluído",
      "proposto": true
    },
    {
      "id": "m4",
      "nome": "Arsenal dark fantasy",
      "status": "concluído",
      "proposto": true
    },
    {
      "id": "m5",
      "nome": "Herói criado completo (#72)",
      "status": "concluído",
      "proposto": true
    },
    {
      "id": "m8",
      "nome": "Fase viva, estilo Hades (#112)",
      "status": "próximo",
      "proposto": true
    },
    {
      "id": "m10",
      "nome": "Arsenal grande e fusões (#115)",
      "status": "a fazer",
      "proposto": true
    },
    {
      "id": "m9",
      "nome": "Visual e identidade (#98, #116)",
      "status": "a fazer",
      "proposto": true
    },
    {
      "id": "m7",
      "nome": "Pronto pro zip final (#79 fechada, falta #63)",
      "status": "a fazer",
      "proposto": true
    },
    {
      "id": "m6",
      "nome": "Corrida com profundidade (#63)",
      "status": "esperando o Alisson",
      "proposto": true
    },
    {
      "id": "m11",
      "nome": "Atualização automática (#106)",
      "status": "a fazer",
      "proposto": true
    },
    {
      "id": "m12",
      "nome": "Online por último (#94 item 5)",
      "status": "a fazer",
      "proposto": true
    }
  ],
  "proximo_marco": {
    "id": "m8",
    "nome": "Fase viva, estilo Hades (#112)",
    "faltam": 1,
    "total": 8,
    "itens_faltando": [
      "Loja obrigatória entre fases, estilo Hades"
    ],
    "mudou": null
  },
  "proximo_passo": {
    "acao": "Fazer a loja obrigatória entre fases (#112): depois de cada fase vencida, o jogador passa pela sala da loja antes do próximo nó, em vez de depender do sorteio do mapa.",
    "porque": "É o único item que falta pro m8, a sala já existe e foi refeita no #119, e não depende de ninguém.",
    "paralelo": "Em paralelo, no Vita (PR #87): de manhã o Alisson instala e roda os 4 .vpk e libera o FTP pra puxar o CSV e o log de fps; só depois disso começa a horda em C++. Também: medir o fps com 500 inimigos com a máquina parada (#94), ícones das armas universais e mecânica das fusões (#115), ícones de 3 dádivas (#98).",
    "mudou": null
  },
  "decisoes_pendentes": [
    {
      "pergunta": "Calibrar jogando: começo do Hazaki, prorrogação, missão, 50 armas universais e fusões estão bons na mão?",
      "opcoes": [
        "Manter os números atuais",
        "Hazaki mais difícil: 0,8 / 0,92",
        "Mexer na prorrogação ou no equilíbrio das armas universais"
      ],
      "padrao": "Manter os números atuais até o Alisson jogar.",
      "quem": "Alisson",
      "desde": "2026-10-07",
      "fonte": "#63, #117, #114 e #120"
    },
    {
      "pergunta": "Música do duelo final: manter a Crusade ou trocar pela Gathering Darkness (já baixada)?",
      "opcoes": [
        "Manter a Crusade",
        "Trocar pela Gathering Darkness"
      ],
      "padrao": "Manter a Crusade.",
      "quem": "Alisson",
      "desde": "2026-10-06",
      "fonte": "#63 (antes na #79, já fechada)"
    },
    {
      "pergunta": "Objetivos próprios por fase: também nos andares 3, 5 e 7, ou só nos 2 e 4 de cada região como hoje?",
      "opcoes": [
        "Só andares 2 e 4 (como está)",
        "Acrescentar 3, 5 e 7"
      ],
      "padrao": "Só andares 2 e 4.",
      "quem": "Alisson",
      "desde": "2026-10-08",
      "fonte": "#63; #86"
    },
    {
      "pergunta": "Pacotes de ícones, HUD e sprites do Breno (#116): onde estão os arquivos?",
      "opcoes": [
        "O Breno manda os arquivos e eles viram base de arte",
        "Usar só como referência e redesenhar no nosso pixel art"
      ],
      "padrao": "Redesenho próprio, usando os pacotes só como referência. O Odyssey (plugin de Unreal) foi descartado.",
      "quem": "Breno",
      "desde": "2026-10-08",
      "fonte": "#116 (avaliação)"
    },
    {
      "pergunta": "Criar o repositório público só de versões (KIKIU-Releases) pro jogo se atualizar sozinho?",
      "opcoes": [
        "Criar, dar acesso de escrita ao Alisson e publicar à mão",
        "Criar e publicar automático pelo GitHub Actions",
        "Ficar sem atualizador"
      ],
      "padrao": "Sem atualizador: o Breno continua gerando o instalador à mão.",
      "quem": "Breno",
      "desde": "2026-10-07",
      "fonte": "#106"
    },
    {
      "pergunta": "Ajustes de admin no GitHub: apagar a branch sozinho depois do merge e escrever a descrição do repositório",
      "opcoes": [
        "O Breno marca 'Automatically delete head branches' e escreve a descrição",
        "Deixar como está"
      ],
      "padrao": "Fica como está; mesclamos com --delete-branch.",
      "quem": "Breno",
      "desde": "2026-10-07",
      "fonte": "#95"
    },
    {
      "pergunta": "Futuro da Cairu: fica neste repositório ou vai pra um só dela? E dividir o mundo.gd (2.080 linhas)?",
      "opcoes": [
        "Deixar como está, separada por pasta e etiqueta",
        "Repositório próprio, levando o histórico sem reescrever a main",
        "Dividir o mundo.gd, só movendo código"
      ],
      "padrao": "Fica como está e congelada.",
      "quem": "Breno",
      "desde": "2026-10-05",
      "fonte": "#2 e #95"
    },
    {
      "pergunta": "Visão gráfica da #6: quais referências, que tipo de 3D, o que incomoda e o que melhorar primeiro?",
      "opcoes": [
        "O Breno responde as 5 perguntas da #6",
        "Fechar a #6 e seguir pela #98 e #116"
      ],
      "padrao": "Seguir pela #98 e #116 enquanto o Breno não responde.",
      "quem": "Breno",
      "desde": "2026-10-05",
      "fonte": "#6"
    },
    {
      "pergunta": "Vita: como levar a horda do jogo (inimigos.gd) para C++?",
      "opcoes": [
        "Portar a class V, o atualizar e o _draw para C++ (HordaVita)",
        "Propor à main uma horda orientada a dados, que serve aos dois",
        "Aceitar pouca horda no Vita"
      ],
      "padrao": "Medir no aparelho primeiro; depois começar pela opção 1 só para movimento, separação e desenho.",
      "quem": "Alisson",
      "desde": "2026-10-08",
      "fonte": "PR #87; jogos/hordas-vita/STATUS.md e PLANO_BACKPORT.md"
    }
  ],
  "paineis": [
    {
      "nome": "Fila de trabalho",
      "motivo": "O Alisson fixou a ordem (#112, #115, #98, #94 fps, online por último) e PC e notebook trabalham ao mesmo tempo. A fila mostra o que é agora e o que vem depois, pra ninguém pegar a mesma coisa."
    },
    {
      "nome": "Saúde dos testes",
      "motivo": "Cada entrega só entra com as 46 cenas sem falha e o robô sem SCRIPT ERROR; é o portão real do projeto."
    },
    {
      "nome": "Pra conferir no olho",
      "motivo": "O que só uma pessoa confirma: os 4 .vpk no Vita e o FTP liberado (de manhã) e, no jogo principal, armas universais, fusões, missão, loja nova e cenários das 4 regiões, vistos só por print e pelo robô. É o roteiro da próxima sessão do Alisson."
    },
    {
      "nome": "Trabalho fora da main",
      "motivo": "Mostra o que existe só nesta máquina e o que está em rascunho no GitHub (o Vita, #87, que trabalha sozinho esta noite), pra ninguém pisar no trabalho do outro."
    },
    {
      "nome": "Issues e PRs abertos",
      "motivo": "10 issues abertas (a #79 fechou): fase (#112), armas (#115), visual (#98, #116, #6), fila (#94, #63), atualizador (#106) e o que é do Breno (#95, #2)."
    }
  ],
  "testes": {
    "cenas": 46,
    "falhas": 0,
    "quando": "2026-10-08",
    "fonte": "#120: suíte 46/46 com falhas=0",
    "observacao": "rolamento e transicao dependem de tempo e já falharam sob carga (passam ao repetir). Depois do pull, rodar --import antes dos testes.",
    "mudou": null
  },
  "riscos": [
    {
      "risco": "50 armas universais, fusões, missão e loja nunca foram jogadas por uma pessoa.",
      "efeito": "Equilíbrio pode ficar fácil ou cansativo, e fusões sem mecânica própria podem parecer só soma de números.",
      "o_que_fazer": "Painel 'Pra conferir no olho'; padrão é manter os números até alguém jogar."
    },
    {
      "risco": "Armas universais sem ícone próprio e 3 dádivas sem ícone.",
      "efeito": "Cartas destoam e ficam difíceis de ler no meio da horda.",
      "o_que_fazer": "Itens abertos no m10 e no m9; redesenho próprio (padrão da #116)."
    },
    {
      "risco": "fps com 500 inimigos medido só com a máquina ocupada.",
      "efeito": "Os ~8 ms podem estar inflados ou esconder um pico real.",
      "o_que_fazer": "Medir de novo com a máquina parada antes de mexer em código."
    },
    {
      "risco": "Portal, missão e loja só rodam no anfitrião.",
      "efeito": "No online, os clientes não veem a missão nem dividem a loja direito.",
      "o_que_fazer": "Fica no m12 (online por último)."
    },
    {
      "risco": "Testes que dependem de tempo (rolamento, transicao).",
      "efeito": "Podem barrar um PR bom sob carga.",
      "o_que_fazer": "Repetir antes de mexer; guardar a primeira linha FALHOU: se repetir."
    },
    {
      "risco": "O LEIA-ME.txt do jogo pode ainda descrever o tema antigo (Cairu x vírus).",
      "efeito": "Vai junto no zip e confunde quem testa.",
      "o_que_fazer": "Conferir junto com o resto da #98."
    },
    {
      "risco": "Template com C++ e jogo convertido nunca rodaram no Vita; só no PC (Godot 3).",
      "efeito": "Um .vpk pode não abrir ou rodar lento; a horda do jogo ainda é GDScript (teto de 60 inimigos vivos).",
      "o_que_fazer": "Rodar primeiro o diag (KIKU00003) e o piloto com C++ (KIKU00002), depois o jogo (KIKU00004); puxar CSV e log por FTP antes de mexer na horda. A v2 (30,4 fps) segue como base."
    }
  ],
  "so_nesta_maquina": {
    "worktrees_de_agentes": [],
    "observacao": "Pasta principal em dia com a origin/main (748e0c8), sem nada pendente. A worktree do Vita (cfeaa91) já tem a main mesclada e está publicada, sem nada pendente.",
    "worktree_vita": {
      "pasta": "E:\\Dev\\KIKIU-Vita\\repo",
      "branch": "alisson/vita-piloto",
      "situacao": "publicado (PR #87 rascunho, cfeaa91); template com C++ compilado na distro WSL 'vita-build'; os 4 .vpk ficam nesta máquina"
    },
    "mudou": "A worktree do Vita mesclou a main e ganhou template, conversor e 4 .vpk."
  },
  "github": {
    "issues_abertas": [
      {
        "n": 116,
        "titulo": "Avaliar pacotes de ícones, HUD e sprites do Breno e o plugin Odyssey",
        "nota": "avaliada: Odyssey não serve; pergunta ao Breno sobre os arquivos"
      },
      {
        "n": 115,
        "titulo": "50 armas universais, variações, fusões e equilíbrio pós nível 30",
        "nota": "grosso no #120; faltam ícones e mecânica das fusões"
      },
      {
        "n": 112,
        "titulo": "Transição de fase, missões do chefe, cronômetro, loja e cenários",
        "nota": "falta só a loja obrigatória"
      },
      {
        "n": 106,
        "titulo": "Atualizador automático (repositório público de versões)",
        "nota": "esperando o Breno"
      },
      {
        "n": 98,
        "titulo": "Ícones que combinem, textos bonitos e fonte mística em pixel",
        "nota": "fonte e textos no #120; faltam ícones de 3 dádivas"
      },
      {
        "n": 95,
        "titulo": "Organização do GitHub: o que precisa do Breno",
        "nota": "esperando o Breno"
      },
      {
        "n": 94,
        "titulo": "Fazer tudo que falta",
        "nota": "fps medido ocupado (~8 ms); falta medir parado; online por último"
      },
      {
        "n": 63,
        "titulo": "O que falta para terminar o jogo",
        "nota": "calibrar jogando, música do duelo, objetivos 3/5/7"
      },
      {
        "n": 6,
        "titulo": "Revisar a visão do jogo e os gráficos",
        "nota": "esperando o Breno"
      },
      {
        "n": 2,
        "titulo": "Cairu: mundo.gd muito grande",
        "nota": "estacionada"
      }
    ],
    "issues_fechadas_agora": [
      {
        "n": 79,
        "titulo": "Terminar tudo que falta (fila principal)",
        "nota": "auditoria: tudo entregue"
      }
    ],
    "prs_abertos": 1,
    "prs_abertos_lista": [
      {
        "n": 87,
        "titulo": "Port PS Vita: piloto de desempenho (Godot 3 / godot-vita)"
      }
    ],
    "commits_main": {
      "2026-10-05": 7,
      "2026-10-06": 34,
      "2026-10-07": 22,
      "2026-10-08": 1
    }
  },
  "decisoes_resolvidas": [
    {
      "pergunta": "Resultado do piloto no Vita decide backport, fase 2 ou abandono",
      "decidido": "Seguir, opção 2: build do template Vita (VitaSDK no WSL 'vita-build') com módulo C++ da horda, mirando 40 a 50 fps.",
      "quem": "Alisson",
      "quando": "2026-10-08",
      "base": "v2 no aparelho: ~185 inimigos a 30 fps; 300 com luz a 30,4 fps (passou no limite)"
    }
  ],
  "pendencias_manha": [
    {
      "o_que": "Testar no Vita o .vpk com módulo C++ (ainda não testado): instalar e rodar kikiu_piloto_cpp.vpk (KIKU00002) e kikiu_diag.vpk (KIKU00003)",
      "quem": "Alisson",
      "quando": "manhã de 2026-10-09",
      "contexto": "Template com C++ compilado na noite de 2026-10-08, mas só rodou no PC. Mesma rampa da v2: comparar com 30,4 fps (300 com luz); meta 40 a 50 fps.",
      "fonte": "PR #87; jogos/hordas-vita/STATUS.md na branch"
    },
    {
      "o_que": "Instalar e rodar kikiu_piloto.vpk (KIKU00001) e kikiu_vita.vpk (KIKU00004, o jogo de verdade convertido)",
      "quem": "Alisson",
      "quando": "manhã de 2026-10-09",
      "contexto": "O KIKU00004 grava o log de fps em ux0:data/kikiu_vita_log.txt.",
      "fonte": "PR #87; jogos/hordas-vita/STATUS.md"
    },
    {
      "o_que": "Liberar o FTP do Vita pra puxar o CSV e o log",
      "quem": "Alisson",
      "quando": "manhã de 2026-10-09",
      "contexto": "Sem os números do aparelho, a decisão da horda em C++ fica parada no padrão (medir primeiro).",
      "fonte": "PR #87"
    }
  ]
};
window.MARCOS = {
  "atualizado_em": "2026-10-08",
  "marcos": [
    { "id": "m1", "nome": "Horda jogável com os amigos", "proposto": true, "status": "concluído", "itens": [
      { "nome": "Heróis, armas globais e exclusivas (#19)", "status": "concluído", "evidencia": "#23, #24, #25" },
      { "nome": "Dragão Cobalto do Hazaki (#20)", "status": "concluído", "evidencia": "#30" },
      { "nome": "Descobertas do mundo: santuários, fragmentos, eventos (#21)", "status": "concluído", "evidencia": "#41" },
      { "nome": "UI/UX legível com mouse e controle (#7)", "status": "concluído", "evidencia": "#43" },
      { "nome": "Hazaki final, mortes, horror e mapa de progressão (#32)", "status": "concluído", "evidencia": "#39 a #49" } ] },
    { "id": "m2", "nome": "Online completo", "proposto": true, "status": "concluído", "itens": [
      { "nome": "Polimento e desempenho com 500 inimigos (#55)", "status": "concluído", "evidencia": "#56, #57, #58" },
      { "nome": "Lobby, lista de salas, chat de texto e de voz (#13)", "status": "concluído", "evidencia": "#59 a #62" } ] },
    { "id": "m3", "nome": "Mundo em 5 regiões", "proposto": true, "status": "concluído", "itens": [
      { "nome": "Regiões 5 × 5 com chefe por região (#64)", "status": "concluído", "evidencia": "#69, #70, #73 a #76" },
      { "nome": "Movimento e ambientação estilo Dimraeth (#68)", "status": "concluído", "evidencia": "#82, #83, #84" } ] },
    { "id": "m4", "nome": "Arsenal dark fantasy", "proposto": true, "status": "concluído", "itens": [
      { "nome": "Troca de tema: fim da informática nas armas e itens (#65)", "status": "concluído", "evidencia": "#80" },
      { "nome": "Seis armas públicas novas com evolução (#65)", "status": "concluído", "evidencia": "#81" } ] },
    { "id": "m5", "nome": "Herói criado completo (#72)", "proposto": true, "status": "concluído", "itens": [
      { "nome": "Raça e classe (marco 1)", "status": "concluído", "evidencia": "#77" },
      { "nome": "Herói criado morre de vez", "status": "concluído", "evidencia": "#78" },
      { "nome": "Criação marco 2: nome, pontos, defeito voluntário, paleta, 6 heróis salvos, herói criado no online", "status": "concluído", "evidencia": "#86" },
      { "nome": "Preparo com mochila, comida e amuleto + baú pessoal", "status": "concluído", "evidencia": "#88 (d77264f)" },
      { "nome": "Elementos: estados, poça de gelo, efeitos em camadas", "status": "concluído", "evidencia": "#89 (56926d0)" },
      { "nome": "Raças com gancho (as outras 8)", "status": "concluído", "evidencia": "#90 (0229301): 8 raças com gancho, 13 no total" } ] },
    { "id": "m8", "nome": "Fase viva, estilo Hades (#112)", "proposto": true, "status": "próximo", "itens": [
      { "nome": "Mapa em ramificação com arte por região (#96)", "status": "concluído", "evidencia": "#101 (4190f43)" },
      { "nome": "Abertura cinematográfica de fase", "status": "concluído", "evidencia": "#107 (09045af)" },
      { "nome": "Marco A: prorrogação que esquenta, portal de saída e transição", "status": "concluído", "evidencia": "#114 (97f7f38); prints com janela conferidos; online por último" },
      { "nome": "Marco B: 5 variantes de cenário da Floresta", "status": "concluído", "evidencia": "#113 (6bfad6d); teste variantes" },
      { "nome": "Marco B: variantes do Pântano, Deserto, Gelo e Reino", "status": "concluído", "evidencia": "#120 (748e0c8); teste variantes" },
      { "nome": "Marco C: missão do chefe com 4 tipos (fragmentos, pilares, selos, invocar)", "status": "concluído", "evidencia": "#118 (848ac66); teste missao_chefe" },
      { "nome": "Marco D: sala da loja por jogador, preço sobe a cada compra", "status": "concluído", "evidencia": "#118 (848ac66); teste loja_sala" },
      { "nome": "Loja obrigatória entre fases, estilo Hades", "status": "a fazer", "evidencia": "Único item que falta; sala refeita no #119 (f55e512)" } ] },
    { "id": "m10", "nome": "Arsenal grande e fusões (#115)", "proposto": true, "status": "a fazer", "itens": [
      { "nome": "Armas crescem com o nível", "status": "concluído", "evidencia": "#108; começo suavizado no #117" },
      { "nome": "50 armas universais", "status": "concluído", "evidencia": "#120 (748e0c8)" },
      { "nome": "8 variações por arma conforme o que se pega", "status": "concluído", "evidencia": "#120" },
      { "nome": "Limite de 5 slots com no máximo 2 únicas, ascensão, reforja e fusões", "status": "concluído", "evidencia": "#120" },
      { "nome": "Depois do nível 30, cura só como último recurso", "status": "concluído", "evidencia": "#120" },
      { "nome": "Ícones das armas universais", "status": "a fazer", "evidencia": "#115" },
      { "nome": "Mecânica própria das fusões", "status": "a fazer", "evidencia": "#115" } ] },
    { "id": "m9", "nome": "Visual e identidade (#98, #116)", "proposto": true, "status": "a fazer", "itens": [
      { "nome": "Animações fluidas de heróis e monstros (#97)", "status": "concluído", "evidencia": "#102, #103" },
      { "nome": "Sala da loja com arte do Blender, luz e partículas", "status": "concluído", "evidencia": "#119 (f55e512)" },
      { "nome": "Ícones que combinem com cada item, carta e dádiva", "status": "a fazer", "evidencia": "#98: faltam os ícones de 3 dádivas" },
      { "nome": "Textos de dark fantasy, raridade uma vez só, acentos certos", "status": "concluído", "evidencia": "#120: raridade uma vez só e textos das dádivas" },
      { "nome": "Fonte mística em pixel, licença livre, com acentos", "status": "concluído", "evidencia": "#120: Jacquard 12" },
      { "nome": "Avaliar os pacotes do Breno e o plugin Odyssey", "status": "concluído", "evidencia": "#116 avaliada: Odyssey é plugin de Unreal; pacotes só como referência" },
      { "nome": "Revisão visual grande da #6", "status": "esperando o Breno", "evidencia": "#6 sem resposta desde 2026-10-05" } ] },
    { "id": "m7", "nome": "Pronto pro zip final (#79 fechada, falta #63)", "proposto": true, "status": "a fazer", "itens": [
      { "nome": "Música: ouvir e decidir o duelo (Crusade ou Gathering Darkness, já baixada)", "status": "esperando o Alisson", "evidencia": "#63; padrão: Crusade" },
      { "nome": "Golpe de cliente online leva o id da arma (cliente aplica elemento)", "status": "concluído", "evidencia": "#92 (a3d5e4b)" },
      { "nome": "Desempenho em PC antigo: qualidade gráfica, engasgo do começo", "status": "concluído", "evidencia": "#109 (20bf57a); docs/PERF_2026-10-07.md" },
      { "nome": "Medir fps com 500 inimigos com a máquina parada (#94)", "status": "a fazer", "evidencia": "Medido com a máquina ocupada: ~8 ms medianos, sem otimização segura achada" },
      { "nome": "Fechar a #79", "status": "concluído", "evidencia": "Fechada em 2026-10-08 (auditoria: tudo entregue)" },
      { "nome": "Fechar a #63 (calibrar jogando, música, objetivos 3/5/7)", "status": "a fazer", "evidencia": "#63; padrões: manter números, Crusade, só andares 2 e 4" } ] },
    { "id": "m6", "nome": "Corrida com profundidade (#63)", "proposto": true, "status": "esperando o Alisson", "itens": [
      { "nome": "Especial por herói (tecla E)", "status": "concluído", "evidencia": "#66" },
      { "nome": "Calor: dificuldade com modificadores", "status": "concluído", "evidencia": "#67" },
      { "nome": "Etiquetas e bônus de conjunto", "status": "concluído", "evidencia": "#86" },
      { "nome": "Objetivo próprio por fase (3, 5 e 7 primeiro)", "status": "concluído", "evidencia": "#86 (andares 2 e 4); 3/5/7 é decisão, padrão: só 2 e 4" },
      { "nome": "Cartas que mudam o comportamento do jogo", "status": "concluído", "evidencia": "#86" },
      { "nome": "Santuários que faltam: prova, outro elemento, dádivas em dupla", "status": "concluído", "evidencia": "#86; requisito de elemento do selado no #89" },
      { "nome": "Legibilidade: barra de elite, etiqueta de drop, marca de área", "status": "concluído", "evidencia": "#82; #91 (1ad307a)" },
      { "nome": "Começo do Hazaki recalibrado com o robô", "status": "concluído", "evidencia": "#117 (89f7970): média 32 → 45 abates aos 30 s, meta 35" },
      { "nome": "Conferir jogando: Hazaki, prorrogação, raças, elementos, missão, armas universais e fusões", "status": "esperando o Alisson", "evidencia": "Decisão de calibração; padrão: manter os números atuais" } ] },
    { "id": "m11", "nome": "Atualização automática (#106)", "proposto": true, "status": "a fazer", "itens": [
      { "nome": "Versão visível no título, nas Opções e na pausa", "status": "concluído", "evidencia": "#105, #110" },
      { "nome": "Instalador Windows com ícone no .exe", "status": "concluído", "evidencia": "#110, #111 (precisa do rcedit na máquina que exporta)" },
      { "nome": "Repositório público só de versões (KIKIU-Releases)", "status": "esperando o Breno", "evidencia": "#106, passo a passo no comentário" },
      { "nome": "Módulo de atualização: consulta, download do .pck, checksum, aplicar na próxima abertura", "status": "a fazer", "evidencia": "#106; depende do repositório" },
      { "nome": "Publicar a Release a cada marco (à mão ou Actions)", "status": "a fazer", "evidencia": "#106" } ] },
    { "id": "m12", "nome": "Online por último (#94 item 5)", "proposto": true, "status": "a fazer", "itens": [
      { "nome": "Online de 4 a 6 jogadores com herói criado, mochila, elementos e raças", "status": "a fazer", "evidencia": "#94 item 5; os 5 online_*.sh passam com 2 instâncias" },
      { "nome": "Teste online ao vivo entre duas casas (voz, lag, perda)", "status": "a fazer", "evidencia": "#63 'Também vale'" },
      { "nome": "Portal de saída e prorrogação com 2 instâncias reais", "status": "a fazer", "evidencia": "#114: eventos saida_aberta, saida e fase_completa sem teste real" },
      { "nome": "Missão do chefe e loja no cliente (hoje só o anfitrião)", "status": "a fazer", "evidencia": "#118: TODOs em loja.gd e no script da missão" } ] }
  ]
};
window.MAPA_EXTRA = {
  "nota": "Conteúdo do mapa que não está em estado.json nem em marcos.json. Regere junto com o dados.js.",
  "fila": [
    {
      "n": "1",
      "texto": "#112 marcos A, B (Floresta), C e D",
      "estado": "feito",
      "tag": "#113 a #118"
    },
    {
      "n": "2",
      "texto": "Sala da loja refeita: arte do Blender, luz e partículas",
      "estado": "feito",
      "tag": "#119"
    },
    {
      "n": "3",
      "texto": "Variantes de cenário do Pântano, Deserto, Gelo e Reino (#112)",
      "estado": "feito",
      "tag": "#120"
    },
    {
      "n": "4",
      "texto": "50 armas universais, 8 variações, 5 slots, ascensão, reforja e fusões (#115)",
      "estado": "feito",
      "tag": "#120"
    },
    {
      "n": "5",
      "texto": "Fonte Jacquard 12, raridade uma vez só e textos das dádivas (#98)",
      "estado": "feito",
      "tag": "#120"
    },
    {
      "n": "6",
      "texto": "Avaliar pacotes do Breno e Odyssey (#116): só referência",
      "estado": "feito",
      "tag": "#116"
    },
    {
      "n": "7",
      "texto": "Agora: loja obrigatória entre fases (#112); fecha o m8",
      "estado": "agora",
      "tag": "próximo passo"
    },
    {
      "n": "8",
      "texto": "Medir fps com 500 inimigos com a máquina parada (#94)",
      "estado": "a fazer",
      "tag": "m7, em paralelo"
    },
    {
      "n": "9",
      "texto": "Ícones das armas universais e mecânica própria das fusões (#115)",
      "estado": "a fazer",
      "tag": "m10"
    },
    {
      "n": "10",
      "texto": "Ícones de 3 dádivas (#98)",
      "estado": "a fazer",
      "tag": "m9"
    },
    {
      "n": "11",
      "texto": "Fechar a #63: calibrar jogando, música, objetivos 3/5/7",
      "estado": "a fazer",
      "tag": "Alisson"
    },
    {
      "n": "12",
      "texto": "Atualizador automático (#106)",
      "estado": "a fazer",
      "tag": "esperando o Breno"
    },
    {
      "n": "13",
      "texto": "Online: 4 a 6 jogadores, portal, missão e loja no cliente",
      "estado": "a fazer",
      "tag": "por último"
    },
    {
      "n": "14",
      "texto": "Fora da fila (Vita, PR #87): template com C++ e jogo convertido prontos; horda em C++ só depois de medir no aparelho",
      "estado": "fora",
      "tag": "Vita"
    }
  ],
  "olho_humano": [
    {
      "n": "1",
      "texto": "Vita: instalar e rodar os 4 .vpk (KIKU00002 piloto com C++, KIKU00003 diag, KIKU00001, KIKU00004 jogo com log de fps); meta 40 a 50 fps com 300 inimigos",
      "tag": "Alisson, de manhã"
    },
    {
      "n": "1b",
      "texto": "Vita: liberar o FTP pra puxar o CSV e ux0:data/kikiu_vita_log.txt",
      "tag": "Alisson, de manhã"
    },
    {
      "n": "2",
      "texto": "50 armas universais e fusões: as cartas fazem sentido e as builds variam?",
      "tag": "Alisson"
    },
    {
      "n": "3",
      "texto": "Limite de 5 slots (máx. 2 únicas): aperta demais ou de menos?",
      "tag": "Alisson"
    },
    {
      "n": "4",
      "texto": "Sala da loja nova: luz de velas, lareira e partículas, e o preço subindo 25% por compra",
      "tag": "Alisson"
    },
    {
      "n": "5",
      "texto": "Cenários de Pântano, Deserto, Gelo e Reino por andar",
      "tag": "Alisson ou Breno"
    },
    {
      "n": "6",
      "texto": "Fonte Jacquard 12 legível no meio da horda e com acentos",
      "tag": "qualquer um"
    },
    {
      "n": "7",
      "texto": "Missão do chefe: 24 s de espera e distância dos pontos",
      "tag": "Alisson"
    },
    {
      "n": "8",
      "texto": "Começo do Hazaki com 0,85 / 0,95: ficou fácil demais?",
      "tag": "Alisson"
    },
    {
      "n": "9",
      "texto": "Música do duelo: Crusade ou Gathering Darkness",
      "tag": "Alisson"
    },
    {
      "n": "10",
      "texto": "Fps em Alta, Média e Baixa no i5-3470",
      "tag": "Breno"
    }
  ],
  "testes_kpis_extra": [
    {
      "v": 0,
      "k": "SCRIPT ERROR do robô",
      "tipo": "good"
    },
    {
      "v": 2,
      "k": "testes que dependem de tempo e já falharam sob carga (rolamento, transicao)",
      "tipo": ""
    }
  ]
};
