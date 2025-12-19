---
name: diff-quiz
description: Generate a quiz to verify human understanding of code changes. Use when reviewing PRs or commits to ensure the submitter understands what they're proposing.
---

# Diff Quiz

This task generates a quiz based on a git diff to help verify that a human
submitter has meaningful understanding of code they're proposing — particularly
relevant when agentic AI tools assisted in generating the code.

## Purpose

When developers use AI tools to generate code, there's a risk of submitting
changes without fully understanding them. This quiz helps:

- Verify baseline competency in the relevant programming language(s)
- Confirm understanding of the specific changes being proposed
- Ensure the submitter could maintain and debug the code in the future

The quiz is designed to be educational, not adversarial. It should help
identify knowledge gaps that could lead to problems down the road.

## Difficulty Levels

### Easy

Basic verification that the submitter is familiar with the project and has
general programming competency. Questions at this level do NOT require deep
understanding of the specific diff.

Example question types:
- What programming language(s) is this project written in?
- What is the purpose of this project (based on README or documentation)?
- What build system or package manager does this project use?
- Name one external dependency this project uses and what it's for
- What testing framework does this project use?
- What does `<common language construct>` do? (e.g., "What does `?` do in Rust?")

### Medium

Verify baseline understanding of both the programming language and the specific
changes in the diff. The submitter should be able to explain what the code does.

Example question types:
- Explain in your own words what this function/method does
- What error conditions does this code handle?
- Why might the author have chosen `<approach A>` over `<approach B>`?
- What would happen if `<input>` were passed to this function?
- This code uses `<library/API>`. What is the purpose of the `<specific call>`?
- What tests would you write to verify this change works correctly?
- Walk through what happens when `<scenario>` occurs
- What existing code does this change interact with?

### Hard

Verify deep understanding — the submitter should in theory be able to have
written this patch themselves. Questions probe implementation details,
architectural decisions, and broader project knowledge.

Example question types:
- Write pseudocode for how you would implement `<core algorithm from the diff>`
- This change affects `<component>`. What other parts of the codebase might
  need to be updated as a result?
- What are the performance implications of this approach?
- Describe an alternative implementation and explain the tradeoffs
- How does this change interact with `<unrelated subsystem>`?
- What edge cases are NOT handled by this implementation?
- If this code fails in production, how would you debug it?
- Why is `<specific implementation detail>` necessary? What would break without it?
- Explain the memory/ownership model used here (for languages like Rust/C++)

## Workflow

### Step 1: Identify the Diff

Determine the commit range to quiz on:

```bash
# For a PR, find the merge base
MERGE_BASE=$(git merge-base HEAD main)
git log --oneline $MERGE_BASE..HEAD
git diff $MERGE_BASE..HEAD

# For a specific commit
git show <commit-sha>

# For a range of commits
git diff <base>..<head>
```

### Step 2: Analyze the Changes

Before generating questions, understand:

1. **Languages involved** — What programming languages are being modified?
2. **Scope of changes** — How many files? How many lines? New feature vs bugfix?
3. **Complexity** — Simple refactor or complex algorithmic changes?
4. **Project context** — What part of the system is being modified?

### Step 3: Generate Questions

Generate questions appropriate to the requested difficulty level. Guidelines:

- **Easy**: 4-6 questions, should take 2-5 minutes to answer
- **Medium**: 6-9 questions, should take 10-15 minutes to answer
- **Hard**: 8-12 questions, should take 20-30 minutes to answer

**Question ordering**: Put the most important questions first. The quiz should
front-load questions that best verify understanding, so users who demonstrate
competency early can stop without answering everything.

For each question:
- State the question clearly
- If referencing specific code, include the relevant snippet or file:line
- Indicate what type of answer is expected (short answer, explanation, pseudocode)

**IMPORTANT**: Do NOT include grading notes, expected answers, or hints in the
quiz output. The quiz is for the human to answer, and grading happens in a
separate step.

## Output Formats

### Format 1: Markdown (default)

Present the quiz in markdown for the human to read and answer conversationally:

```markdown
# Diff Quiz: [Brief description of changes]

**Difficulty:** [Easy/Medium/Hard]
**Estimated time:** [X minutes]
**Commits:** [commit range or PR number]

---

## Questions

### Question 1
[Question text]

**Expected answer type:** [Short answer / Explanation / Pseudocode / etc.]

### Question 2
...
```

### Format 2: Bash Script (`--script` or "as a script")

Generate a self-contained bash script that:
1. Displays each question interactively
2. Prompts the user for their answer
3. Appends all answers to a `.answers.txt` file for later grading
4. **Asks "Continue? [Y/n]" every 2-3 questions** — allowing early exit if
   the user has demonstrated sufficient understanding

