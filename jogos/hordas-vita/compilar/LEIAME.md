# Compilar o template Vita com o módulo da horda

Testado em 2026-10-08 numa distro WSL dedicada (`vita-build`, Ubuntu 24.04 importado de
`ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz` para `E:\Dev\KIKIU-Vita\wsl`), VitaSDK 2026.08 (GCC 15.2).

1. `setup_wsl.sh` (root): pacotes, usuário `vita`, clona `vdpm`, `vita-packages-extra` e o godot-vita no commit
   `7ca87562` (o mesmo do editor 3.5-rc5-vita1). **Correções que o script ainda não tem** (feitas à mão):
   - não criar `/usr/local/vitasdk` antes do `bootstrap-vitasdk.sh` (ele recusa se a pasta existe);
   - o `vdpm` novo não instala com `install-all.sh` nem com `vdpm arquivo.tar.xz`; usar
     `vdpm install libpng freetype libvorbis libogg opus libtheora zlib libjpeg-turbo libwebp zstd libpcre2 taihen vita-rss-libdl`
     e `vdpm pacman -- -U --noconfirm ~/vita-packages-extra/pvr_psp2/pvr_psp2-3.9-1-vita.pkg.tar.xz`.
2. `build_vita.sh module_bullet_enabled=no` (usuário `vita`): copia `../modulo/horda_vita` para `modules/`, compila
   (~17 min do zero, ~30 s incremental) e gera `bin/vita_template/` (eboot.bin + module/*.suprx + sce_sys).
   O SCsub do fork falha se `bin/vita_template` já existe: o script apaga antes.
3. Empacotar: `cd ~/godot-vita/bin/vita_template && zip -qr vita_release_horda.zip eboot.bin module sce_sys` e copiar
   para a pasta do editor (`ferramentas/`). O `exportar.sh` com `VARIANTE=cpp` usa esse zip.
4. `build_x11.sh`: o mesmo motor para Linux (com `module_vhacd_enabled=no`, que não compila no GCC 13), para testar o
   caminho C++ no PC pelo WSLg: `godot.x11.opt.debug.64 --path <piloto> --bench-rapido`.

Pelo Git Bash, chamar o WSL com `MSYS_NO_PATHCONV=1` e scripts em arquivo (o Git Bash expande `$` e converte
caminhos `/mnt/...` na linha de comando).
