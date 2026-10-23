# Ritmo da v2 — resumo da QA histórica de 21/10/2026

Os relatórios completos, tentativas e manifestos foram retirados do Git no fechamento #400 e preservados no [anexo histórico](https://github.com/user-attachments/files/33817845/qa-historica-21-outubro.zip). O ZIP reúne os 14 arquivos originais de ritmo e save real; SHA-256: `f9597197eeb68074016e9073765e973f6de7a481330ebcb139f469a3a726b3e7`. Este resumo não representa uma nova execução.

A comparação usou Godot 4.4.1 headless, Floresta/Fácil, três arquétipos, sementes 1 e 2, teto de 300 s e `--playtest_q` nos dois lados. O controlador/vigia corrigido foi igual nas duas fases (SHA-256 `a0cc4e265e49d6617d7f7ccb3a60e4d4b4cb6c026b18835ace9aa14bd008d487`). A referência BEFORE foi `3681c15043879bb1d2b2bdcbff10653a1b28abb0`; os AFTER históricos foram `4c221cb`, `e5bdd32` após corrigir o alcance e `72149ec` após incluir o segundo raio da Chuva. Os seis AFTER foram repetidos a cada correção; não houve aprovação retroativa do produto anterior.

Os seis pares finais encerraram com código 0, sem SCRIPT ERROR nem trava, todos no teto de 300 s. Os níveis finais passaram de 25–28 para 25–30; o pico de vivos ficou até 84. A primeira tentativa teve uma trava do Nicão e interferência de fixture em APPDATA QA compartilhado: continua reprovada no anexo. O controle posterior Nicão/Floresta/Fácil/semente 1 sem Q chegou a 300 s, nível 26 e 666 abates; valida somente aquela regressão do robô.

A guarda externa foi pulada nos lotes iniciais e no BEFORE porque a pasta QA ainda não existia; isso não prova hashes preservados. Nos AFTER corrigidos e no controle posterior, a pasta foi criada antes e a guarda permaneceu inalterada. APPDATA era exclusivo de QA; a prova de save sujo é [separada](../save_real_2026_10_21.md).

As regressões focadas provaram o acerto real do Q final do Lucas a 575 px, inclusive com herói afastado, e a extra da Chuva além da caixa anterior, mantendo controles fora do alcance e pool fixo. O segundo raio reproduziu uma falha antes e passou depois; a suíte de ritmo e as suítes afetadas registraram `falhas=0`. Avisos de renderer na saída headless não comprovam ausência de vazamento gráfico.

Teto de tempo não é vitória. A amostra mede o efeito conjunto das regras, não isola curvas, não aprova balanço humano, quatro mapas ou dificuldades. A política não aciona E/Ruptura do Hazaki; Matheus compartilha arquétipo, mas sua cobertura visual é separada no #394. `proc_ms` headless não é FPS renderizado nem prova desempenho no i5-3470. Os resultados históricos não substituem QA do commit atual.
