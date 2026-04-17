#!/bin/zsh

set -euo pipefail

action="$1"
settings_file="$2"
template="$3"
launch_agent_path="$4"
launch_agent_label="$5"
gui_domain="$6"
executable="$7"
stdout_log="$8"
stderr_log="$9"

settings_tool=(zsh ./scripts/settings.sh "$settings_file")

write_plist() {
  mkdir -p "$(dirname "$stdout_log")" "$(dirname "$launch_agent_path")"
  "${settings_tool[@]}" write-plist "$template" "$launch_agent_path" "$launch_agent_label" "$executable" "$stdout_log" "$stderr_log"
  plutil -lint "$launch_agent_path" >/dev/null
}

bootout() {
  launchctl bootout "$gui_domain/$launch_agent_label" 2>/dev/null || true
}

bootstrap() {
  launchctl bootstrap "$gui_domain" "$launch_agent_path"
}

case "$action" in
  sync)
    was_loaded=0
    launchctl print "$gui_domain/$launch_agent_label" >/dev/null 2>&1 && was_loaded=1 || true
    [[ -f "$launch_agent_path" ]] && write_plist
    if [[ "$was_loaded" == 1 ]]; then
      bootout
      bootstrap
      echo "Updated $launch_agent_label schedule"
    fi
    ;;
  install)
    write_plist
    bootout
    bootstrap
    echo "Installed $launch_agent_path"
    ;;
  enable)
    bootout
    bootstrap
    echo "Enabled $launch_agent_label"
    ;;
  disable)
    bootout
    echo "Disabled $launch_agent_label"
    ;;
  reload)
    bootout
    bootstrap
    echo "Reloaded $launch_agent_label"
    ;;
  uninstall)
    bootout
    rm -f "$launch_agent_path"
    echo "Removed $launch_agent_path"
    ;;
  *)
    echo "usage: agent.sh [sync|install|enable|disable|reload|uninstall] ..." >&2
    exit 1
    ;;
esac
