## binder

Enable android binder modules for waydroid support.

## disable-vgem

Disable virtual graphics memory (vgem) module to prevent Mesa from creating llvmpipe (software rendering) which
interferes with the onboard graphics in games causing extremely poor performance.

## initramfs

Set initramfs compression to xz + set initramfs name to allow the kernel to include it.

## iommu

Set iommu to passthrough mode by default to remove the need for some AMD users to add `iommu=pt` to their kernel
parameters.

## lsm

Add apparmor and SELinux support to the kernel.

## storage

Set storage drivers to be built into the kernel, as they are not in the initramfs.
If this is not enabled, emmc storage will not be detected on boot -> kernel panic.

## strict-devmem

Disable strict devmem to allow MrChromebox's scripts to work under Eupnea kernels.

## zram

Set default zram compression mode to lzo-rle.

## version-string

Add the eupnea name to the kernel version string.

## hostname

Set the default hostname to "localhost".

## cb-mem

Enable Google SMI callbacks and enable access to the coreboot memory entries from sysfs.

## console-loglevel

Set the default console loglevel to 7 and quiet to 4.

## nvidia-disable

Disable any nvidia related components in the kernel.

## i2c

Set i2c modules to be built into the kernel, as they are not in the initramfs.