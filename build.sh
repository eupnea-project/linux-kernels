#!/bin/bash

# Exit on errors
#set -e

KERNEL_VERSION=v6.3.2
KERNEL_SOURCE=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
BUILD_ROOT_DIRECTORY=$(pwd)
MODULES_FOLDER=modules
KERNEL_CONFIG=kernel.conf

#outputs given message and color choice
#First parameter is message to output
#Second parameter is color choice
write_output() {

  case ${2,,} in
  green)
    echo -e "\e[32m$1\e[0m"
    ;;
  yellow)
    echo -e "\e[33m$1\e[0m"
    ;;
  red)
    echo -e "\e[31m$1\e[0m"
    ;;
  blue)
    echo -e "\e[34m$1\e[0m"
    ;;
  magenta)
    echo -e "\e[35m$1\e[0m"
    ;;
  white)
    echo -e "\e[37m$1\e[0m"
    ;;
  *)
    echo -e $1
    ;;
  esac
}

check_if_directory_exists() {
  if [[ -d $1 ]]; then
    return 0
  else
    return 1
  fi
}

check_if_file_exists() {
  if [[ -f $1 ]]; then
    return 0
  else
    return 1
  fi
}

clone_mainline() {
  check_if_directory_exists $KERNEL_VERSION
  if [[ $? -eq 1 ]]; then
    if ! git clone --depth 1 --branch $KERNEL_VERSION --single-branch $KERNEL_SOURCE $KERNEL_VERSION; then
      write_output "Failed to clone repository. Please check your network connection and try again." "red"
      exit 1
    fi
  else
    write_output "Kernel already cloned!" "yellow"
  fi
  cd $KERNEL_VERSION
}

apply_kernel_patches() {
  check_if_file_exists ".patches_applied"
  if [[ $? -eq 1 ]]; then
    write_output "Applying kernel patches." "yellow"
    echo -e "\e[33m"
    for file in $(ls $BUILD_ROOT_DIRECTORY/patches); do

      if ! patch -p1 <$BUILD_ROOT_DIRECTORY/patches/$file; then
        write_output "Failed to apply patch $file." "red"
        exit 1
      fi
    done
    echo -e "\e[0m"
    touch .patches_applied
  else
    write_output "Kernel patches already applied!" "yellow"
  fi
}

setup_kernel_config() {
  check_if_file_exists ".config"
  if [[ $? -eq 1 ]]; then
    write_output "No existing kernel config, creating config file" "yellow"
    cp $BUILD_ROOT_DIRECTORY/$KERNEL_CONFIG $BUILD_ROOT_DIRECTORY/$KERNEL_VERSION/.config
  else
    write_output "Kernel config already exists" "yellow"
  fi
  make olddefconfig >null

  #empty initial initramfs file to be populated after kernel build
  touch initramfs.cpio.xz
}

#verifies that terminal is interactive and not running in docker
check_terminal_is_interactive() {

  if [[ -t 0 ]] && [[ ! -f /.dockerenv ]]; then
    return 0
  else
    return 1
  fi
}

#Builds clean kernel if 0, incremental build if 1
build_kernel() {
  if [[ $? -eq 0 ]]; then
    write_output "Building clean kernel" "yellow"
    if ! make -j"$(nproc)"; then
      write_output "Kernel build failed." "red"
      exit 1
    else
      write_output "Kernel build completed" "green"
    fi
  else
    write_output "Building incremental kernel" "yellow"
    make clean
    if ! make -j"$(nproc)"; then
      write_output "Kernel build failed." "red"
    else
      write_output "Kernel build completed" "green"
    fi
  fi
}

edit_kernel_config() {

  cd $BUILD_ROOT_DIRECTORY/$KERNEL_VERSION
  make menuconfig
}

user_input() {

  echo -e "\e[33m"
  read -p "Would you like to make edits to the kernel config? (y/n) " -n 1 -r
  echo
  echo -e "\e[0m"
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    edit_kernel_config
  fi

  echo -e "\e[33m"
  read -p "Make clean kernel build? (y/n)" -n 1 -r
  echo
  echo -e "\e[0m"
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    build_kernel 0
  else
    build_kernel 1
  fi

}

clone_mainline
apply_kernel_patches
setup_kernel_config
check_terminal_is_interactive
if [[ $? -eq 0 ]]; then
  user_input
else
  build_kernel 0
fi

KVER=$(file -bL arch/x86/boot/bzImage | grep -o 'version [^ ]*' | cut -d ' ' -f 2)

#Installs modules to $MODULES_FOLDER
install_modules() {
  check_if_directory_exists $MODULES_FOLDER
  if [[ $? -eq 1 ]]; then
    sudo rm -r $MODULES_FOLDER
    mkdir $MODULES_FOLDER

  else
    mkdir $MODULES_FOLDER

  fi
  make -j"$(nproc)" modules_install INSTALL_MOD_PATH=$MODULES_FOLDER INSTALL_MOD_STRIP=1
}
install_modules

cd $MODULES_FOLDER/lib/modules/$KVER
# Remove broken symlinks
rm -rf */build
rm -rf */source

# Create an archive for the modules
tar -cvI "xz -9 -T0" -f $BUILD_ROOT_DIRECTORY/modules.tar.xz *
echo "Modules archive created!"

# Create an archive containing headers to build out of tree modules
# Taken from the archlinux linux PKGBUILD
cd $BUILD_ROOT_DIRECTORY/$KERNEL_VERSION
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

# Generate initramfs from the built modules
dracut --kver=$KVER --add-drivers="i915" --kmoddir $BUILD_ROOT_DIRECTORY/$KERNEL_VERSION/$MODULES_FOLDER --xz --reproducible --no-hostonly --force --nofscks initramfs.cpio.xz
# remove built modules
sudo rm -rf "/lib/modules/$KVER"
# restore original modules if needed
sudo mv "/lib/modules/$KVER-backup" "/lib/modules/$KVER" || true

# rebuild kernel with initramfs
make -j"$(nproc)"

# Copy kernel to root
echo "Second kernel build completed"
cp arch/x86/boot/bzImage ../bzImage

echo "Full build completed"
