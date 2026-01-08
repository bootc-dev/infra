# Skills

Reusable skill definitions for AI agents using the
[Agent Skills](https://agentskills.io/) format.

Each skill is a directory containing a `SKILL.md` file with YAML frontmatter
(`name`, `description`) followed by markdown instructions. Skills may also
include `scripts/`, `references/`, and `assets/` subdirectories.

## Available Skills

- **[perform-forge-review](perform-forge-review/SKILL.md)** — Create AI-assisted
  code reviews on GitHub, GitLab, or Forgejo. Builds review comments in a local
  JSONL file for human inspection before submitting as a pending/draft review.
