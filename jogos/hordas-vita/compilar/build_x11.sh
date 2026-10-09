#!/bin/bash
cd ~/godot-vita
python3 /mnt/e/Dev/KIKIU-Vita/repo/jogos/hordas-vita/compilar/patches_motor.py ~/godot-vita || exit 1
rm -rf modules/horda_vita && cp -r /mnt/e/Dev/KIKIU-Vita/repo/jogos/hordas-vita/modulo/horda_vita modules/
time scons platform=x11 target=release_debug tools=no module_bullet_enabled=no module_vhacd_enabled=no -j8 werror=no
echo "BUILD_SAIDA=$?"
