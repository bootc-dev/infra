# Tasks

Reusable task definitions for AI agents. See [AGENTS.md](../../AGENTS.md)
for how to execute these tasks.

Each `.md` file uses YAML frontmatter (`name`, `description`) followed
by markdown instructions — compatible with Claude Code skills and
OpenCode commands.

## Available Tasks

- **[perform-forge-review](perform-forge-review.md)** — Create AI-assisted code
  reviews on GitHub, GitLab, or Forgejo. Builds review comments in a local JSONL
  file for human inspection before submitting as a pending/draft review.
