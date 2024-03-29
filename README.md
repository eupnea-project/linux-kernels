# THE EUPNEA PROJECT HAS BEEN DISCONTINUED

Please use one of the following projects instead:
* MrChromebox's UEFI/RW_L (turn chromebook into almost a normal laptop): https://mrchromebox.tech/#fwscript
* FyraLab's submarine (does not require firmware modification): https://github.com/FyraLabs/submarine

<details>
<summary>View the old readme</summary>

# Linux kernels

### [Kernel docs page](https://eupnea-project.github.io/docs/project/kernels)

* [Building the Eupnea-Mainline kernel](https://eupnea-project.github.io/docs/compile/kernel#building-the-eupnea-mainline-kernel)
* [Building the Eupnea-ChromeOS kernel](https://eupnea-project.github.io/docs/compile/kernel#building-the-eupnea-chromeos-kernel)

## Overlaid configs

To allow continuously importing changes from the upstream kernel
config ([currently arch linux](https://raw.githubusercontent.com/archlinux/svntogit-packages/packages/linux/trunk/config))
all changes made by the Eupnea team are stored as individual overlay configs that are appended to the base config.

A daily workflow pulls the fresh upstream config into base-kernel.conf , appends the overlay configs (from
kernel-conf-overlays) and runs `make olddefconfig` to automatically combine the configs (the appended config options are
prioritized over the base config options) to create combined-kernel.conf which can then used to build the kernel.

* [Overlays-readme (mainline)](kernel-conf-overlays/mainline/README.md)  
* [Overlays-readme (chromeos)](kernel-conf-overlays/chromeos/README.md)  
