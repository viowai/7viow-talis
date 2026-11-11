#!/usr/bin/env python3
"""Convert owned legacy bundles to verified ZIP backups; default is inventory only."""
import argparse
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

PROJECT = Path(__file__).resolve().parents[1]
LSREGISTER = Path('/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister')


def owned_roots():
    support = Path.home() / 'Library/Application Support'
    cache = Path.home() / 'Library/Caches/Talis'
    return [support / 'Talis/Backups', support / 'Talis v1 Preview/Backups',
            cache / 'Build', cache / 'Build.noindex', PROJECT / '.trellis/tasks', PROJECT / 'dist', PROJECT.parent / '_local']


def bundles(root):
    if not root.exists():
        return
    for parent, directories, _ in os.walk(root):
        for name in list(directories):
            path = Path(parent) / name
            if name == 'Archives.noindex' or path.is_symlink():
                directories.remove(name)
            elif (name.endswith('.archive') or (name.endswith('.app') and root.name != 'Build.noindex')) and (path / 'Contents/Info.plist').is_file():
                directories.remove(name)
                yield path


def compare_payload(source, restored):
    """Compare bytes and supported bundle filesystem semantics, without digests."""
    def entries(root):
        result = {}
        for parent, dirs, files in os.walk(root, followlinks=False):
            for name in dirs + files:
                p = Path(parent) / name
                result[p.relative_to(root)] = p
        return result
    before, after = entries(source), entries(restored)
    if before.keys() != after.keys():
        raise RuntimeError(f'restored entry set differs: {source}')
    for relative, path in before.items():
        other = after[relative]
        a, b = path.lstat(), other.lstat()
        if stat.S_IFMT(a.st_mode) != stat.S_IFMT(b.st_mode) or stat.S_IMODE(a.st_mode) != stat.S_IMODE(b.st_mode):
            raise RuntimeError(f'restored type/mode differs: {relative}')
        if path.is_symlink():
            if os.readlink(path) != os.readlink(other):
                raise RuntimeError(f'restored symlink differs: {relative}')
        elif path.is_file():
            with path.open('rb') as left, other.open('rb') as right:
                while True:
                    data = left.read(1024 * 1024)
                    if data != right.read(1024 * 1024):
                        raise RuntimeError(f'restored bytes differ: {relative}')
                    if not data:
                        break


def convert(source, destination):
    if destination.exists():
        raise RuntimeError(f'recovery destination already exists; inspect before continuing: {destination}')
    subprocess.run(['bash', '-c', 'source "$1"; archive_bundle "$2" "$3"', '_',
                    str(PROJECT / 'scripts/archive_bundle.sh'), str(source), str(destination)], check=True,
                   stdout=subprocess.DEVNULL)
    with tempfile.TemporaryDirectory(prefix='.restore-', dir=destination.parent) as temporary:
        restored = Path(temporary) / 'Payload'
        subprocess.run(['ditto', '-x', '-k', '--rsrc', '--extattr', '--acl', str(destination), str(restored)], check=True)
        compare_payload(source, restored)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--root', type=Path, action='append', help='Explicit owned root; defaults to the seven Talis artifact roots')
    args = parser.parse_args()
    records = []
    if args.report.exists():
        records = json.loads(args.report.read_text())
    def save():
        args.report.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.report.with_suffix('.partial')
        temporary.write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
        temporary.replace(args.report)
    for root in args.root or owned_roots():
        for source in list(bundles(root)):
            archive_root = root if root.name != 'Build' else root.with_name('Build.noindex')
            destination = archive_root / 'Archives.noindex/legacy' / (str(source.relative_to(root)) + '.zip')
            record = dict(source=str(source), archive=str(destination), layout='contents-at-zip-root', status='planned')
            records.append(record)
            if args.apply:
                try:
                    convert(source, destination)
                    record['status'] = 'verified-recovery'
                    save()  # persist recovery mapping before removing the original directory
                    result = subprocess.run([str(LSREGISTER), '-u', str(source)], capture_output=True, text=True)
                    record['unregister_exit'] = result.returncode
                    # Old cached aliases may contain the path before the historical rename.
                    if source.name == 'AppBundle.archive':
                        result = subprocess.run([str(LSREGISTER), '-u', str(source.with_name('Talis.app'))], capture_output=True, text=True)
                        record['former_name_unregister_exit'] = result.returncode
                    shutil.rmtree(source)
                    record['status'] = 'converted'
                except Exception as error:
                    record['status'] = 'retained-error'
                    record['error'] = str(error)
                    save()
                    raise
            save()
            print(record['status'], source, flush=True)
    shortcut = PROJECT / 'dist/Talis.app'
    if args.apply and not args.root and shortcut.is_symlink():
        records.append(dict(source=str(shortcut), status='removed-generated-symlink', target=os.readlink(shortcut)))
        subprocess.run([str(LSREGISTER), '-u', str(shortcut)], capture_output=True)
        shortcut.unlink()
        save()
    print(f'{len(records)} mappings: {args.report}')


if __name__ == '__main__':
    main()
