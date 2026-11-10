#!/usr/bin/env python3
import sys
import json
import os
import time

# Ensure UTF-8 output on Windows
if sys.platform == "win32":
    try:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

def get_git_branch(cwd):
    """Finds current git branch by traversing upwards looking for .git (pure Python, fast)."""
    if not cwd:
        return ""
    try:
        cur = os.path.abspath(cwd)
        while True:
            git_path = os.path.join(cur, ".git")
            if os.path.isfile(git_path):
                try:
                    with open(git_path, "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read().strip()
                    if content.startswith("gitdir:"):
                        git_path = os.path.normpath(os.path.join(cur, content[7:].strip()))
                except Exception:
                    pass
            if os.path.isdir(git_path):
                head_file = os.path.join(git_path, "HEAD")
                if os.path.isfile(head_file):
                    try:
                        with open(head_file, "r", encoding="utf-8", errors="ignore") as f:
                            ref = f.read().strip()
                        if ref.startswith("ref: refs/heads/"):
                            return ref[len("ref: refs/heads/"):]
                        elif ref:
                            return ref[:7]
                    except Exception:
                        pass
                break
            parent = os.path.dirname(cur)
            if parent == cur:
                break
            cur = parent
    except Exception:
        pass
    return ""

def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            return
        payload = json.loads(raw)
    except Exception:
        return

    # ANSI Colors
    reset = "\033[0m"
    bold = "\033[1m"
    dim = "\033[2m"
    red = "\033[31m"
    green = "\033[32m"
    yellow = "\033[33m"
    magenta = "\033[35m"
    cyan = "\033[36m"
    sep = f"{dim} │ {reset}"

    # 1. Model
    model_obj = payload.get("model")
    if isinstance(model_obj, dict):
        model = model_obj.get("display_name") or model_obj.get("id") or "Claude"
    elif isinstance(model_obj, str):
        model = model_obj
    else:
        model = "Claude"
    part_model = f"{magenta}{model}{reset}"

    # 2. Context Window
    cw = payload.get("context_window") or {}
    ctx_pct = cw.get("used_percentage") or 0.0
    try:
        ctx_int = int(round(float(ctx_pct)))
    except (ValueError, TypeError):
        ctx_int = 0
    filled = min(10, max(0, ctx_int // 10))
    empty = 10 - filled
    bar = "█" * filled + "░" * empty
    if ctx_int >= 80:
        ctx_color = red
    elif ctx_int >= 50:
        ctx_color = yellow
    else:
        ctx_color = green
    part_ctx = f"{ctx_color}{bar} {ctx_int}%{reset}"

    # 3. Git Branch
    ws = payload.get("workspace") or {}
    cwd = ws.get("current_dir") or payload.get("cwd") or os.getcwd()
    part_git = ""
    branch = get_git_branch(cwd)
    if branch:
        part_git = f"{green}{branch}{reset}"

    # 4 & 5. Rate Limits
    quota = payload.get("quota")
    rate_limits = payload.get("rate_limits") or {}

    def rate_color(p):
        if p >= 80:
            return red
        if p >= 50:
            return yellow
        return green

    if quota and isinstance(quota, dict):
        g5 = quota.get("gemini-5h") if isinstance(quota.get("gemini-5h"), dict) else {}
        p5 = quota.get("3p-5h") if isinstance(quota.get("3p-5h"), dict) else {}
        g5_rem = g5.get("remaining_fraction")
        p5_rem = p5.get("remaining_fraction")
        rem5 = []
        if isinstance(g5_rem, (int, float)): rem5.append(g5_rem)
        if isinstance(p5_rem, (int, float)): rem5.append(p5_rem)
        min_rem5 = min(rem5) if rem5 else 1.0
        r5 = (1.0 - min_rem5) * 100.0

        gw = quota.get("gemini-weekly") if isinstance(quota.get("gemini-weekly"), dict) else {}
        pw = quota.get("3p-weekly") if isinstance(quota.get("3p-weekly"), dict) else {}
        gw_rem = gw.get("remaining_fraction")
        pw_rem = pw.get("remaining_fraction")
        rem7 = []
        if isinstance(gw_rem, (int, float)): rem7.append(gw_rem)
        if isinstance(pw_rem, (int, float)): rem7.append(pw_rem)
        min_rem7 = min(rem7) if rem7 else 1.0
        r7 = (1.0 - min_rem7) * 100.0

        r5_resets = g5.get("reset_time", "") if (g5.get("remaining_fraction", 1.0) < p5.get("remaining_fraction", 1.0)) else p5.get("reset_time", "")
        r7_resets = gw.get("reset_time", "") if (gw.get("remaining_fraction", 1.0) < pw.get("remaining_fraction", 1.0)) else pw.get("reset_time", "")
    else:
        five_h = rate_limits.get("five_hour") if isinstance(rate_limits.get("five_hour"), dict) else {}
        seven_d = rate_limits.get("seven_day") if isinstance(rate_limits.get("seven_day"), dict) else {}
        try:
            r5 = float(five_h.get("used_percentage") or 0.0)
        except (ValueError, TypeError):
            r5 = 0.0
        try:
            r7 = float(seven_d.get("used_percentage") or 0.0)
        except (ValueError, TypeError):
            r7 = 0.0
        r5_resets = five_h.get("resets_at") or ""
        r7_resets = seven_d.get("resets_at") or ""

    r5_int = int(round(r5))
    r7_int = int(round(r7))
    part_r5 = f"{rate_color(r5_int)}Session:{r5_int}%{reset}"
    part_r7 = f"{rate_color(r7_int)}Weekly:{r7_int}%{reset}"

    # 6. Session Duration
    transcript_path = payload.get("transcript_path")
    part_dur = ""
    if transcript_path and os.path.exists(transcript_path):
        try:
            stat = os.stat(transcript_path)
            btime = getattr(stat, 'st_birthtime', None) or stat.st_ctime
            elapsed = int(time.time() - btime)
            if elapsed > 0:
                hrs = elapsed // 3600
                mins = (elapsed % 3600) // 60
                dur = f"{hrs}h {mins:02d}m" if hrs > 0 else f"{mins}m"
                part_dur = f"{dim}{dur}{reset}"
        except Exception:
            pass

    # 7. Folder
    folder = os.path.basename(os.path.normpath(cwd)) if cwd else ""
    part_folder = f"{bold}{cyan}{folder}{reset}"

    # Write rate-cache.json for integrations (both agy and claude)
    cache_data = {
        "r5": r5_int,
        "r7": r7_int,
        "r5_resets_at": str(r5_resets),
        "r7_resets_at": str(r7_resets),
        "context_pct": ctx_int,
        "model": str(model),
        "cwd": str(cwd),
        "ts": int(time.time())
    }
    try:
        user_home = os.path.expanduser("~")
        for target_sub in [os.path.join(".gemini", "antigravity-cli"), ".claude"]:
            target_dir = os.path.join(user_home, target_sub)
            if os.path.exists(target_dir):
                target_file = os.path.join(target_dir, "rate-cache.json")
                tmp_file = target_file + f".tmp.{os.getpid()}"
                with open(tmp_file, "w", encoding="utf-8") as f:
                    json.dump(cache_data, f)
                os.replace(tmp_file, target_file)
    except Exception:
        pass

    # Assemble line
    parts = [part_model, part_ctx]
    if part_git:
        parts.append(part_git)
    parts.append(part_r5)
    parts.append(part_r7)
    if part_dur:
        parts.append(part_dur)
    parts.append(part_folder)

    output = sep.join(parts)
    sys.stdout.write(output + "\n")
    sys.stdout.flush()

if __name__ == "__main__":
    main()
