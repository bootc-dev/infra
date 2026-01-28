#!/bin/bash
# Test that nested podman and VMs work correctly in this devcontainer.
# This script is designed to be run inside the container after devenv-init.sh.
set -euo pipefail

echo "=== Testing nested podman and VMs ==="

echo "Running devenv-init.sh..."
sudo /usr/local/bin/devenv-init.sh

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

# Test bcvk (VM) if available and /dev/kvm exists
if command -v bcvk >/dev/null 2>&1 && [ -e /dev/kvm ]; then
    echo ""
    echo "=== Testing bcvk VM ==="
    echo "bcvk version:"
    bcvk --version
    
    echo "Running bcvk ephemeral VM with SSH..."
    bcvk ephemeral run-ssh "$image" -- echo "Hello from bcvk VM!"
    
    echo "=== bcvk VM test passed ==="
else
    echo ""
    echo "=== Skipping bcvk VM test (bcvk not available or /dev/kvm missing) ==="
fi

echo ""
echo "=== All tests passed ==="
