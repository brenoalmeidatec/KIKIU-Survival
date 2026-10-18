from pathlib import Path
p=Path('jogos/hordas/projeto/v2/LEIA-ME.md');s=p.read_text(encoding='utf-8');s=s.replace('<<<<<<< HEAD\n','').replace('=======\n','\n').replace('>>>>>>> codex/cidade-selecao\n','');p.write_text(s,encoding='utf-8')
p=Path('jogos/hordas/projeto/v2/altar.gd');s=p.read_text(encoding='utf-8').replace('_mapa.size = Vector2(252, 40)','_mapa.size = Vector2(248, 40)');p.write_text(s,encoding='utf-8')
