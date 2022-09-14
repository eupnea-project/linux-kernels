#!/bin/bash

# From https://stackoverflow.com/q/59895
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";

sudo apt update -y
sudo apt install -y netpbm imagemagick git build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison cgpt vboot-kernel-utils

# Exit on errors
set -e

# Clone mainline
KERNEL_VERSION=v6.0-rc4
if [[ ! -d $KERNEL_VERSION ]]; then
	git clone --depth 1 --branch $KERNEL_VERSION --single-branch https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git $KERNEL_VERSION
fi

(
    # Bootlogo not working for now
    echo "Setting up the bootlogo"
    cd logo
    mogrify -format ppm "logo.png"
    ppmquant 224 logo.ppm > logo_224.ppm
    pnmnoraw logo_224.ppm > logo_final.ppm
)

cd $KERNEL_VERSION

# Prevents a dirty kernel
echo "mod" >> .gitignore
touch .scmversion

MODULES="modules.tar.xz"
HEADERS="headers.tar.xz"
VMLINUZ="bzImage"
SYSTEM_MAP="System.map-breath"
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
        make clean; make -j$(nproc) || exit
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
make -j$(nproc) modules_install INSTALL_MOD_PATH=mod
make -j$(nproc) headers_install INSTALL_HDR_PATH=hdr

# Creates an archive containing /lib/modules/...
cd mod
# Speedy multicore compression
# Some version of tar don't support arguments after the command in the -I option,
# so we're putting the arguments and the command in a script
echo "xz -9 -T0" > fastxz
chmod +x fastxz
tar -cvI './fastxz' -f ../../$MODULES lib/
echo "modules.tar.xz created!"

# Compress headers
cd ..
cd hdr

echo "xz -9 -T0" > fastxz
chmod +x fastxz
tar -cvI './fastxz' -f ../../$HEADERS include/
echo "headers.tar.xz created!"

# Copy the vmlinuz, system.map, and kernel config to the kernel directory
cd ..
cp System.map ../$SYSTEM_MAP
cp .config ../$CONFIG

cd ..
