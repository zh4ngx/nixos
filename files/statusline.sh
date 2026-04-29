#!/usr/bin/env bash

# Read JSON input from stdin
input=$(cat)

# Extract information from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
model_id=$(echo "$input" | jq -r '.model.model_id // empty')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
current_usage=$(echo "$input" | jq '.context_window.current_usage')

# Context window size: use JSON value if available, otherwise infer from model
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
if [ -z "$context_size" ] || [ "$context_size" = "null" ]; then
    # Fallback: infer context window from model ID/name
    case "$model_id" in
        *opus-4-7*|*opus-4.7*)       context_size=1000000 ;; # 1M
        *opus-4-6*|*opus-4.6*)       context_size=200000 ;;  # 200k (1M with beta header)
        *opus-4-5*|*opus-4.5*)       context_size=200000 ;;  # 200k (1M beta)
        *sonnet-4-5*|*sonnet-4.5*)   context_size=200000 ;;  # 200k (1M beta)
        *haiku-4-5*|*haiku-4.5*)     context_size=200000 ;;
        *opus-4-1*|*opus-4.1*)       context_size=200000 ;;
        *sonnet-4*|*claude-4*)       context_size=200000 ;;  # 200k (1M beta)
        *3-7*|*3.7*)                 context_size=200000 ;;
        *3-5*|*3.5*)                 context_size=200000 ;;
        *3-opus*|*3-sonnet*|*3-haiku*) context_size=200000 ;;
        *)                           context_size=200000 ;;  # safe default
    esac
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'
LIGHT_GRAY='\033[38;5;250m'
DARK_GRAY='\033[38;5;238m'

# Helper: format token count (e.g., 1000000 -> "1M", 200000 -> "200k", 45000 -> "45k")
format_tokens() {
    local tokens=$1
    if [ "$tokens" -ge 1000000 ]; then
        local m=$((tokens / 1000000))
        local remainder=$(( (tokens % 1000000) / 100000 ))
        if [ "$remainder" -gt 0 ]; then
            echo "${m}.${remainder}M"
        else
            echo "${m}M"
        fi
    elif [ "$tokens" -ge 1000 ]; then
        echo "$((tokens / 1000))k"
    else
        echo "${tokens}"
    fi
}

# Calculate context percentage (only input-related tokens, not output)
if [ "$current_usage" != "null" ]; then
    input_tokens=$(echo "$current_usage" | jq '.input_tokens // 0')
    cache_create=$(echo "$current_usage" | jq '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$current_usage" | jq '.cache_read_input_tokens // 0')
    current_tokens=$((input_tokens + cache_create + cache_read))
    context_percent=$((current_tokens * 100 / context_size))
    token_display="$(format_tokens $current_tokens)/$(format_tokens $context_size)"
else
    context_percent=0
    token_display="0k/$(format_tokens $context_size)"
fi

# Build context progress bar (15 chars wide)
bar_width=15
filled=$((context_percent * bar_width / 100))
# Cap filled at bar_width to prevent overflow
[ "$filled" -gt "$bar_width" ] && filled=$bar_width
empty=$((bar_width - filled))

bar=""
for ((i = 0; i < filled; i++)); do bar+="${LIGHT_GRAY}█"; done
for ((i = 0; i < empty; i++)); do bar+="${DARK_GRAY}█"; done
bar+="${NC}"

# Cost extraction
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
[ "$session_cost" != "empty" ] && session_cost=$(printf "%.4f" "$session_cost") || session_cost=""

# Compaction count — read from session JSONL.
# Auto-compact (compact_20260112) is functionally inert under prompt caching:
# the trigger checks per-request `input_tokens` (the uncached fresh portion),
# which stays tiny when caching does its job, so it never crosses any
# reasonable threshold even at 500k+ cumulative cached context. This means
# manual reset (`/exit + mz`) is the real quality-protection mechanism. The
# c=N indicator below colors the count by context-percent so a heavy session
# with c=0 lights up RED — that's "manually reset now" signal.
session_id=$(echo "$input" | jq -r '.session_id // empty')
compaction_count=0
if [ -n "$session_id" ] && [ -n "$current_dir" ]; then
    slug=$(echo "$current_dir" | sed 's|/|-|g')
    case "$model_id" in
        *glm*)  agent_dir="$HOME/.claude-glm" ;;
        *opus*) agent_dir="$HOME/.claude-opus" ;;
        *)      agent_dir="$HOME/.claude-opus" ;;
    esac
    jsonl_path="${agent_dir}/projects/${slug}/${session_id}.jsonl"
    if [ -f "$jsonl_path" ]; then
        # grep -c always prints a count to stdout (0 if no match); exit 1 on
        # zero matches is fine — we capture stdout, not exit status.
        compaction_count=$(grep -c '"subtype":"compact_boundary"' "$jsonl_path" 2>/dev/null)
    fi
