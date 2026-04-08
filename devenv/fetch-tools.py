#!/usr/bin/env python3
"""Fetch pre-built binary tools into /usr/local/bin.

Reads tool names and versions from tool-versions.txt, downloads the
appropriate architecture-specific release archive from GitHub, and
extracts the binary into /usr/local/bin.

This script is shared between c10s and debian container builds.
"""

import platform
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

INSTALL_DIR = Path("/usr/local/bin")


@dataclass
class Tool:
    """Download specification for a single tool."""

    # GitHub owner/repo (e.g. "jj-vcs/jj")
    repo: str
    # Map from uname machine string to the arch token used in release filenames.
    # Missing arch means the tool is unavailable on that platform.
    arch_map: dict[str, str]
    # Format string for the release tag, given {version}.
    tag_fmt: str
    # Format string for the tarball filename, given {version} and {arch}.
    tarball_fmt: str
    # Path to the binary inside the extracted archive, given {version} and {arch}.
    # Relative to the extraction directory.
    binary_path_fmt: str
    # Name of the installed binary in /usr/local/bin.
    binary_name: str


TOOLS: dict[str, Tool] = {
    "bcvk": Tool(
        repo="bootc-dev/bcvk",
        arch_map={"x86_64": "x86_64"},  # x86_64 only
        tag_fmt="{version}",  # version already includes 'v' prefix
        tarball_fmt="bcvk-{arch}-unknown-linux-gnu.tar.gz",
        binary_path_fmt="bcvk-{arch}-unknown-linux-gnu",
        binary_name="bcvk",
    ),
    "scorecard": Tool(
        repo="ossf/scorecard",
        arch_map={"x86_64": "amd64", "aarch64": "arm64"},
        tag_fmt="{version}",  # version already includes 'v' prefix
        tarball_fmt="scorecard_{version_bare}_linux_{arch}.tar.gz",
        binary_path_fmt="scorecard",
        binary_name="scorecard",
    ),
    "nushell": Tool(
        repo="nushell/nushell",
        arch_map={"x86_64": "x86_64", "aarch64": "aarch64"},
        tag_fmt="{version}",  # no 'v' prefix
        tarball_fmt="nu-{version}-{arch}-unknown-linux-gnu.tar.gz",
        binary_path_fmt="nu-{version}-{arch}-unknown-linux-gnu/nu",
        binary_name="nu",
    ),
    "jj": Tool(
        repo="jj-vcs/jj",
        arch_map={"x86_64": "x86_64", "aarch64": "aarch64"},
        tag_fmt="v{version}",  # add 'v' prefix
        tarball_fmt="jj-v{version}-{arch}-unknown-linux-musl.tar.gz",
        binary_path_fmt="jj",
        binary_name="jj",
    ),
    "cargo-nextest": Tool(
        repo="nextest-rs/nextest",
        arch_map={"x86_64": "x86_64", "aarch64": "aarch64"},
        tag_fmt="cargo-nextest-{version}",
        tarball_fmt="cargo-nextest-{version}-{arch}-unknown-linux-gnu.tar.gz",
        binary_path_fmt="cargo-nextest",
        binary_name="cargo-nextest",
    ),
}


# Version strings must be alphanumeric with dots, hyphens, and an optional
# leading 'v'.  This rejects path traversal sequences and other surprises.
_VERSION_RE = re.compile(r"^v?[A-Za-z0-9]+(?:[.\-][A-Za-z0-9]+)*$")


def parse_tool_versions(path: Path) -> dict[str, str]:
    """Parse tool-versions.txt, returning {name: version}."""
    versions = {}
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "@" not in line:
            print(f"warning: skipping malformed line: {line}", file=sys.stderr)
            continue
        name, version = line.split("@", 1)
        if not _VERSION_RE.match(version):
            print(
                f"error: {path}:{lineno}: invalid version string: {version!r}",
                file=sys.stderr,
            )
            sys.exit(1)
        versions[name] = version
    return versions


def fetch_tool(name: str, version: str, arch: str) -> None:
    """Download and install a single tool."""
    tool = TOOLS[name]

    mapped_arch = tool.arch_map.get(arch)
    if mapped_arch is None:
        print(f"{name} unavailable for {arch}")
        return

    tag = tool.tag_fmt.format(version=version)
    # version_bare strips a leading 'v' for tools like scorecard that use
    # it in the tarball name but not in the tag
    version_bare = version.lstrip("v")
    fmt_vars = {"version": version, "version_bare": version_bare, "arch": mapped_arch}

    tarball = tool.tarball_fmt.format(**fmt_vars)
    url = f"https://github.com/{tool.repo}/releases/download/{tag}/{tarball}"
    binary_path = tool.binary_path_fmt.format(**fmt_vars)

    with tempfile.TemporaryDirectory() as td:
        subprocess.run(
            ["curl", "-fLO", url],
            cwd=td,
            check=True,
        )
        subprocess.run(
            ["tar", "xzf", tarball],
            cwd=td,
            check=True,
        )
        src = Path(td) / binary_path
        dst = INSTALL_DIR / tool.binary_name
        dst.write_bytes(src.read_bytes())
        dst.chmod(0o755)
        print(f"installed {dst}")


def main() -> None:
    script_dir = Path(__file__).parent
    versions_file = script_dir / "tool-versions.txt"
    versions = parse_tool_versions(versions_file)

    arch = platform.machine()
    print(f"arch: {arch}")

    # Clear out old versions of tools managed by this script
    for tool in TOOLS.values():
        path = INSTALL_DIR / tool.binary_name
        if path.is_file():
            path.unlink()
            print(f"removed {path}")

    unknown = set(versions) - set(TOOLS)
    if unknown:
        print(f"error: unknown tools in tool-versions.txt: {unknown}", file=sys.stderr)
        sys.exit(1)

    for name in TOOLS:
        if name not in versions:
            print(
                f"error: {name} defined in TOOLS but missing from tool-versions.txt",
                file=sys.stderr,
            )
            sys.exit(1)
        fetch_tool(name, versions[name], arch)


if __name__ == "__main__":
    main()
