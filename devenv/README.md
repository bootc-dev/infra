# A devcontainer for work on bootc-org projects

This container image is suitable for use on
developing projects in the bootc-dev organization,
especially bootc.

It includes all tools used in the Justfile
for relevant projects.

## Base image

At the current time the default is using Debian sid, mainly because
other parts of the upstream use CentOS Stream as a *target system*
base, but this helps prove out the general case of "src != target"
that is a philosophy of bootc (and containers in general)
as well as just helping prepare/motivate for bootc-on-Debian.

## Nested container support

This image supports running `podman` and `podman build` inside the container
(podman-in-podman). The `userns-setup` script configures the environment at
container startup.

### Reference: quay.io/podman/stable

Our nested container configuration is based on the official
[quay.io/podman/stable](https://github.com/containers/image_build/tree/main/podman)
image. Key differences:

| Feature | quay.io/podman/stable | bootc-devenv |
|---------|----------------------|--------------|
| **default_sysctls** | `[]` | `[]` |
| **cgroups** | `"disabled"` | `"disabled"` (constrained) / `"no-conmon"` (full) |
| **cgroup_manager** | `"cgroupfs"` | `"cgroupfs"` |
| **netns/userns/ipcns/utsns/cgroupns** | `"host"` for all | `utsns = "host"` (constrained only) |
| **BUILDAH_ISOLATION** | `chroot` (env var) | Not set (uses OCI default) |
| **subuid/subgid** | Hardcoded for `podman` user | Dynamically calculated based on available UID range |
| **storage** | Modified storage.conf for fuse-overlayfs | VOLUME mounts avoid overlay-on-overlay |

### Constrained vs full UID namespace

The `userns-setup` script detects whether we're running in a constrained UID
namespace (typical for rootless podman, GitHub Codespaces, etc.) and adjusts:

- **Full namespace** (>100k UIDs): Uses default subuid/subgid, `cgroups = "no-conmon"`
- **Constrained namespace** (<100k UIDs): Dynamically calculates subuid/subgid
  ranges, uses `cgroups = "disabled"` and `utsns = "host"`

## Building locally

See the `Justfile`, but it's just a thin wrapper around a default
of `podman build` of this directory.
