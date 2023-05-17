# Eupnea-Mainline kernel

[Kernel docs page](https://eupnea-linux.github.io/docs/project/kernels#mainline-eupnea-kernel)

# Building the Eupnea-Mainline kernel

[Build instructions](https://eupnea-linux.github.io/docs/compile/kernel#building-the-eupnea-mainline-kernel)

# Overlaid configs

To allow continuously importing changes from the base-kernel
config ([currently arch linux](https://raw.githubusercontent.com/archlinux/svntogit-packages/packages/linux/trunk/config))
all changes made by the Eupnea team are stored as individual overlay configs that are appended to the base config. After
running `make olddefconfig` the base config is updated and the overlay configs are applied automatically. This is
performed daily by a GitHub action and results in the combined-kernel.conf file.