from pathlib import Path
import os
import shutil
import subprocess
import sys

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
BUILD = SCRIPT_DIR / "build" / "questa"

# Set QUESTA_BIN to the win64 directory of your Questa installation.
# Example: C:\questasim64_2024.3\win64
questa_bin_env = os.environ.get("QUESTA_BIN")

if questa_bin_env:
    QUESTA_BIN = Path(questa_bin_env)

    def tool(name: str) -> str:
        executable = QUESTA_BIN / f"{name}.exe"
        if not executable.exists():
            raise FileNotFoundError(f"Cannot find {executable}")
        return str(executable)
else:
    def tool(name: str) -> str:
        executable = shutil.which(name)
        if executable is None:
            raise FileNotFoundError(
                f"Cannot find {name}. Set the QUESTA_BIN environment variable."
            )
        return executable


VLIB = tool("vlib")
VMAP = tool("vmap")
VLOG = tool("vlog")
VSIM = tool("vsim")


def run(command):
    print("+", " ".join(map(str, command)))
    subprocess.run(
        [str(argument) for argument in command],
        cwd=BUILD,
        check=True,
    )


def main():
    gui = "--gui" in sys.argv

    BUILD.mkdir(parents=True, exist_ok=True)

    run([VLIB, "work"])
    run([VMAP, "work", "work"])

    include_dirs = [
        ROOT,
        ROOT / "include",
        ROOT / "source",
        ROOT / "source" / "master",
        ROOT / "source" / "slave",
        ROOT / "tests",
    ]

    vlog_command = [
        VLOG,
        "-sv",
        "-work",
        "work",
    ]

    for directory in include_dirs:
        vlog_command.append(f"+incdir+{directory.as_posix()}")

    vlog_command.append(str(ROOT / "tests" / "fpt_apb_tb_top.sv"))

    run(vlog_command)

    if gui:
        run([
            VSIM,
            "-voptargs=+acc",
            "work.fpt_apb_tb_top",
            "-do",
            (
                "view wave; "
                "add wave sim:/fpt_apb_tb_top/PCLK; "
                "add wave sim:/fpt_apb_tb_top/PRESETn; "
                "add wave -r sim:/fpt_apb_tb_top/apb_if/*; "
                "run -all; "
                "wave zoom full"
            ),
        ])
    else:
        run([
            VSIM,
            "-c",
            "-l",
            "simulation.log",
            "work.fpt_apb_tb_top",
            "-do",
            "onerror {quit -f -code 1}; run -all; quit -f -code 0",
        ])


if __name__ == "__main__":
    main()
