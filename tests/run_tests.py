"""Run Godot suites with private save directories and check their completion markers."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("godot", help="Path to the Godot executable")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
failures = []
for suite in sorted(Path(__file__).parent.glob("test_*.gd")):
    with tempfile.TemporaryDirectory(prefix="astral-qa-") as profile:
        env = dict(os.environ, APPDATA=profile, XDG_DATA_HOME=profile)
        frames = "92000" if suite.stem == "test_playthrough" else "6000"
        result = subprocess.run(
            [args.godot, "--headless", "--path", str(root), "--fixed-fps", "60",
             "--script", str(suite.resolve()), "--quit-after", frames],
            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace",
        )
    passed = (result.returncode == 0 and re.search(r"^PASS\b", result.stdout, re.M)
              and not re.search(r"^(SCRIPT ERROR|ERROR):", result.stdout, re.M))
    print(suite.stem, "PASS" if passed else result.stdout, flush=True)
    if not passed:
        failures.append(suite.stem)
raise SystemExit(bool(failures))
