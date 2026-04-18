#!/bin/zsh

set -euo pipefail

file="${1:-.make-settings}"
action="${2:-}"

[[ -f "$file" ]] && source "$file"

COMBO="${COMBO:-tahoe}"
TAHOE_MORNING_START="${TAHOE_MORNING_START:-0600}"
TAHOE_DAY_START="${TAHOE_DAY_START:-1200}"
TAHOE_EVENING_START="${TAHOE_EVENING_START:-1800}"
TAHOE_NIGHT_START="${TAHOE_NIGHT_START:-2200}"
SEQUOIA_MORNING_START="${SEQUOIA_MORNING_START:-0600}"
SEQUOIA_SUNRISE_START="${SEQUOIA_SUNRISE_START:-1200}"
SEQUOIA_NIGHT_START="${SEQUOIA_NIGHT_START:-2100}"

save() {
  cat > "$file" <<EOF
COMBO=$COMBO
TAHOE_MORNING_START=$TAHOE_MORNING_START
TAHOE_DAY_START=$TAHOE_DAY_START
TAHOE_EVENING_START=$TAHOE_EVENING_START
TAHOE_NIGHT_START=$TAHOE_NIGHT_START
SEQUOIA_MORNING_START=$SEQUOIA_MORNING_START
SEQUOIA_SUNRISE_START=$SEQUOIA_SUNRISE_START
SEQUOIA_NIGHT_START=$SEQUOIA_NIGHT_START
EOF
}

print_settings() {
  echo "combo: $COMBO"
  if [[ "$COMBO" == "sequoia" ]]; then
    echo "morning: $SEQUOIA_MORNING_START"
    echo "sunrise: $SEQUOIA_SUNRISE_START"
    echo "night: $SEQUOIA_NIGHT_START"
  else
    echo "morning: $TAHOE_MORNING_START"
    echo "day: $TAHOE_DAY_START"
    echo "evening: $TAHOE_EVENING_START"
    echo "night: $TAHOE_NIGHT_START"
  fi
}

write_plist() {
  local template="$3" output="$4" label="$5" executable="$6" stdout_log="$7" stderr_log="$8"
  sed \
    -e "s|__LABEL__|$label|g" \
    -e "s|__STDOUT_LOG__|$stdout_log|g" \
    -e "s|__STDERR_LOG__|$stderr_log|g" \
    "$template" | awk \
    -v combo="$COMBO" -v exe="$executable" \
    -v tm="$TAHOE_MORNING_START" -v td="$TAHOE_DAY_START" -v te="$TAHOE_EVENING_START" -v tn="$TAHOE_NIGHT_START" \
    -v sm="$SEQUOIA_MORNING_START" -v ss="$SEQUOIA_SUNRISE_START" -v sn="$SEQUOIA_NIGHT_START" '
      function emit(hhmm, h, m) {
        h = substr(hhmm,1,2) + 0
        m = substr(hhmm,3,2) + 0
        print "    <dict>"
        print "      <key>Hour</key>"
        print "      <integer>" h "</integer>"
        print "      <key>Minute</key>"
        print "      <integer>" m "</integer>"
        print "    </dict>"
      }
      function program_args() {
        print "  <key>ProgramArguments</key>"
        print "  <array>"
        print "    <string>" exe "</string>"
        print "    <string>auto</string>"
        print "    <string>--combo</string>"
        print "    <string>" combo "</string>"
        if (combo == "sequoia") {
          print "    <string>--morning-start</string>"
          print "    <string>" sm "</string>"
          print "    <string>--sunrise-start</string>"
          print "    <string>" ss "</string>"
          print "    <string>--night-start</string>"
          print "    <string>" sn "</string>"
        } else {
          print "    <string>--morning-start</string>"
          print "    <string>" tm "</string>"
          print "    <string>--day-start</string>"
          print "    <string>" td "</string>"
          print "    <string>--evening-start</string>"
          print "    <string>" te "</string>"
          print "    <string>--night-start</string>"
          print "    <string>" tn "</string>"
        }
        print "  </array>"
      }
      /__PROGRAM_ARGUMENTS__/ {
        program_args()
        next
      }
      /__START_CALENDAR_INTERVAL__/ {
        print "  <key>StartCalendarInterval</key>"
        print "  <array>"
        if (combo == "sequoia") {
          emit(sm); emit(ss); emit(sn)
        } else {
          emit(tm); emit(td); emit(te); emit(tn)
        }
        print "  </array>"
        next
      }
      { print }
    ' > "$output"
}

case "$action" in
  print)
    print_settings
    ;;
  auto)
    if [[ "$COMBO" == "sequoia" ]]; then
      echo "--combo sequoia --morning-start $SEQUOIA_MORNING_START --sunrise-start $SEQUOIA_SUNRISE_START --night-start $SEQUOIA_NIGHT_START"
    else
      echo "--combo tahoe --morning-start $TAHOE_MORNING_START --day-start $TAHOE_DAY_START --evening-start $TAHOE_EVENING_START --night-start $TAHOE_NIGHT_START"
    fi
    ;;
  choose-combo)
    read "?Choose combo [tahoe/sequoia] (default: $COMBO): " value
    case "${value:-$COMBO}" in
      tahoe|Tahoe) COMBO=tahoe ;;
      sequoia|Sequoia) COMBO=sequoia ;;
      *) echo "Unsupported combo: ${value:-$COMBO}" >&2; exit 1 ;;
    esac
    save
    echo "Saved combo: $COMBO"
    ;;
  choose-time)
    if [[ "$COMBO" == "sequoia" ]]; then
      read "?Enter morning start (HHmm, default: 0600): " value; SEQUOIA_MORNING_START="${value:-0600}"
      read "?Enter sunrise start (HHmm, default: 1200): " value; SEQUOIA_SUNRISE_START="${value:-1200}"
      read "?Enter night start (HHmm, default: 2100): " value; SEQUOIA_NIGHT_START="${value:-2100}"
    else
      read "?Enter morning start (HHmm, default: 0600): " value; TAHOE_MORNING_START="${value:-0600}"
      read "?Enter day start (HHmm, default: 1200): " value; TAHOE_DAY_START="${value:-1200}"
      read "?Enter evening start (HHmm, default: 1800): " value; TAHOE_EVENING_START="${value:-1800}"
      read "?Enter night start (HHmm, default: 2200): " value; TAHOE_NIGHT_START="${value:-2200}"
    fi
    save
    echo "Saved $COMBO time points"
    ;;
  reset-defaults)
    if [[ "$COMBO" == "sequoia" ]]; then
      SEQUOIA_MORNING_START=0600
      SEQUOIA_SUNRISE_START=1200
      SEQUOIA_NIGHT_START=2100
    else
      TAHOE_MORNING_START=0600
      TAHOE_DAY_START=1200
      TAHOE_EVENING_START=1800
      TAHOE_NIGHT_START=2200
    fi
    save
    echo "Reset $COMBO time points to defaults"
    ;;
  write-plist)
    write_plist "$@"
    ;;
  *)
    echo "usage: settings.sh [settings-file] [print|auto|choose-combo|choose-time|reset-defaults|write-plist]" >&2
    exit 1
    ;;
esac
