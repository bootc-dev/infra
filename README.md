# CI Infrastructure

This repository provides centralised configuration and automation for the [bootc-dev](https://github.com/bootc-dev) organisation. It is designed to simplify and standardise infrastructure, with Renovate as one part of the overall setup. The repository will grow to support additional infrastructure and automation purposes in the future as needed.


## Table of Contents

- [Purpose](#purpose)
- [Development Environment](#development-environment)
- [Container Image Management](#container-image-management)
- [Renovate](#renovate)
- [Getting Started](#getting-started)
- [Support & Contributions](#support--contributions)
- [License](#license)

---

## Purpose

The main goal of this repository is to:

- **Centralise configuration** for CI and automation tools across the organisation.
- **Simplify onboarding** for new repositories and maintainers.
- **Enable strict configuration inheritance** for consistency, with flexibility for overrides.
- **Group and manage dependencies and automation** for easier review and maintenance.

---

## Development Environment

Containerized development environment with necessary tools and dependencies.

```bash
just devenv-build              # Build locally
just devenv-build-tagged       # Build with proper tags
just devenv-push               # Build and push to registry
```

Images are tagged with `:latest` (main branch only), `:branch-shortsha`, and `:branch-longsha` for traceability.

---

## Container Garbage Collection

Automated cleanup of old container images from GitHub Container Registry. Written in Rust using the xtask pattern.

```bash
just container-gc-dry-run      # Preview deletions
just container-gc              # Delete images older than 14 days
just container-gc-custom 30    # Custom retention period
```

Or with full options:
```bash
cargo xtask container-gc --retention-days 30 --org bootc-dev --dry-run false
```

Runs automatically every Sunday at 2 AM UTC. Can be triggered manually:
```bash
gh workflow run container-gc.yml -f retention-days=30 -f dry-run=true
```

See `crates/xtask/` for implementation details.

---

## Development

### Building

```bash
cargo build --release
```

### Testing

```bash
cargo test
cargo clippy --all-targets -- -D warnings
cargo fmt --all -- --check
```

### CI

Continuous integration runs on all PRs and pushes to main, validating:
- Code formatting with rustfmt
- Linting with clippy
- Build in release mode
- All tests pass

---


## Renovate

This section describes how Renovate Bot is configured and used in this repository to manage dependency updates across multiple repositories in the organisation.

### How It Works

1. **Autodiscovery**: Renovate is configured to automatically find all repositories the GitHub App token has access to.
1. **Shared Configuration**: The `renovate-shared-config.json` file defines base rules, grouping strategies, and custom package rules. All repositories inherit these settings unless they opt out.
1. **No Onboarding PRs**: Onboarding PRs are disabled, so repositories start using the shared config immediately.
1. **Branch Naming**: All Renovate branches are prefixed for easy identification.
1. **Platform Support**: The configuration is tailored for GitHub, with support for forked repositories and platform-specific features.

#### For Repository Maintainers

If your repository is part of the bootc-dev GitHub organisation:

1. **Inherit the central config**: By default, your repository will use the shared configuration from this repo. No additional setup is required unless you want to override specific settings.
1. **Customise if needed**: You can add your own `renovate.json` or similar config file in your repository to override or extend the shared settings.
1. **Review dependency PRs**: Renovate will create PRs for dependency updates according to the shared rules, grouping, and strategies defined here.

#### For Organisation Admins

- **Update shared config**: To change organisation-wide Renovate behaviour, edit the configuration files in this repository. Changes will propagate to all inheriting repositories.
- **Monitor and audit**: Use the central config to ensure compliance and best practices across all projects.

### Manually Running Renovate

You can manually trigger the Renovate workflow from the GitHub Actions tab:

1. Go to the **Actions** tab in this repository.
2. Select the **Renovate** workflow.
3. Click **Run workflow**.
4. Optionally, set the log level (`info` or `debug`) before starting.

This is useful for testing configuration changes or running Renovate outside the scheduled times.

#### Key Features

- **Best-practices base config**: Extends Renovate's recommended settings for reliability and security.
- **Commit sign-off**: Ensures all dependency update commits are signed off for traceability.
- **Dependency grouping**: Groups updates for GitHub Actions, Rust, Docker, and more for easier review.
- **Custom rules**: Includes rules for disabling certain updates (e.g., Fedora OCI images) and controlling digest pinning.

---

## Getting Started

1. Ensure your repository is part of the organisation and Renovate is installed.
1. Review the [Renovate documentation](https://docs.renovatebot.com/) for advanced usage and customisation options.

---

## Support & Contributions

For questions or improvements, open an issue or pull request in this repository. Contributions to the shared configuration are welcome and help improve dependency management for all projects in the organisation.

---

## License

MIT OR Apache-2.0
