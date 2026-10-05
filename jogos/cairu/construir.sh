#!/bin/bash
# Gera build/JOGO.exe e JOGO_prototipo.zip a partir de projeto/.
set -e
G=${GODOT:-/tmp/claude-0/-home-claude/6fe740fe-adef-5c56-a23e-e09c9065fd98/scratchpad/Godot_v4.4.1-stable_linux.x86_64}
cd "$(dirname "$0")"
rm -f projeto/_t.gd projeto/_t.gd.uid
(cd projeto && timeout 300 "$G" --headless --import >/dev/null 2>&1 || true)
(cd projeto && timeout 300 "$G" --headless --export-release "Windows Desktop" ../build/JOGO.exe 2>&1 | grep -iE "error|fail" || true)
rm -rf build/capitulos build/audio
mkdir -p build/capitulos/mapas
cp projeto/capitulos/*.json build/capitulos/
cp projeto/capitulos/*.txt build/capitulos/ 2>/dev/null || true
cp projeto/capitulos/mapas/*.json projeto/capitulos/mapas/*.png build/capitulos/mapas/
if [ -d projeto/assets/audio ]; then
  mkdir -p build/audio/musica build/audio/efeitos
  cp projeto/assets/audio/musica/*.ogg build/audio/musica/ 2>/dev/null || true
  cp projeto/assets/audio/efeitos/*.wav build/audio/efeitos/ 2>/dev/null || true
  mkdir -p build/audio/vozes
  cp projeto/assets/audio/vozes/*.ogg projeto/assets/audio/vozes/*.wav build/audio/vozes/ 2>/dev/null || true
fi
cp LEIA-ME.txt build/LEIA-ME.txt
cp ferramentas/*.bat build/ 2>/dev/null || true
JOGO_DIR="$(pwd)" python3 - <<'P'
import zipfile, os, glob, time
os.chdir(os.environ['JOGO_DIR'])
# a pasta compartilhada às vezes demora pra mostrar os arquivos recém-copiados:
# confere se tudo que devia estar no build está lá antes de zipar
esperado = {'capitulos': len(glob.glob('projeto/capitulos/*.json') + glob.glob('projeto/capitulos/*.txt')
                             + glob.glob('projeto/capitulos/mapas/*.json') + glob.glob('projeto/capitulos/mapas/*.png')),
            'audio': len(glob.glob('projeto/assets/audio/musica/*.ogg') + glob.glob('projeto/assets/audio/efeitos/*.wav')
                         + glob.glob('projeto/assets/audio/vozes/*.ogg') + glob.glob('projeto/assets/audio/vozes/*.wav'))}
for tentativa in range(20):
    achado = {k: sum(len(f) for _, _, f in os.walk(os.path.join('build', k))) for k in esperado}
    if all(achado[k] >= esperado[k] for k in esperado):
        break
    time.sleep(2)
else:
    raise SystemExit('build incompleto: %s de %s' % (achado, esperado))
with zipfile.ZipFile('JOGO_prototipo.zip.novo', 'w', zipfile.ZIP_DEFLATED) as z:
    for raiz, _, arqs in os.walk('build'):
        for a in arqs:
            p = os.path.join(raiz, a)
            z.write(p, os.path.join('JOGO', os.path.relpath(p, 'build')))
z = zipfile.ZipFile('JOGO_prototipo.zip.novo')
assert z.testzip() is None
for k in esperado:
    n = sum(1 for x in z.namelist() if x.startswith('JOGO/%s/' % k))
    assert n >= esperado[k], 'faltou %s no zip: %d de %d' % (k, n, esperado[k])
os.replace('JOGO_prototipo.zip.novo', 'JOGO_prototipo.zip')
print('zip', round(os.path.getsize('JOGO_prototipo.zip')/1e6, 1), 'MB')
P
ls -la build/JOGO.exe
