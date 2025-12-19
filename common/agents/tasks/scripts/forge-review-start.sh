#!/usr/bin/env bash
# Start a new forge review by creating a JSONL file with metadata
#
# Usage: forge-review-start.sh --body TEXT [--review-file FILE]
#
# Arguments:
#   --body TEXT        Review body text (must include attribution)
#   --review-file FILE Output JSONL file (default: .git/review.jsonl)
#
# The first line of the JSONL file will contain review metadata:
#   {"body": "Review body text..."}
#
# Subsequent lines (added by forge-review-append-comment.sh) contain comments:
#   {"path": "src/lib.rs", "line": 42, "body": "..."}
#
# Example:
#   forge-review-start.sh --body "Assisted-by: OpenCode (Claude Sonnet 4)
#
#   AI-generated review. Comments prefixed with AI: are unedited."

set -euo pipefail

usage() {
    cat >&2 <<EOF
Usage: $0 --body TEXT [OPTIONS]

Required:
  --body TEXT        Review body text (must include attribution)

Optional:
  --review-file FILE Output JSONL file (default: .git/review.jsonl)

Example:
  $0 --body "Assisted-by: OpenCode (Claude Sonnet 4)"
EOF
    exit 1
}

BODY=""
REVIEW_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --body)
            BODY="$2"
            shift 2
            ;;
        --review-file)
            REVIEW_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$BODY" ]]; then
    echo "Error: --body is required" >&2
    usage
fi

# Default review file
if [[ -z "$REVIEW_FILE" ]]; then
    REVIEW_FILE=".git/review.jsonl"
fi

# Check if file already exists
if [[ -f "$REVIEW_FILE" ]]; then
    echo "Error: Review file already exists: $REVIEW_FILE" >&2
    echo "Delete it first or use a different --review-file" >&2
    exit 1
fi

# Ensure parent directory exists
mkdir -p "$(dirname "$REVIEW_FILE")"

# Write metadata as first line
jq -n --arg body "$BODY" \
    '{body: $body}' > "$REVIEW_FILE"

echo "Review started: $REVIEW_FILE"
