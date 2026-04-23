#!/usr/bin/env python3
"""Install simple cargo tools listed in cargo-tools.txt.

Reads crate names and versions from cargo-tools.txt, installs each via
``cargo install --locked``, moves the resulting binaries to /usr/local/bin,
and cleans up cargo registry/build artifacts.

This script is shared between c10s, debian, and ubuntu container builds.
Prerequisites: rustup and a C linker (gcc) must already be installed.

For tools with special requirements (e.g. kani-verifier which needs
a setup step and its own KANI_HOME), use a dedicated install script instead.
"""

import os
import re
import subprocess
import sys
from pathlib import Path

CARGO_HOME = Path("/usr/local/cargo")
INSTALL_DIR = Path("/usr/local/bin")

# Version strings must be alphanumeric with dots, hyphens, and an optional
# leading 'v'.  This rejects path traversal sequences and other surprises.
_VERSION_RE = re.compile(r"^v?[A-Za-z0-9]+(?:[.\-][A-Za-z0-9]+)*$")


def parse_cargo_tools(path: Path) -> list[tuple[str, str]]:
    """Parse cargo-tools.txt, returning [(crate, version)] in order."""
    tools = []
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "@" not in line:
            print(f"warning: skipping malformed line: {line}", file=sys.stderr)
            continue
        crate, version = line.split("@", 1)
        if not _VERSION_RE.match(version):
            print(
                f"error: {path}:{lineno}: invalid version string: {version!r}",
                file=sys.stderr,
            )
            sys.exit(1)
        tools.append((crate, version))
    return tools


def install_crate(crate: str, version: str) -> None:
    """Install a single crate via cargo install."""
    print(f"installing {crate}@{version}")
    subprocess.run(
        [
            "/bin/time", "-f", "%E %C",
            "cargo", "install", "--locked", crate, "--version", version,
        ],
        check=True,
    )


def collect_binaries() -> None:
    """Move cargo-installed binaries to INSTALL_DIR.

    Skips rustup-managed symlinks (cargo, rustc, rustup, etc.) which
    are symlinks in CARGO_HOME/bin.
    """
    cargo_bin = CARGO_HOME / "bin"
    for entry in sorted(cargo_bin.iterdir()):
        if entry.is_symlink():
            continue
        if not entry.is_file():
            continue
        dst = INSTALL_DIR / entry.name
        entry.rename(dst)
        print(f"installed {dst}")


def cleanup() -> None:
    """Remove cargo registry and build artifacts."""
    import shutil

    for subdir in ("registry", "git"):
        p = CARGO_HOME / subdir
        if p.exists():
            shutil.rmtree(p)
            print(f"cleaned {p}")


def main() -> None:
    os.environ["RUSTUP_HOME"] = "/usr/local/rustup"
    os.environ["CARGO_HOME"] = str(CARGO_HOME)
    # Ensure cargo and rustc are on PATH
    path = os.environ.get("PATH", "")
    os.environ["PATH"] = f"/usr/local/bin:{path}"

    script_dir = Path(__file__).parent
    tools_file = script_dir / "cargo-tools.txt"
    tools = parse_cargo_tools(tools_file)

    if not tools:
        print("error: no tools found in cargo-tools.txt", file=sys.stderr)
        sys.exit(1)

    for crate, version in tools:
        install_crate(crate, version)

    collect_binaries()
    cleanup()


if __name__ == "__main__":
    main()