fi

if [ "$compaction_count" -gt 0 ]; then
    compact_color="${GREEN}"     # compact has fired, healthy churn
elif [ "$context_percent" -gt 75 ]; then
    compact_color="${RED}"       # heavy + no compact = manually reset
elif [ "$context_percent" -gt 50 ]; then
    compact_color="${YELLOW}"    # getting heavy, heads up
else
    compact_color="${GRAY}"      # fine, low context
fi
compact_indicator="${compact_color}c${compaction_count}${NC}"

# Directory info
dir_name=$(basename "$current_dir")
cd "$current_dir" 2>/dev/null || cd /

# Sync indicator
sync_enabled=""
if grep -q "sync_tasks.py" ~/.claude/settings.json 2>/dev/null; then
    sync_enabled=" ${GREEN}⟳${NC}"
fi

# Git information
git_info=""

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || echo "detached")
    status_output=$(git status --porcelain 2>/dev/null)

    if [ -n "$status_output" ]; then
        total_files=$(echo "$status_output" | wc -l | xargs)

        # Staged changes
        staged_stats=$(git diff --numstat --cached 2>/dev/null | awk '{added+=$1; removed+=$2} END {print added+0, removed+0}')
        staged_added=$(echo "$staged_stats" | cut -d' ' -f1)
        staged_removed=$(echo "$staged_stats" | cut -d' ' -f2)

        # Unstaged changes
        unstaged_stats=$(git diff --numstat 2>/dev/null | awk '{added+=$1; removed+=$2} END {print added+0, removed+0}')
        unstaged_added=$(echo "$unstaged_stats" | cut -d' ' -f1)
        unstaged_removed=$(echo "$unstaged_stats" | cut -d' ' -f2)

        # Untracked files
        untracked_lines=$(echo "$status_output" | grep '^??' | cut -c4- | xargs -I {} sh -c 'test -f "{}" && wc -l < "{}" || echo 0' 2>/dev/null | awk '{sum+=$1} END {print sum+0}')

        added=$((staged_added + unstaged_added + untracked_lines))
        removed=$((staged_removed + unstaged_removed))

        git_info=" ${YELLOW}(${branch}${NC} ${YELLOW}|${NC} ${GRAY}${total_files} files${NC}"
        [ "$added" -gt 0 ] && git_info="${git_info} ${GREEN}+${added}${NC}"
        [ "$removed" -gt 0 ] && git_info="${git_info} ${RED}-${removed}${NC}"
        git_info="${git_info} ${YELLOW})${NC}"
    else
        git_info=" ${YELLOW}(${branch})${NC}"
    fi
fi

# Output
context_info="${bar} ${token_display} (${context_percent}%) ${compact_indicator}"
echo -e "${BLUE}${dir_name}${NC} ${GRAY}|${NC} ${CYAN}${model_name}${NC} ${GRAY}|${NC} ${context_info}${sync_enabled}${git_info:+ ${GRAY}|${NC}}${git_info}"
