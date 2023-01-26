#!/usr/bin/env python3
import json
import subprocess
from urllib.request import urlopen


def bash(command: str) -> str:
    output = subprocess.check_output(command, shell=True, text=True).strip()
    print(output, flush=True)
    return output


if __name__ == "__main__":
    # Read json from kernel.org
    with urlopen("https://www.kernel.org/releases.json") as response:
        data = json.loads(response.read())

    # Get the latest stable version
    latest_version = "v" + data["latest_stable"]["version"]

    # Git clone the latest stable version
    bash(f"git clone --depth=1 --branch={latest_version} https://git.kernel.org/pub/scm/linux/kernel/git/"
         f"stable/linux.git")

    # Copy old config into local stable repo
    bash("cp kernel.conf linux/.config")

    # Update config
    bash("cd linux && make olddefconfig")

    # Update bash script
    with open("build.sh", "r") as file:
        build_script = file.readlines()
    build_script[1] = f"  KERNEL_VERSION={latest_version}"
    with open("build.sh", "w") as file:
        file.writelines(build_script)

    # Copy new config back to repo
    bash("cp linux/.config kernel.conf")
