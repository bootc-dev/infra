#!/bin/bash
# Submit a forge review to GitHub
#
# Usage: forge-review-submit-github.sh [--dry-run] OWNER REPO PR_NUMBER [REVIEW_FILE] [REVIEW_BODY]
#
# Options:
#   --dry-run    Validate the review file without submitting
#
# Arguments:
#   OWNER        Repository owner
#   REPO         Repository name
#   PR_NUMBER    Pull request number
#   REVIEW_FILE  Path to JSONL file with comments (default: .git/.forge-review.jsonl)
#   REVIEW_BODY  Review body text (default: standard attribution header)
#
# Environment:
#   GH_TOKEN or GITHUB_TOKEN - GitHub authentication token (optional if gh is configured)
#
# The JSONL file should contain one JSON object per line:
#   {"path": "src/lib.rs", "line": 42, "body": "AI: Comment text"}
#
# On success, removes the review file. On failure, preserves it.

set -euo pipefail

usage() {
    echo "Usage: $0 [--dry-run] OWNER REPO PR_NUMBER [REVIEW_FILE] [REVIEW_BODY]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --dry-run    Validate the review file without submitting" >&2
    exit 1
}

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

if [[ $# -lt 3 ]]; then
    usage
fi

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"
REVIEW_FILE="${4:-.git/.forge-review.jsonl}"
REVIEW_BODY="${5:-Assisted-by: OpenCode (Claude Sonnet 4)

AI-generated review based on REVIEW.md guidelines.
Comments prefixed with \"AI:\" are unedited AI output.}"

if [[ ! -f "$REVIEW_FILE" ]]; then
    echo "Error: Review file not found: $REVIEW_FILE" >&2
    exit 1
fi

# Validate JSONL syntax and count comments
if ! COMMENTS=$(jq -s '. // []' < "$REVIEW_FILE" 2>&1); then
    echo "Error: Invalid JSONL syntax in $REVIEW_FILE" >&2
    echo "$COMMENTS" >&2
    exit 1
fi

COMMENT_COUNT=$(echo "$COMMENTS" | jq 'length')

# Validate each comment has required fields
INVALID=$(echo "$COMMENTS" | jq '[.[] | select(.path == null or .body == null)] | length')
if [[ "$INVALID" -gt 0 ]]; then
    echo "Error: $INVALID comment(s) missing required fields (path, body)" >&2
    exit 1
fi

if [[ $DRY_RUN -eq 1 ]]; then
    echo "Review validated: $COMMENT_COUNT pending comment(s) for $OWNER/$REPO#$PR_NUMBER"
    exit 0
fi

# Check gh CLI is available
if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh CLI not found. Install from https://cli.github.com/" >&2
    exit 1
fi

# Create the review (pending by default - omit event param)
RESULT=$(jq -n \
  --arg body "$REVIEW_BODY" \
  --argjson comments "$COMMENTS" \
  '{body: $body, comments: $comments}' | \
gh api "repos/$OWNER/$REPO/pulls/$PR_NUMBER/reviews" \
  -X POST --input - 2>&1) || true

# Check result and clean up
if echo "$RESULT" | jq -e '.id' > /dev/null 2>&1; then
  echo "Review created: $(echo "$RESULT" | jq -r '.html_url // .id')"
  rm "$REVIEW_FILE"
else
  echo "Failed to create review: $RESULT" >&2
  echo "Review file preserved at $REVIEW_FILE" >&2
  # Common error: "User can only have one pending review per pull request"
  exit 1
fi
