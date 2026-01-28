# Validate devcontainer.json syntax
devcontainer-validate:
	npx --yes @devcontainers/cli read-configuration --workspace-folder .

# Build devenv Debian image with local tag
devenv-build-debian:
	cd devenv && podman build --jobs=4 -f Containerfile.debian -t localhost/bootc-devenv-debian .

# Build devenv CentOS Stream 10 image with local tag
devenv-build-c10s:
	cd devenv && podman build --jobs=4 -f Containerfile.c10s -t localhost/bootc-devenv-c10s .

# Build devenv image with local tag (defaults to Debian)
devenv-build: devenv-build-debian

# Test devcontainer with a locally built image
# Usage: just devcontainer-test <os>
# Example: just devcontainer-test debian
devcontainer-test os:
	#!/bin/bash
	set -euo pipefail
	cat > /tmp/devcontainer-override.json << 'EOF'
	{
	  "image": "localhost/bootc-devenv-{{os}}:latest",
	  "runArgs": [
	    "--security-opt", "label=disable",
	    "--security-opt", "unmask=/proc/*",
	    "--device", "/dev/net/tun",
	    "--device", "/dev/kvm"
	  ],
	  "postCreateCommand": {
	    "devenv-init": "sudo /usr/local/bin/devenv-init.sh"
	  }
	}
	EOF
	npx --yes @devcontainers/cli up --workspace-folder . --docker-path podman --override-config /tmp/devcontainer-override.json --remove-existing-container
	npx @devcontainers/cli exec --workspace-folder . --docker-path podman /usr/libexec/devenv-selftest.sh
