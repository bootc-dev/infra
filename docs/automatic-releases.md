# Proposal: release PRs for bootc-dev

This is research and a draft design for a reusable workflow in
[bootc-dev/actions](https://github.com/bootc-dev/actions), not a release workflow
installed in this repository. No release is automated by this document.
The goal is to make a pending release visible as a **draft pull request**:
maintainers edit its description as release notes, and merging it publishes
the release. Repositories can still supply their own build and version-bump
steps.

## What other projects do

| Project / approach | Notes and release trigger | Fit for this proposal |
| --- | --- | --- |
| [bootc's release workflow](https://github.com/bootc-dev/bootc/blob/main/.github/workflows/release.yml) | A merged PR labeled `release` triggers a signed tag, a draft GitHub release and asset uploads. Its release body initially contains placeholder notes; publication is a separate step. | Reuse the PR gate and asset preparation, but make the reviewed PR description the notes and publish after uploading assets. |
| [release-please](https://github.com/googleapis/release-please), used by CNCF [Prometheus Java client](https://github.com/prometheus/client_java/blob/main/.github/workflows/release-please.yml) and [OpenTelemetry JS Contrib](https://github.com/open-telemetry/opentelemetry-js-contrib/blob/main/.github/workflows/release-please.yml) | Keeps a release PR up to date from conventional commits; merging updates version files and a changelog, then tags and creates a GitHub release. It [parses notes from the merged PR body](https://github.com/googleapis/release-please/blob/main/src/util/pull-request-body.ts) and can [open draft PRs](https://github.com/googleapis/release-please/blob/main/docs/customizing.md#opening-as-a-draft-pull-request). | Closest precedent for a visible merge-to-release gate and PR-body-derived notes, but also maintains generated changelog/version files. |
| [semantic-release](https://github.com/semantic-release/semantic-release) | Computes versions and notes from commits and publishes from CI on the release branch. | Useful automation, but no explicit release-approval PR. |
| [Kubernetes](https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG) (CNCF) | Keeps versioned changelogs in the source tree. | Shows the in-repo notes alternative; not the desired PR-body approach. |
| [OpenSSF Scorecard](https://github.com/ossf/scorecard/blob/main/RELEASE.md) | A release manager drafts and edits notes in a GitHub draft release, signs a tag and publishes the release; its release procedure calls for validating artifacts and provenance. | Closest precedent for editable notes without a changelog file, but the review surface is a release draft rather than a PR and publication is manual. |
| [systemd NEWS](https://github.com/systemd/systemd/blob/main/NEWS) and [curl release procedure](https://github.com/curl/curl/blob/master/docs/RELEASE-PROCEDURE.md) | Maintain notes in source (`NEWS` or `RELEASE-NOTES`); curl's procedure includes a signed tag and release tarballs. | Demonstrates human-curated notes, but not a common GitHub PR-to-release workflow. |

[GitHub-generated release notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes)
can seed the PR description (merged PRs, contributors, changelog link, configurable
categories). Generate them **before** the review, not again on publish: otherwise
maintainers' edits would be lost. Do not copy the whole PR description blindly if
it contains automation metadata; define a dedicated notes section or keep the
entire description as notes, with version and workflow metadata in labels/title.

## Immutable releases are a prerequisite

[GitHub's immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)
lock the published release's tag and assets and generate a release attestation.
They **do not** lock the title or notes. GitHub recommends creating a draft
release, uploading all assets, then publishing it. Immutability must be
[enabled for each repository or enforced at organization level](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes);
it only applies to releases published after it is enabled. This should replace
the custom GitHub-stored GPG tag key as the default *release integrity* mechanism
where consumers use GitHub releases and verify their attestations; projects
requiring independently verifiable GPG signatures may still need them.

**Fail closed before creating any tag or publishing:** the eventual implementation
must establish that immutability is enabled for the target repository, including
inherited organization policy. A published release's
[`immutable` field](https://docs.github.com/en/rest/releases/releases) can verify
the outcome, but a prior release does not prove that the *next* release will
be immutable. The documented [repository](https://docs.github.com/en/rest/repos/repos#get-a-repository)
and release REST response schemas do not expose a prospective repository
setting; validate a supported settings API with the required permissions before
implementing this gate. If that cannot be done, do not automate publication
until a reliable, fail-closed check is available.
Never interpret a missing field or a failed permissions check as "enabled".

## Draft PR for bootc-dev/actions

**Proposed title:** Add a reusable draft-PR-to-immutable-release workflow

**Proposed PR description:**

> Open or update one draft release PR for unreleased changes. Put generated
> release notes in its description so maintainers can review and edit them.
> Once a maintainer marks it ready and merges it, create a draft GitHub release
> targeting the merged commit, attach project-supplied assets, then publish
> using the PR's final notes. Refuse to release unless immutable releases are
> enabled, and verify the published release is immutable.
>
> The common workflow owns PR lifecycle, notes transfer, and release safety;
> each caller owns version selection, version-file changes and asset builds.
> Roll out to bcvk and bootc first, then other repositories after validation.

Implementation contract to review in that PR:

1. A scheduled or manually dispatched workflow in each caller (or a central
   dispatcher with an authorized GitHub App) requests a draft release PR from a
   pinned reusable workflow. Only one PR per repository/version; update its
   branch and regenerated draft notes only if human edits will not be overwritten
   (for example, compare the last bot-generated body before replacing it).
   Check immutability enablement here too, to avoid opening a doomed PR.
   Avoid an empty release: skip if there are no unreleased changes. Expose a
   manual override for versioning rather than prescribing SemVer for every repo.
2. The PR contains the proposed version and optional repository-specific version
   bumps; its body contains editable notes. Require normal branch protection and
   review, including dismissing approvals after new commits. Document who may
   change its version/notes and avoid publishing notes
   from an untrusted fork PR or arbitrary PR with a `release` label.
3. On a merged release PR, fetch the PR via the GitHub API using its number,
   verify its provenance (trusted head repository/branch and expected release
   marker), target branch, version and nonempty final notes. Do not use
   `pull_request_target` to execute checkout code from an untrusted PR. Use a
   data-safe API input for the body, never interpolate PR text into a shell
   script. Use a GitHub App token if PR creation must trigger ordinary PR checks; events
   created by `GITHUB_TOKEN` have [special trigger behavior](https://docs.github.com/en/actions/concepts/security/github_token#when-github_token-triggers-workflow-runs).
4. Recheck immutability immediately before publication; reject an existing or
   moved version tag/release rather than retargeting it. Use the actual merged
   default-branch commit SHA, not a stale draft-branch SHA, for the release tag.
   Make retries idempotent and surface partial failures for manual recovery.
5. Create a draft release with the final PR notes and tag, build and attach
   every required asset, then publish. After publication check `immutable` on
   that release and report its attestation. A failed post-publication verification
   is a security incident, not a way to undo publication. Do not publish partial
   asset sets.
   Release consumers should verify the attestation instead of trusting an
   unauthenticated artifact download.

This design deliberately leaves the settings-gate API, version policy, asset
interface and permissions to be validated in the **actions** implementation PR;
there is no safe cross-repository release workflow to enable here yet.