The script should be saved to a file like `diff-quiz-<commit-short>.sh`.

```bash
#!/bin/bash
# Diff Quiz: [Brief description]
# Difficulty: [Easy/Medium/Hard]
# Commit: [commit hash]
# Generated: [date]

set -e

ANSWERS_FILE=".answers-$(date +%Y%m%d-%H%M%S).txt"

cat << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                         DIFF QUIZ                              ║
║────────────────────────────────────────────────────────────────║
║  Difficulty: [Easy/Medium/Hard]                                ║
║  Estimated time: [X] minutes                                   ║
║  Commit: [hash]                                                ║
║                                                                ║
║  Answer each question. Your responses will be saved to:        ║
║  [answers file]                                                ║
║                                                                ║
║  For multi-line answers, type your response and press          ║
║  Enter twice (empty line) to submit.                           ║
╚════════════════════════════════════════════════════════════════╝
EOF

echo "Answers file: $ANSWERS_FILE"
echo ""

# Header for answers file
cat << EOF > "$ANSWERS_FILE"
# Diff Quiz Answers
# Difficulty: [Easy/Medium/Hard]
# Commit: [hash]
# Date: $(date -Iseconds)
# ─────────────────────────────────────────────────────────────────

EOF

read_answer() {
    local answer=""
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        answer+="$line"$'\n'
    done
    echo "${answer%$'\n'}"  # Remove trailing newline
}

# Question 1
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Question 1 of N"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat << 'EOF'
[Question text here]

Expected answer type: [Short answer / Explanation / etc.]
EOF
echo ""
echo "Your answer (empty line to submit):"
answer=$(read_answer)
cat << EOF >> "$ANSWERS_FILE"
## Question 1
[Question text here]

### Answer
$answer

EOF
echo ""

# ... repeat for each question ...

# After every 2-3 questions, prompt to continue:
echo ""
read -p "Continue to more questions? [Y/n] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Stopping early. Your answers so far have been saved."
    # jump to completion message
fi

# ... continue with remaining questions ...

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Quiz complete! Your answers have been saved to: $ANSWERS_FILE"
echo ""
echo "To have your answers graded, run:"
echo "  [agent command] grade diff-quiz $ANSWERS_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
```

Make the script executable: `chmod +x diff-quiz-<commit>.sh`

## Grading

Grading is a **separate step** performed after the human completes the quiz.

When asked to grade a quiz (e.g., "grade diff-quiz .answers.txt"):

1. Read the answers file
2. Re-analyze the original commit/diff to understand the correct answers
3. For each answer, evaluate:
   - **Correctness** — Is the answer factually accurate?
   - **Completeness** — Did they address all parts of the question?
   - **Depth** — Does the answer show genuine understanding vs. surface-level recall?
4. Provide feedback for each question:
   - What was good about the answer
   - What was missing or incorrect
   - Additional context that might help their understanding
5. Give an overall assessment:
   - **Pass** — Demonstrates sufficient understanding for the difficulty level
   - **Partial** — Some gaps, may want to review specific areas
   - **Needs Review** — Significant gaps suggest the code should be reviewed more carefully

Grading should be constructive and educational, not punitive.

## Usage Examples

### Example 1: Quick sanity check before merge

```
User: Run diff quiz on this PR, easy difficulty

Agent: [Generates 3-5 basic questions about the project and language]
```

### Example 2: Generate a script for async completion

```
User: Generate a medium diff-quiz script for commit abc123

Agent: [Creates diff-quiz-abc123.sh that the user can run on their own time]
```

### Example 3: Grade completed answers

```
User: Grade diff-quiz .answers-20240115-143022.txt

Agent: [Reads answers, evaluates against the commit, provides feedback]
```

### Example 4: Full workflow

```
User: Generate hard diff-quiz for this PR as a script
[User runs the script, answers questions]
User: Grade the quiz: .answers-20240115-143022.txt
Agent: [Provides detailed feedback and pass/fail assessment]
```

## Notes

- The quiz should be fair — questions should be answerable by someone who
  genuinely wrote or deeply reviewed the code
- Avoid gotcha questions or obscure trivia
- For Easy level, questions should be passable by any competent developer
  familiar with the project, even if they didn't write this specific code
- For Hard level, it's acceptable if the submitter needs to look things up,
  but they should know *what* to look up and understand the answers
- Consider the context — a typo fix doesn't need a Hard quiz
- Questions should probe understanding, not memorization
- **Never include answers or grading notes in the quiz itself** — this defeats
  the purpose of verifying understanding
