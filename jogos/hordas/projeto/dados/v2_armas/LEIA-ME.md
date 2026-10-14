# Armas da v2: lotes de staging

Esta pasta guarda os lotes de armas novas (golpes secundários) feitos por agentes. Cada `lote_N.json` tem 9 armas. Os 45 golpes já estão no jogo: entraram em `dados/v2_cartas.json` (campo `golpes`) e os cinco tipos novos estão em `v2/armas_novas.gd`. Os lotes ficam aqui como registro e como referência de `arte` (o que o Alisson desenha); o jogo lê `v2_cartas.json`, não estes arquivos.

Meta: 50 golpes no total = 5 que já existem (`laminas`, `aura_fogo`, `corvos`, `raio`, `runa`) + 45 novos (5 lotes de 9).

## Formato de cada arma

```json
{
  "id": "flechas_sombrias",
  "icone": "icone_u_arco_sussurro",
  "nome": "Flechas Sombrias",
  "desc": "Dispara uma flecha no inimigo mais perto a cada poucos segundos.",
  "tipo": "projetil",
  "max": 5,
  "peso": 1.2,
  "cor": [0.5, 0.3, 0.9],
  "base": { "dano": 8, "recarga": 1.8, "quantidade": 1, "vel": 340, "alcance": 220, "perfura": 0 },
  "niveis": [
    { "texto": "+1 flecha", "quantidade": 1 },
    { "texto": "+4 de dano", "dano": 4 },
    { "texto": "perfura 1 inimigo", "perfura": 1 },
    { "texto": "+6 de dano e atira mais rápido", "dano": 6, "recarga": -0.3 }
  ],
  "arte": {
    "visual": "Descrição do que aparece na tela, em português, para o Alisson desenhar.",
    "cores": ["roxo escuro", "branco"],
    "tamanho": "projétil de 10x3 px; impacto de 16 px",
    "duracao": "0,2 s no impacto",
    "provisorio": "Uma linha reta fina de 2 px na cor da arma, sem sprite."
  }
}
```

Campos obrigatórios: `id`, `icone`, `nome`, `desc`, `tipo`, `max`, `peso`, `cor`, `base`, `niveis` (exatamente 4 itens), `arte`.

- `id`: minúsculas, sem acento, com `_` (é o identificador no código).
- `icone`: nome de um PNG existente em `assets/gerado/` (sem extensão). Use só ícones que **ainda não aparecem** em `dados/v2_cartas.json`. Liste a pasta antes de escolher. Ícones com prefixo `icone_u_` servem bem para armas.
- `nome`: até 24 caracteres.
- `desc`: 1 frase, até 70 caracteres, em português, dizendo o que a arma faz e como ela dispara ("a cada X s", "automática", "sai da katana" etc.). Sem números fixos (o valor sobe com o nível).
- `max`: sempre 5.
- `peso`: entre 0,8 e 1,5 (1,0 é a média).
- `cor`: rgb entre 0 e 1, na paleta do efeito (não repetir a cor de outra arma do mesmo lote).
- `niveis`: exatamente 4 itens (níveis 2 a 5). Cada um tem `texto` (até 24 caracteres) e só os campos que mudam em relação a `base`. Os campos somam ou (se negativos) reduzem: `recarga: -0.3` diminui o tempo.

## Tipos (a família define os campos de `base`)

Tipos que já existem no código (parâmetros iguais aos de `dados/v2_cartas.json`, use-os como modelo):

- `orbita`: `dano`, `quantidade`, `raio`, `giro` (rad/s), `tique` (s entre dois acertos no mesmo monstro), `empurra`.
- `aura`: `dano`, `raio`, `tique`, `empurra`, `queima_dps`, `queima_t`.
- `corvos`: `dano`, `recarga`, `quantidade`, `duracao`, `velocidade`, `tique`, `alcance`.
- `raio`: `dano`, `recarga`, `quantidade`, `cadeia` (saltos), `raio`, `alcance`.
- `runa`: `dano`, `recarga`, `quantidade`, `duracao`, `raio`, `explosao`.

Tipos NOVOS (ainda sem código: o Claude do Alisson implementa depois; use exatamente estes campos):

- `projetil`: a cada `recarga` s, dispara `quantidade` projéteis no inimigo mais perto a até `alcance` px. Campos: `dano`, `recarga`, `quantidade`, `vel` (px/s), `alcance` (px), `perfura` (quantos inimigos atravessa; 0 = para no primeiro), `explosao` (raio de dano em área no impacto em px; 0 = nenhum).
- `nuvem`: a cada `recarga` s, uma nuvem cai num ponto a até `alcance` px do herói e fica `duracao` s. Dá `dano` a cada `tique` s a quem está dentro, de raio `raio` px. Campos: `dano`, `recarga`, `alcance`, `raio`, `duracao`, `tique`, `lentidao` (fração que o monstro perde de velocidade, 0 a 0,6; 0 = nenhuma).
- `anel`: a cada `recarga` s, um anel de choque sai do herói e cresce até `raio` px em `vel` px/s. Quem o toca leva `dano` uma vez e é empurrado `empurra` px. Campos: `dano`, `recarga`, `raio`, `vel`, `empurra`.
- `meteoro`: a cada `recarga` s, `quantidade` meteoros caem em pontos sorteados a até `alcance` px do herói. Cada um mostra um aviso de `aviso` s no chão (círculo piscando) e então cai com dano `dano` em raio `raio` px. Campos: `dano`, `recarga`, `quantidade`, `alcance`, `raio`, `aviso`.
- `aliado`: a cada `recarga` s, invoca `quantidade` espíritos perto do herói. Cada um persegue o inimigo mais perto por `duracao` s, a `vel` px/s, e dá `dano` a cada `tique` s em contato. Campos: `dano`, `recarga`, `quantidade`, `duracao`, `vel`, `tique`.

## Balanço (valores de nível 1)

- `dano`: entre 4 e 25 (projéteis e nuvens de dano baixo; explosões e meteoros mais altos).
- `recarga`: entre 0,6 e 5 s.
- `quantidade`: 1 a 4 no nível 1.
- `alcance`: entre 120 e 300 px. `raio`: entre 30 e 90 px (nuvens e meteoros podem chegar a 110).
- Cada nível 2 a 5 soma algo perto de 25% a 40% do valor de base (dano +3 a +8; recarga -0,2 a -0,4; quantidade +1; etc.). O nível 5 deve ser a melhor versão da arma, não um salto.
- Nunca repita um `id` que já existe em `dados/v2_cartas.json`.

## Animação e efeito (campo `arte`)

Escreva para quem vai desenhar: o que aparece, onde aparece, cores (nomes e rgb), tamanho em px, duração e como fica no impacto. Cite a tela de 960x540 como referência. O campo `provisorio` descreve um efeito simples que dá para fazer só com código (uma linha, um círculo, uma partícula), sem arquivo de arte novo. Nada de texto com números de balanço no `arte`.

## Regras para quem escreve um lote

1. Escreva **só** o arquivo do lote indicado. Não edite nenhum outro arquivo do repositório. Não rode git.
2. Valide o JSON antes de terminar: `python3 -I -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print(len(d))" CAMINHO`. Deve imprimir 9.
3. Confira na pasta de ícones que cada `icone` existe e que não aparece em `dados/v2_cartas.json`.
4. Responda com uma lista curta: id, tipo, nome, e qualquer dúvida de balanço. Sem texto extra.
