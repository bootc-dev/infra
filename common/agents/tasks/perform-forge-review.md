---
name: perform-forge-review
description: Create AI-assisted code reviews on GitHub, GitLab, or Forgejo. Use when asked to review a PR/MR, analyze code changes, or provide review feedback.
---

# Perform Forge Review

This task describes how to create and manage code reviews on GitHub, GitLab,
and Forgejo/Gitea with human oversight.

## Overview

The recommended workflow:

1. AI analyzes the PR diff and builds comments in a local JSONL file
2. Submit the review as pending/draft (not visible to others yet)
3. Human reviews in the forge UI, can add `@ai:` tasks for follow-up
4. Human submits when satisfied

Optionally after step 1, the JSONL review state can be passed off
into another security context that has write access (or at least
the ability to create draft reviews).

## Attribution Convention

**Review header:**
```
< your text here >

---
Assisted-by: ToolName (ModelName)

<details>
Comments prefixed with "AI:" are unedited AI output.
Executed from bootc-dev/infra task.
</details>
```

**Comment prefixes:**
- `AI: ` — unedited AI output
- `@ai: ` — human question/task for AI to process
- No prefix — human has reviewed/edited

**Comment types:**

- `*Important*:` — should be resolved before merge
- (no marker) — normal suggestion, can be addressed post-merge or ignored
- `(low)` — minor nit, feel free to ignore
- `**Question**:` — clarification needed (can combine with priority)

Examples:
- `AI: *Important*: This will panic on empty input`
- `AI: Consider using iterators here`
- `AI: (low) Rename to follow naming convention`
- `AI: **Question**: Is this intentional?`

**Filtering by priority:**

If user instructions specify a priority filter (e.g., "important only"), create
inline comments only for that priority level. Summarize the most relevant
normal/low priority items in a `<details>` section in the review body:

```markdown
<details>
<summary>Additional suggestions (normal/low priority)</summary>

- `src/lib.rs:42` — Consider using iterators
- `src/main.rs:15` — Minor: rename to follow convention
</details>
```

Avoid inline comments for purely positive observations (e.g., "Good approach here").
These create noise and require manual resolution. If positive aspects are worth
noting, briefly mention them in the review body.

**Review body content:**

Do not summarize or re-describe the PR changes — the commit messages already
contain that information. The review body should only contain:
- Attribution header (required)
- Positive observations worth highlighting (optional, brief)
- Concerns not tied to specific lines (optional)
- Notes about missing context in the PR description (if any)
- Collapsed lower-priority items when filtering (see above)

---

## Workflow

**Note**: If you already have a pending review on this PR, you cannot create
another. Check for existing pending reviews first (see API Reference) and
either add comments to it or delete it before proceeding.

### Step 1: Check Out the PR

Check out the PR branch locally. This lets you read files directly to get
accurate line numbers (diff line numbers are error-prone):

```bash
# GitHub
gh pr checkout PR_NUMBER

# GitLab
glab mr checkout MR_IID

# Forgejo (using forgejo-cli, or fall back to git fetch)
forgejo-cli pr checkout PR_INDEX
# or: git fetch origin pull/PR_INDEX/head:pr-PR_INDEX && git checkout pr-PR_INDEX
```

### Step 2: See the Code

After checkout, determine the merge base (fork point) and review the changes:

```bash
# Find the merge base with the target branch (usually main)
MERGE_BASE=$(git merge-base HEAD main)

# View commit history since fork point
git log --oneline $MERGE_BASE..HEAD

# View the combined diff of all changes
git diff $MERGE_BASE..HEAD

# Or view each commit's diff separately
git log -p $MERGE_BASE..HEAD
```

Review commit-by-commit to understand the logical structure of the changes.
Pay attention to commit messages — they should explain the "why" behind each
change. For larger PRs, reviewing each commit separately often provides better
context than a single combined diff. Note any commits where the message doesn't
match the code changes or where the reasoning is unclear.

### Step 3: Build the Review

The scripts in this task are located in the `scripts/` subdirectory relative to this
file (i.e., `common/agents/tasks/scripts/` from the repo root, or wherever `common/`
is synced in your project).

First, start the review with metadata (including attribution):

