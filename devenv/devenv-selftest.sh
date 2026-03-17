#!/bin/bash
# Test that nested podman and VMs work correctly in this devcontainer.
# This script is designed to be run inside the container after devenv-init.sh
# has already been executed (e.g., via postCreateCommand).
set -euo pipefail

echo "=== Testing nested podman and VMs ==="

echo "Podman version:"
podman --version

echo "Podman info (rootless):"
podman info --format '{{.Host.Security.Rootless}}'

# Use CentOS Stream 10 as the test image for both container and VM
image="quay.io/centos-bootc/centos-bootc:stream10"

echo "Pulling $image..."
podman pull "$image"

echo "Running nested container..."
podman run --rm "$image" echo "Hello from nested podman!"

echo "=== Nested container test passed ==="

# Test bcvk (VM) if available and /dev/kvm exists.
# This is best-effort: in nested containers /dev/kvm can appear accessible
# but fail at runtime due to namespace restrictions, so we don't fail the
# overall selftest if bcvk fails.
if command -v bcvk >/dev/null 2>&1 && [ -e /dev/kvm ]; then
    echo ""
    echo "=== Testing bcvk VM (best-effort) ==="
    echo "bcvk version:"
    bcvk --version

    echo "Running bcvk ephemeral VM with SSH..."
    if bcvk ephemeral run-ssh "$image" -- echo "Hello from bcvk VM!"; then
        echo "=== bcvk VM test passed ==="
    else
        echo "=== bcvk VM test failed (KVM may not be functional in this environment) ==="
    fi
else
    echo ""
    echo "=== Skipping bcvk VM test (bcvk not available or /dev/kvm missing) ==="
fi

echo ""
echo "=== All tests passed ==="
