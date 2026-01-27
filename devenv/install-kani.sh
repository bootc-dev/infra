#!/bin/bash
# Install Kani formal verification tool
# This script is shared between c10s and debian container builds.
# Prerequisites: rustup must already be installed (via install-rust.sh)
set -xeuo pipefail

# Required environment variable (passed as build ARG)
: "${kaniversion:?kaniversion is required}"

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
