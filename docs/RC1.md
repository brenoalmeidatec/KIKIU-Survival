# Saída do beta: o caminho até a RC1 da v2

Pedido do Alisson em 05/11/2026, à noite: "Já deixe tudo preparado para a finalização do jogo e o lançamento da RC1.
Precisamos sair do beta." Escrito pelo Claude do Alisson (PC). O prazo oficial continua na #342 (RC em sex 13/11,
lançamento na semana de 16/11). Este arquivo diz **o que falta, em que ordem e quem decide**. Marque aqui ou na #342
conforme for andando.

## Decisão já tomada nesta noite

- **Sem tag `v2.0-beta2`.** A ideia da #450 (pré-release beta 2) é absorvida: a próxima tag de versão é a **`v2.0-rc1`**.
  A Latest `build-*` de cada push na main continua sendo a build de teste do dia a dia (o atalho "KIKIU (teste)" baixa ela).
  _Se o Alisson preferir publicar o beta 2 antes, basta dizer; o resto do plano não muda._
- **O LightWolf é herói principal** (3º na escolha), sem portão beta (#621).

## 1. Juntar o que está pronto (ordem de merge)

| Ordem | PR | Estado em 06/11, 0h | Decisão |
|---|---|---|---|
| 1 | #618 (grade de pixel, 2ª rodada) | CI 8/8, revisado, sem conflito | Alisson jogou; falta o "mergeia" |
| 2 | #621 (LightWolf 3º, mísseis livres, santuário, rodada 7, esqueleto Vita) | rascunho, empilhado no #618 | depois do #618, base vira a main |
| 3 | #611 a #617 | incluídos no #618 | fechar como incluídos no merge do #618 |
| 4 | #597 (números de dano somados) | conflito com a main | refazer em cima da main ou fechar |
| 5 | #578, #598, #588 (rosto, elenco, lobo espectral) | conflito, pedem ok visual | o retrato do LightWolf já veio do #598 no #621; o resto: o Alisson e o Isac decidem se entra na RC1 ou na v3 |

PRs antigos fora da RC1 (ficam abertos como referência ou fecham): #476, #330, #304.

## 2. Congelar recursos (a partir do merge do #621)

Depois do #621, **só entra correção** até a RC1: crash, save, build, travamento, texto errado, desempenho no i5.
Recurso novo vai para a v3 (#416). Polimento visual pequeno do Isac (#459) entra se for só dados ou arte.

## 3. O que precisa ser verificado antes da tag

- [ ] **Partida completa nos 4 mapas** com cada um dos 3 principais (Hazaki, Nick, LightWolf), em F/M/D: o robô de
      playtest (#301) cobre a ida até a vitória; um humano confere o fim de jogo e os créditos.
- [ ] **FPS no i5-3470 do Breno** com o F3 (item aberto da #342). Pior caso: Enxame Final com o LightWolf atirando e a Q.
- [ ] **Save:** abrir a RC1 por cima de um save do beta de 23/10 e de um save de hoje (`ferramentas/teste_guarda_save.py`
      no CI cobre o formato; a abertura real é manual).
- [ ] **Reduzir piscadas e clarões** (#592) num passe de 10 minutos com a opção ligada.
- [ ] **Bugs abertos que bloqueiam:** #590 (AppImage sem versão). Os outros da lista de issues são v3 ou ideia.
- [ ] Créditos e `docs/LICENCAS_ARTE.md` / `docs/LICENCAS_AUDIO.md` batendo com o que está no export (pixelfx, fontes, sons).

## 4. Publicar a RC1 (só com o OK do Alisson)

1. Versão: `config/version="2.0.0"` já está no `project.godot`; o `release.yml` copia ela para o `.exe`.
   A RC1 sai como `2.0.0` mesmo (a tag diz que é RC). **Mexer no `project.godot` ou em `.github/workflows` pede o ok do
   Alisson** (regra do portão de merge).
2. Hoje o `release.yml` só cria tags `build-AAAA-MM-DD-<sha>` a cada push na main. Para a RC1 há dois caminhos:
   a) **sem mexer no workflow:** depois que o push da main gerar a Latest, renomear a Release dela para `v2.0-rc1`
      (`gh release edit build-... --tag v2.0-rc1 --title "KIKIU v2.0 RC1" --prerelease`) e escrever as notas;
   b) **com um ajuste pequeno no workflow** (entrada `tag` no `workflow_dispatch`): mais limpo, mas pede o ok acima.
   Recomendação: **(a)** para a RC1, **(b)** para a versão final.
3. Notas curtas: o que é novo desde o beta de 23/10 (o LOGBOOK tem tudo), os 3 heróis principais, o que testar.
4. Avisar na #342 e no Telegram (o Alisson leva).

## 5. Depois da RC1

- De sáb 14 a qui 19/11: só correção do que aparecer; a versão final é a `v2.0` (Latest).
- Port do Vita: começa **depois** da `v2.0`, pelo `jogos/hordas-vita-v2/LEIAME.md` (#87).
