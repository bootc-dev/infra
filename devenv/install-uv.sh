#!/bin/bash
# Install uv system-wide into /usr/local
# This script is shared between c10s and debian container builds.
# Similar to rustup, we install the binary to /usr/local/bin and configure
# tools to be installed system-wide via environment variables.
set -xeuo pipefail

: "${uvversion:?uvversion is required}"

arch=$(arch)

# Map arch to uv naming convention
case "${arch}" in
  x86_64) uvarch=x86_64 ;;
  aarch64) uvarch=aarch64 ;;
  *) echo "uv unavailable for $arch"; exit 1 ;;
esac

target=uv-${uvarch}-unknown-linux-gnu.tar.gz

td=$(mktemp -d)
(
  cd $td
  /bin/time -f '%E %C' curl -fLO https://github.com/astral-sh/uv/releases/download/${uvversion}/$target
  tar xvzf $target
  # The extracted directory has the same name as the archive without .tar.gz
  extracted_dir=uv-${uvarch}-unknown-linux-gnu
  mv $extracted_dir/uv /usr/local/bin/uv
  mv $extracted_dir/uvx /usr/local/bin/uvx
)
rm -rf $td

# Verify installation
/usr/local/bin/uv --version
