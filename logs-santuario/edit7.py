from pathlib import Path
p=Path('jogos/hordas/projeto/v2/altar.gd');s=p.read_text(encoding='utf-8');s=s.replace('## Santuário da v2: a tela antes da floresta e a CENA PRINCIPAL do jogo (run/main_scene). Com `--v1` (ou um argumento só da v1,','## Santuário da v2: a tela de preparação entre o título e a partida. Com `--v1` (ou um argumento só da v1,')
for line in ['const LINHA_Y0 := 128.0  # primeira linha de melhoria\n','const LINHA_H := 36.0\n','const CONQ_Y0 := 128.0  # primeira conquista\n','const CONQ_H := 92.0\n']:
 s=s.replace(line,'')
s=s.replace('\t\t\tefeito.text = "Libera ao cumprir: %s" % _nome_conquista(str(m.requer))\n','').replace('\t\t\tefeito.text = "%s   nível máximo" % Meta.texto_efeito(m, n)\n','').replace('\t\t\tvar agora := ("Agora: " + Meta.texto_efeito(m, n)) if n > 0 else "Não comprada"\n\t\t\tefeito.text = "%s   %s" % [agora, Meta.texto_proximo(m, n)]\n','')
s=s.replace('apoio = "Última: %d/300 s" % int(valor)', 'apoio = "Última: %d/%d s" % [int(valor), int(limite)]');p.write_text(s,encoding='utf-8')
