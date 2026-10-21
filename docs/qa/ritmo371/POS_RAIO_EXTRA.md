# Repetição depois de incluir o raio da adaga extra

Depois do primeiro conserto de alcance, a revisão encontrou uma segunda margem necessária na busca: a extra da Chuva herda o raio da adaga, além dos120px de voo. Com área3,304, Mira192% e dt0,1, um segundo corpo atingível podia começar poucos pixels além da caixa anterior. A prova com Q/build reais falhou antes e passou depois. O conserto altera o produto: por isso os **seis casos AFTER foram repetidos**, sem reaproveitar o lote anterior como se fosse o código final.

Runtime novo medido: `72149ecc3570d7915d654b6eeb0a08ef942480e9`. Mesma política, mapa, dificuldade, sementes e Q usado; mesmo controlador/vigia SHA256 `a0cc4e265e49d6617d7f7ccb3a60e4d4b4cb6c026b18835ace9aa14bd008d487`. A referência BEFORE `3681c15043879bb1d2b2bdcbff10653a1b28abb0` não mudou e foi reaproveitada do lote identificado no relatório anterior. Seu estado da guarda (pulada por pasta QA ausente) continua explicitamente registrado. Neste AFTER novo, a raiz QA foi criada antes: a guarda externa foi conferida e permaneceu inalterada. Não houve engine no perfil real, e a prova com save sujo é separada no #391.

| Arquétipo | Semente | Nível antes → depois | Abates | Q usados | Dano sofrido | Pico de vivos |
|---|---:|---:|---:|---:|---:|---:|
| hazaki | 1 | 26 → 25 | 615 → 487 | 3 → 3 | 71 → 53 | 83 → 84 |
| hazaki | 2 | 26 → 29 | 670 → 721 | 4 → 3 | 15 → 17 | 81 → 83 |
| nicao | 1 | 27 → 27 | 665 → 700 | 4 → 3 | 19 → 10 | 81 → 84 |
| nicao | 2 | 28 → 30 | 684 → 771 | 3 → 4 | 18 → 11 | 80 → 84 |
| lucas | 1 | 25 → 29 | 606 → 679 | 4 → 3 | 32 → 32 | 84 → 84 |
| lucas | 2 | 27 → 29 | 659 → 656 | 4 → 3 | 17 → 24 | 75 → 78 |

Os seis processos novos encerraram com código0, sem SCRIPT ERROR nem trava, no teto300s. Com os seis controles anteriores são seis pares; teto não é vitória nem equilíbrio humano aprovado. Os manifests preservam SHA256 dos bytes reais do worktree Windows antes de executar e conferidos ao publicar; ao comparar blobs Git, considerar normalização LF/CRLF. Os relatórios anteriores continuam intactos. O JSON novo guarda produto, contadores e hashes sem CFG, caminhos absolutos ou comandos de máquina.

Ainda falta experiência humana nos quatro mapas e dificuldades. Este headless não mede FPS renderizado nem isola a contribuição de cada curva. As adagas não tiveram dano ou regra estreita de colisão alterados: a busca passou a incluir candidatos que os segmentos reais podem atingir, inclusive Chuva criada no mesmo quadro, corpos grandes e herói afastado da origem.

O lote fixo60Hz não cobre o pico100ms da regressão: esse limite é exercitado pelo teste determinístico separado. O manifesto AFTER agora inclui também Config e project.godot, além de v2/dados. O merge da dependência391 acrescenta proteção antes do autoload nas cenas de teste/GIF; nesta CLI mundo.tscn/--playtest esse caminho não é acionado. A fixture canônica do teste de ritmo é uma alteração de teste, separada do conserto de busca.
