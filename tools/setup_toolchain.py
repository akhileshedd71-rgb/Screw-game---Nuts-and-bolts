#!/usr/bin/env python3
"""Install pinned official Godot and optional Android SDK tooling in a writable directory.
TLS remains verified. Every downloaded artifact is verified against its publisher's
checksum manifest before extraction. Does not modify system directories.
"""
import argparse
import concurrent.futures
import hashlib
import os
from pathlib import Path
import stat
import urllib.request
import xml.etree.ElementTree as ET
from zipfile import ZipFile

VERSION = '4.7.2'
RELEASE = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/'
TEMPLATES = {'version.txt', 'linux_debug.x86_64', 'linux_release.x86_64',
             'web_nothreads_debug.zip', 'web_nothreads_release.zip',
             'web_debug.zip', 'web_release.zip', 'android_debug.apk',
             'android_release.apk', 'android_source.zip'}


def verified_download(url, target, digest, algorithm):
    if not target.exists() or hashlib.file_digest(target.open('rb'), algorithm).hexdigest() != digest:
        temporary = target.with_suffix(target.suffix + '.download')
        urllib.request.urlretrieve(url, temporary)
        actual = hashlib.file_digest(temporary.open('rb'), algorithm).hexdigest()
        if actual != digest:
            temporary.unlink()
            raise ValueError(f'{algorithm} verification failed: {target.name}')
        temporary.replace(target)
    print(f'Verified {target.name}', flush=True)


def write_member(target, payload, executable=False):
    # Reuse valid extracted files and replace atomically, including when an editor
    # is currently executing the older binary from this path.
    if target.exists():
        with target.open('rb') as handle:
            same = hashlib.file_digest(handle, 'sha256').digest() == hashlib.sha256(payload).digest()
        if same:
            return
    temporary = target.with_name(target.name + '.installing')
    temporary.write_bytes(payload)
    if executable:
        temporary.chmod(0o755)
    temporary.replace(target)


def install_godot(root):
    directory = root / 'godot' / VERSION
    directory.mkdir(parents=True, exist_ok=True)
    manifest = urllib.request.urlopen(RELEASE + 'SHA512-SUMS.txt', timeout=60).read()
    (directory / 'SHA512-SUMS.txt').write_bytes(manifest)
    expected = {line.split()[-1].lstrip('*'): line.split()[0]
                for line in manifest.decode().splitlines() if line.split()}
    names = [f'Godot_v{VERSION}-stable_linux.x86_64.zip', f'Godot_v{VERSION}-stable_export_templates.tpz']
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        list(executor.map(lambda name: verified_download(RELEASE + name, directory / name,
                                                        expected[name], 'sha512'), names))
    with ZipFile(directory / names[0]) as archive:
        executable = f'Godot_v{VERSION}-stable_linux.x86_64'
        write_member(directory / executable, archive.read(executable), executable=True)
    destination = root / 'xdg-data' / 'godot' / 'export_templates' / f'{VERSION}.stable'
    destination.mkdir(parents=True, exist_ok=True)
    with ZipFile(directory / names[1]) as archive:
        for name in archive.namelist():
            if Path(name).name in TEMPLATES:
                write_member(destination / Path(name).name, archive.read(name))
    print(f'Godot {VERSION} and matching export templates installed in {root}')


def install_android(root):
    destination = root / 'android-sdk'
    destination.mkdir(parents=True, exist_ok=True)
    manifest = urllib.request.urlopen('https://dl.google.com/android/repository/repository2-1.xml', timeout=60).read()
    (root / 'android-repository.xml').write_bytes(manifest)
    packages = ET.fromstring(manifest)
    for package in packages.iter('remotePackage'):
        package_name = package.get('path')
        if package_name not in ('build-tools;36.0.0', 'platform-tools'):
            continue
        for archive in package.findall('./archives/archive'):
            if archive.findtext('host-os') != 'linux':
                continue
            name = archive.findtext('./complete/url')
            digest = archive.findtext('./complete/checksum')
            zip_path = destination / name
            verified_download('https://dl.google.com/android/repository/' + name, zip_path, digest, 'sha1')
            base = destination / ('build-tools/36.0.0' if package_name.startswith('build-tools') else 'platform-tools')
            with ZipFile(zip_path) as contents:
                for member in contents.infolist():
                    relative = Path(*Path(member.filename).parts[1:])
                    if '..' in relative.parts:
                        raise ValueError('Unsafe SDK archive member')
                    target = base / relative
                    if member.is_dir():
                        target.mkdir(parents=True, exist_ok=True)
                    else:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(contents.read(member))
                        mode = member.external_attr >> 16
                        if mode:
                            target.chmod(stat.S_IMODE(mode))
            print(f'Installed {package_name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(os.getenv('SCREWCRAFT_TOOL_ROOT', '/workspace/.tools')))
    parser.add_argument('--android', action='store_true')
    args = parser.parse_args()
    install_godot(args.root)
    if args.android:
        install_android(args.root)


if __name__ == '__main__':
    main()
