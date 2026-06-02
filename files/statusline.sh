#!/usr/bin/env bash

# Shared Claude Code statusline. This follows Claude's current statusline JSON
# shape; missing fields simply omit their segment.
input=$(cat)

blue='\033[0;34m'
green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
cyan='\033[0;36m'
gray='\033[0;90m'
reset='\033[0m'

fmt_tokens() {
    local n="${1:-}"
    [[ "$n" =~ ^[0-9]+$ ]] || return 0
    if ((n >= 1000000)); then
        printf "%sM" "$((n / 1000000))"
    elif ((n >= 1000)); then
        printf "%sk" "$((n / 1000))"
    else
        printf "%s" "$n"
    fi
}

fmt_ms() {
    local ms="${1:-}"
    [[ "$ms" =~ ^[0-9]+$ ]] || return 0
    local s=$((ms / 1000))
    if ((s >= 3600)); then
        printf "%sh%02dm" "$((s / 3600))" "$(((s % 3600) / 60))"
    elif ((s >= 60)); then
        printf "%sm" "$((s / 60))"
    elif ((s > 0)); then
        printf "%ss" "$s"
    fi
}

join() {
    local sep="${gray} | ${reset}"
    local first=1 part
    for part in "$@"; do
        [[ -n "$part" ]] || continue
        if ((first)); then
            printf "%b" "$part"
            first=0
        else
            printf "%b%b" "$sep" "$part"
        fi
    done
    printf "\n"
}

row=$(
    jq -r '
      def pct:
        if . == null then ""
        elif . <= 1 then ((. * 100) | round | tostring)
        else (. | round | tostring)
        end;

      [
        (.workspace.current_dir // env.PWD),
        (.model.display_name // "Claude"),
        (.effort.level // ""),
        (if .thinking.enabled == true then "think" else "" end),
        (.context_window.used_percentage | pct),
        (.context_window.total_input_tokens // ""),
        (.context_window.context_window_size // ""),
        (.rate_limits.five_hour.used_percentage | pct),
        (.rate_limits.seven_day.used_percentage | pct),
        (.cost.total_cost_usd // ""),
        (.duration_ms // "")
      ] | join("\u001f")
    ' <<<"$input" 2>/dev/null
)

IFS=$'\037' read -r current_dir model effort thinking ctx_pct ctx_tokens ctx_size five_hour seven_day cost duration_ms <<<"$row"
current_dir="${current_dir:-$PWD}"

dir_segment="${blue}$(basename "$current_dir")${reset}"

model_segment="${cyan}${model:-Claude}${reset}"
[[ -n "$effort" ]] && model_segment+=" ${gray}${effort}${reset}"
[[ -n "$thinking" ]] && model_segment+=" ${yellow}${thinking}${reset}"

ctx_segment=""
if [[ "$ctx_pct" =~ ^[0-9]+$ ]]; then
    ctx_color="$green"
    ((ctx_pct >= 80)) && ctx_color="$red"
    ((ctx_pct >= 60 && ctx_pct < 80)) && ctx_color="$yellow"
    ctx_segment="${ctx_color}ctx ${ctx_pct}%${reset}"
    if [[ "$ctx_tokens" =~ ^[0-9]+$ && "$ctx_size" =~ ^[0-9]+$ ]]; then
        ctx_segment+=" ${gray}$(fmt_tokens "$ctx_tokens")/$(fmt_tokens "$ctx_size")${reset}"
    fi
fi

limits_segment=""
if [[ -n "$five_hour" || -n "$seven_day" ]]; then
    limits_segment="${gray}limits${reset}"
    [[ -n "$five_hour" ]] && limits_segment+=" 5h ${five_hour}%"
    [[ -n "$seven_day" ]] && limits_segment+=" 7d ${seven_day}%"
fi

cost_segment=""
if [[ "$cost" =~ ^[0-9]+([.][0-9]+)?$ && ! "$cost" =~ ^0([.]0*)?$ ]]; then
    cost_segment="${gray}\$$(printf "%.2f" "$cost")${reset}"
fi
duration=$(fmt_ms "$duration_ms")
[[ -n "$duration" ]] && cost_segment+=" ${gray}${duration}${reset}"

git_segment=""
if cd "$current_dir" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    [[ -n "$branch" ]] || branch=$(git rev-parse --short HEAD 2>/dev/null || true)
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    git_segment="${yellow}${branch:-detached}${reset}"
    [[ "$dirty" != "0" ]] && git_segment+=" ${yellow}~${dirty}${reset}"
fi

join "$dir_segment" "$model_segment" "$ctx_segment" "$limits_segment" "$cost_segment" "$git_segment"
