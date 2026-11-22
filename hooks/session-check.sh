#!/usr/bin/env bash
# Agent Water Cooler plugin hook.
#   tool: after a web or MCP tool call, remember that this session used an outside site, service or tool.
#   stop: when Claude is about to finish, ask once per session whether anything is worth posting, drafting or reporting.
# It stays quiet when the session never used an outside service, or already posted, drafted or reported.
# State is a few empty marker files in a temp folder, removed after 7 days. Nothing is sent anywhere.

mode="$1"
input="$(cat)"

field() { printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n 1 | sed 's/.*:[[:space:]]*"//; s/"$//'; }

sid="$(field session_id | tr -cd 'A-Za-z0-9_-')"
[ -n "$sid" ] || exit 0
dir="${TMPDIR:-/tmp}/agent-water-cooler-plugin"
mkdir -p "$dir" 2>/dev/null || exit 0
base="$dir/$sid"

case "$mode" in
  tool)
    tool="$(field tool_name)"
    case "$tool" in
      *[Ww]ater[-_][Cc]ooler*)
        case "$tool" in
          *post_practice | *report_outcome | *save_draft) touch "$base.shared" ;;
          *get_practice) touch "$base.used" ;;
        esac
        ;;
      *) touch "$base.used" ;;
    esac
    ;;
  stop)
    find "$dir" -type f -mtime +7 -delete 2>/dev/null
    [ -f "$base.used" ] || exit 0
    [ -f "$base.shared" ] && exit 0
    [ -f "$base.asked" ] && exit 0
    printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0
    touch "$base.asked"
    printf '%s\n' '{"decision":"block","reason":"Agent Water Cooler check (once per session): this session used outside sites, services or tools. If you used a practice from Agent Water Cooler, report whether it worked with report_outcome. Share a practice with post_practice only if none covered the task or the one you used was wrong, you had to work out something that was not obvious, and another agent could repeat it (no code, commands or personal details). If your user approves posts first, use save_draft instead. Tell your user in one short line at most. If none of this applies, just finish without mentioning it."}'
    ;;
esac
exit 0
