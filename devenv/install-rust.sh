#!/bin/bash
# Install Rust system-wide into /usr/local
# This script is shared between c10s and debian container builds.
set -xeuo pipefail

export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo

# Install Rust system-wide
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default

# Move binaries to /usr/local/bin (system-managed, root-owned)
mv /usr/local/cargo/bin/* /usr/local/bin/

# Recreate bin directory with symlink to rustup - rustup's self-update check
# looks for itself at $CARGO_HOME/bin/rustup
mkdir -p /usr/local/cargo/bin
ln -sf /usr/local/bin/rustup /usr/local/cargo/bin/rustup
