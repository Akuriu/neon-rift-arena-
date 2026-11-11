#!/usr/bin/env python3
"""Read the Godot version and check metadata required for distribution."""

import argparse
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
ANDROID_PACKAGE = "com.riflearena.alpha"


def setting(text, name):
    match = re.search(r"^" + re.escape(name) + r'=(?:"([^"]+)"|(\d+))$', text, re.M)
    if not match:
        raise ValueError(f"Paramètre absent ou invalide : {name}")
    return match[1] or match[2]


def versions():
    version = setting((ROOT / "project.godot").read_text(encoding="utf-8"), "config/version")
    match = re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)-alpha", version)
    if not match:
        raise ValueError(f"Version Alpha invalide : {version}")
    major, minor, patch = map(int, match.groups())
    label = f"v{major}.{minor}.{patch} Alpha"
    tag = f"v{version}"
    presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    expected = {
        "application/file_version": f"{major}.{minor}.{patch}.0",
        "application/product_version": f"{major}.{minor}.{patch}.0",
        "version/name": version,
        "version/code": str(major * 1000000 + minor * 1000 + patch),
        "package/unique_name": ANDROID_PACKAGE,
    }
    for key, value in expected.items():
        if setting(presets, key) != value:
            raise ValueError(f"{key} doit valoir {value}")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    if label not in readme or f"## {tag}\n" not in changelog:
        raise ValueError(f"README ou CHANGELOG non aligné sur {tag}")
    previous = f"v{major}.{minor}.{patch - 1}-alpha" if patch else ""
    return {"version": version, "label": label, "tag": tag, "package": ANDROID_PACKAGE, "previous": previous}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--field", choices=["version", "label", "tag", "package", "previous"], default="tag")
    parser.add_argument("--tag")
    args = parser.parse_args()
    try:
        info = versions()
        if args.tag is not None and args.tag != info["tag"]:
            raise ValueError(f"Le tag {args.tag} doit correspondre à {info['tag']}")
        print(info[args.field])
    except ValueError as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
