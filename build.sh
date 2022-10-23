#!/bin/bash

# Exit on errors
set -e

# Kernel Version
case $1 in
stable)
  KERNEL_VERSION=v6.0
  ;;
testing)
  KERNEL_VERSION=v6.1-rc1
  ;;
*)
  echo "./build.sh [stable|testing]"
  exit 1
  ;;
esac

# Clone mainline
if [[ ! -d $KERNEL_VERSION ]]; then
  git clone --depth 1 --branch $KERNEL_VERSION --single-branch https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git $KERNEL_VERSION
fi

(
  # Bootlogo not working for now
  echo "Setting up the bootlogo"
  cd logo
  mogrify -format ppm "logo.png"
  ppmquant 224 logo.ppm >logo_224.ppm
  pnmnoraw logo_224.ppm >logo_final.ppm
)

cd $KERNEL_VERSION

# Prevents a dirty kernel
echo "mod" >>.gitignore
touch .scmversion

# File naming
case $1 in
stable)
  MODULES="modules-stable.tar.xz"
  HEADERS="headers-stable.tar.xz"
  VMLINUZ="bzImage-stable"
  ;;
testing)
  MODULES="modules-testing.tar.xz"
  HEADERS="headers-testing.tar.xz"
  VMLINUZ="bzImage-testing"
  ;;
esac

[[ -f .config ]] || cp ../.config .config || exit

make olddefconfig

# If the terminal is interactive and not running in docker
if [[ -t 0 ]] && [[ ! -f /.dockerenv ]]; then

  read -p "Would you like to make edits to the kernel config? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    make menuconfig
  fi

  read -p "Would you like to write the new config to github? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [[ $KERNEL_VERSION == "alt-chromeos-5.10" ]]; then
      cp .config ../../kernel.alt.conf
    else
      cp .config ../../kernel.conf
    fi
  fi

  echo "Building kernel"
  read -p "Would you like a full rebuild? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    make clean
    make -j$(nproc) || exit
  else
    make -j$(nproc) || exit
  fi

else

  make -j$(nproc)

fi

cp arch/x86/boot/bzImage ../$VMLINUZ
echo "bzImage and modules built"

rm -rf mod || true
mkdir mod
make -j$(nproc) modules_install INSTALL_MOD_PATH=mod INSTALL_MOD_STRIP=1
make -j$(nproc) headers_install INSTALL_HDR_PATH=hdr

# Creates an archive containing /lib/modules/...
cd mod
# Speedy multicore compression
# Some version of tar don't support arguments after the command in the -I option,
# so we're putting the arguments and the command in a script
echo "xz -9 -T0" >fastxz
chmod +x fastxz
tar -cvI './fastxz' -f ../../$MODULES lib/
echo "modules.tar.xz created!"

# Compress headers
cd ..
cd hdr

echo "xz -9 -T0" >fastxz
chmod +x fastxz
tar -cvI './fastxz' -f ../../$HEADERS include/
echo "headers.tar.xz created!"

# Copy the vmlinuz, and kernel config to the kernel directory
cd ..
cp .config ../$CONFIG

cd ..
