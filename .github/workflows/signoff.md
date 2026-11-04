---
description: |
  DCO signoff command handler. Maintainers can comment /signoff on a pull
  request to add DCO signoff to all commits. Only dispatches a runner when
  the /signoff command is used, avoiding unnecessary runs for every comment.

label_command:
  command: signoff
  permission: triage

permissions:
  contents: write
  pull-requests: write

safe-outputs:
  github-app:
    client-id: ${{ vars.GH_AW_APP_CLIENT_ID }}
    private-key: ${{ secrets.GH_AW_APP_PRIVATE_KEY }}
  add-comment:
    max: 1
---

# DCO Signoff Handler

You are a DCO signoff automation agent. A maintainer has used the `/signoff`
command on pull request #{{ github.event.issue.number }}.

## Your Task

Add DCO signoff to all commits on this pull request:

1. Get the PR details (branch name, head SHA, base branch):
   ```bash
   gh pr view {{ github.event.issue.number }} --json headRefName,headRefOid,baseRefName
   ```

2. Check out the PR branch and verify the tip commit SHA matches the current
   state to prevent race conditions.

3. Get the commenter's identity:
   ```bash
   gh api /users/{{ github.event.comment.user.login }}
   ```
   Extract name and email. If no public email, use the noreply format:
   `{user_id}+{username}@users.noreply.github.com`

4. Check if all commits already have the signoff from this commenter:
   ```bash
   git log origin/$BASE_BRANCH..HEAD --grep="Signed-off-by: $NAME <$EMAIL>" --invert-grep --oneline | wc -l
   ```
   If count is 0, all commits are already signed off.

5. If not already signed off, configure git identity and use `git rebase --signoff`
   to add signoff to all commits:
   ```bash
   git config user.name "$NAME"
   git config user.email "$EMAIL"
   git rebase --signoff origin/$BASE_BRANCH
   ```

6. Push the signed commits using `push-to-pull-request-branch` safe-output.

7. Post feedback using `add-comment` safe-output:
   - ✅ "All commits are already signed off by you." (if already signed)
   - ✅ "DCO signoff added to all commits successfully." (if signed off)
   - ❌ "Cannot add signoff: the tip commit has changed. Expected: `$SHA`
     Actual: `$ACTUAL_SHA`. Please try again." (if SHA mismatch)

## Important Notes

- The `label_command` trigger already handles permission validation (triage or
  higher required), so you don't need to check permissions yourself.
- Use `git rebase --signoff` to add signoff to all commits in the PR, not just
  the tip commit.
- Always verify the SHA before modifying commits to prevent race conditions.
- Use `--force-with-lease` when pushing to ensure safe force push.
