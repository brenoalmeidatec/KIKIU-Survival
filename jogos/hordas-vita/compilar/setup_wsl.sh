#!/bin/bash
# Prepara a distro WSL vita-build: pacotes, VitaSDK (vdpm, todos os pacotes), pvr_psp2 e godot-vita no commit do editor.
set -x
export DEBIAN_FRONTEND=noninteractive
export VITASDK=/usr/local/vitasdk
export PATH=$VITASDK/bin:$PATH
apt-get update
apt-get install -y build-essential git cmake python3 python3-pip python3-setuptools scons pkg-config libarchive-tools \
  fakeroot zip unzip curl wget sudo xz-utils bzip2 autoconf automake libtool file ccache
id vita >/dev/null 2>&1 || useradd -m -s /bin/bash vita
echo "vita ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vita
mkdir -p $VITASDK && chown vita:vita $VITASDK
sudo -u vita -H bash -c "
  export VITASDK=$VITASDK PATH=$VITASDK/bin:\$PATH
  cd ~ && rm -rf vdpm vita-packages-extra
  git clone --depth 1 https://github.com/vitasdk/vdpm && cd vdpm && ./bootstrap-vitasdk.sh && ./install-all.sh
  cd ~ && git clone --depth 1 https://github.com/isage/vita-packages-extra
  cd ~/vita-packages-extra/pvr_psp2 && vita-makepkg && vdpm ./*-arm.tar.xz
"
sudo -u vita -H bash -c "cd ~ && rm -rf godot-vita && git clone https://github.com/SonicMastr/godot-vita && cd godot-vita && git checkout 7ca87562f40daaed7e41eaa5aef76ff3ec0bc8ba"
arm-vita-eabi-gcc --version | head -1
ls $VITASDK/arm-vita-eabi/lib | grep -iE "gles|egl|gpu_es4" | head
echo SETUP_FIM
