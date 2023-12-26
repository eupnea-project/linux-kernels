#!/usr/bin/env python3
import json
import os
import subprocess
from urllib.request import urlopen, urlretrieve


def bash(command: str) -> str:
    output = subprocess.check_output(command, shell=True, text=True).strip()
    print(output, flush=True)
    return output


if __name__ == "__main__":
    # pull fresh arch linux config to use as base.conf
    urlretrieve(url="https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/raw/main/config",
                filename="kernel-configs/noinitramfs/base-kernel.conf")

    # duplicate base.conf to temp_combined.conf
    with open("kernel-configs/noinitramfs/base-kernel.conf", "r") as base:
        with open("temp_combined.conf", "w") as combined:
            combined.write(base.read())

    # append all overlays to combined.conf
    for file in os.listdir("kernel-conf-overlays/noinitramfs"):
        if file != "README.md":
            with open(f"kernel-conf-overlays/noinitramfs/{file}", "r") as overlay:
                with open("temp_combined.conf", "a") as combined:
                    combined.write("\n" + overlay.read())

    # Copy combined config into local stable repo
    bash("cp temp_combined.conf linux/.config")

    # Update config
    bash("cd linux && make olddefconfig")

    # Copy updated combined config back to repo
    bash("cp linux/.config ./kernel-configs/noinitramfs/combined-kernel.conf")
