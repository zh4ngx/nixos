#!/usr/bin/env bash
# Client-side auto-compact nudge for Claude Code.
#
# The API's compact_20260112 server-side trigger checks per-request
# usage.input_tokens, which under prompt caching is the FRESH/uncached portion
# only (typically 1-6 tokens per turn). It never fires for long sessions.
#
# This UserPromptSubmit hook reads the latest usage object from the session's
# JSONL transcript, sums input + cache_read + cache_creation, and if the total
# exceeds AUTO_COMPACT_NUDGE_THRESHOLD (default 400000) emits an
# additionalContext system note instructing the model to invoke /compact.
set -euo pipefail

THRESHOLD="${AUTO_COMPACT_NUDGE_THRESHOLD:-400000}"

input=$(cat)

parsed=$(jq -r '[.session_id // "", .workspace.current_dir // "", .model.model_id // ""] | @tsv' <<<"$input")
IFS=$'\t' read -r session_id current_dir model_id <<<"$parsed"

[[ -z "$session_id" || -z "$current_dir" ]] && exit 0

agent_dir="$HOME/.claude-opus"
case "$model_id" in
  *opus*) agent_dir="$HOME/.claude-opus" ;;
  *glm*)  agent_dir="$HOME/.claude-glm" ;;
esac

slug=$(printf '%s' "$current_dir" | sed 's|/|-|g')
jsonl="$agent_dir/projects/$slug/$session_id.jsonl"

[[ -f "$jsonl" ]] || exit 0

last_usage_line=$(grep -F '"usage":{' "$jsonl" | tail -1)
[[ -n "$last_usage_line" ]] || exit 0

total=$(jq -r '
  (.message.usage // .usage) as $u
  | (($u.input_tokens // 0)
     + ($u.cache_read_input_tokens // 0)
     + ($u.cache_creation_input_tokens // 0))
' <<<"$last_usage_line")

[[ "$total" =~ ^[0-9]+$ ]] || exit 0

if (( total > THRESHOLD )); then
  msg="⚠️ AUTO-COMPACT NUDGE: Conversation context has reached ${total} tokens (threshold ${THRESHOLD}). The compact_20260112 trigger doesn't fire under prompt caching, so this is a client-side nudge. You MUST invoke /compact NOW before continuing the user's task to preserve quality. Hindsight will retain pre-compact state automatically."
  jq -n --arg msg "$msg" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $msg
    }
  }'
fi

exit 0
