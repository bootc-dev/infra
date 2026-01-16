# Standard Operating Procedure: New Repository Setup

This document describes the steps required when creating a new repository in the
bootc-dev organization.

## 1. Add the Maintainers Team

All repositories should grant the `maintainers` team **Maintain** permission.
This provides consistent access for organization maintainers across all repos.

To add the team via `gh`:

```sh
gh api -X PUT repos/bootc-dev/<REPO_NAME>/teams/maintainers \
  -f permission=maintain
```

Or via the GitHub web UI:
1. Go to the repository Settings
2. Navigate to Collaborators and teams
3. Click "Add teams"
4. Search for "maintainers"
5. Select "Maintain" as the role

## 2. Configure Renovate

The organization uses a centralized Renovate configuration managed from this
repository. To enable Renovate on a new repository, create a `renovate.json`
file in the repository root:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>bootc-dev/infra:renovate-shared-config.json"
  ]
}
```

This inherits all shared configuration including:
- Recommended base config with signed-off commits
- GitHub Actions, Rust, Docker, and npm dependency detection
- Dependency grouping by ecosystem
- Custom managers for Containerfiles and txt files
- Disabled Fedora OCI updates and digest pinning

### Repository-Specific Overrides

If synced workflow files are used (rebase.yml, openssf-scorecard.yml, etc.),
add the repository to the `ignorePaths` rule in
[renovate-shared-config.json](renovate-shared-config.json) to avoid
conflicting updates.

## 3. Post-Setup Verification

After setup, verify:
- [ ] `maintainers` team appears in Settings > Collaborators and teams with Maintain role
- [ ] `renovate.json` exists and passes validation
- [ ] Renovate creates initial dependency update PRs (may take up to 24h or trigger manually)

To manually trigger Renovate, run the workflow from the
[Actions tab](https://github.com/bootc-dev/infra/actions/workflows/renovate.yml)
in this repository.
