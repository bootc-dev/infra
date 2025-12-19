#!/usr/bin/env bash
# Submit a forge review to GitHub
#
# Usage: forge-review-submit-github.sh [--dry-run] OWNER REPO PR_NUMBER [REVIEW_FILE]
#
# Options:
#   --dry-run    Validate the review file without submitting
#
# Arguments:
#   OWNER        Repository owner
#   REPO         Repository name
#   PR_NUMBER    Pull request number
#   REVIEW_FILE  Path to JSONL file (default: .git/review.jsonl)
#
# Environment:
#   GH_TOKEN or GITHUB_TOKEN - GitHub authentication token (optional if gh is configured)
#
# The JSONL file must be created with forge-review-start.sh and contain:
#   Line 1: {"body": "Review body with attribution..."}
#   Line 2+: {"path": "src/lib.rs", "line": 42, "body": "..."}
#
# On success, removes the review file. On failure, preserves it.

set -euo pipefail

usage() {
    echo "Usage: $0 [--dry-run] OWNER REPO PR_NUMBER [REVIEW_FILE]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --dry-run    Validate the review file without submitting" >&2
    echo "" >&2
    echo "REVIEW_FILE must be created with forge-review-start.sh first." >&2
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
REVIEW_FILE="${4:-.git/review.jsonl}"

if [[ ! -f "$REVIEW_FILE" ]]; then
    echo "Error: Review file not found: $REVIEW_FILE" >&2
    exit 1
fi

# Parse JSONL: extract metadata and comments separately
if ! ALL_ENTRIES=$(jq -s '. // []' < "$REVIEW_FILE" 2>&1); then
    echo "Error: Invalid JSONL syntax in $REVIEW_FILE" >&2
    echo "$ALL_ENTRIES" >&2
    exit 1
fi

# Extract metadata (first line) and comments (remaining lines)
METADATA=$(echo "$ALL_ENTRIES" | jq '.[0]')
if [[ "$METADATA" == "null" ]]; then
    echo "Error: Empty review file: $REVIEW_FILE" >&2
    echo "Create the review file with forge-review-start.sh first" >&2
    exit 1
fi

REVIEW_BODY=$(echo "$METADATA" | jq -r '.body')
if [[ -z "$REVIEW_BODY" || "$REVIEW_BODY" == "null" ]]; then
    echo "Error: First line missing 'body' field" >&2
    exit 1
fi

# Extract comments (all lines after the first)
COMMENTS=$(echo "$ALL_ENTRIES" | jq '.[1:]')
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
