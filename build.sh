#!/bin/bash

# Exit on errors
set -e

KERNEL_VERSION=v6.3.1

# Clone mainline
if [[ ! -d $KERNEL_VERSION ]]; then
  git clone --depth 1 --branch $KERNEL_VERSION --single-branch https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git $KERNEL_VERSION
fi

cd $KERNEL_VERSION

# Apply patches to the kernel
if [[ ! -e .patches_applied ]]; then
  for file in $(ls ../patches); do
    echo applying $file
    patch -p1 <../patches/$file
  done
  touch .patches_applied
fi

# Prevent a dirty kernel
echo "mod" >>.gitignore
rm -rf .git

# Copy config if it doesn't exist
[[ -f .config ]] || cp ../kernel.conf .config || exit
make olddefconfig

# make dummy initramfs file
# the first builds bzImage is not used anyways
touch initramfs.cpio.gz

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
    make -j"$(nproc)" || exit
  else
    make -j"$(nproc)" || exit
  fi

else

  make -j"$(nproc)"

fi

echo "Initial Kernel build completed"

KVER=$(file -bL arch/x86/boot/bzImage | grep -o 'version [^ ]*' | cut -d ' ' -f 2)

# Install modules
rm -rf mod || true
mkdir mod

if [[ -d /lib/modules/$KVER ]]; then
	echo "Your currently installed kernel modules conflict with the ones being built"
	read -p "Would you like to temporarily rename your modules folder to resolve the conflict? (y/n): " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo "Backing up modules"
		sudo mv /lib/modules/$KVER /lib/modules/$KVER-backup
	else
		echo "Kernel build aborted"
		exit
	fi
fi

make -j"$(nproc)" modules_install INSTALL_MOD_PATH=mod INSTALL_MOD_STRIP=1

# Move modules folder to root of mod
cd mod
mv lib/modules/* .
rm -r lib

# Remove broken symlinks
rm -rf */build
rm -rf */source

# Create an archive for the modules
tar -cvI "xz -9 -T0" -f ../../modules.tar.xz *
echo "Modules archive created!"

# Create an archive containing headers to build out of tree modules
# Taken from the archlinux linux PKGBUILD
cd ../
rm -r hdr || true
mkdir -p hdr
HDR_PATH=$(pwd)/hdr/linux-headers-$KVER

# Build files
install -Dt "$HDR_PATH" -m644 .config Makefile Module.symvers System.map # vmlinux
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

# Remove broken symlinks
find -L "$HDR_PATH" -type l -printf 'Removing %P\n' -delete

# Strip files
find "$HDR_PATH" -type f -exec strip {} \;

# Strip vmlinux
# strip "$HDR_PATH/vmlinux"

# Remove duplicate folder
rm -r "$HDR_PATH"/hdr

# Create an archive for the headers
cd "$HDR_PATH"/..
tar -cvI "xz -9 -T0" -f ../../headers.tar.xz *
echo "Headers archive created!"
cd ..

# Install the built modules into /lib/modules for dracut
sudo tar xvf ../modules.tar.xz -C /lib/modules
echo Installing modules to /lib/modules/$KVER
# Generate initramfs from the built modules
dracut --kver=$KVER --add-drivers="i915" --xz --reproducible --no-hostonly --force --nofscks initramfs.cpio.gz
# remove built modules
sudo rm -rf /lib/modules/$KVER
# restore original modules if needed
sudo mv /lib/modules/$KVER-backup /lib/modules/$KVER || true

# rebuild kernel with initramfs
make -j"$(nproc)"

# Copy kernel to root
echo "Second kernel build completed"
cp arch/x86/boot/bzImage ../bzImage

echo "Full build completed"
