#!/usr/bin/env python3
import json
import subprocess
from urllib.request import urlopen


def bash(command: str) -> str:
    output = subprocess.check_output(command, shell=True, text=True).strip()
    print(output, flush=True)
    return output


def update_stable(releases_json: dict) -> None:
    # Get the latest stable version
    latest_stable = "v" + releases_json["releases"][1]["version"]

    # Git clone the latest stable version
    bash(f"git clone --depth=1 --branch={latest_stable} https://git.kernel.org/pub/scm/linux/kernel/git/"
         f"stable/linux.git")

    # Copy old config into local stable repo
    bash("cp config-stable linux/.config")

    # Update config
    bash("cd linux && make olddefconfig")

    # Copy new config back to repo
    bash("cp linux/.config config-stable")


def update_testing(releases_json: dict) -> None:
    # Get the latest mainline version
    latest_stable = "v" + releases_json["latest_stable"]["version"]

    # Git clone the latest mainline version
    bash(f"git clone --depth=1 --branch={latest_stable} https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/"
         f"linux.git")

    # Copy old config into local stable repo
    bash("cp config-testing linux/.config")

    # Update config
    bash("cd linux && make olddefconfig")

    # Copy new config back to repo
    bash("cp linux/.config config-testing")


if __name__ == "__main__":
    # Read json from kernel.org
    with urlopen("https://www.kernel.org/releases.json") as response:
        data = json.loads(response.read())

    update_stable(data)
    # remove the linux repo
    bash("rm -rf ./linux")
    update_testing(data)
