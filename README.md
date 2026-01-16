# CI Infrastructure

This repository provides centralized configuration and automation for the
[bootc-dev](https://github.com/bootc-dev) organization.

## What's Here

- **[Development Environment](devenv/README.md)** - Containerized dev environment with
  necessary tools
- **[Renovate](#renovate)** - Centralized dependency update management
- **Container Garbage Collection** - Automated cleanup of old images from GHCR

## Renovate

Renovate runs centrally from this repository using autodiscovery. All org repositories
automatically inherit the shared configuration from `renovate-shared-config.json`.

Key features of the shared config:
- Signed-off commits for all dependency updates
- Grouped updates by ecosystem (GitHub Actions, Rust, Docker, npm)
- Custom regex managers for Containerfiles and version files
- Disabled digest pinning for container images

### For Repository Maintainers

Add a `renovate.json` to your repository to inherit the shared config:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["local>bootc-dev/infra:renovate-shared-config.json"]
}
```

Override or extend settings as needed for your repository.

### Manual Runs

Trigger Renovate manually from the [Actions tab](../../actions/workflows/renovate.yml)
with optional debug logging.

## License

MIT OR Apache-2.0
