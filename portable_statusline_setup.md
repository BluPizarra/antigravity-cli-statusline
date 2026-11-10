# Portable Antigravity CLI Status Line Setup Guide

This guide provides a completely self-contained installer script that your brother can run on his own system to configure the custom status line.

---

## 1. Quick One-Line Installation

He can copy and paste the following bash command block in his terminal to automatically create the script inside his global `~/.gemini/antigravity-cli/` directory and configure the CLI settings:

```bash
# Create the config directory if it doesn't exist
mkdir -p ~/.gemini/antigravity-cli

# Write the status line rendering script
cat << 'EOF' > ~/.gemini/antigravity-cli/statusline.sh
#!/usr/bin/env bash
payload=$(cat)
product=$(echo "$payload" | jq -r '.product // "claude"')

reset='\033[0m'; bold='\033[1m'; dim='\033[2m'
red='\033[31m'; green='\033[32m'; yellow='\033[33m'
magenta='\033[35m'; cyan='\033[36m'
sep="${dim} │ ${reset}"

# 1. Model
model=$(echo "$payload" | jq -r '.model.display_name // .model.id // .model // "Claude"')
part_model="${magenta}${model}${reset}"

# 2. Context Window
ctx_pct=$(echo "$payload" | jq -r '.context_window.used_percentage // 0')
ctx_int=$(printf "%.0f" "$ctx_pct")
filled=$(( ctx_int * 10 / 100 )); empty=$(( 10 - filled ))
bar=""
for ((i=0;i<filled;i++)); do bar+="█"; done
for ((i=0;i<empty;i++)); do bar+="░"; done
if   (( ctx_int >= 80 )); then ctx_color="$red"
elif (( ctx_int >= 50 )); then ctx_color="$yellow"
else                           ctx_color="$green"; fi
part_ctx="${ctx_color}${bar} ${ctx_int}%${reset}"

# 3. Git Branch
cwd=$(echo "$payload" | jq -r '.workspace.current_dir // .cwd // ""')
[[ -z "$cwd" ]] && cwd="$PWD"
part_git=""
if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  part_git="${green} ${branch}${reset}"
fi

# 4 & 5. Rate Limits
rate_color() {
  local p; p=$(printf "%.0f" "$1")
  if   (( p >= 80 )); then printf "%s" "$red"
  elif (( p >= 50 )); then printf "%s" "$yellow"
  else                     printf "%s" "$green"; fi
}
r5=$(echo "$payload" | jq -r '
  if .quota != null then
    (1 - ([ .quota."gemini-5h".remaining_fraction // 1, .quota."3p-5h".remaining_fraction // 1 ] | min)) * 100
  else
    .rate_limits.five_hour.used_percentage // 0
  end')
r7=$(echo "$payload" | jq -r '
  if .quota != null then
    (1 - ([ .quota."gemini-weekly".remaining_fraction // 1, .quota."3p-weekly".remaining_fraction // 1 ] | min)) * 100
  else
    .rate_limits.seven_day.used_percentage // 0
  end')
r5_resets=$(echo "$payload" | jq -r '
  if .quota != null then
    if (.quota."gemini-5h".remaining_fraction // 1) < (.quota."3p-5h".remaining_fraction // 1) then
      .quota."gemini-5h".reset_time // ""
    else
      .quota."3p-5h".reset_time // ""
    end
  elif .rate_limits.five_hour.resets_at != null then
    .rate_limits.five_hour.resets_at
  else
    ""
  end')
r7_resets=$(echo "$payload" | jq -r '
  if .quota != null then
    if (.quota."gemini-weekly".remaining_fraction // 1) < (.quota."3p-weekly".remaining_fraction // 1) then
      .quota."gemini-weekly".reset_time // ""
    else
      .quota."3p-weekly".reset_time // ""
    end
  elif .rate_limits.seven_day.resets_at != null then
    .rate_limits.seven_day.resets_at
  else
    ""
  end')
part_r5="$(rate_color $r5)Session:$(printf "%.0f" $r5)%${reset}"
part_r7="$(rate_color $r7)Weekly:$(printf "%.0f" $r7)%${reset}"

# 6. Session Duration
transcript=$(echo "$payload" | jq -r '.transcript_path // ""')
part_dur=""
if [[ -n "$transcript" && -e "$transcript" ]]; then
  btime=$(stat -f %B "$transcript" 2>/dev/null || stat -c %Z "$transcript" 2>/dev/null)
  if [[ -n "$btime" && "$btime" != "0" ]]; then
    elapsed=$(( $(date +%s) - btime ))
    hrs=$(( elapsed / 3600 )); mins=$(( (elapsed % 3600) / 60 ))
    if (( hrs > 0 )); then
      dur="${hrs}h $(printf "%02d" $mins)m"
    else
      dur="${mins}m"
    fi
    part_dur="${dim}${dur}${reset}"
  fi
fi

# 7. Folder
folder=$(basename "$cwd")
part_folder="${bold}${cyan}${folder}${reset}"

# Write rate-cache.json for integrations
if [[ "$product" == "antigravity" ]]; then
  mkdir -p "$HOME/.gemini/antigravity-cli" 2>/dev/null || true
  jq -n \
    --argjson r5    "$(printf "%.0f" $r5)" \
    --argjson r7    "$(printf "%.0f" $r7)" \
    --arg     r5at  "$r5_resets" \
    --arg     r7at  "$r7_resets" \
    --argjson ctx   "$ctx_int" \
    --arg     model "$model" \
    --arg     cwd   "$cwd" \
    --argjson ts    "$(date +%s)" \
    '{r5:$r5,r7:$r7,r5_resets_at:$r5at,r7_resets_at:$r7at,context_pct:$ctx,model:$model,cwd:$cwd,ts:$ts}' \
    > "$HOME/.gemini/antigravity-cli/rate-cache.json" 2>/dev/null || true
else
  jq -n \
    --argjson r5    "$(printf "%.0f" $r5)" \
    --argjson r7    "$(printf "%.0f" $r7)" \
    --arg     r5at  "$r5_resets" \
    --arg     r7at  "$r7_resets" \
    --argjson ctx   "$ctx_int" \
    --arg     model "$model" \
    --arg     cwd   "$cwd" \
    --argjson ts    "$(date +%s)" \
    '{r5:$r5,r7:$r7,r5_resets_at:$r5at,r7_resets_at:$r7at,context_pct:$ctx,model:$model,cwd:$cwd,ts:$ts}' \
    > "$HOME/.claude/rate-cache.json" 2>/dev/null || true
fi

# Print final status line
line="$part_model${sep}$part_ctx"
[[ -n "$part_git" ]] && line+="${sep}$part_git"
line+="${sep}$part_r5${sep}$part_r7"
[[ -n "$part_dur" ]] && line+="${sep}$part_dur"
line+="${sep}$part_folder"
printf "%b\n" "$line"
EOF

# Make the status line script executable
chmod +x ~/.gemini/antigravity-cli/statusline.sh

# Safely append or merge the configuration block in settings.json
SETTINGS_FILE="$HOME/.gemini/antigravity-cli/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    # Merge using jq to keep existing options
    temp_file=$(mktemp)
    jq --arg script "$HOME/.gemini/antigravity-cli/statusline.sh" '.statusLine = {"type": "command", "command": $script}' "$SETTINGS_FILE" > "$temp_file"
    mv "$temp_file" "$SETTINGS_FILE"
else
    # Create brand new settings file
    cat << EOF > "$SETTINGS_FILE"
{
  "statusLine": {
    "type": "command",
    "command": "$HOME/.gemini/antigravity-cli/statusline.sh"
  }
}
EOF
fi

echo "Status line successfully installed! Please restart agy to see it."
```

---

## 2. Requirements

* **`jq`**: The script uses `jq` to parse JSON metrics from the CLI. Ensure it is installed on the machine (e.g. `sudo apt install jq` or `brew install jq`).
* **`git`**: Used to retrieve branch information inside git workspaces.
* **Terminal font**: The progress bar is rendered using standard unicode blocks (█░), which render cleanly in standard terminal settings. No Nerd Fonts are strictly required.
