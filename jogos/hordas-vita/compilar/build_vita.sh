#!/bin/bash
# Compila o template Vita (godot-vita 7ca87562) com o módulo horda_vita. Log em build_vita.log.
export VITASDK=/usr/local/vitasdk
export PATH=$VITASDK/bin:$PATH
cd ~/godot-vita
python3 /mnt/e/Dev/KIKIU-Vita/repo/jogos/hordas-vita/compilar/patches_motor.py ~/godot-vita || exit 1
rm -rf bin/vita_template modules/horda_vita && cp -r /mnt/e/Dev/KIKIU-Vita/repo/jogos/hordas-vita/modulo/horda_vita modules/
time scons platform=vita target=release tools=no -j8 "$@"
echo "BUILD_SAIDA=$?"
ls -la bin/ | tail -8
# empacota o template para o editor (exportar.sh VARIANTE=cpp)
if [ -f bin/vita_template/eboot.bin ]; then
	(cd bin/vita_template && rm -f /tmp/vr.zip && zip -qr /tmp/vr.zip eboot.bin module sce_sys && cp /tmp/vr.zip /mnt/e/Dev/KIKIU-Vita/ferramentas/vita_release_horda.zip && echo "TEMPLATE_EMPACOTADO")
fi