```bash
scripts/forge-review-start.sh \
  --body "Assisted-by: OpenCode (Claude Sonnet 4)

AI-generated review. Comments prefixed with AI: are unedited." \
  --review-file .git/review-123.jsonl
```

Then use `forge-review-append-comment.sh` to add comments. It validates that
your comment targets the correct line by requiring a matching text fragment:

```bash
scripts/forge-review-append-comment.sh \
  --file src/lib.rs \
  --line 42 \
  --match "fn process_data" \
  --body "AI: *Important*: Missing error handling for empty input" \
  --review-file .git/review-123.jsonl
```

This prevents comments from being attached to wrong lines if the file has changed.
The script will error if the match text is not found on the specified line.

Use a PR-specific review file (e.g., `.git/review-123.jsonl`) to avoid conflicts
when reviewing multiple PRs.

The JSONL file format:
```
{"body": "Review body with attribution..."}
{"path": "src/lib.rs", "line": 42, "body": "AI: ..."}
{"path": "src/main.rs", "line": 10, "body": "AI: ..."}
```

After adding comments, validate the review before submitting:

```bash
scripts/forge-review-submit-github.sh --dry-run owner repo 123 .git/review-123.jsonl
# Output: Review validated: 5 pending comment(s) for owner/repo#123
```

### Step 4: Submit the Review

Submit the review using the appropriate script for your forge:

#### GitHub

```bash
scripts/forge-review-submit-github.sh owner repo 123 .git/review-123.jsonl
```

Requires: `gh` CLI configured with authentication.

#### GitLab

```bash
export GITLAB_TOKEN="glpat-xxxx"
scripts/forge-review-submit-gitlab.sh 12345 67 .git/review-67.jsonl
```

For GitLab renames, use `--old-path` when appending comments.

#### Forgejo

```bash
export FORGEJO_TOKEN="xxxx"
export FORGEJO_URL="https://codeberg.org"
scripts/forge-review-submit-forgejo.sh owner repo 123 .git/review-123.jsonl
```

All submit scripts read the review body from the metadata entry in the JSONL file,
so no separate body argument is needed.

---

## Processing @ai: Tasks

When a human adds `@ai: <question>` to a comment, the AI should:

1. Check for existing pending review (see API Reference below)
2. Find comments containing `@ai:`
3. Read the question/task and relevant code context
4. Generate a response
5. Update the comment, appending:

```markdown
@ai: Is this error handling correct?

---
**AI Response**: No, the error is being silently ignored. Consider...
```

The human can then:
- Edit to remove the `@ai:` prefix if satisfied
- Add follow-up `@ai:` tasks
- Delete the comment if not useful
- Submit when done

---

## Platform Comparison

| Feature | GitHub | GitLab | Forgejo |
|---------|--------|--------|---------|
| Pending/Draft Reviews | ✅ | ✅ | ✅ |
| Edit Pending Comments | ✅ (GraphQL) | ✅ (REST) | ❌ |
| Delete Pending Comments | ✅ | ✅ | ✅ |
| Add to Pending Review | ✅ | ✅ | ✅ |
| Inline Comments | ✅ | ✅ | ✅ |
| Submit with State | ✅ | ✅* | ✅ |
| CLI Support | gh | glab | tea |

*GitLab handles APPROVE separately via Approvals API.

---

## API Reference

Direct API calls for advanced operations (editing, deleting, submitting).

### GitHub

#### Check for Existing Pending Review

```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviews(last: 10, states: [PENDING]) {
        nodes {
          id
          databaseId
          body
          comments(first: 100) {
            nodes { id body path line }
          }
        }
      }
    }
  }
}'
```

#### Edit a Pending Comment

REST returns 404 for pending comments. Use GraphQL:

```bash
gh api graphql -f query='
mutation {
  updatePullRequestReviewComment(input: {
    pullRequestReviewCommentId: "PRRC_xxxxx",
    body: "Updated comment text"
  }) {
    pullRequestReviewComment { id body }
  }
}'
```

#### Add Comment to Existing Pending Review

```bash
gh api graphql -f query='
mutation {
  addPullRequestReviewThread(input: {
    pullRequestReviewId: "PRR_xxxxx",
    body: "AI: New comment",
    path: "src/lib.rs",
    line: 50,
    side: RIGHT
  }) {
    thread { id }
  }
}'
```

