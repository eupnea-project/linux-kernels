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

Set storage drivers to be built into the kernel to prevent issues on wake from sleep (kernel cant find rootfs).

## strict-devmem

Disable strict devmem to allow MrChromebox's scripts to work under Eupnea kernels.

## zram

Set default zram compression mode to lzo-rle.

## tpm modules

TODO?