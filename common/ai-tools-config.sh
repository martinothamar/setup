#!/bin/bash

COMMON_ASSISTANT_INSTRUCTIONS=$(
  cat <<'EOT'
IMPORTANT BEHAVIORAL RULES:
- In all interactions, be extremely concise
- Be direct and straightforward in all responses
- Avoid overly positive or enthusiastic language
- Challenge assumptions and point out potential issues or flaws
- Provide constructive criticism
- Verify assumptions before proceeding

IMPORTANT PROGRAMMING RULES: 
- Minimize code, be DRY
  - Code is liability, logic is an opportunity for bugs
  - We should have as little code as necessary to solve the problem
  - Duplicated logic leads to drift and inconsistency which leads to tech debt, bugs and progress slowdown
  - Important for both source- and test-code 
    - Examples:
      - Reusable functions, fixtures, types
      - Prefer table-driven/parameterized tests
      - Create consts and variables for strings/numbers when they are repeated
- Code should be clear and easily readable
- Don't prematurely build abstractions
- Use the right algorithms and datastructures for the problem
- Fix root causes (no band-aid solutions)
- Minimize external dependencies
- Be defensive
  - Examples:
    - Validation for arguments and parameters
    - Bounds and limits for sizes, parallelism etc
- Fail fast/early
- Return errors for user errors, use assertions for critical invariants and programmer errors
- Prefer pure code - easily testable
- Domain models should be free from infrastructure and dependencies
- Parse, dont validate. Prefer representations that prevent invalid states by design
- Be performant
  - Avoid unneeded work and allocations
  - Non-pessimize (don't write slow code for no reason)
  - Examples:
    - Minimize heap allocations (preallocate, reuse allocations, avoid closures, use stack, escape-analysis-friendly code)
    - CPU cache friendly datastructures, algorithms and layout
    - Minimize contention in parallel code
    - Pass by value for small arguments (~16 bytes or less)
    - Batching operations
- Comments should explain _why_ something is done, never _what_ is being done
  - Avoid obvious comments, we only want comments that explain non-obvious reasoning
  - Should have comments: "magic numbers/strings" and non-obvious configuration values
- Strict linting and static analysis
  - Don't suppress lints or warnings without a very good reason
- Warnings should be treated as errors
  - Suppressions should be documented and well-reasoned

Some rules can appear to be in contradicting and must be decided on based on domain and context, prompt the user if needed.
EOT
)

INTERVIEW_COMMAND_CONTENT=$(
  cat <<'EOT'
Read the plan file $1 thoroughly before starting. Look up and read any files, references, or external resources mentioned in the plan to build full context.

Interview me in detail about:
- Technical implementation details
- UI & UX considerations
- Concerns and edge cases
- Tradeoffs and alternatives
- Testing strategies

IMPORTANT:
- Focus on non-obvious but material and important questions that require deeper thinking
- Focus on high-level outcomes, not low-level implementation details
- After every round of questions, update the plan file with based on answers given
- Update the plan inline, in the respective sections that made you think to ask the individual questions
- Make sure the plan stays cohesive and well-structured

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

# install_skills TARGET_DIR REPO_URL REPO_PREFIX SKILL...
install_skills() {
  local target_dir="${1-}"
  local repo_url="${2-}"
  local repo_prefix="${3-}"
  if [ -z "$target_dir" ] || [ -z "$repo_url" ] || [ -z "$repo_prefix" ]; then
    echo "install_skills: missing required arguments" >&2
    return 1
  fi
  shift 3
  local skills=("$@")
  if [ "${#skills[@]}" -eq 0 ]; then
    echo "install_skills: no skills specified" >&2
    return 1
  fi

  mkdir -p "$target_dir"

  local tmp_dir
  tmp_dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" RETURN

  echo "Fetching skills from $repo_url..."
  if ! git clone --depth 1 --filter=blob:none --no-checkout \
      "$repo_url" "$tmp_dir/repo" 2>/dev/null; then
    echo "Warning: failed to clone $repo_url" >&2
    return 1
  fi

  local sparse_paths=()
  for skill in "${skills[@]}"; do
    sparse_paths+=("$repo_prefix/$skill")
  done

  (
    cd "$tmp_dir/repo"
    git sparse-checkout init --cone
    git sparse-checkout set "${sparse_paths[@]}"
    git checkout 2>/dev/null
  )

  for skill in "${skills[@]}"; do
    local src="$tmp_dir/repo/$repo_prefix/$skill"
    local dst="$target_dir/$skill"
    if [ -d "$src" ]; then
      rm -rf "$dst"
      cp -r "$src" "$dst"
      echo "Installed skill: $skill -> $dst"
    else
      echo "Warning: skill '$skill' not found in $repo_url" >&2
    fi
  done
}

install_ai_tools() {
  echo "========================================"
  echo "Installing/updating AI coding tools..."

  if command -v claude &>/dev/null; then
    echo "Updating Claude Code..."
    claude update || echo "Claude update failed (may already be latest)"
  else
    echo "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code@latest
  fi

  echo "Installing/updating Codex CLI..."
  npm install -g @openai/codex@latest

  echo "Installing/updating Copilot CLI..."
  npm install -g @github/copilot@latest

  echo "Installing/updating OpenCode..."
  npm install -g opencode-ai@latest

  echo "AI tools installation complete!"
  echo "========================================"
}

configure_claude() {
  echo "========================================"
  echo "Configuring Claude global instructions..."

  mkdir -p ~/.claude
  mkdir -p ~/.claude/commands

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.claude/CLAUDE.md

  install_skills ~/.claude/skills \
    https://github.com/openai/skills skills/.curated \
    gh-address-comments gh-fix-ci

  install_skills ~/.claude/skills \
    https://github.com/anthropics/skills skills \
    pdf

  write_interview_prompt ~/.claude/commands/interview.md \
    "---" \
    "description: Interview me about the plan" \
    "argument-hint: [plan]" \
    "model: claude-opus-4-6" \
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

  install_skills ~/.codex/skills \
    https://github.com/openai/skills skills/.curated \
    gh-address-comments gh-fix-ci pdf

  write_interview_prompt ~/.codex/prompts/interview.md \
    "---" \
    "description: Interview me about the plan" \
    "argument-hint: [plan]" \
    "---"

  backup_if_exists ~/.codex/config.toml

  cat >~/.codex/config.toml <<'EOT'
model = "gpt-5.3-codex"
model_reasoning_effort = "high"
tool_output_token_limit = 25000
# Leave room for native compaction near the 272-273k context window.
# Formula: 273000 - (tool_output_token_limit + 15000)
# With tool_output_token_limit=25000 => 273000 - (25000 + 15000) = 233000
model_auto_compact_token_limit = 233000
web_search = "cached"

[features]
unified_exec = true
apply_patch_freeform = true
shell_snapshot = true
multi_agent = true
collaboration_modes = true
steer=true
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
    "model: openai/gpt-5.3-codex" \
    "---"

  backup_if_exists ~/.config/opencode/opencode.json

  cat >~/.config/opencode/opencode.json <<'EOT'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "openai/gpt-5.3-codex",
  "provider": {
    "openai": {
      "models": {
        "gpt-5.3-codex": {
          "options": {
            "reasoningEffort": "high"
          }
        }
      }
    }
  },
  "permission": {
    "webfetch": "allow"
  }
}
EOT

  echo "OpenCode configuration complete!"
  echo "========================================"
}

configure_copilot() {
  echo "========================================"
  echo "Configuring Copilot global instructions..."

  mkdir -p ~/.copilot
  mkdir -p ~/.copilot/agents

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.copilot/copilot-instructions.md

  backup_if_exists ~/.copilot/config.json

  cat >~/.copilot/config.json <<'EOT'
{
  "model": "gpt-5.3-codex",
  "reasoning_effort": "high"
}
EOT

  # Copilot CLI doesn't support custom slash commands yet (github/copilot-cli#618).
  # Use an agent file as a workaround for the interview workflow.
  cat >~/.copilot/agents/interview.agent.md <<'EOT'
---
name: interview
description: Interview me about a plan file
tools: ["read", "edit", "search"]
---

EOT
  printf '%s\n' "$INTERVIEW_COMMAND_CONTENT" >>~/.copilot/agents/interview.agent.md

  echo "Copilot configuration complete!"
  echo "========================================"
}
