#!/bin/bash
set -euo pipefail
# Set things up so that podman can run nested inside the privileged
# docker container of a codespace or devpod.

# Fix the propagation - only needed in some environments (e.g., codespaces)
# In devpod with rootless podman, / may already have shared propagation
# or we may not have permission to remount it.
propagation=$(findmnt -J -o TARGET,PROPAGATION / | jq -r '.filesystems[0].propagation // "unknown"')
if [ "$propagation" = "private" ]; then
    if mount -o remount --make-shared / 2>/dev/null; then
        echo "Set / to shared propagation"
    else
        echo "Warning: Could not set / to shared propagation (may not be needed)"
    fi
fi

# This is actually safe to expose to all users really, like Fedora derivatives do
if [ -e /dev/kvm ]; then
    chmod a+rw /dev/kvm 2>/dev/null || true
fi

# Handle nested cgroups - update containers.conf if it exists and has the settings commented out
if [ -f /usr/share/containers/containers.conf ]; then
    sed -i -e 's,^#cgroups =.*,cgroups = "no-conmon",' -e 's,^#cgroup_manager =.*,cgroup_manager = "cgroupfs",' /usr/share/containers/containers.conf
fi
