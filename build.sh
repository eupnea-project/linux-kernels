#!/bin/bash

# Exit on errors
set -e

# Kernel Version
case $1 in
stable)
  KERNEL_VERSION=v6.0.9
  ;;
testing)
  KERNEL_VERSION=v6.1-rc5
  ;;
*)
  echo "./build.sh [stable|testing]"
  exit 0
  ;;
esac

# Stable uses a different repo than mainline
case $1 in
stable)
  KERNEL_URL=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
  ;;
testing)
  KERNEL_URL=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
  ;;
esac

# Clone mainline
if [[ ! -d $KERNEL_VERSION ]]; then
  git clone --depth 1 --branch $KERNEL_VERSION --single-branch $KERNEL_URL $KERNEL_VERSION
fi

(
  # Bootlogo not working for now
  echo "Setting up the bootlogo"
  cp logo/depthboot_boot_logo.ppm $KERNEL_VERSION/drivers/video/logo/logo_linux_clut224.ppm
)

cd $KERNEL_VERSION

# Apply patch to fix speakers on kbl avs
patch -p1 < ../kbl-avs.patch

# Prevents a dirty kernel
echo "mod" >>.gitignore
touch .scmversion

# File naming
case $1 in
stable)
  MODULES="modules-stable.tar.xz"
  HEADERS="headers-stable.tar.xz"
  VMLINUZ="bzImage-stable"
  CONFIG="config-stable"
  ;;
testing)
  MODULES="modules-testing.tar.xz"
  HEADERS="headers-testing.tar.xz"
  VMLINUZ="bzImage-testing"
  CONFIG="config-testing"
  ;;
esac

[[ -f .config ]] || cp ../$CONFIG .config || exit

make olddefconfig

# If the terminal is interactive and not running in docker
if [[ -t 0 ]] && [[ ! -f /.dockerenv ]]; then

  read -p "Would you like to make edits to the kernel config? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    make menuconfig
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

cp arch/x86/boot/bzImage ./vmlinux
cp vmlinux ../$VMLINUZ
echo "bzImage and modules built"

rm -rf mod || true
mkdir mod
make -j$(nproc) modules_install INSTALL_MOD_PATH=mod INSTALL_MOD_STRIP=1

# Move files around
cd mod
mv lib/modules/* .
rm -r lib

# Remove broken symlinks
rm -rf */build
rm -rf */source

# Create an archive for the modules
tar -cvI "xz -9 -T0" -f ../../$MODULES *
echo "$MODULES created!"

# Creates an archive containing headers to build out of tree modules
# Taken from the archlinux linux PKGBUILD
cd ../
rm -r hdr || true
mkdir hdr
HDR_PATH=$(pwd)/hdr

# Build files
install -Dt "$HDR_PATH" -m644 .config Makefile Module.symvers System.map vmlinux
install -Dt "$HDR_PATH/kernel" -m644 kernel/Makefile
install -Dt "$HDR_PATH/arch/x86" -m644 arch/x86/Makefile
cp -t "$HDR_PATH" -a scripts
# Fixes errors when building
install -Dt "$HDR_PATH/tools/objtool" tools/objtool/objtool
# install -Dt "$HDR_PATH/tools/bpf/resolve_btfids" tools/bpf/resolve_btfids/resolve_btfids # Disabled in kconfig

# Install header files
cp -t "$HDR_PATH" -a include
cp -t "$HDR_PATH/arch/x86" -a arch/x86/include
install -Dt "$HDR_PATH/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s
install -Dt "$HDR_PATH/drivers/md" -m644 drivers/md/*.h
install -Dt "$HDR_PATH/net/mac80211" -m644 net/mac80211/*.h
install -Dt "$HDR_PATH/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h
install -Dt "$HDR_PATH/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
install -Dt "$HDR_PATH/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
install -Dt "$HDR_PATH/drivers/media/tuners" -m644 drivers/media/tuners/*.h
install -Dt "$HDR_PATH/drivers/iio/common/hid-sensors" -m644 drivers/iio/common/hid-sensors/*.h

# Install kconfig files
find . -name 'Kconfig*' -exec install -Dm644 {} "$HDR_PATH/{}" \;

# Remove uneeded architectures
for arch in "$HDR_PATH"/arch/*/; do
  [[ $arch = */x86/ ]] && continue
  rm -r "$arch"
done

# Remove docs
rm -r "$HDR_PATH/Documentation"

# Remove broken symlinks
find -L "$HDR_PATH" -type l -printf 'Removing %P\n' -delete

# Strip libraries and binaries
while read -rd '' file; do
  case "$(file -bi "$file")" in
    application/x-sharedlib\;*)      # Libraries (.so)
      strip -v $STRIP_SHARED "$file" ;;
    application/x-archive\;*)        # Libraries (.a)
      strip -v $STRIP_STATIC "$file" ;;
    application/x-executable\;*)     # Binaries
      strip -v $STRIP_BINARIES "$file" ;;
    application/x-pie-executable\;*) # Relocatable binaries
      strip -v $STRIP_SHARED "$file" ;;
  esac
done < <(find "$HDR_PATH" -type f -perm -u+x ! -name vmlinux -print0)

# Strip vmlinux
strip -v $STRIP_STATIC "$HDR_PATH/vmlinux"

# Create an archive for the headers
cd $HDR_PATH
tar -cvI "xz -9 -T0" -f ../../$HEADERS *
echo "$HEADERS created!"
