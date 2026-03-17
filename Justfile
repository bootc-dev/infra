# Generate per-OS devcontainer.json from the default (debian) template
devcontainer-generate:
	#!/bin/bash
	set -euo pipefail
	template=common/.devcontainer/devcontainer.json
	for os in debian ubuntu; do
	  mkdir -p "common/.devcontainer/${os}"
	  sed -e "s/devenv-debian/devenv-${os}/g" "$template" > "common/.devcontainer/${os}/devcontainer.json"
	done

# Validate devcontainer.json syntax and that per-OS configs are in sync
devcontainer-validate:
	#!/bin/bash
	set -euo pipefail
	template=common/.devcontainer/devcontainer.json
	for os in debian ubuntu; do
	  if ! diff -u "common/.devcontainer/${os}/devcontainer.json" <(sed "s/devenv-debian/devenv-${os}/g" "$template"); then
	    echo "ERROR: common/.devcontainer/${os}/devcontainer.json is out of sync with template"
	    echo "Run 'just devcontainer-generate' to fix"
	    exit 1
	  fi
	done
	echo "All devcontainer configs are in sync"
	npx --yes @devcontainers/cli read-configuration --workspace-folder .

# Build devenv Debian image with local tag
devenv-build-debian:
	cd devenv && podman build --jobs=4 -f Containerfile.debian -t localhost/bootc-devenv-debian .

# Build devenv Ubuntu 24.04 image with local tag
devenv-build-ubuntu:
	cd devenv && podman build --jobs=4 -f Containerfile.ubuntu -t localhost/bootc-devenv-ubuntu .

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
	config=common/.devcontainer/{{os}}/devcontainer.json
	# Tag local image to match what devcontainer.json expects
	podman tag localhost/bootc-devenv-{{os}}:latest ghcr.io/bootc-dev/devenv-{{os}}:latest
	npx --yes @devcontainers/cli up \
	  --workspace-folder . \
	  --docker-path podman \
	  --config "$config" \
	  --remove-existing-container
	npx @devcontainers/cli exec \
	  --workspace-folder . \
	  --docker-path podman \
	  --config "$config" \
	  /usr/libexec/devenv-selftest.sh
