#!/usr/bin/env python3
"""Teste da guarda do save real do runner de playtest (#301), sem Godot e sem tocar no user:// de verdade.

Roda com: python3 -I ferramentas/teste_guarda_save.py
Cria uma pasta temporária que imita a raiz de user:// e confere que retrato_user + comparar_retratos acusam byte alterado,
arquivo criado e arquivo apagado, e que mudança em playtest/ e logs/ (ou só de mtime) não acusa. Também confere a limpeza de órfãos.
ECO-8 (classe CalibracaoEco8, no mesmo arquivo para o CI já rodar): conferir_ids, conferir_dificuldade, levou, _desvio, matriz_mapa_dif,
desvios_tabela e a detecção de partida inválida (robô repetindo a mesma escolha de carta).
"""
import importlib.util
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

ALVO = Path(__file__).resolve().parent / "playtest_v2.py"
spec = importlib.util.spec_from_file_location("playtest_v2", ALVO)
pt = importlib.util.module_from_spec(spec)
sys.modules["playtest_v2"] = pt
spec.loader.exec_module(pt)


class GuardaSave(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.raiz = Path(self._tmp.name)
        (self.raiz / "recordes.json").write_bytes(b'{"melhor": 10}')
        (self.raiz / "opcoes.cfg").write_bytes(b"[audio]\nvolume=1.0\n")
        (self.raiz / "playtest").mkdir()
        (self.raiz / "logs").mkdir()
        (self.raiz / "playtest" / "meta_1.cfg").write_bytes(b"x")
        (self.raiz / "logs" / "godot.log").write_bytes(b"log")

    def difs(self, antes):
        return pt.comparar_retratos(antes, pt.retrato_user(self.raiz))

    def test_sem_mudanca_nao_acusa(self):
        antes = pt.retrato_user(self.raiz)
        self.assertEqual(self.difs(antes), [])

    def test_byte_alterado_acusa(self):
        antes = pt.retrato_user(self.raiz)
        (self.raiz / "recordes.json").write_bytes(b'{"melhor": 11}')
        self.assertEqual([(n, t) for n, t, _ in self.difs(antes)], [("recordes.json", "alterado")])

    def test_arquivo_criado_acusa(self):
        antes = pt.retrato_user(self.raiz)
        (self.raiz / "meta.cfg").write_bytes(b"novo")
        self.assertEqual([(n, t) for n, t, _ in self.difs(antes)], [("meta.cfg", "criado")])

    def test_arquivo_apagado_acusa(self):
        antes = pt.retrato_user(self.raiz)
        (self.raiz / "opcoes.cfg").unlink()
        self.assertEqual([(n, t) for n, t, _ in self.difs(antes)], [("opcoes.cfg", "apagado")])

    def test_playtest_e_logs_nao_acusam(self):
        antes = pt.retrato_user(self.raiz)
        (self.raiz / "playtest" / "meta_1.cfg").write_bytes(b"mudou")
        (self.raiz / "playtest" / "meta_2.cfg").write_bytes(b"criado")
        (self.raiz / "playtest" / "meta_1.cfg").unlink()
        (self.raiz / "logs" / "godot.log").write_bytes(b"outro log, bem maior")
        (self.raiz / "logs" / "godot_novo.log").write_bytes(b"novo")
        self.assertEqual(self.difs(antes), [])

    def test_ilegivel_acusa(self):
        antes = pt.retrato_user(self.raiz)
        antes["recordes.json"] = ("ILEGIVEL", 0)
        self.assertEqual([n for n, _, _ in self.difs(antes)], ["recordes.json"])

    def test_so_mtime_nao_acusa(self):
        antes = pt.retrato_user(self.raiz)
        f = self.raiz / "opcoes.cfg"
        os.utime(f, (time.time() + 500, time.time() + 500))
        self.assertEqual(self.difs(antes), [])

    def test_pasta_inexistente_ou_none(self):
        self.assertEqual(pt.retrato_user(None), {})
        self.assertEqual(pt.retrato_user(self.raiz / "nao_existe"), {})

    def test_limpar_orfaos_so_os_velhos(self):
        velho, novo = self.raiz / "playtest" / "meta_velho.cfg", self.raiz / "playtest" / "meta_novo.cfg"
        velho.write_bytes(b"v")
        novo.write_bytes(b"n")
        antigo = time.time() - 2 * 3600
        os.utime(velho, (antigo, antigo))
        os.utime(self.raiz / "playtest" / "meta_1.cfg", (antigo, antigo))
        self.assertEqual(pt.limpar_orfaos(self.raiz), 2)
        self.assertFalse(velho.exists())
        self.assertTrue(novo.exists())
        # nada fora de playtest/ é tocado
        self.assertTrue((self.raiz / "recordes.json").exists())
        self.assertEqual(pt.limpar_orfaos(self.raiz / "nao_existe"), 0)



def partida(mapa, dif, desfecho, tempo=600.0, chefes=None, cartas=None, dano=100, fracao=1.0, pedida=None):
    """Um resultado como o rodar_partida monta: `dificuldade` é a pedida e o JSON traz a gravada pelo jogo."""
    j = {"desfecho": "vitoria" if desfecho == "vitoria" else "morte", "tempo_jogo": tempo, "nivel": 10, "dano_sofrido": dano,
         "fracao_mapa": fracao, "dificuldade": dif, "chefes_tempo": chefes or [], "cartas": cartas or ["a", "b", "c"]}
    return {"heroi": "hazaki", "mapa": mapa, "semente": 1, "dificuldade": pedida if pedida is not None else dif, "desfecho": desfecho,
            "motivo": "", "json": j, "erros_script": 0, "log": "logs/teste.log", "comando": "teste", "trava_linha": "", "tempo_real_s": 0.0}


class CalibracaoEco8(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tabela = Path(self._tmp.name) / "tabela.json"
        self.tabela.write_text(json.dumps({"tolerancia": 0.2, "vitoria_min": {"floresta": 5.0}, "chefao_s": [35, 60],
                                           "eco7": {"derrotas_antes_60_pct_max": 0.25, "dano_medio_sobre_facil_max": 1.4}}), encoding="utf-8")

    def texto(self, res):
        return "\n".join(pt.desvios_tabela({"tabela": self.tabela}, res))

    def test_levou(self):
        self.assertEqual(pt.levou({"aparece": 100.0, "cai": 120.0}), 20.0)
        self.assertEqual(pt.levou({"cai": 45.0}), 45.0)
        self.assertIsNone(pt.levou({"aparece": 100.0, "cai": -1}))
        self.assertIsNone(pt.levou({"aparece": 100.0}))
        self.assertIsNone(pt.levou({"aparece": 100.0, "cai": None}))

    def test_desvio_escalar_e_faixa(self):
        d, fora = pt._desvio(6.0, 5.0, 0.2)
        self.assertAlmostEqual(d, 0.2)
        self.assertFalse(fora)  # 20% exatos não passam da tolerância
        self.assertTrue(pt._desvio(6.1, 5.0, 0.2)[1])
        self.assertEqual(pt._desvio(45, [35, 60], 0.2), (0.0, False))  # dentro da faixa
        d, fora = pt._desvio(20, [35, 60], 0.2)
        self.assertAlmostEqual(d, -15 / 35)
        self.assertTrue(fora)
        d, fora = pt._desvio(96, [35, 60], 0.2)
        self.assertAlmostEqual(d, 36 / 60)
        self.assertTrue(fora)
        self.assertFalse(pt._desvio(30, [35, 60], 0.2)[1])  # 14% abaixo: dentro da tolerância

    def test_conferir_ids_exigir(self):
        pt.conferir_ids(["x"], [], "herói")  # sem a lista de válidos, herói e mapa seguem aceitando (comportamento de antes)
        with self.assertRaises(pt.ErroUso):
            pt.conferir_ids(["facil"], [], "dificuldade", exigir=True)  # dados ilegíveis não deixam passar qualquer dificuldade
        with self.assertRaises(pt.ErroUso):
            pt.conferir_ids(["epica"], ["facil", "medio", "dificil"], "dificuldade", exigir=True)
        pt.conferir_ids(["dificil", "facil"], ["facil", "medio", "dificil"], "dificuldade", exigir=True)

    def test_dificuldade_pedida_x_gravada(self):
        certa = partida("floresta", "dificil", "vitoria")
        pt.conferir_dificuldade(certa)
        self.assertEqual(certa["desfecho"], "vitoria")
        errada = partida("floresta", "medio", "vitoria", pedida="dificil")  # pediu Difícil e o jogo rodou Médio
        pt.conferir_dificuldade(errada)
        self.assertEqual(errada["desfecho"], "sem_json")
        self.assertIn("pedida 'dificil'", errada["motivo"])
        self.assertIn("'medio'", errada["motivo"])
        sem = partida("floresta", "", "vitoria", pedida="dificil")  # o JSON nem traz a dificuldade
        pt.conferir_dificuldade(sem)
        self.assertEqual(sem["desfecho"], "sem_json")
        livre = partida("floresta", "medio", "vitoria", pedida="")  # sem --dificuldades não há o que cruzar
        pt.conferir_dificuldade(livre)
        self.assertEqual(livre["desfecho"], "vitoria")

    def test_maior_repeticao(self):
        self.assertEqual(pt.maior_repeticao([]), 0)
        self.assertEqual(pt.maior_repeticao(None), 0)
        self.assertEqual(pt.maior_repeticao(["a", "b", "a", "a", "c"]), 2)
        self.assertEqual(pt.maior_repeticao(["laminas"] * 533), 533)

    def test_matriz_mapa_dif(self):
        chefe = {"nome": "C", "nivel": 40, "aparece": 100.0, "cai": 130.0}
        res = [
            partida("medio", "facil", "derrota", tempo=215.0, fracao=0.23, dano=300),  # Ruínas Fácil: derrota aos 3:35, não estouro de teto
            partida("floresta", "dificil", "vitoria", tempo=300.0, chefes=[chefe]),
            partida("floresta", "dificil", "vitoria", tempo=320.0, chefes=[dict(chefe, cai=190.0)]),
        ]
        linhas = pt.matriz_mapa_dif(res)
        ruinas = [x for x in linhas if x.startswith("| medio | facil")]
        self.assertEqual(len(ruinas), 1)
        self.assertIn("| 1 | 0 | 1 | 0 | 0 | — | 1 de 1 |", ruinas[0])  # 1 partida, 0 vitórias, 1 derrota, 0 teto, 0 problemas, sem tempo de vitória
        flo = [x for x in linhas if x.startswith("| floresta | dificil")][0]
        self.assertIn("| 2 | 2 | 0 | 0 | 0 | 5:10 |", flo)  # média de 300 e 320 s
        self.assertIn("| 60 | 60 |", flo)  # chefão final e todas as lutas: 30 s e 90 s, média 60

    def test_gatilhos_eco7(self):
        res = [
            partida("floresta", "facil", "vitoria", dano=100),
            partida("floresta", "medio", "derrota", dano=150, fracao=0.3),
            partida("laboratorio", "medio", "vitoria", dano=150),
            partida("floresta", "dificil", "derrota", dano=200, fracao=0.5),
        ]
        t = self.texto(res)
        self.assertIn("- medio: derrotas antes de 60% do mapa = 1 de 2 partidas (50%)", t)
        self.assertIn("ACIONA", t.split("- medio:")[1].splitlines()[0])
        self.assertIn("dano sofrido no Médio / no Fácil = 1.50", t)
        self.assertNotIn("precisa de partidas", t)
        self.assertNotIn("MEDIÇÃO INVÁLIDA", t)

    def test_gatilho_dano_sem_facil_avisa(self):
        t = self.texto([partida("floresta", "medio", "vitoria")])
        self.assertIn("precisa de partidas no Fácil e no Médio", t)

    def test_desvio_de_chefao_e_vitoria_na_tabela(self):
        chefe = {"nome": "C", "nivel": 40, "aparece": 100.0, "cai": 120.0}  # levou 20 s: abaixo de 35
        res = [partida("floresta", "dificil", "vitoria", tempo=390.0, chefes=[chefe])]  # 6,5 min contra 5,0: +30%
        t = self.texto(res)
        self.assertIn("tempo de vitória | 6.5 min | 5 min | +30% DESVIA", t)
        self.assertIn("chefão derrubado | 20 s | 35-60 s | -43% DESVIA", t)

    def test_partida_invalida_fora_das_medias(self):
        # o caso da revisão: uma inválida de 900 s mais uma válida de 600 s davam 12,5 min de média; o certo é 10 min,
        # e a inválida só aparece na lista à parte. Confere os números no relatório inteiro, não só a frase.
        presa = partida("floresta", "dificil", "vitoria", tempo=900.0, cartas=["a"] + ["laminas"] * 533)
        boa = partida("floresta", "dificil", "vitoria", tempo=600.0)
        self.assertEqual([n for _, n in pt.partidas_invalidas([presa, boa])], [533])
        self.assertEqual(pt.separar_invalidas([presa, boa])[0], [boa])
        saida = Path(self._tmp.name) / "saida"
        saida.mkdir()
        cfg = {"janela": False, "versao": "teste", "godot": "teste", "paralelas": 1, "max": None, "timeout": 900.0, "extras": [],
               "saida": saida, "tabela": self.tabela}
        pt.escrever_relatorio(cfg, "teste", [presa, boa], 1.0, False)
        md = (saida / "relatorio.md").read_text(encoding="utf-8")
        self.assertNotIn("12:30", md)
        self.assertIn("| floresta | dificil | 1 | 1 | 0 | 0 | 0 | 10:00 |", md)  # matriz: só a válida
        self.assertIn("| hazaki | 1 | 1 | 0 | 0 | 0 | 0 | 10:00 |", md)  # por herói
        self.assertIn("tempo de vitória | 10.0 min | 5 min | +100% DESVIA", md)  # desvio sobre a válida
        self.assertIn("**Resultado (partidas válidas):** 1 partida:", md)
        self.assertIn("**Medições inválidas (fora de todas as médias, listadas no fim):** 1 medição", md)
        self.assertIn("mesma carta 533 vezes seguidas", md)
        self.assertEqual(sum(1 for x in md.splitlines() if x.startswith("| hazaki | floresta | dificil | 1 |")), 1)  # Partidas: só a válida

    def test_contagem_trava_conta_mesmo_em_invalida(self):
        presa = partida("laboratorio", "dificil", "trava", cartas=["laminas"] * 533)
        c = pt.contagem([presa, partida("floresta", "dificil", "vitoria")])
        self.assertEqual((c["vitoria"], c["trava"], c["sem_json"]), (1, 1, 0))  # a trava é defeito; a inválida não entra em vitória


if __name__ == "__main__":
    unittest.main()
