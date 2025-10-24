#!/bin/bash
set -euo pipefail
# Set things up so that podman can run nested inside the privileged
# docker container of a codespace.

if test "${CODESPACES:-}" != "true"; then
    exit 0
fi
echo "Detected codespace, initializing"

# First, ensure that /var/lib/containers (storage) is on the persistent
# mounted volume, not overlay so we don't have overlay-on-overlay issues.
# Confusingly in codespaces, /tmp is a (large) persistent volume instead of
# it being at /var/tmp as one might expect.
mkdir -p -m 0700 /tmp/containers-storage
rm -rf /var/lib/containers && ln -sr /tmp/containers-storage /var/lib/containers

# Handle nested cgroups
sed -i -e 's,^#cgroups =.*,cgroups = "no-conmon",' /usr/share/containers/containers.conf
sed -i -e 's,^#cgroup_manager =.*,cgroup_manager = "cgroupfs",' /usr/share/containers/containers.conf
