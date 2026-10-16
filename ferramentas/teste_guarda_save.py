#!/usr/bin/env python3
"""Teste da guarda do save real do runner de playtest (#301), sem Godot e sem tocar no user:// de verdade.

Roda com: python3 -I ferramentas/teste_guarda_save.py
Cria uma pasta temporária que imita a raiz de user:// e confere que retrato_user + comparar_retratos acusam byte alterado,
arquivo criado e arquivo apagado, e que mudança em playtest/ e logs/ (ou só de mtime) não acusa. Também confere a limpeza de órfãos.
"""
import importlib.util
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


if __name__ == "__main__":
    unittest.main()
