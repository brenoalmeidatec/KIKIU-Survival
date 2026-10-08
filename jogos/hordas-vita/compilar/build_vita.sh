#!/bin/bash
# Compila o template Vita (godot-vita 7ca87562) com o módulo horda_vita. Log em build_vita.log.
export VITASDK=/usr/local/vitasdk
export PATH=$VITASDK/bin:$PATH
cd ~/godot-vita
rm -rf bin/vita_template modules/horda_vita && cp -r /mnt/e/Dev/KIKIU-Vita/repo/jogos/hordas-vita/modulo/horda_vita modules/
time scons platform=vita target=release tools=no -j8 "$@"
echo "BUILD_SAIDA=$?"
ls -la bin/ | tail -8
