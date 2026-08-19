#!/bin/bash
# Claude Code status line, mirroring the Codex CLI status line:
#   model effort · dir · branch · Context N% used · weekly N% left · version · NK window · Fast on/off
# Receives session JSON on stdin: https://code.claude.com/docs/en/statusline

input=$(cat)

mapfile -t f < <(jq -r '
  (.model.display_name // .model.id // "?"),
  (.effort.level // ""),
  (.workspace.current_dir // .cwd // ""),
  (.version // "?"),
  (.context_window.used_percentage // 0 | round | tostring),
  ((.context_window.context_window_size // 0) as $w |
   if $w >= 1000000 then ((($w / 100000) | round / 10) | tostring | sub("\\.0$"; "") + "M")
   else (($w / 1000) | round | tostring) + "K" end),
  (if .rate_limits.seven_day.used_percentage != null
   then (100 - .rate_limits.seven_day.used_percentage | round | tostring)
   else "" end),
  (if .fast_mode then "on" else "off" end)
' <<<"$input")

model="${f[0]}" effort="${f[1]}" dir="${f[2]}" version="${f[3]}"
ctx_pct="${f[4]}" window="${f[5]}" weekly_left="${f[6]}" fast="${f[7]}"

branch=$(git -C "$dir" branch --show-current 2>/dev/null)

parts=()
if [ -n "$effort" ]; then
  parts+=("$model $effort")
else
  parts+=("$model")
fi
parts+=("${dir/#$HOME/\~}")
[ -n "$branch" ] && parts+=("$branch")
parts+=("Context ${ctx_pct}% used")
[ -n "$weekly_left" ] && parts+=("weekly ${weekly_left}% left")
parts+=("$version" "${window} window" "Fast $fast")

out="${parts[0]}"
for p in "${parts[@]:1}"; do
  out+=" · $p"
done
printf '%s\n' "$out"
