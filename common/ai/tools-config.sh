#!/bin/bash

# Absolute path to this file's directory — used to reference bundled skills
_AI_CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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

TASK-TYPE APPLICABILITY RULES:
- Use the development workflow below only for implementation/refactor/debug tasks that change code
- For review-only tasks (code review, design review, architecture review), do not force development workflow sections
- For review-only tasks, use the review response contract in this file

MANDATORY DEVELOPMENT WORKFLOW RULES:
- For non-trivial implementation/refactor/debug tasks, use this sequence and do not skip phases:
  - Phase 0 - Prior-art scan
    - Search the codebase for existing patterns/utilities before designing new code
    - Prefer extending/consolidating existing implementations over adding parallel logic
    - If similar code is not reused, explain why (mismatch, constraints, or risk)
  - Phase 1 - Design (no code edits yet)
    - Provide 2-3 viable approaches with tradeoffs: complexity, maintainability, performance, and risk
    - Recommend one approach and explain why other options were rejected
    - If requirements are ambiguous or conflicting, ask focused questions before implementation
  - Phase 2 - Implement
    - Implement only the selected design
    - Keep the diff minimal and avoid new duplication
  - Phase 3 - Simplify
    - Re-read the code and remove redundancy, dead code, and over-abstractions
    - Consolidate repeated logic/test setup using helpers or table-driven tests when reuse is real
  - Phase 4 - Verify
    - Run relevant checks (lint, tests, static analysis, type checks) before finalizing
    - If checks cannot run, state exactly which commands were not run and why
  - Phase 5 - Independent review
    - Request review from an independent subagent/reviewer when available
    - Reviewer focus: design quality, duplication, regressions, test gaps, and unnecessary complexity
    - If subagent/reviewer is unavailable, perform a strict self-review using the same checklist and state this limitation
- For trivial implementation edits, use a lightweight version of this flow, but still do a self-review and verification pass
- Never finalize implementation work without an explicit DRY/simplification pass

FINAL RESPONSE CONTRACT (DEVELOPMENT TASKS ONLY):
- Keep output concise
- Include:
  - Design decision summary
  - Prior-art/reuse summary (what existing code was considered, reused, or intentionally not reused)
  - Simplification summary (what duplication/redundancy was removed)
  - Verification summary (commands run + outcome, or precise gaps)
  - Review summary (reviewer findings, or explicit self-review fallback)

FINAL RESPONSE CONTRACT (REVIEW-ONLY TASKS):
- Keep output concise
- Include:
  - Findings first, ordered by severity, with file/line references when available
  - Open questions/assumptions

Some rules can appear to be in contradicting and must be decided on based on domain and context, prompt the user if needed.
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

# _dir_checksum DIR — stable content hash of all files under DIR
_dir_checksum() {
  (cd "$1" && find . -type f | sort | xargs sha256sum 2>/dev/null | awk '{print $1}' | sha256sum | cut -d' ' -f1)
}

# install_local_skills TARGET_DIR SRC_DIR SKILL...
install_local_skills() {
  local target_dir="${1-}"
  local src_dir="${2-}"
  if [ -z "$target_dir" ] || [ -z "$src_dir" ]; then
    echo "install_local_skills: missing required arguments" >&2
    return 1
  fi
  shift 2
  local skills=("$@")
  if [ "${#skills[@]}" -eq 0 ]; then
    echo "install_local_skills: no skills specified" >&2
    return 1
  fi

  mkdir -p "$target_dir"

  for skill in "${skills[@]}"; do
    local src="$src_dir/$skill"
    local dst="$target_dir/$skill"
    if [ ! -d "$src" ]; then
      echo "Warning: local skill '$skill' not found at $src" >&2
      continue
    fi
    if [ -d "$dst" ] && [ "$(_dir_checksum "$src")" = "$(_dir_checksum "$dst")" ]; then
      echo "Skill up to date: $skill"
      continue
    fi
    rm -rf "$dst"
    cp -r "$src" "$dst"
    echo "Installed skill: $skill -> $dst"
  done
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

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.claude/CLAUDE.md

  install_local_skills ~/.claude/skills "$_AI_CONFIG_DIR/skills" \
    gh-address-comments gh-fix-ci interview design-review distsys-review

  install_skills ~/.claude/skills \
    https://github.com/anthropics/skills skills \
    pdf

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

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.codex/AGENTS.md

  install_local_skills ~/.codex/skills "$_AI_CONFIG_DIR/skills" \
    gh-address-comments gh-fix-ci interview design-review distsys-review

  install_skills ~/.codex/skills \
    https://github.com/openai/skills skills/.curated \
    pdf

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

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.config/opencode/AGENTS.md

  # OpenCode discovers skills from ~/.claude/skills/ automatically,
  # so all skills installed for Claude are available here too.

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

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.copilot/copilot-instructions.md

  backup_if_exists ~/.copilot/config.json

  cat >~/.copilot/config.json <<'EOT'
{
  "model": "gpt-5.3-codex",
  "reasoning_effort": "high"
}
EOT

  echo "Copilot configuration complete!"
  echo "========================================"
}
