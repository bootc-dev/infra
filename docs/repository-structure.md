# Repository structure

The bootc-dev organization contains a number of repositories. While not every
repository will function in exactly in the same way, there are
"baseline" configuration and procedures that should generally apply.

## Maintainers

There should be a `maintainers` team with the **Maintain** permission
that is used by repositories by default.

## Renovate

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

## PR gating and merging

Each repository MUST enable the following settings via a branch protection rule for `main`:

- Require a pull request before merging
- Require approvals

### required-checks

Having some kind of CI is also required. Repositories SHOULD enable the automatic merge setting,
and configure at least one gating CI check.

The ["required-checks" pattern](https://github.com/bootc-dev/bootc/blob/main/.github/workflows/ci.yml)
is where the repository configuration gates solely on that check which in turn gates on others, allowing easy dynamic
reconfiguration of the required checks without requiring administrator intervention.

## Language

In this organization, Rust is preferred.

## Developer experience

Repositories SHOULD have a [Justfile](https://just.systems/) which acts as a development entry point. It
is strongly encouraged to follow the pattern in [bootc Justfile](https://github.com/bootc-dev/bootc/blob/main/Justfile)
where e.g. GitHub Actions mostly invoke `just <x>` so all CI flows are easily
replicable outside of GHA.

## Devcontainer

Repositories SHOULD have a `.devcontainer.json` (one is synchronized by default from this repo)
and key targets in the `Justfile` should run in that environment.

## Unit and integration tests

Any nontrivial code SHOULD have unit tests and integration tests. An integration test MUST
be a separately built artifact that tests a production build in a "black box" fashion.

### Integration test environments

Integration tests SHOULD be flexible and adaptable. In particular, there are multiple
"test suite runner environments" which our integration tests should work with.

- [Debian autopkgtest](https://wiki.debian.org/autopkgtest)
- [tmt](https://tmt.readthedocs.io/en/stable/) (and [Fedora CI](https://packit.dev/fedora-ci/))

Privileged and destructive tests should be clearly distinct.

At the current time, bootc has some "bridging" between a custom integration test suite
and tmt. However, a pattern used in other repositories is to have an integration test
binary written in Rust that uses `libtest-mimic` - in this pattern all tests are just
part of a simple single binary.

- [composefs-rs](https://github.com/composefs/composefs-rs/tree/main/crates/integration-tests)
- [bcvk](https://github.com/bootc-dev/bcvk/blob/main/Justfile)

### Future direction

Goal: Convert all repositories to a pattern like this, and create reliable bridging
between it and tmt and Debian autopkgtest. For example, support converting
the tests into the relevant framework format.
