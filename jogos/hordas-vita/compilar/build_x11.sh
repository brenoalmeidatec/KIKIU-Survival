#!/bin/bash
# Build Linux (x11) do mesmo commit com o módulo, só para testar o caminho C++ no PC (WSLg). Log em build_x11.log.
set -x
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y libx11-dev libxcursor-dev libxinerama-dev libgl1-mesa-dev \
  libglu1-mesa-dev libasound2-dev libpulse-dev libudev-dev libxi-dev libxrandr-dev mesa-utils >/dev/null
cd ~/godot-vita
rm -rf modules/horda_vita && cp -r /mnt/e/Dev/KIKIU-Vita/repo/jogos/hordas-vita/modulo/horda_vita modules/
time scons platform=x11 target=release_debug tools=no module_bullet_enabled=no module_vhacd_enabled=no -j8 werror=no
echo "BUILD_SAIDA=$?"
ls -la bin/ | grep x11
