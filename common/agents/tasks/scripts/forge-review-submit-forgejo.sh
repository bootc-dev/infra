#!/bin/bash
# Submit a forge review to Forgejo/Gitea
#
# STATUS: DRAFT/UNTESTED - This script has not been tested against a real Forgejo/Gitea instance.
#
# Usage: forge-review-submit-forgejo.sh [--dry-run] OWNER REPO PR_INDEX [REVIEW_FILE] [REVIEW_BODY]
#
# Options:
#   --dry-run    Validate the review file without submitting
#
# Arguments:
#   OWNER        Repository owner
#   REPO         Repository name
#   PR_INDEX     Pull request index number
#   REVIEW_FILE  Path to JSONL file with comments (default: .git/.forge-review.jsonl)
#   REVIEW_BODY  Review body text (default: standard attribution header)
#
# Environment:
#   FORGEJO_TOKEN or GITEA_TOKEN - Forgejo/Gitea authentication token (required)
#   FORGEJO_URL or GITEA_URL     - Instance URL (required, e.g., https://codeberg.org)
#
# The JSONL file should contain one JSON object per line:
#   {"path": "src/lib.rs", "line": 42, "body": "AI: Comment text"}
#
# On success, removes the review file. On failure, preserves it.

set -euo pipefail

usage() {
    echo "Usage: $0 [--dry-run] OWNER REPO PR_INDEX [REVIEW_FILE] [REVIEW_BODY]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --dry-run    Validate the review file without submitting" >&2
    echo "" >&2
    echo "Environment variables:" >&2
    echo "  FORGEJO_TOKEN or GITEA_TOKEN - Authentication token (required)" >&2
    echo "  FORGEJO_URL or GITEA_URL     - Instance URL (required)" >&2
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
PR_INDEX="$3"
REVIEW_FILE="${4:-.git/.forge-review.jsonl}"
REVIEW_BODY="${5:-Assisted-by: OpenCode (Claude Sonnet 4)

AI-generated review based on REVIEW.md guidelines.
Comments prefixed with \"AI:\" are unedited AI output.}"

if [[ ! -f "$REVIEW_FILE" ]]; then
    echo "Error: Review file not found: $REVIEW_FILE" >&2
    exit 1
fi

# Validate JSONL syntax and count comments
if ! COMMENTS_RAW=$(jq -s '. // []' < "$REVIEW_FILE" 2>&1); then
    echo "Error: Invalid JSONL syntax in $REVIEW_FILE" >&2
    echo "$COMMENTS_RAW" >&2
    exit 1
fi

COMMENT_COUNT=$(echo "$COMMENTS_RAW" | jq 'length')

# Validate each comment has required fields
INVALID=$(echo "$COMMENTS_RAW" | jq '[.[] | select(.path == null or .body == null)] | length')
if [[ "$INVALID" -gt 0 ]]; then
    echo "Error: $INVALID comment(s) missing required fields (path, body)" >&2
    exit 1
fi

if [[ $DRY_RUN -eq 1 ]]; then
    echo "Review validated: $COMMENT_COUNT pending comment(s) for $OWNER/$REPO#$PR_INDEX"
    exit 0
fi

TOKEN="${FORGEJO_TOKEN:-${GITEA_TOKEN:-}}"
BASE_URL="${FORGEJO_URL:-${GITEA_URL:-}}"

if [[ -z "$TOKEN" ]]; then
    echo "Error: FORGEJO_TOKEN or GITEA_TOKEN environment variable required" >&2
    exit 1
fi

if [[ -z "$BASE_URL" ]]; then
    echo "Error: FORGEJO_URL or GITEA_URL environment variable required" >&2
    exit 1
fi

# Strip trailing slash from URL
BASE_URL="${BASE_URL%/}"

# Transform JSONL to Forgejo format (line -> new_position)
COMMENTS=$(echo "$COMMENTS_RAW" | jq 'map({path, new_position: .line, body})')

# Create the review (pending by default - omit event param)
RESULT=$(jq -n \
  --arg body "$REVIEW_BODY" \
  --argjson comments "$COMMENTS" \
  '{body: $body, comments: $comments}' | \
curl -s -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Content-Type: application/json" \
  -d @- \
  "$BASE_URL/api/v1/repos/$OWNER/$REPO/pulls/$PR_INDEX/reviews" 2>&1)

if echo "$RESULT" | jq -e '.id' > /dev/null 2>&1; then
  echo "Review created successfully"
  rm "$REVIEW_FILE"
else
  echo "Failed to create review: $RESULT" >&2
  echo "Review file preserved at $REVIEW_FILE" >&2
  exit 1
fi
