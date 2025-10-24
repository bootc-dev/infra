# Build devenv image with local tag
devenv-build:
	cd devenv && podman build --jobs=4 -t localhost/bootc-devenv .

# Build devenv image with proper tagging (latest + git SHA)
devenv-build-tagged:
	#!/usr/bin/env bash
	set -euo pipefail
	GIT_SHA=$(git rev-parse --short HEAD)
	GIT_SHA_LONG=$(git rev-parse HEAD)
	BRANCH=$(git rev-parse --abbrev-ref HEAD)
	IMAGE_BASE="ghcr.io/bootc-dev/devenv-debian"
	cd devenv
	# Build with multiple tags
	podman build \
		-t "${IMAGE_BASE}:latest" \
		-t "${IMAGE_BASE}:${BRANCH}-${GIT_SHA}" \
		-t "${IMAGE_BASE}:${BRANCH}-${GIT_SHA_LONG}" \
		.
	echo "Built and tagged:"
	echo "  - ${IMAGE_BASE}:latest"
	echo "  - ${IMAGE_BASE}:${BRANCH}-${GIT_SHA}"
	echo "  - ${IMAGE_BASE}:${BRANCH}-${GIT_SHA_LONG}"

# Push devenv image with all tags
devenv-push: devenv-build-tagged
	#!/usr/bin/env bash
	set -euo pipefail
	GIT_SHA=$(git rev-parse --short HEAD)
	GIT_SHA_LONG=$(git rev-parse HEAD)
	BRANCH=$(git rev-parse --abbrev-ref HEAD)
	IMAGE_BASE="ghcr.io/bootc-dev/devenv-debian"
	podman push "${IMAGE_BASE}:latest"
	podman push "${IMAGE_BASE}:${BRANCH}-${GIT_SHA}"
	podman push "${IMAGE_BASE}:${BRANCH}-${GIT_SHA_LONG}"
	echo "Pushed all tags to registry"

# Run container garbage collection (dry run by default)
container-gc-dry-run:
	cargo xtask container-gc --dry-run true --retention-days 14

# Run container garbage collection (actual deletion)
container-gc:
	cargo xtask container-gc --retention-days 14

# Run container garbage collection with custom retention period
container-gc-custom retention_days:
	cargo xtask container-gc --retention-days {{retention_days}}
