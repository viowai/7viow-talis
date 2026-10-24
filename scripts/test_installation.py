#!/usr/bin/env python3
"""Exercise the real installer transaction in temporary directories."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CASES = ["fresh", "upgrade", "copy", "stage-signature", "backup-move", "activate", "final-signature", "fresh-final-signature"]
for case in CASES:
    with tempfile.TemporaryDirectory(prefix="talis-install-test-") as temp:
        root = Path(temp)
        source = root / "build" / "Talis.app"
        target = root / "Applications" / "Talis.app"
        backup = root / "data" / "Backups"
        source.mkdir(parents=True)
        (source / "version").write_text("new")
        target.parent.mkdir()
        old = not case.startswith("fresh")
        if old:
            target.mkdir()
            (target / "version").write_text("old")
        backup.parent.mkdir()
        marker = backup.parent / "user-templates.json"
        marker.write_text("user content remains")
        bin_dir = root / "bin"
        bin_dir.mkdir()
        scripts = {
            "ditto": 'if [[ "$FAIL_STEP" == copy ]]; then mkdir -p "$2"; exit 61; fi\nexec /usr/bin/ditto "$@"',
            "codesign": 'last="${!#}"\nif [[ "$FAIL_STEP" == stage-signature && "$last" == */.talis-install.*/* ]]; then exit 62; fi\nif [[ "$FAIL_STEP" == *final-signature && "$last" == "$TEST_TARGET" ]]; then exit 63; fi\nexit 0',
            "mv": 'if [[ "$FAIL_STEP" == backup-move && "$1" == "$TEST_TARGET" ]]; then exit 64; fi\nif [[ "$FAIL_STEP" == activate && "$1" == */.talis-install.*/* ]]; then exit 65; fi\nexec /bin/mv "$@"',
        }
        for name, body in scripts.items():
            file = bin_dir / name
            file.write_text("#!/bin/bash\n" + body + "\n")
            file.chmod(0o755)
        env = dict(os.environ, PATH=str(bin_dir) + ":" + os.environ["PATH"], FAIL_STEP=case, TEST_TARGET=str(target))
        command = ['bash', '-c', 'source "$1"; install_bundle "$2" "$3" "$4"', '_', str(ROOT / 'scripts/install_bundle.sh'), str(source), str(target), str(backup)]
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        success = case in ("fresh", "upgrade")
        assert (result.returncode == 0) == success, (case, result.stderr)
        assert marker.read_text() == "user content remains", case
        assert (source / "version").read_text() == "new", case
        if success:
            assert (target / "version").read_text() == "new", case
        elif old:
            assert (target / "version").read_text() == "old", (case, result.stderr)
        else:
            assert not target.exists(), case
        old_backups = list(backup.glob("*/Talis.app/version"))
        assert len(old_backups) == (1 if case == "upgrade" else 0), case
        if old_backups:
            assert old_backups[0].read_text() == "old"
        assert not list(target.parent.glob(".talis-install.*")), (case, result.stdout, result.stderr)
        print("PASS:", case)
print("PASS: 8 isolated installation cases; installed App and real user data untouched")
