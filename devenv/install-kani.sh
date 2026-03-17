#!/bin/bash
# Install Kani formal verification tool
# This script is shared between c10s, debian, and ubuntu container builds.
# Prerequisites: rustup must already be installed (via install-rust.sh)
set -xeuo pipefail

# Required environment variable (passed as build ARG)
: "${kaniversion:?kaniversion is required}"

# Install gcc (required to compile Kani's C stubs)
if command -v dnf >/dev/null; then
    dnf install -y gcc && dnf clean all
elif command -v apt-get >/dev/null; then
    apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev && rm -rf /var/lib/apt/lists/*
else
    echo "error: unsupported package manager" >&2
    exit 1
fi

export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo
export PATH="/usr/local/bin:$PATH"

# Install Kani to a system-wide location so all users can access it
export KANI_HOME=/usr/local/kani

# Install kani-verifier
/bin/time -f '%E %C' cargo install --locked kani-verifier --version $kaniversion

# Run kani setup - downloads bundle and installs required nightly toolchain
/bin/time -f '%E %C' /usr/local/cargo/bin/cargo-kani setup

# Move kani binaries to /usr/local/bin, keep rustup symlink
mv /usr/local/cargo/bin/cargo-kani /usr/local/cargo/bin/kani /usr/local/bin/
