# Container Garbage Collection

Automated cleanup tool for GitHub Container Registry images. Deletes old container images based on configurable retention policies while protecting important tags.

## Usage

### Prerequisites

- Rust toolchain
- GitHub CLI (`gh`) installed and authenticated: `gh auth login`
- Token must have `packages:write` permission

```bash
# Dry run (recommended first)
cargo xtask container-gc --dry-run true

# Delete images older than 14 days
cargo xtask container-gc

# Custom retention period
cargo xtask container-gc --retention-days 30

# All options
cargo xtask container-gc --retention-days 30 --org bootc-dev --dry-run false --protect-latest true
```

### Options

- `--retention-days` - Days to retain images (default: 14)
- `--dry-run` - Preview without deleting (default: false)
- `--org` - GitHub organization (default: bootc-dev)
- `--protect-latest` - Skip images tagged as 'latest' (default: true)

All options support environment variables: `RETENTION_DAYS`, `DRY_RUN`, `ORG`.

## GitHub Actions

Runs automatically every Sunday at 2 AM UTC. Manual trigger:

```bash
gh workflow run container-gc.yml -f retention-days=30 -f dry-run=true
```

## Implementation

Uses `xshell` to fork the `gh` CLI for GitHub API access. See module documentation in `src/container_gc.rs` for details.

### Limitations

- GitHub API rate limits apply (typically 5000 requests/hour for authenticated users)
- Deletions are permanent and cannot be undone
- No audit log beyond workflow logs

## License

MIT OR Apache-2.0

