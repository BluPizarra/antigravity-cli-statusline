# Antigravity CLI Status Line Sharing Guide

This guide contains the configuration and script necessary to enable and customize the status line in **Antigravity CLI (`agy`)**. 

---

## 1. The Configuration (`settings.json`)

To enable the status line, add or update the `statusLine` configuration block in the global settings file:
* **File Location**: `~/.gemini/antigravity-cli/settings.json` (on macOS/Linux) or `%USERPROFILE%\.gemini\antigravity-cli\settings.json` (on Windows).

Add the following block:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/path/to/your/statusline.sh"
  }
}
```

> [!NOTE]
> Make sure to replace `/path/to/your/statusline.sh` with the actual absolute path to where you save the script below.

---

## 2. The Script (`statusline.sh`)

Save the following code block as a script (e.g., `statusline.sh`), and make it executable by running `chmod +x statusline.sh`.

```bash
#!/usr/bin/env bash
# Claude Statusline v8 — managed by Claude Statusline VS Code extension
# Do not edit manually; it will be overwritten on next activation.
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
```

---

## 3. What This Custom Script Displays

* **Model**: Shows the active model name (e.g. Gemini 3.5 Flash) in magenta.
* **Context Bar**: A visual bar (█░) indicating context window utilization, colored dynamically (Green < 50%, Yellow >= 50%, Red >= 80%).
* **Git Branch**: Identifies if you are in a Git workspace and displays the active branch name in green.
* **Session Quota**: Remaining/used 5h Gemini & 3rd party quota percentage.
* **Weekly Quota**: Remaining/used weekly quota percentage.
* **Session Duration**: Calculates and prints the elapsed time of your active agent session in a dim/subtle format.
* **Workspace Folder**: The name of the current folder in bold cyan.
* **VS Code Sync**: Caches model metadata and quota rates in `~/.gemini/antigravity-cli/rate-cache.json` for extension integrations.
