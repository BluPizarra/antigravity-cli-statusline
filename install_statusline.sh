#!/usr/bin/env bash
# Antigravity CLI Status Line Installer
# Run this script to automatically install and configure the status line.

set -e

# Target paths
CONFIG_DIR="$HOME/.gemini/antigravity-cli"
STATUSLINE_SCRIPT="$CONFIG_DIR/statusline.sh"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

echo "=== Antigravity CLI Status Line Installer ==="

# 1. Ensure configuration directory exists
mkdir -p "$CONFIG_DIR"

# 2. Check for dependencies
if ! command -v jq &> /dev/null; then
    echo "⚠️  Warning: 'jq' is not installed. This status line script relies on 'jq' to parse metrics."
    echo "Please install it using your package manager (e.g., 'brew install jq' or 'sudo apt install jq')."
fi

# 3. Create the statusline.sh script
echo "Writing status line script to $STATUSLINE_SCRIPT..."
cat << 'EOF' > "$STATUSLINE_SCRIPT"
#!/usr/bin/env bash
# Custom status line script for Antigravity CLI (agy)
# Automatically displays model, context, git branch, quotas, and session info.

payload=$(cat)
product=$(echo "$payload" | jq -r '.product // "claude"')

reset='\033[0m'; bold='\033[1m'; dim='\033[2m'
red='\033[31m'; green='\033[32m'; yellow='\033[33m'
magenta='\033[35m'; cyan='\033[36m'
sep="${dim} │ ${reset}"

# ── 1. Model ────────────────────────────────────────────────────────────────
model=$(echo "$payload" | jq -r '.model.display_name // .model.id // .model // "Claude"')
part_model="${magenta}${model}${reset}"

# ── 2. Context window ───────────────────────────────────────────────────────
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

# ── 3. Git branch ───────────────────────────────────────────────────────────
cwd=$(echo "$payload" | jq -r '.workspace.current_dir // .cwd // ""')
[[ -z "$cwd" ]] && cwd="$PWD"
part_git=""
if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  part_git="${green} ${branch}${reset}"
fi

# ── 4 & 5. Rate limits ──────────────────────────────────────────────────────
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

# ── 6. Session duration ─────────────────────────────────────────────────────
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

# ── 7. Folder ───────────────────────────────────────────────────────────────
folder=$(basename "$cwd")
part_folder="${bold}${cyan}${folder}${reset}"

# ── Write rate-cache.json for VS Code extension ─────────────────────────────
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

# ── Assemble and print ──────────────────────────────────────────────────────
line="$part_model${sep}$part_ctx"
[[ -n "$part_git" ]] && line+="${sep}$part_git"
line+="${sep}$part_r5${sep}$part_r7"
[[ -n "$part_dur" ]] && line+="${sep}$part_dur"
line+="${sep}$part_folder"
printf "%b\n" "$line"
EOF

chmod +x "$STATUSLINE_SCRIPT"
echo "✅ Custom status line script installed to $STATUSLINE_SCRIPT"

# 4. Update settings.json
echo "Configuring $SETTINGS_FILE..."
if [ -f "$SETTINGS_FILE" ]; then
    # Merge statusLine setting into existing settings.json
    temp_file=$(mktemp)
    jq --arg script "$STATUSLINE_SCRIPT" '.statusLine = {"type": "command", "command": $script}' "$SETTINGS_FILE" > "$temp_file"
    mv "$temp_file" "$SETTINGS_FILE"
else
    # Create new settings.json
    cat << EOF > "$SETTINGS_FILE"
{
  "statusLine": {
    "type": "command",
    "command": "$STATUSLINE_SCRIPT"
  }
}
EOF
fi

echo "✅ Settings updated successfully!"
echo "🎉 Status line configuration is complete. Restart your Antigravity CLI ('agy') to see it in action!"
