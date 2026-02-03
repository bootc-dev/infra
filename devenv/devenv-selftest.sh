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

# Test new tools added to devenv
echo ""
echo "=== Testing additional devenv tools ==="

# Test nushell - should be available on all images
echo "Testing nushell..."
if ! command -v nu >/dev/null 2>&1; then
    echo "Error: nushell (nu) command not found" >&2
    exit 1
fi
echo "nushell version:"
nu --version
echo "nushell basic functionality test:"
echo 'print "Hello from nushell!"' | nu
echo "=== nushell test passed ==="

# Test tmt - available on both systems but installed differently
echo "Testing tmt..."
if ! command -v tmt >/dev/null 2>&1; then
    echo "Error: tmt command not found" >&2
    exit 1
fi
echo "tmt version:"
tmt --version
echo "tmt basic functionality test:"
# Create a minimal test directory with a working tmt setup
tmpdir=$(mktemp -d)
(
    cd "$tmpdir"
    # Create basic fmf metadata directory and file
    mkdir -p .fmf
    echo "1" > .fmf/version
    
    # Create a minimal test
    mkdir -p tests
    cat > tests/basic.fmf <<EOF
summary: Basic validation test
test: echo "tmt test validation passed"
duration: 5s
EOF
    
    # Create a minimal plan
    mkdir -p plans
    cat > plans/basic.fmf <<EOF
summary: Basic validation plan
discover:
    how: fmf
execute:
    how: local
EOF
    
    # Test tmt functionality
    echo "Testing tmt plan discovery..."
    tmt plan ls
    echo "Testing tmt test discovery..."
    tmt test ls
    echo "Basic tmt validation complete"
)
rm -rf "$tmpdir"
echo "=== tmt test passed ==="



echo ""
echo "=== All tests passed ==="
