#!/bin/bash
# Fetch architecture-independent binary tools into /usr/local/bin
# This script is shared between c10s and debian container builds.
set -xeuo pipefail

# Required environment variables (passed as build ARGs)
: "${bcvkversion:?bcvkversion is required}"
: "${scorecardversion:?scorecardversion is required}"

arch=$(arch)

rm -vrf /usr/local/bin/*

# bcvk
if test "${arch}" = x86_64; then
  td=$(mktemp -d)
  (
    cd $td
    target=bcvk-${arch}-unknown-linux-gnu
    /bin/time -f '%E %C' curl -fLO https://github.com/bootc-dev/bcvk/releases/download/$bcvkversion/${target}.tar.gz
    tar xvzf $target.tar.gz
    mv $target /usr/local/bin/bcvk
  )
  rm -rf $td
else
  echo bcvk unavailable for $arch
fi

# scorecard (OpenSSF security scanner)
td=$(mktemp -d)
(
  cd $td
  # Map arch to scorecard naming convention
  case "${arch}" in
    x86_64) scarch=amd64 ;;
    aarch64) scarch=arm64 ;;
    *) echo "scorecard unavailable for $arch"; exit 0 ;;
  esac
  target=scorecard_${scorecardversion#v}_linux_${scarch}.tar.gz
  /bin/time -f '%E %C' curl -fLO https://github.com/ossf/scorecard/releases/download/$scorecardversion/$target
  tar xvzf $target
  mv scorecard /usr/local/bin/scorecard
)
rm -rf $td
