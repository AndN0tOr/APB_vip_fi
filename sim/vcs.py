from pathlib import Path
import os
import shutil
import subprocess
import sys

SCRIPT_DIR = Path(__file__).resolve().parent  # sim/
ROOT = SCRIPT_DIR.parent                      # Project root directory
BUILD = SCRIPT_DIR / "build" / "vcs"          # sim/build/vcs/

# Look for VCS_HOME environment variable or system PATH
vcs_home_env = os.environ.get("VCS_HOME")

if vcs_home_env:
    VCS_BIN = Path(vcs_home_env) / "bin"

    def tool(name: str) -> str:
        executable = VCS_BIN / name
        if not executable.exists():
            raise FileNotFoundError(f"Cannot find {executable}")
        return str(executable)
else:
    def tool(name: str) -> str:
        executable = shutil.which(name)
        if executable is None:
            raise FileNotFoundError(
                f"Cannot find {name}. Set the VCS_HOME environment variable."
            )
        return executable

VCS = tool("vcs")
URG = tool("urg")  # Khai báo công cụ URG để xuất báo cáo coverage


def run(command, cwd=BUILD):
    print("+", " ".join(map(str, command)))
    env = os.environ.copy()
    env["ROOT"] = str(ROOT)

    subprocess.run(
        [str(argument) for argument in command],
        cwd=cwd,
        env=env,
        check=True,
    )


def main():
    gui = "--gui" in sys.argv
    cov = "--cov" in sys.argv

    BUILD.mkdir(parents=True, exist_ok=True)

    flist_path = SCRIPT_DIR.parent / "flist.f"

    if not flist_path.exists():
        raise FileNotFoundError(f"Cannot find filelist at: {flist_path}")

    # Step 1: VCS Compile Command using flist.f
    vcs_command = [
        VCS,
        "-full64",
        "-sverilog",
        "-ntb_opts", "uvm",
        "-timescale=1ns/1ps",
        "-f", str(flist_path),
        "-top", "fpt_apb_tb_top",
        "-debug_access+all",
        "-kdb",
        "-l", "compile.log",
        "-o", "simv",
    ]

    if gui:
        vcs_command.extend(["-gui"])
    if cov:
        # Sửa chính tả 'brancg' -> 'branch' và chỉ định thư mục lưu database coverage (.vdb)
        vcs_command.extend(["-cm", "line+cond+fsm+tgl+branch+assert", "-cm_dir", "simv.vdb"])

    # Run VCS Compilation
    run(vcs_command)

    # Step 2: Run Simulation Executable
    simv_executable = BUILD / "simv"
    
    sim_command = [
        simv_executable,
        "-l", "simulation.log",
    ]

    if gui:
        sim_command.append("-gui")
    if cov:
        # Sửa lỗi cú pháp .extend() truyền sai tham số
        sim_command.extend(["-cm", "line+cond+fsm+tgl+branch+assert", "-cm_dir", "simv.vdb"])

    run(sim_command)

    # Step 3: Generate Coverage Report using URG
    if cov:
        urg_command = [
            URG,
            "-dir", "simv.vdb",
            "-report", "urgReport",      # Tạo thư mục urgReport chứa file HTML
            "-format", "both",           # Xuất ra cả file HTML và Text summary
        ]
        run(urg_command)


if __name__ == "__main__":
    main()