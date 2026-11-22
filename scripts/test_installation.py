#!/usr/bin/env python3
"""Run the real transaction with isolated Apps and injected filesystem failures."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CASES = ["fresh", "upgrade", "finder-metadata", "copy", "metadata-clear", "stage-signature",
         "archive-create", "archive-verify", "archive-commit", "backup-move", "activate",
         "final-signature", "fresh-final-signature", "final-signature-restore", "final-signature-remove"]
for case in CASES:
    with tempfile.TemporaryDirectory(prefix="talis-install-test-", suffix=".noindex") as temp:
        root = Path(temp)
        source = root / "build" / "Talis.app"
        target = root / "Applications" / "Talis.app"
        backup = root / "data" / "Backups"
        source.mkdir(parents=True)
        (source / "version").write_text("new")
        if case == "finder-metadata":
            subprocess.run(["/usr/bin/xattr", "-wx", "com.apple.FinderInfo", "4150504c" + "00" * 28, str(source)], check=True)
        target.parent.mkdir()
        old = not case.startswith("fresh")
        if old:
            target.mkdir()
            (target / "version").write_text("old")
            payload = target / "executable"
            payload.write_bytes(b"old executable\x00bytes")
            payload.chmod(0o755)
            (target / "link").symlink_to("executable")
            subprocess.run(["/usr/bin/xattr", "-wx", "com.apple.ResourceFork", b"resource-fork-fixture".hex(), str(payload)], check=True)
        backup.parent.mkdir()
        marker = backup.parent / "user-templates.json"
        marker.write_text("user content remains")
        bin_dir = root / "bin"
        bin_dir.mkdir()
        scripts = {
            "ditto": 'if [[ "$FAIL_STEP" == copy && "$1" != -c ]]; then mkdir -p "$2"; exit 61; fi\nif [[ "$FAIL_STEP" == archive-create && "$1" == -c ]]; then exit 68; fi\nexec /usr/bin/ditto "$@"',
            "unzip": 'if [[ "$FAIL_STEP" == archive-verify ]]; then exit 69; fi\nexec /usr/bin/unzip "$@"',
            "xattr": 'if [[ "$FAIL_STEP" == metadata-clear ]]; then exit 67; fi\nexec /usr/bin/xattr "$@"',
            "codesign": 'last="${!#}"\nif [[ "$FAIL_STEP" == finder-metadata ]] && /usr/bin/xattr -p com.apple.FinderInfo "$last" >/dev/null 2>&1; then exit 66; fi\nif [[ "$FAIL_STEP" == stage-signature && "$last" == */Payload ]]; then exit 62; fi\nif [[ "$FAIL_STEP" == *final-signature* && "$last" == "$TEST_TARGET" ]]; then exit 63; fi\nexit 0',
            "mv": 'if [[ "$FAIL_STEP" == archive-commit && "$1" == */.archive.*/AppBundle.zip ]]; then exit 70; fi\nif [[ "$FAIL_STEP" == backup-move && "$1" == "$TEST_TARGET" ]]; then exit 64; fi\nif [[ "$FAIL_STEP" == activate && "$1" == */Payload ]]; then exit 65; fi\nif [[ "$FAIL_STEP" == final-signature-restore && "$1" == */PreviousBundle ]]; then exit 71; fi\nexec /bin/mv "$@"',
            "rm": 'if [[ "$FAIL_STEP" == final-signature-remove && "${!#}" == "$TEST_TARGET" ]]; then exit 72; fi\nexec /bin/rm "$@"',
        }
        for name, body in scripts.items():
            file = bin_dir / name
            file.write_text("#!/bin/bash\n" + body + "\n")
            file.chmod(0o755)
        env = dict(os.environ, PATH=str(bin_dir) + ":" + os.environ["PATH"], FAIL_STEP=case, TEST_TARGET=str(target), DITTONORSRC="1")
        command = ['bash', '-c', 'source "$1"; install_bundle "$2" "$3" "$4"', '_', str(ROOT / 'scripts/install_bundle.sh'), str(source), str(target), str(backup)]
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        success = case in ("fresh", "upgrade", "finder-metadata")
        assert (result.returncode == 0) == success, (case, result.stdout, result.stderr)
        assert marker.read_text() == "user content remains", case
        assert (source / "version").read_text() == "new", case
        retained = case in ("final-signature-restore", "final-signature-remove")
        if success or case == "final-signature-remove":
            assert (target / "version").read_text() == "new", case
        elif retained or not old:
            assert not target.exists(), case
        else:
            assert (target / "version").read_text() == "old", (case, result.stderr)
        archives = list(backup.glob("Archives.noindex/*/AppBundle.zip"))
        expect_archive = old and case not in ("copy", "metadata-clear", "stage-signature", "archive-create", "archive-verify", "archive-commit")
        assert len(archives) == int(expect_archive), (case, archives)
        for archive in archives:
            restore = root / "restore" / "Talis.app"
            subprocess.run(["/usr/bin/ditto", "-x", "-k", "--rsrc", "--extattr", "--acl", str(archive), str(restore)], check=True)
            assert (restore / "version").read_text() == "old", case
            assert (restore / "executable").read_bytes() == b"old executable\x00bytes", case
            assert (restore / "executable").stat().st_mode & 0o777 == 0o755, case
            assert (restore / "link").is_symlink() and os.readlink(restore / "link") == "executable", case
            assert subprocess.check_output(["/usr/bin/xattr", "-px", "com.apple.ResourceFork", str(restore / "executable")]).decode().replace(" ", "").replace("\n", "").lower() == b"resource-fork-fixture".hex(), case
        assert not list(backup.rglob("*.app")) and not list(backup.rglob("*.archive")), case
        assert not list(backup.rglob(".archive.*")), case
        preserved = list(target.parent.glob(".talis-install.noindex/transaction.*/PreviousBundle/version"))
        assert len(preserved) == int(retained), (case, preserved)
        if retained:
            assert preserved[0].read_text() == "old", case
            assert "已验证压缩备份" in result.stderr, case
        else:
            assert not (target.parent / ".talis-install.noindex").exists(), case
        print("PASS:", case)
print(f"PASS: {len(CASES)} isolated installation cases; ZIP restore bytes/modes/symlinks/resource forks; real App/data untouched")
