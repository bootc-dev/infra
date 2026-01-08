---
name: perform-forge-review
description: Create AI-assisted code reviews on GitHub, GitLab, or Forgejo. Use when asked to review a PR/MR, analyze code changes, or provide review feedback.
---

# Perform Forge Review

Create code reviews on GitHub, GitLab, or Forgejo with human oversight.

## Workflow

Use `scripts/reviewtool` for all operations. It requires Python 3 with no
external dependencies.

### 1. Check out the PR

```bash
scripts/reviewtool checkout 123
```

This checks out the PR branch and shows the diff. For GitLab/Forgejo, set
the appropriate environment variables first.

### 2. Review the code

Read the files, understand the changes. Use `git diff` and `git log` as needed.

### 3. Build comments

Start a review, then add comments:

```bash
scripts/reviewtool start --pr 123 --body "Assisted-by: OpenCode (Claude Sonnet 4)

AI-generated review. Comments prefixed with AI: are unedited."

scripts/reviewtool add --pr 123 \
  --file src/lib.rs --line 42 --match "fn process_data" \
  --body "AI: *Important*: Missing error handling"
```

The `--match` flag validates the line content to prevent misplaced comments.

### 4. Submit

```bash
scripts/reviewtool submit --pr 123
```

The review is created as pending/draft. The human reviews in the forge UI
and submits when satisfied.

## Comment conventions

**Prefixes:**
- `AI: ` — unedited AI output
- `@ai: ` — human question for AI to process
- No prefix — human reviewed/edited

**Priority markers:**
- `*Important*:` — must resolve before merge
- (none) — normal suggestion
- `(low)` — minor nit

## Review body

Do not summarize the PR changes. The body should contain:
- Attribution (required)
- Concerns not tied to specific lines (optional)

Avoid positive-only inline comments — they create noise.
