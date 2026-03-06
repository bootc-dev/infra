# A devcontainer for work on bootc-dev projects

This is an image designed for the [devcontainer ecosystem](https://containers.dev/)
along with targeting the development of projects in this bootc-dev
organization, especially bootc.

## Components

- Rust, Go and C/C++ toolchains
- podman (for nested containers, see below)
- `nu`
- [jj (Jujutsu)](https://github.com/jj-vcs/jj) as a Git-compatible VCS frontend
- [bcvk](https://github.com/bootc-dev/bcvk/) to launch bootc VMs
- [tmt](https://tmt.readthedocs.io/) since bootc testing requires it
- [Kani](https://model-checking.github.io/kani/usage.html)

## Base images

There are two images:

- [ghcr.io/bootc-dev/devenv-debian](https://github.com/orgs/bootc-dev/packages/container/package/devenv-debian) which uses Debian sid as a base
- [ghcr.io/bootc-dev/devenv-c10s](https://github.com/orgs/bootc-dev/packages/container/package/devenv-c10s) which uses CentOS Stream 10 as a base

## Nested container support

This image supports running `podman` and `podman build` inside the container
(podman-in-podman). The [userns-setup](userns-setup) script configures the environment at
container startup, handling both constrained (Codespaces, rootless) and full UID namespaces.

Note that in order to enable this you will also need to pair it with
a [devcontainer JSON](../common/.devcontainer/devcontainer.json).

## Building locally

See the `Justfile`, but it's just a thin wrapper around a default
of `podman build` of this directory.
