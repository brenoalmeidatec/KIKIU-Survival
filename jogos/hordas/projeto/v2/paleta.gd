extends RefCounted
## Fonte única das cores e tamanhos da UI da v2.
## O gerador de molduras lê estas mesmas constantes; não duplique valores em outras telas.
## Texturas de arte podem ter luz/sombra próprias; cores semânticas vêm daqui.

const PAINEL := Color("#01030b")
const CARTAO := Color("#12111a")
const CARTAO_SELECIONADO := Color("#211f2b")
const BORDA := Color("#5c5773")
const MOLDURA := Color("#ccd1e6")
const MOLDURA_ESCURA := Color("#9999b3")
const MOLDURA_APAGADA := Color("#6b6b80")
const TEXTO := Color("#ebe6f5")
const TEXTO_SECUNDARIO := Color("#b8b3d4")
const CABECALHO := Color("#9e99b8")
const TEXTO_APAGADO := Color("#8c8fa3")
const FOCO := Color("#fff7cc")
const VALOR := Color("#ffeda8")
const OURO := Color("#ffdb6b")
const ALMA := Color("#cca8ff")
const DICA := Color("#99ccfa")
const BONUS := Color("#8cf29e")
const DIVISOR := Color("#8c87ad")
const VIDA := Color("#b9212d")
const XP := Color("#e0bc48")
const FOLEGO := Color("#4aa3d9")
const FOLEGO_CANSADO := Color("#ff5933")
const FANTASMA_CHEFE := Color("#ecceb0")
const BARRA_VAZIA := Color("#29263d")
const BARRA_BORDA := Color("#0a0814")
const PERIGO := Color("#ff544d")
const FUSAO := Color("#ff73d9")
const CARTA_APAGADA := Color("#737373")
const DANO_NUMERO := Color("#fff5d6")
const DANO_CRITICO := Color("#ffbd33")
const ANUNCIO_ELITE := Color("#bf73ff")
const ANUNCIO_NIVEL := Color("#d1ebff")
const SECAO_HEROI := Color("#ff998c")
const SECAO_KATANA := Color("#ffc773")
const SECAO_GOLPES := Color("#99ccff")
const SECAO_PARTIDA := Color("#99f2d9")
const RARIDADES := [Color("#ccd1db"), Color("#59a8ff"), Color("#bd66ff"), Color("#ffbd33")]
const COMBO_MARCOS := [Color("#ffdb6b"), Color("#ff8c26"), Color("#ff4d4d"), Color("#cc66ff"), Color("#80f2ff")]
const BRANCO := Color("#ffffff")
const PRETO := Color("#000000")
const CARGA_LARANJA := Color("#ff8c33")
const HABILIDADE_DESATIVADA := Color("#524f57")
const HABILIDADE_BORDA := Color("#948c85")
const CONTRAGOLPE := Color("#ff7a2e")
const CARGA_PERFEITA := Color("#ffe099")
const RECARGA_LINHA := Color("#e6a64d")
const RUPTURA_BORDA := Color("#73664d")
const HABILIDADE_FUNDO := Color("#211f29")
const TECLA_APAGADA := Color("#615e59")
const RECARGA_BORDA := Color("#998059")
const CARGA_MARCA := Color("#0d0d12")
const VIDA_PISCA := Color("#ff6666")
const TEXTO_TAMANHO := 16
const TEXTO_GRANDE := 32
const TITULO_PEQUENO := 19
const TITULO_MEDIO := 37
const TITULO_GRANDE := 56
const NUMERO_PEQUENO := 8
const NUMERO_GRANDE := 16


static func alfa(cor: Color, opacidade: float) -> Color:
	return Color(cor.r, cor.g, cor.b, opacidade)
