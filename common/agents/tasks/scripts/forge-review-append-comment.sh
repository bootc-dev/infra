#!/usr/bin/env bash
# Append a review comment to a JSONL file with line content validation
#
# Usage: forge-review-append-comment.sh --file PATH --line NUM --match TEXT --body COMMENT [--review-file FILE]
#
# Arguments:
#   --file PATH        File path relative to repo root (e.g., src/lib.rs)
#   --line NUM         Line number in the file
#   --match TEXT       Text that must appear on that line (for validation)
#   --body COMMENT     The review comment body
#   --review-file FILE Output JSONL file (default: .git/review.jsonl)
#   --old-path PATH    Original file path for renames (GitLab only)
#
# The review file must first be created with forge-review-start.sh.
#
# The script verifies that --match text appears on the specified line before
# appending. This prevents comments from being attached to wrong lines when
# the file has changed.
#
# Example:
#   forge-review-append-comment.sh \
#     --file src/lib.rs \
#     --line 42 \
#     --match "fn process_data" \
#     --body "AI: *Important*: Missing error handling for empty input"

set -euo pipefail

usage() {
    cat >&2 <<EOF
Usage: $0 --file PATH --line NUM --match TEXT --body COMMENT [OPTIONS]

Required:
  --file PATH        File path relative to repo root
  --line NUM         Line number in the file
  --match TEXT       Text that must appear on that line (for validation)
  --body COMMENT     The review comment body

Optional:
  --review-file FILE Output JSONL file (default: .git/review.jsonl)
  --old-path PATH    Original file path for renames (GitLab compatibility)

Example:
  $0 --file src/lib.rs --line 42 --match "fn process" --body "AI: Add docs"
EOF
    exit 1
}

FILE=""
LINE=""
MATCH=""
BODY=""
REVIEW_FILE=""
OLD_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            FILE="$2"
            shift 2
            ;;
        --line)
            LINE="$2"
            shift 2
            ;;
        --match)
            MATCH="$2"
            shift 2
            ;;
        --body)
            BODY="$2"
            shift 2
            ;;
        --review-file)
            REVIEW_FILE="$2"
            shift 2
            ;;
        --old-path)
            OLD_PATH="$2"
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
if [[ -z "$FILE" ]]; then
    echo "Error: --file is required" >&2
    usage
fi
if [[ -z "$LINE" ]]; then
    echo "Error: --line is required" >&2
    usage
fi
if [[ -z "$MATCH" ]]; then
    echo "Error: --match is required" >&2
    usage
fi
if [[ -z "$BODY" ]]; then
    echo "Error: --body is required" >&2
    usage
fi

# Validate line is a number
if ! [[ "$LINE" =~ ^[0-9]+$ ]]; then
    echo "Error: --line must be a positive integer, got: $LINE" >&2
    exit 1
fi

# Check file exists
if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE" >&2
    exit 1
fi

# Extract the actual line content
ACTUAL_LINE=$(sed -n "${LINE}p" "$FILE")

if [[ -z "$ACTUAL_LINE" ]]; then
    echo "Error: Line $LINE does not exist in $FILE" >&2
    exit 1
fi

# Check if match text appears on the line
if [[ "$ACTUAL_LINE" != *"$MATCH"* ]]; then
    echo "Error: Match text not found on line $LINE" >&2
    echo "  Expected to find: $MATCH" >&2
    echo "  Actual line content: $ACTUAL_LINE" >&2
    exit 1
fi

# Default review file
if [[ -z "$REVIEW_FILE" ]]; then
    REVIEW_FILE=".git/review.jsonl"
fi

# Verify review file exists (must be created with forge-review-start.sh first)
if [[ ! -f "$REVIEW_FILE" ]]; then
    echo "Error: Review file not found: $REVIEW_FILE" >&2
    echo "Create it first with forge-review-start.sh" >&2
    exit 1
fi

# Build the JSON object
if [[ -n "$OLD_PATH" ]]; then
    # Include old_path for GitLab renames
    jq -n --arg path "$FILE" --argjson line "$LINE" --arg body "$BODY" --arg old_path "$OLD_PATH" \
        '{path: $path, line: $line, body: $body, old_path: $old_path}' >> "$REVIEW_FILE"
else
    jq -n --arg path "$FILE" --argjson line "$LINE" --arg body "$BODY" \
        '{path: $path, line: $line, body: $body}' >> "$REVIEW_FILE"
fi

echo "Added comment for $FILE:$LINE"
