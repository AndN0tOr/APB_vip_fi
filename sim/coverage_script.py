"""Write the coverage holes of a Questa UCDB into one readable log.

Usage: python3 sim/coverage_script.py [coverage.ucdb] [output.log]
Defaults: sim/build/questa/coverage.ucdb -> sim/build/questa/coverage_holes.log
"""
from datetime import datetime
from pathlib import Path
import os
import re
import shutil
import subprocess
import sys

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
BUILD = SCRIPT_DIR / "build" / "questa"

# Short hints for every coverpoint, keyed by its name in the covergroups.
HINTS = {
    "PWRITE_CP": "read/write not both exercised.",
    "PADDR_CP": "'zero' is a single address, rarely hit by random; bins use "
                "absolute addresses, not the slave address map, so a slave "
                "can never hit bins outside its own region.",
    "PWDATA_CP": "corner values (0, all-ones) need a directed sequence; "
                 "random 32-bit data almost never produces them.",
    "PRDATA_CP": "read data comes from the memory init pattern "
                 "(INCR/ALL1/...); few reads are sampled.",
    "PSTRB_CP": "too few write samples to hit every strobe pattern.",
    "WAIT_CP": "long bin starts at 16 but the slave delay is soft "
               "[0:15] (FPT_APB_PREADY_DELAY_LOW); run a MEDIUM/HIGH delay test.",
    "DELAY_CP": "long bin starts at 16 but the slave delay is soft "
                "[0:15] (FPT_APB_PREADY_DELAY_LOW); run a MEDIUM/HIGH delay test.",
    "PSLVERR_CP": "slave never answered with this PSLVERR value.",
    "OP_X_ERROR": "needs both reads and writes answered with PSLVERR "
                  "(about 5% of slave responses); run more transfers or a "
                  "PSLVERR test.",
}


def find_vcover():
    vcover = shutil.which("vcover")
    if vcover:
        return vcover
    questa_home = Path(os.environ.get("QUESTA_HOME",
                                      "/home/stupidrat/altera/questasim"))
    vcover = questa_home / "bin" / "vcover"
    if not vcover.exists():
        raise FileNotFoundError("Cannot find vcover. Set QUESTA_HOME.")
    return str(vcover)


def vcover_report(vcover, ucdb, *options):
    result = subprocess.run(
        [vcover, "report", *options, str(ucdb)],
        capture_output=True, text=True, check=True,
    )
    return result.stdout.splitlines()


def short_instance(path):
    """uvm_test_top.fpt_apb_env.slave_agent_1.m_apb_slave_coverage -> slave_agent_1"""
    match = re.search(r"(master_agent|slave_agent_\d+)", path)
    return match.group(1) if match else path.strip()


def summary_section(vcover, ucdb):
    lines = ["1. SUMMARY (metrics below 100%)", "=" * 80]
    instance = None
    for line in vcover_report(vcover, ucdb):
        header = re.match(r"=== Instance: (\S+)", line)
        if header:
            instance = header.group(1)
            continue
        row = re.match(r"\s+(Assertions|Branches|Conditions|Expressions|"
                       r"FSM \w+|Statements|Toggles|Covergroups)\s+"
                       r"(\S+)\s+(\S+)\s+(\S+)\s+([\d.]+)%", line)
        if row and float(row.group(5)) < 100.0:
            name, bins, hits, misses, percent = row.groups()
            detail = f"   (hit {hits}/{bins})" if hits != "na" else ""
            lines.append(f"  {instance:<45} {name:<12} {percent:>7}%{detail}")
    lines.append("")
    return lines


def covergroup_section(vcover, ucdb):
    lines = ["2. FUNCTIONAL COVERAGE HOLES (covergroup bins with 0 hits)",
             "=" * 80]
    owner = point = None
    holes = {}  # owner -> [(coverpoint, bin)], -all prints each instance twice
    for line in vcover_report(vcover, ucdb, "-details", "-cvg", "-all"):
        group = re.match(r"\s*(TYPE|Covergroup instance)\s+(\S+)", line)
        if group:
            kind, path = group.groups()
            owner = ("TYPE " + path.split("/")[1]) if kind == "TYPE" \
                else short_instance(path)
            if kind != "TYPE" and owner == path.strip():
                # The master covergroup has no set_inst_name().
                owner = "master_agent" if "master" in path else owner
            continue
        cp = re.match(r"\s+(?:Coverpoint|Cross)\s+(\S+)", line)
        if cp:
            point = cp.group(1)
            continue
        zero = re.match(r"\s+bin\s+(.+?)\s+0\s+1\s+\S+\s+ZERO", line)
        if zero and owner and not owner.startswith("TYPE"):
            hole = (point, zero.group(1))
            if hole not in holes.setdefault(owner, []):
                holes[owner].append(hole)
    if not holes:
        lines.append("  No holes.")
    for owner, owner_holes in holes.items():
        lines.append(f"  {owner}  ({len(owner_holes)} hole(s))")
        for point, name in owner_holes:
            lines.append(f"    [HOLE] {point:<11} bin {name}")
    points = sorted({point for owner_holes in holes.values() for point, _ in owner_holes})
    if points:
        lines.append("  Why:")
        lines += [f"    {point:<11} {HINTS.get(point, '-')}" for point in points]
    total = sum(len(owner_holes) for owner_holes in holes.values())
    lines += [f"  Total: {total} bin(s) never hit.", ""]
    return lines


