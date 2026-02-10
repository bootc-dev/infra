#!/bin/bash
# Initialize development environment
set -euo pipefail

# Set up podman for nested containers
python3 /usr/lib/devenv/userns-setup "$@"
