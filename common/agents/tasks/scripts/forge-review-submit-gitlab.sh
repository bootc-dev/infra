#!/usr/bin/env bash
# Submit a forge review to GitLab
#
# STATUS: DRAFT/UNTESTED - This script has not been tested against a real GitLab instance.
#
# Usage: forge-review-submit-gitlab.sh [--dry-run] PROJECT_ID MR_IID [REVIEW_FILE]
#
# Options:
#   --dry-run    Validate the review file without submitting
#
# Arguments:
#   PROJECT_ID   GitLab project ID (numeric or URL-encoded path)
#   MR_IID       Merge request IID
#   REVIEW_FILE  Path to JSONL file (default: .git/review.jsonl)
#
# Environment:
#   GITLAB_TOKEN or PRIVATE_TOKEN - GitLab authentication token (required)
#   GITLAB_URL                    - GitLab instance URL (default: https://gitlab.com)
#
# The JSONL file must be created with forge-review-start.sh and contain:
#   Line 1: {"body": "Review body with attribution..."}
#   Line 2+: {"path": "src/lib.rs", "line": 42, "body": "...", "old_path": "..."}
#
# Note: old_path is optional for comments, defaults to path if not specified.
#
# On success, removes the review file. On failure, preserves it.

set -euo pipefail

usage() {
    echo "Usage: $0 [--dry-run] PROJECT_ID MR_IID [REVIEW_FILE]" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  --dry-run    Validate the review file without submitting" >&2
    echo "" >&2
    echo "REVIEW_FILE must be created with forge-review-start.sh first." >&2
    echo "" >&2
    echo "Environment variables:" >&2
    echo "  GITLAB_TOKEN or PRIVATE_TOKEN - GitLab authentication token (required)" >&2
    echo "  GITLAB_URL                    - GitLab instance URL (default: https://gitlab.com)" >&2
    exit 1
}

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

if [[ $# -lt 2 ]]; then
    usage
fi

PROJECT_ID="$1"
MR_IID="$2"
REVIEW_FILE="${3:-.git/review.jsonl}"

TOKEN="${GITLAB_TOKEN:-${PRIVATE_TOKEN:-}}"
GITLAB_URL="${GITLAB_URL:-https://gitlab.com}"
# Strip trailing slash from URL
GITLAB_URL="${GITLAB_URL%/}"

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
    echo "Review validated: $COMMENT_COUNT pending comment(s) for GitLab project $PROJECT_ID MR !$MR_IID"
    exit 0
fi

if [[ -z "$TOKEN" ]]; then
    echo "Error: GITLAB_TOKEN or PRIVATE_TOKEN environment variable required" >&2
    exit 1
fi

# Get MR version info first
VERSION_RESPONSE=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_requests/$MR_IID/versions" 2>&1)

VERSION_INFO=$(echo "$VERSION_RESPONSE" | jq '.[0]' 2>/dev/null)

if [[ -z "$VERSION_INFO" || "$VERSION_INFO" == "null" ]]; then
    echo "Error: Failed to get MR version info: $VERSION_RESPONSE" >&2
    echo "Review file preserved at $REVIEW_FILE" >&2
    exit 1
fi

BASE_SHA=$(echo "$VERSION_INFO" | jq -r '.base_commit_sha')
HEAD_SHA=$(echo "$VERSION_INFO" | jq -r '.head_commit_sha')
START_SHA=$(echo "$VERSION_INFO" | jq -r '.start_commit_sha')

# Validate we got valid SHAs
if [[ "$BASE_SHA" == "null" || -z "$BASE_SHA" ]]; then
    echo "Error: Invalid version info - missing base_commit_sha" >&2
    echo "Review file preserved at $REVIEW_FILE" >&2
    exit 1
fi

# Create draft notes from comments
# Use process substitution to avoid subshell exit propagation issues
COMMENT_COUNT_INT=$(echo "$COMMENTS" | jq 'length')
if [[ "$COMMENT_COUNT_INT" -gt 0 ]]; then
    while IFS= read -r comment; do
      [[ -z "$comment" ]] && continue
      
      path=$(echo "$comment" | jq -r '.path')
      line_num=$(echo "$comment" | jq -r '.line')
      body=$(echo "$comment" | jq -r '.body')
      old_path=$(echo "$comment" | jq -r '.old_path // .path')

      RESULT=$(curl -s --request POST \
        --header "PRIVATE-TOKEN: $TOKEN" \
        --form-string "note=$body" \
        --form-string "position[position_type]=text" \
        --form-string "position[base_sha]=$BASE_SHA" \
        --form-string "position[head_sha]=$HEAD_SHA" \
        --form-string "position[start_sha]=$START_SHA" \
        --form-string "position[old_path]=$old_path" \
        --form-string "position[new_path]=$path" \
        --form-string "position[new_line]=$line_num" \
        "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_requests/$MR_IID/draft_notes" 2>&1)

      if ! echo "$RESULT" | jq -e '.id' > /dev/null 2>&1; then
        echo "Failed to create draft note for $path:$line_num: $RESULT" >&2
        echo "Review file preserved at $REVIEW_FILE" >&2
        exit 1
      fi
    done < <(echo "$COMMENTS" | jq -c '.[]')
fi

# Post the main review body as a note
NOTE_RESULT=$(curl -s --request POST \
  --header "PRIVATE-TOKEN: $TOKEN" \
  --form-string "body=$REVIEW_BODY" \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/merge_requests/$MR_IID/notes" 2>&1)

if ! echo "$NOTE_RESULT" | jq -e '.id' > /dev/null 2>&1; then
    echo "Warning: Failed to post review summary note: $NOTE_RESULT" >&2
    echo "Draft comments were created successfully" >&2
fi

echo "Review created successfully"
rm "$REVIEW_FILE"
