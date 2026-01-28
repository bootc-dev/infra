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

# Test nested podman and VMs work in a devcontainer image
# Usage: just devcontainer-test <image>
# Example: just devcontainer-test ghcr.io/bootc-dev/devenv-debian:latest
# Note: Uses --privileged because Docker doesn't support podman's unmask=/proc/* option
devcontainer-test image:
	docker run --rm --privileged "{{ image }}" /usr/libexec/devenv-selftest.sh
