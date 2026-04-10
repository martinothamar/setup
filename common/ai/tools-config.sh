#!/bin/bash

# Absolute path to this file's directory — used to reference bundled skills
_AI_CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

COMMON_ASSISTANT_INSTRUCTIONS_FILE="$_AI_CONFIG_DIR/AGENTS.md"
if [ ! -f "$COMMON_ASSISTANT_INSTRUCTIONS_FILE" ]; then
  echo "COMMON_ASSISTANT_INSTRUCTIONS file not found: $COMMON_ASSISTANT_INSTRUCTIONS_FILE" >&2
  exit 1
fi
COMMON_ASSISTANT_INSTRUCTIONS="$(cat "$COMMON_ASSISTANT_INSTRUCTIONS_FILE")"

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
    cd "$tmp_dir/repo" || exit
    git sparse-checkout init --cone
    git sparse-checkout set "${sparse_paths[@]}"
    git checkout 2>/dev/null
  ) || return 1

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

  echo "Installing/updating Pi..."
  npm install -g @mariozechner/pi-coding-agent@latest

  echo "AI tools installation complete!"
  echo "========================================"
}

configure_claude() {
  echo "========================================"
  echo "Configuring Claude global instructions..."

  mkdir -p ~/.claude

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.claude/CLAUDE.md

  install_local_skills ~/.claude/skills "$_AI_CONFIG_DIR/skills" \
    gh-address-comments gh-fix-ci interview design-review distsys-review dev-workflow

  install_skills ~/.claude/skills \
    https://github.com/anthropics/skills skills \
    pdf

  install_skills ~/.claude/skills \
    https://github.com/slidevjs/slidev skills \
    slidev

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
    gh-address-comments gh-fix-ci interview design-review distsys-review dev-workflow

  install_skills ~/.codex/skills \
    https://github.com/openai/skills skills/.curated \
    pdf

  install_skills ~/.codex/skills \
    https://github.com/slidevjs/slidev skills \
    slidev

  backup_if_exists ~/.codex/config.toml

  cat >~/.codex/config.toml <<'EOT'
model = "gpt-5.4"
model_reasoning_effort = "high"
tool_output_token_limit = 25000
# Leave room for native compaction near the 272-273k context window.
# Formula: 273000 - (tool_output_token_limit + 15000)
# With tool_output_token_limit=25000 => 273000 - (25000 + 15000) = 233000
model_auto_compact_token_limit = 233000
web_search = "cached"

[agents]
max_threads = 6
max_depth = 1

[features]
unified_exec = true
apply_patch_freeform = true
shell_snapshot = true
multi_agent = true
collaboration_modes = true
steer=true
EOT

  mkdir -p ~/.codex/agents
  backup_if_exists ~/.codex/agents/reviewer.toml

  cat >~/.codex/agents/reviewer.toml <<'EOT'
name = "reviewer"
description = "Code reviewer"
model = "gpt-5.4"
model_reasoning_effort = "xhigh"
sandbox_mode = "read-only"
developer_instructions = """
Review code like an owner.
Prioritize correctness, performance, security, behavior regressions, test methodology and code coverage.
Lead with concrete findings, include reproduction steps when possible, and avoid style-only comments unless they hide a real bug.
"""
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
  "model": "openai/gpt-5.4",
  "provider": {
    "openai": {
      "models": {
        "gpt-5.4": {
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
  "model": "gpt-5.4",
  "reasoning_effort": "high"
}
EOT

  echo "Copilot configuration complete!"
  echo "========================================"
}

configure_pi() {
  echo "========================================"
  echo "Configuring Pi global instructions..."

  mkdir -p ~/.pi/agent

  printf '%s\n' "$COMMON_ASSISTANT_INSTRUCTIONS" >~/.pi/agent/AGENTS.md

  install_local_skills ~/.pi/agent/skills "$_AI_CONFIG_DIR/skills" \
    gh-address-comments gh-fix-ci interview design-review distsys-review dev-workflow

  install_skills ~/.pi/agent/skills \
    https://github.com/openai/skills skills/.curated \
    pdf

  install_skills ~/.pi/agent/skills \
    https://github.com/slidevjs/slidev skills \
    slidev

  mkdir -p ~/.pi/agent/extensions
  if [ ! -f "$_AI_CONFIG_DIR/extensions/minimal-mode.ts" ]; then
    echo "Pi extension not found: $_AI_CONFIG_DIR/extensions/minimal-mode.ts" >&2
    return 1
  fi
  if [ ! -f ~/.pi/agent/extensions/minimal-mode.ts ] || ! cmp -s \
      "$_AI_CONFIG_DIR/extensions/minimal-mode.ts" \
      ~/.pi/agent/extensions/minimal-mode.ts; then
    cp "$_AI_CONFIG_DIR/extensions/minimal-mode.ts" ~/.pi/agent/extensions/minimal-mode.ts
    echo "Installed Pi extension: ~/.pi/agent/extensions/minimal-mode.ts"
  else
    echo "Pi extension up to date: minimal-mode.ts"
  fi

  backup_if_exists ~/.pi/agent/settings.json

  cat >~/.pi/agent/settings.json <<'EOT'
{
  "defaultProvider": "openai-codex",
  "defaultModel": "gpt-5.4",
  "defaultThinkingLevel": "high",
  "theme": "dark",
  "transport": "sse",
  "enabledModels": [
    "openai-codex/gpt-5.4",
    "anthropic/claude-*",
    "google/gemini-*"
  ],
  "compaction": {
    "enabled": true,
    "reserveTokens": 16384,
    "keepRecentTokens": 20000
  },
  "retry": {
    "enabled": true,
    "maxRetries": 3,
    "baseDelayMs": 2000,
    "maxDelayMs": 60000
  },
  "steeringMode": "one-at-a-time",
  "followUpMode": "one-at-a-time"
}
EOT

  echo "Pi configuration complete!"
  echo "========================================"
}
