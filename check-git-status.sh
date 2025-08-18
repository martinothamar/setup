#!/bin/bash

echo "Checking git repositories for uncommitted changes and stashes..."
echo "============================================================"

find . -maxdepth 3 -name ".git" -type d | while read -r git_dir; do
    repo_dir=$(dirname "$git_dir")
    echo
    echo "Checking repository: $repo_dir"
    echo "----------------------------------------"
    
    cd "$repo_dir" || continue
    
    # Check for uncommitted changes
    if ! git diff --quiet --exit-code || ! git diff --cached --quiet --exit-code; then
        echo "⚠️  UNCOMMITTED CHANGES FOUND:"
        
        # Show unstaged changes
        if ! git diff --quiet --exit-code; then
            echo "  • Unstaged changes:"
            git diff --name-only | sed 's/^/    /'
        fi
        
        # Show staged changes
        if ! git diff --cached --quiet --exit-code; then
            echo "  • Staged changes:"
            git diff --cached --name-only | sed 's/^/    /'
        fi
        
        # Show untracked files
        untracked=$(git ls-files --others --exclude-standard)
        if [ -n "$untracked" ]; then
            echo "  • Untracked files:"
            echo "$untracked" | sed 's/^/    /'
        fi
    else
        echo "✅ No uncommitted changes"
    fi
    
    # Check for commits that haven't been pushed
    current_branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$current_branch" ]; then
        # Get the upstream branch
        upstream=$(git rev-parse --abbrev-ref "$current_branch@{upstream}" 2>/dev/null)
        if [ -n "$upstream" ]; then
            # Check if there are unpushed commits
            unpushed=$(git log "$upstream..HEAD" --oneline 2>/dev/null)
            if [ -n "$unpushed" ]; then
                unpushed_count=$(echo "$unpushed" | wc -l)
                echo "🚀 UNPUSHED COMMITS FOUND ($unpushed_count):"
                echo "$unpushed" | sed 's/^/  /'
            else
                echo "✅ No unpushed commits"
            fi
        else
            echo "ℹ️  No upstream branch configured for $current_branch"
        fi
    else
        echo "ℹ️  Not on any branch (detached HEAD)"
    fi
    
    # Check for stashes
    stash_count=$(git stash list | wc -l)
    if [ "$stash_count" -gt 0 ]; then
        echo "📦 STASHES FOUND ($stash_count):"
        git stash list | sed 's/^/  /'
    else
        echo "✅ No stashes"
    fi
    
    cd - > /dev/null
done

echo
echo "============================================================"
echo "Git repository check complete!"