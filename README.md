# APB_vip_fi

Reference repo: [1](https://github.com/mbits-mirafra/apb_avip) [2](https://github.com/asveske/apb_vip)

Plan: [link](https://docs.google.com/spreadsheets/d/1E-tFrMDzXq3ddTPvspKoZt6vzT8TeH31DOQvM-1_6kQ/edit?gid=206709590#gid=206709590)

Diagram: [link](https://drive.google.com/file/d/1hWdgIud8ltGhvamM8n0e_G58TUKHaFJo/view?usp=sharing)

## QuestaSim simulation

Requirements: Python 3, QuestaSim installation.

From the repository root, point `QUESTA_BIN` to the QuestaSim executable directory (win64). For example:

```powershell
$env:QUESTA_BIN = "D:\QuestaSim\win64"
```

Compile and run the testbench in command-line mode:

```powershell
python .\sim\questa.py
```

To open the QuestaSim GUI:

```powershell
python .\sim\questa.py --gui
```

The script compiles `tests/fpt_apb_tb_top.sv`. Generated files and the command-line simulation log are placed in `sim/build/questa`.

## VCS simulation

Requirements: Python 3, Synopsys VCS installation on Linux.

From the repository root, ensure VCS_HOME is set to your VCS installation path. For example:

```Bash
export VCS_HOME="/opt/synopsys/vcs/X-2025.06"
```

Compile and run the testbench in command-line mode:
```Bash
python3 sim/vcs.py
```

To open the VCS GUI:
```Bash
python3 sim/vcs.py --gui
```

The script reads the filelist at `flist.f`. Generated build artifacts `simv` and simulation logs are placed in `sim/build/vcs`.