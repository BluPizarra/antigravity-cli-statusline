#!/usr/bin/env bash
# Custom status line script for Antigravity CLI (agy)
# Automatically displays model, context, git branch, quotas, and session info.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v python &>/dev/null; then
  python "$SCRIPT_DIR/statusline.py" 2>/dev/null
  exit 0
elif command -v python3 &>/dev/null; then
  python3 "$SCRIPT_DIR/statusline.py" 2>/dev/null
  exit 0
fi

# Fallback in pure bash if python is not available
payload=$(cat)
product=$(echo "$payload" | jq -r '.product // "claude"' 2>/dev/null || echo "antigravity")

reset='\033[0m'; bold='\033[1m'; dim='\033[2m'
red='\033[31m'; green='\033[32m'; yellow='\033[33m'
magenta='\033[35m'; cyan='\033[36m'
sep="${dim} │ ${reset}"

model=$(echo "$payload" | jq -r '.model.display_name // .model.id // .model // "Claude"' 2>/dev/null || echo "Claude")
part_model="${magenta}${model}${reset}"

ctx_pct=$(echo "$payload" | jq -r '.context_window.used_percentage // 0' 2>/dev/null || echo "0")
ctx_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo "0")
filled=$(( ctx_int * 10 / 100 )); empty=$(( 10 - filled ))
bar=""
for ((i=0;i<filled;i++)); do bar+="█"; done
for ((i=0;i<empty;i++)); do bar+="░"; done
if   (( ctx_int >= 80 )); then ctx_color="$red"
elif (( ctx_int >= 50 )); then ctx_color="$yellow"
else                           ctx_color="$green"; fi
part_ctx="${ctx_color}${bar} ${ctx_int}%${reset}"

cwd=$(echo "$payload" | jq -r '.workspace.current_dir // .cwd // ""' 2>/dev/null)
[[ -z "$cwd" ]] && cwd="$PWD"
part_git=""
if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  part_git="${green} ${branch}${reset}"
fi

rate_color() {
  local p; p=$(printf "%.0f" "$1" 2>/dev/null || echo "0")
  if   (( p >= 80 )); then printf "%s" "$red"
  elif (( p >= 50 )); then printf "%s" "$yellow"
  else                     printf "%s" "$green"; fi
}
r5=$(echo "$payload" | jq -r '
  if .quota != null then
    (1 - ([ .quota."gemini-5h".remaining_fraction // 1, .quota."3p-5h".remaining_fraction // 1 ] | min)) * 100
  else
    .rate_limits.five_hour.used_percentage // 0
  end' 2>/dev/null || echo "0")
r7=$(echo "$payload" | jq -r '
  if .quota != null then
    (1 - ([ .quota."gemini-weekly".remaining_fraction // 1, .quota."3p-weekly".remaining_fraction // 1 ] | min)) * 100
  else
    .rate_limits.seven_day.used_percentage // 0
  end' 2>/dev/null || echo "0")
part_r5="$(rate_color $r5)Session:$(printf "%.0f" $r5 2>/dev/null || echo "0")%${reset}"
part_r7="$(rate_color $r7)Weekly:$(printf "%.0f" $r7 2>/dev/null || echo "0")%${reset}"

folder=$(basename "$cwd")
part_folder="${bold}${cyan}${folder}${reset}"

line="$part_model${sep}$part_ctx"
[[ -n "$part_git" ]] && line+="${sep}$part_git"
line+="${sep}$part_r5${sep}$part_r7"
line+="${sep}$part_folder"
printf "%b\n" "$line"
exit 0