def assertion_section(vcover, ucdb):
    lines = ["3. ASSERTIONS (failed or never exercised)", "=" * 80]
    report = vcover_report(vcover, ucdb, "-details", "-assert")
    failed, idle = [], {}
    for index, line in enumerate(report):
        name = re.match(r"(/\S+/(\w+))\s*$", line)
        if not name or index + 2 >= len(report):
            continue
        location = report[index + 1].strip()
        counts = report[index + 2].split()
        if len(counts) != 2 or not all(c.isdigit() for c in counts):
            continue
        fail, passed = map(int, counts)
        path, label = name.groups()
        if fail > 0:
            failed.append(f"  [FAIL] {path}  ({fail} failure(s))  "
                          f"{Path(location).name}")
        elif passed == 0:
            labels = idle.setdefault(path.rsplit("/", 1)[0], [])
            if label not in labels:  # the report lists each assertion twice
                labels.append(label)
    lines += failed or ["  No assertion failures."]
    for instance, labels in idle.items():
        lines.append(f"  [IDLE] {instance}: {len(labels)} never exercised")
        lines.append(f"         {', '.join(labels)}")
    if any("fpt_slave_if_arr" in instance for instance in idle):
        lines.append("         hint: unused slave interfaces "
                     "(FPT_APB_MAX_SLAVE > fpt_slave_numb) never see a transfer.")
    lines.append("")
    return lines


def statement_section(vcover, ucdb):
    lines = ["4. CODE COVERAGE HOLES (statements never executed, project files only)",
             "=" * 80]
    current, skipped = None, 0
    sources = {}
    report = vcover_report(vcover, ucdb, "-details", "-zeros", "-code", "s")
    for line in report:
        file_line = re.match(r"\s+File (\S+)", line)
        if file_line:
            path = Path(file_line.group(1)).resolve()
            current = path if ROOT in path.parents else None
            if current and current not in sources:
                sources[current] = current.read_text(errors="replace").splitlines()
            continue
        stmt = re.match(r"\s+(\d+)\s+\d+\s*$", line)
        if not stmt or current is None:
            continue
        number = int(stmt.group(1))
        text = sources[current][number - 1].strip() if number <= len(sources[current]) else ""
        if text.startswith("`"):
            skipped += 1  # UVM macro expansion, e.g. `uvm_object_utils
            continue
        heading = f"  {current.relative_to(ROOT)}"
        if heading not in lines:  # files with only macro statements get no heading
            lines.append(heading)
        entry = f"    {number:>5}: {text}"
        if lines[-1] != entry:  # one entry per line even with several statements
            lines.append(entry)
    lines += [f"  ({skipped} statement(s) inside UVM macros not listed)", ""]
    return lines


def write_holes_log(ucdb=BUILD / "coverage.ucdb", output=BUILD / "coverage_holes.log"):
    ucdb, output = Path(ucdb), Path(output)
    if not ucdb.exists():
        print(f"No coverage database at {ucdb}")
        return None
    vcover = find_vcover()

    test = "unknown"
    sim_log = ucdb.parent / "simulation.log"
    if sim_log.exists():
        found = re.search(r"Running test (\w+)", sim_log.read_text(errors="replace"))
        test = found.group(1) if found else test

    lines = [
        "COVERAGE HOLES REPORT",
        f"  database : {ucdb}",
        f"  test     : {test}",
        f"  created  : {datetime.now():%Y-%m-%d %H:%M:%S}",
        "",
    ]
    lines += summary_section(vcover, ucdb)
    lines += covergroup_section(vcover, ucdb)
    lines += assertion_section(vcover, ucdb)
    lines += statement_section(vcover, ucdb)
    output.write_text("\n".join(lines) + "\n")
    print(f"Coverage holes written to {output}")
    return output


if __name__ == "__main__":
    write_holes_log(*sys.argv[1:3])
