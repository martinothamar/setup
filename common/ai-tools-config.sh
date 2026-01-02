#!/bin/bash

COMMON_ASSISTANT_INSTRUCTIONS=$(cat <<'EOT'
IMPORTANT:
- In all interactions, be extremely concise and sacrifice grammar for the sake of concision
- Be direct and straightforward in all responses
- Avoid overly positive or enthusiastic language
- Challenge assumptions and point out potential issues or flaws
- Provide constructive criticism
- Verify assumptions before proceeding

IMPORTANT CODE CHARACTERISTICS:
- Be defensive
- Fail early
- Be performant
  - Avoid unneeded work and allocations
  - Non-pessimize
- Comments should explain _why_ something is done, never _what_ is being done
  - Avoid obvious comments, we only want comments that explain non-obvious reasoning
EOT
)

INTERVIEW_COMMAND_CONTENT=$(cat <<'EOT'
Read the plan file $1 thoroughly before starting. Look up and read any files, references, or external resources mentioned in the plan to build full context.

Interview me in detail about:
- Technical implementation details
- UI & UX considerations
- Concerns and edge cases
- Tradeoffs and alternatives

Use your user interaction tool (e.g. AskUserQuestionTool in Claude Code) to ask questions and wait for my response.

Focus on non-obvious questions that require deeper thinking.

After every 2-3 rounds of questions, update the plan file with:
- Clarified requirements from my answers
- Decisions made
- New constraints or considerations discovered

Continue interviewing until comprehensive, then write the final spec to the file.
EOT
)

backup_if_exists() {
  local file="${1-}"
  if [ -z "$file" ]; then
    echo "backup_if_exists: missing file path" >&2
    return 1
  fi

  if [ -f "$file" ]; then
    cp "$file" "${file}.bak"
  fi
}

write_interview_prompt() {
  local path="${1-}"
  if [ -z "$path" ]; then
    echo "write_interview_prompt: missing path" >&2
    return 1
  fi
  shift

  printf '%s\n' "$@" >"$path"
  printf '\n%s\n' "$INTERVIEW_COMMAND_CONTENT" >>"$path"
}

configure_claude() {
  echo "========================================"
  echo "Configuring Claude global instructions..."

  mkdir -p ~/.claude
  mkdir -p ~/.claude/commands

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.claude/CLAUDE.md

  write_interview_prompt ~/.claude/commands/interview.md \
    "---" \
    "description: Interview me about the plan" \
    "argument-hint: [plan]" \
    "model: claude-opus-4-5" \
    "---"

  backup_if_exists ~/.claude/settings.json

  cat >~/.claude/settings.json <<'EOT'
{
  "permissions": {
    "allow": [
      "WebSearch",
      "WebFetch"
    ]
  },
  "alwaysThinkingEnabled": true
}
EOT

  echo "Claude configuration complete!"
  echo "========================================"
}

configure_codex() {
  echo "========================================"
  echo "Configuring Codex global instructions..."

  mkdir -p ~/.codex
  mkdir -p ~/.codex/prompts

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.codex/AGENTS.md

  write_interview_prompt ~/.codex/prompts/interview.md \
    "---" \
    "description: Interview me about the plan" \
    "argument-hint: [plan]" \
    "---"

  backup_if_exists ~/.codex/config.toml

  cat >~/.codex/config.toml <<'EOT'
model = "gpt-5.2-codex"
model_reasoning_effort = "high"
tool_output_token_limit = 25000
# Leave room for native compaction near the 272-273k context window.
# Formula: 273000 - (tool_output_token_limit + 15000)
# With tool_output_token_limit=25000 => 273000 - (25000 + 15000) = 233000
model_auto_compact_token_limit = 233000

[features]
ghost_commit = false
unified_exec = true
apply_patch_freeform = true
web_search_request = true
skills = true
shell_snapshot = true
EOT

  echo "Codex configuration complete!"
  echo "========================================"
}

configure_opencode() {
  echo "========================================"
  echo "Configuring OpenCode global instructions..."

  mkdir -p ~/.config/opencode
  mkdir -p ~/.config/opencode/command

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.config/opencode/AGENTS.md

  write_interview_prompt ~/.config/opencode/command/interview.md \
    "---" \
    "description: Interview me about the plan" \
    "model: anthropic/claude-opus-4-5" \
    "---"

  backup_if_exists ~/.config/opencode/opencode.json

  cat >~/.config/opencode/opencode.json <<'EOT'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-opus-4-5",
  "permission": {
    "webfetch": "allow"
  }
}
EOT

  echo "OpenCode configuration complete!"
  echo "========================================"
}