#### Delete a Pending Comment

```bash
gh api graphql -f query='
mutation {
  deletePullRequestReviewComment(input: {
    id: "PRRC_xxxxx"
  }) {
    pullRequestReviewComment { id }
  }
}'
```

#### Submit the Review

```bash
gh api repos/OWNER/REPO/pulls/PR_NUMBER/reviews/REVIEW_ID/events \
  -X POST -f event="COMMENT"   # or REQUEST_CHANGES or APPROVE
```

### GitLab

#### Check for Existing Draft Notes

```bash
curl --header "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_requests/$MR_IID/draft_notes"
```

#### Edit a Draft Note

```bash
curl --request PUT \
  --header "PRIVATE-TOKEN: $TOKEN" \
  --form-string "note=Updated comment text" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_requests/$MR_IID/draft_notes/$NOTE_ID"
```

#### Delete a Draft Note

```bash
curl --request DELETE \
  --header "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_requests/$MR_IID/draft_notes/$NOTE_ID"
```

#### Submit Review (Publish All Drafts)

```bash
curl --request POST \
  --header "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_requests/$MR_IID/draft_notes/bulk_publish"
```

#### Approve MR (Separate from Review)

```bash
curl --request POST \
  --header "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_requests/$MR_IID/approve"
```

### Forgejo

#### List Reviews (Find Pending)

```bash
curl -H "Authorization: token $TOKEN" \
  "$FORGEJO_URL/api/v1/repos/$OWNER/$REPO/pulls/$PR_INDEX/reviews"
```

Look for reviews with `state: "PENDING"`.

#### Add Comment to Existing Pending Review

```bash
curl -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"path": "src/lib.rs", "new_position": 50, "body": "AI: Comment"}' \
  "$FORGEJO_URL/api/v1/repos/$OWNER/$REPO/pulls/$PR_INDEX/reviews/$REVIEW_ID/comments"
```

#### Delete a Comment

```bash
curl -X DELETE \
  -H "Authorization: token $TOKEN" \
  "$FORGEJO_URL/api/v1/repos/$OWNER/$REPO/pulls/$PR_INDEX/reviews/$REVIEW_ID/comments/$COMMENT_ID"
```

#### Submit the Review

```bash
curl -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"event": "COMMENT", "body": "Review complete"}' \
  "$FORGEJO_URL/api/v1/repos/$OWNER/$REPO/pulls/$PR_INDEX/reviews/$REVIEW_ID"
```

Valid event values: `APPROVE`, `REQUEST_CHANGES`, `COMMENT`

**Note**: Forgejo does not support editing review comments via API.
Workaround: Delete and recreate the comment.

---

## Notes

- Always get the diff first to understand line positioning
- Node IDs (GitHub) come from GraphQL queries
- Project IDs (GitLab) can be numeric or URL-encoded paths
- Pending reviews are only visible to their author
- The JSONL workflow enables future sandboxed execution where the agent
  runs with read-only access and a separate privileged process submits the review

---

## Related Projects

This workflow was influenced by existing tools for distributed/local code review:

### git-appraise

https://github.com/google/git-appraise (5k+ stars)

Google's distributed code review system stores reviews entirely in git using
`git-notes` under `refs/notes/devtools/`. Key design choices:

- **Single-line JSON** per entry with `cat_sort_uniq` merge strategy for
  conflict-free merging
- Separate refs for requests, comments, CI status, and robot comments
- Reviews can be pushed/pulled like regular git data
- Mirrors available for GitHub PRs and Phabricator

The JSONL format in this workflow is compatible with potentially storing
reviews in git-notes in the future. However, we intentionally avoid pushing
review notes to remotes by default—the primary goal is local editing before
forge submission, not distributed review storage.

### git-bug

https://github.com/git-bug/git-bug (9k+ stars)

Distributed, offline-first issue tracker embedded in git. Uses git objects
(not files) for storage with bridges to sync with GitHub/GitLab. Focused on
issues rather than code review, but similar local-first philosophy.

### Radicle

https://radicle.xyz

Fully decentralized code collaboration platform with its own P2P protocol.
Issues and patches are stored in git. A complete forge alternative rather
than a review tool, but demonstrates the broader space of distributed
development tooling.
