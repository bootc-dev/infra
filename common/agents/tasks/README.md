# Tasks

Reusable task definitions for AI agents. See [AGENTS.md](../../AGENTS.md)
for how to execute these tasks.

Each `.md` file uses YAML frontmatter (`name`, `description`) followed
by markdown instructions — compatible with Claude Code skills and
OpenCode commands.

## Available Tasks

- **[diff-quiz](diff-quiz.md)** — Generate a quiz to verify human understanding
  of code changes. Helps ensure that developers using AI tools understand the
  code they're submitting. Supports easy, medium, and hard difficulty levels.

- **[perform-forge-review](perform-forge-review.md)** — Create AI-assisted code
  reviews on GitHub, GitLab, or Forgejo. Builds review comments in a local JSONL
  file for human inspection before submitting as a pending/draft review.
