#!/bin/bash
# Install Rust system-wide into /usr/local
# This script is shared between c10s and debian container builds.
set -xeuo pipefail

export RUSTUP_HOME=/usr/local/rustup
export CARGO_HOME=/usr/local/cargo

# Install Rust system-wide
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile default

# Install nightly toolchain if requested (pinned date, e.g. nightly-2026-03-02)
if [ -n "${rust_nightly:-}" ]; then
  /usr/local/cargo/bin/rustup toolchain install "${rust_nightly}" --profile minimal
  # Symlink the dated nightly as "nightly" so `cargo +nightly` works without
  # requiring write access to RUSTUP_HOME for channel updates.
  host=$(/usr/local/cargo/bin/rustc --print host-tuple)
  ln -sf "${rust_nightly}-${host}" "$RUSTUP_HOME/toolchains/nightly-${host}"
fi

# Move binaries to /usr/local/bin (system-managed, root-owned)
mv /usr/local/cargo/bin/* /usr/local/bin/

# Recreate bin directory with symlink to rustup - rustup's self-update check
# looks for itself at $CARGO_HOME/bin/rustup
mkdir -p /usr/local/cargo/bin
ln -sf /usr/local/bin/rustup /usr/local/cargo/bin/rustup
