from pathlib import Path
import os
import shutil
import subprocess
import sys

from coverage_script import write_holes_log

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
BUILD = SCRIPT_DIR / "build" / "questa"

# Set QUESTA_BIN to the win64 directory of your Questa installation.
# Example: C:\questasim64_2024.3\win64
questa_bin_env = os.environ.get("home/stupidrat/questa_sim-2021.2_1-online.bin")

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


def find_log_editor():
    """Return the Antigravity CLI, or None when it is not installed."""
    # Inside an Antigravity terminal its CLI is already on PATH.
    for name in ("antigravity", "antigravity-ide"):
        editor = shutil.which(name)
        if editor:
            return editor
    # From any other WSL terminal, use the Windows install; it opens WSL paths.
    for editor in sorted(Path("/mnt/c/Users").glob(
            "*/AppData/Local/Programs/Antigravity IDE/bin/antigravity-ide")):
        return str(editor)
    return None


def open_logs():
    """Open the simulation log (and the error log when it is not empty) in Antigravity."""
    logs = [BUILD / "simulation.log"]
    error_log = BUILD / "apb_error.log"
    if error_log.exists() and error_log.stat().st_size > 0:
        logs.append(error_log)
    logs.append(BUILD / "coverage_holes.log")
    logs = [str(log) for log in logs if log.exists()]
    if not logs:
        return

    editor = find_log_editor()
    if editor is None:
        print("Antigravity not found. Logs:", *logs)
        return
    subprocess.run([editor, "--reuse-window", *logs])


def main():
    arguments = sys.argv[1:]

    gui = "--gui" in arguments
    # --no-open: do not open the logs after the run (useful for regressions).
    open_log = "--no-open" not in arguments
    plusargs = [
        argument
        for argument in arguments
        if argument.startswith("+")
    ]

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
    '/home/stupidrat/altera/questasim/linux_x86_64/vlog',
    '-sv',
    '+cover=bcesf',
    '-work', 'work',
    # --- THÊM 2 ĐƯỜNG DẪN NÀY ĐỂ LIÊN KẾT UVM ---
    '+incdir+/home/stupidrat/altera/questasim/verilog_src/uvm-1.2/src',
    '/home/stupidrat/altera/questasim/verilog_src/uvm-1.2/src/uvm_pkg.sv',
    # --------------------------------------------
    '+incdir+/home/stupidrat/APB_vip_fi',
    '+incdir+/home/stupidrat/APB_vip_fi/include',
    ]
    for directory in include_dirs:
        vlog_command.append(f"+incdir+{directory.as_posix()}")

    vlog_command.append(str(ROOT / "tests" / "fpt_apb_tb_top.sv"))

    run(vlog_command)

    if gui:
       run([
            VSIM,
            "-voptargs=+acc",
            "-sv_lib", "/home/stupidrat/altera/questasim/uvm-1.2/linux_x86_64/uvm_dpi"
            "work.fpt_apb_tb_top",
            "-coverage",
            *plusargs,
            "-do",
            (
                "coverage save -onexit coverage.ucdb; "
                "view wave; "
                "add wave sim:/fpt_apb_tb_top/PCLK; "
                "add wave sim:/fpt_apb_tb_top/PRESETn; "
                "add wave -r sim:/fpt_apb_tb_top/apb_if/*; "
                "run -all; "
                "wave zoom full"
            ),
        ])
    else:
        try:
            run([
                VSIM,
                "-coverage",
                "-sv_lib", "/home/stupidrat/altera/questasim/uvm-1.2/linux_x86_64/uvm_dpi",
                "-c",
                "-l",
                "simulation.log",
                "work.fpt_apb_tb_top",
                "+UVM_VERBOSITY=UVM_LOW",
                *plusargs,
                "-do",
                "coverage save -onexit coverage.ucdb; onerror {quit -f -code 1}; run -all; quit -f -code 0",
            ])
        finally:
            try:
                write_holes_log(BUILD / "coverage.ucdb", BUILD / "coverage_holes.log")
            except (OSError, subprocess.CalledProcessError) as error:
                print("Cannot write coverage_holes.log:", error)
            # Open the logs even when vsim fails, since that is when they matter.
            if open_log:
                open_logs()


if __name__ == "__main__":
    main()
