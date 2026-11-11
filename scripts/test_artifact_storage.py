#!/usr/bin/env python3
"""Exercise every official bundle-producing entry and verified legacy conversion."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def protected(path):
    return any(part.endswith('.noindex') for part in Path(path).parts)

with tempfile.TemporaryDirectory(prefix='talis-artifacts-') as temporary:
    base = Path(temporary).resolve()
    # Also exercise custom paths outside noindex by passing relative components.
    for value, expected in [('plain', 'plain/TalisWork.noindex'), ('already.noindex/child', 'already.noindex/child'),
                            ('not.noindexish/child', 'not.noindexish/child/TalisWork.noindex'),
                            ('already.noindex/../outside', 'outside/TalisWork.noindex')]:
        result = subprocess.check_output(['bash', '-c', 'source "$1"; talis_noindex_dir "$2"', '_', str(ROOT/'scripts/artifact_paths.sh'), value], text=True, cwd=base).strip()
        assert result == str(base/expected), (value, result)
    default = subprocess.check_output(['bash', '-c', 'unset TALIS_BUILD_CACHE_DIR; source "$1"; talis_build_cache', '_', str(ROOT/'scripts/artifact_paths.sh')], text=True).strip()
    assert default == str(Path.home()/'Library/Caches/Talis/Build.noindex'), default
    project = base / 'project'
    (project/'scripts').mkdir(parents=True)
    scripts = ['artifact_paths.sh', 'archive_bundle.sh', 'build_desktop_app.sh', 'build_preview_app.sh',
               'build_app.sh', 'package_local.sh', 'test_native_ui.sh']
    for script in scripts:
        shutil.copy(ROOT/'scripts'/script, project/'scripts'/script)
    for script in ['check_environment.sh', 'check_macos_sdk.sh', 'build_brand_assets.sh', 'build_mode_icons.sh']:
        (project/'scripts'/script).write_text('#!/bin/bash\nexit 0\n')
    (project/'Resources/Fonts').mkdir(parents=True)
    (project/'Resources/Fonts/fixture').write_text('font')
    (project/'Resources/en.lproj').mkdir()
    (project/'Resources/en.lproj/Localizable.strings').write_text(
        '/* fixture */\n"fixture" = "fixture";\n'
    )
    (project/'Resources/Info.plist').write_text('<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>PromptLibraryMac</string></dict></plist>')
    (project/'Resources/AppIcon.icns').write_bytes(b'icon')
    for name in ['LICENSE', 'NOTICE', 'THIRD-PARTY-NOTICES.md']:
        (project/name).write_text('fixture')
    (project/'Sources/TalisCore').mkdir(parents=True)
    (project/'Sources/TalisCore/fixture.swift').touch()
    (project/'Sources/PromptLibraryMac').mkdir()
    (project/'Sources/PromptLibraryMac/main.swift').write_text('final class AppDelegate: NSObject {}')
    (project/'Sources/PromptLibraryMac/View.swift').write_text('// fixture')
    fake_bin = base/'bin'
    fake_bin.mkdir()
    output = base/'binary'
    output.mkdir()
    executable = output/'PromptLibraryMac'
    executable.write_text('#!/bin/bash\nexit 0\n')
    executable.chmod(0o755)
    bodies = {
        'xcrun': 'echo /fixture/SDK',
        'swift': 'if [[ " ${*} " == *" --show-bin-path "* ]]; then echo "$TEST_BINARY"; fi',
        'swiftc': 'while (( $# )); do if [[ "$1" == -o ]]; then shift; printf "#!/bin/bash\\nexit 0\\n" > "$1"; chmod +x "$1"; fi; shift; done',
        'codesign': 'echo "${!#}" >> "$TEST_PATH_LOG"',
        'hdiutil': 'while (( $# )); do if [[ "$1" == -srcfolder ]]; then shift; echo "$1" >> "$TEST_PATH_LOG"; fi; shift; done',
    }
    for name in ['strip', 'xattr', 'install_name_tool']:
        bodies[name] = 'exit 0'
    for name, body in bodies.items():
        p=fake_bin/name; p.write_text('#!/bin/bash\n'+body+'\n'); p.chmod(0o755)
    # Relative custom root means the helper must add its own noindex boundary.
    env = dict(os.environ, PATH=str(fake_bin)+':'+os.environ['PATH'], TALIS_BUILD_CACHE_DIR='custom-cache',
               TEST_BINARY=str(output), TEST_PATH_LOG=str(base/'paths.log'))
    for entry, args in [('build_desktop_app.sh', ['explicit-output']), ('build_preview_app.sh', []),
                        ('build_app.sh', []), ('package_local.sh', []), ('test_native_ui.sh', []), ('test_native_ui.sh', ['--review'])]:
        subprocess.run(['bash', str(project/'scripts'/entry), *args], cwd=project, env=env, check=True, stdout=subprocess.DEVNULL)
        print('PASS: entry', entry, *args)
    for path in (base/'paths.log').read_text().splitlines():
        # Inspect the emitted relative path, not just the enclosing test directory.
        if str(base) in path and 'TalisWork.noindex' not in path and '/Talis/' not in path:
            raise AssertionError(('missing workspace boundary', path))
        assert protected(path), path
    assert not (project/'dist/Talis.app').exists()
    assert (project/'dist/Talis.zip').is_file()
    assert not list(project.glob('explicit-output/*.app'))

    legacy = base/'fixtures.noindex/Backups/checkpoint/AppBundle.archive'
    (legacy/'Contents').mkdir(parents=True)
    (legacy/'Contents/Info.plist').write_text('fixture')
    (legacy/'Contents/executable').write_bytes(b'old bundle bytes')
    (legacy/'Contents/executable').chmod(0o755)
    (legacy/'Contents/link').symlink_to('executable')
    report=base/'migration.json'
    subprocess.run(['python3', str(ROOT/'scripts/archive_backups.py'), '--apply', '--root', str(base/'fixtures.noindex/Backups'), '--report', str(report)], check=True, stdout=subprocess.DEVNULL)
    records=json.loads(report.read_text())
    assert not legacy.exists() and records[0]['status']=='converted', records
    archive=Path(records[0]['archive'])
    assert archive.is_file() and protected(archive)
    spec=importlib.util.spec_from_file_location('archives', ROOT/'scripts/archive_backups.py')
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    restored=base/'restored'
    subprocess.run(['ditto','-x','-k',str(archive),str(restored)],check=True)
    peer=base/'peer'; shutil.copytree(restored,peer,symlinks=True)
    module.compare_payload(peer,restored)
    (restored/'Contents/executable').write_bytes(b'corruption')
    try:
        module.compare_payload(peer,restored)
    except RuntimeError:
        pass
    else:
        raise AssertionError('corrupt restoration accepted')
    print('PASS: legacy ZIP restore, executable mode, symlink, corrupt restore rejected')
print('PASS: protected defaults/custom paths, all six generation modes, ZIP-only export and verified legacy conversion')
