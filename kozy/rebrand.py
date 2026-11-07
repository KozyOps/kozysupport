#!/usr/bin/env python3
"""Build-time renames for KozySupport, run by CI on a fresh checkout.

The runtime takes its name from kozy/custom.json (APP_NAME = "KozySupport"),
and derives paths from it: /Applications/KozySupport.app/Contents/MacOS/
KozySupport on macOS, `systemctl ... kozysupport` and the `kozysupport` process
on Linux. The bundle, package and binary names fixed at build time have to
match, which is all this changes. Doing it here instead of committing it keeps
upstream rebases free of conflicts in files upstream edits every release.

Usage: python3 kozy/rebrand.py windows|macos|linux
"""
import re
import sys
from pathlib import Path

NAME = "KozySupport"
LOWER = "kozysupport"
BUNDLE_ID = "com.kozyops.kozysupport"


def edit(path, *pairs, regex=False, count=None):
    p = Path(path)
    s = p.read_text(encoding="utf-8")
    for old, new in pairs:
        n = len(re.findall(old, s)) if regex else s.count(old)
        if n == 0 or (count is not None and n != count):
            sys.exit(f"rebrand: {path}: expected {count or 'some'} of {old!r}, found {n}")
        s = re.sub(old, new, s) if regex else s.replace(old, new)
    p.write_text(s, encoding="utf-8")


def rename_all(s):
    return s.replace("rustdesk", LOWER).replace("RustDesk", NAME)


def windows():
    edit("Cargo.toml",
         ('ProductName = "RustDesk"', f'ProductName = "{NAME}"'),
         ('FileDescription = "RustDesk Remote Desktop"', f'FileDescription = "{NAME} Remote Support"'))
    edit("flutter/windows/runner/Runner.rc",
         ('"ProductName", "RustDesk"', f'"ProductName", "{NAME}"'),
         ('"FileDescription", "RustDesk Remote Desktop"', f'"FileDescription", "{NAME} Remote Support"'))
    # The downloadable exe is the self-extracting packer, which has its own version info.
    edit("libs/portable/Cargo.toml",
         ('ProductName = "RustDesk"', f'ProductName = "{NAME}"'),
         ('FileDescription = "RustDesk Remote Desktop"', f'FileDescription = "{NAME} Remote Support"'))


def macos():
    edit("flutter/macos/Runner/Configs/AppInfo.xcconfig",
         (r"(?m)^PRODUCT_NAME = .*$", f"PRODUCT_NAME = {NAME}"),
         (r"(?m)^PRODUCT_BUNDLE_IDENTIFIER = .*$", f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}"),
         regex=True)
    edit("flutter/macos/Runner.xcodeproj/project.pbxproj", ("RustDesk.app", f"{NAME}.app"), count=4)
    edit("build.py", ("Release/RustDesk.app/Contents/MacOS/", f"Release/{NAME}.app/Contents/MacOS/"), count=1)


def linux():
    edit("flutter/linux/CMakeLists.txt", ('set(BINARY_NAME "rustdesk")', f'set(BINARY_NAME "{LOWER}")'))

    # Packaging files: every rustdesk in them is the package, service, binary
    # or desktop entry name. None of them names the Rust library.
    for src in ["res/rustdesk.service", "res/rustdesk.desktop", "res/rustdesk-link.desktop"]:
        old = Path(src)
        Path(rename_all(src)).write_text(rename_all(old.read_text(encoding="utf-8")), encoding="utf-8")
        old.unlink()
    for f in sorted(Path("res/DEBIAN").iterdir()):
        f.write_text(rename_all(f.read_text(encoding="utf-8")), encoding="utf-8")
    spec = Path("res/rpm-flutter.spec")
    s = rename_all(spec.read_text(encoding="utf-8"))
    s = re.sub(r"(?m)^URL:.*$", "URL:        https://kozyops.com", s)
    s = re.sub(r"(?m)^Vendor:.*$", "Vendor:     KozyOps <support@kozyops.com>", s)
    spec.write_text(s, encoding="utf-8")
    Path("res/pacman_install").write_text(rename_all(Path("res/pacman_install").read_text(encoding="utf-8")), encoding="utf-8")
    pkg = Path("res/PKGBUILD")
    s = rename_all(pkg.read_text(encoding="utf-8"))
    s = re.sub(r'(?m)^pkgdesc=.*$', f'pkgdesc="{NAME} remote support by KozyOps"', s)
    s = re.sub(r'(?m)^url=.*$', 'url="https://kozyops.com"', s)
    pkg.write_text(s, encoding="utf-8")

    # build.py also names the Rust library and cargo targets, so only the two
    # functions that lay out the .deb are renamed.
    p = Path("build.py")
    s = p.read_text(encoding="utf-8")
    for fn in ["generate_control_file", "build_flutter_deb"]:
        m = re.search(rf"(?s)^def {fn}\(.*?\n(?=\S)", s, re.M)
        if not m:
            sys.exit(f"rebrand: build.py: {fn} not found")
        body = rename_all(m.group(0)).replace("libkozysupport", "librustdesk")
        body = body.replace("Maintainer: kozysupport <info@kozysupport.com>", "Maintainer: KozyOps <support@kozyops.com>")
        body = body.replace("Homepage: https://kozysupport.com", "Homepage: https://kozyops.com")
        s = s[: m.start()] + body + s[m.end():]
    p.write_text(s, encoding="utf-8")


if __name__ == "__main__":
    targets = {"windows": windows, "macos": macos, "linux": linux}
    if len(sys.argv) != 2 or sys.argv[1] not in targets:
        sys.exit(__doc__)
    targets[sys.argv[1]]()
    print(f"rebrand: {sys.argv[1]} done")
