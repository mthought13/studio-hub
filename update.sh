#!/bin/bash
# Studio Hub updater for apps installed from the hub (list in ~/.studio-hub/apps).
# LaunchAgent local.studiohub.update runs it at login and every 10 minutes.
#   update.sh               check; new versions → dialog «Обновить / Позже» (log: ~/.studio-hub/update.log)
#   update.sh --now         the same, printing here
#   update.sh --check       only refresh ~/.studio-hub/pending.json, no dialog (apps call it at launch)
#   update.sh --install ID  install the pending update of ID now (the apps' «Обновить» item)
#   update.sh off           switch auto-update off
DIR="$HOME/.studio-hub"
PLIST="$HOME/Library/LaunchAgents/local.studiohub.update.plist"
MODE="${1:-}"
if [ "$MODE" = off ]; then
  launchctl bootout "gui/$(id -u)/local.studiohub.update" 2>/dev/null
  rm -f "$PLIST"
  echo "Автообновление выключено. Включится снова при следующей установке с хаба."
  exit 0
fi
if [ "$MODE" = --install ] && [ -z "${HUB_DETACHED:-}" ]; then
  # An app that runs this as its child would survive its own update (pkill skips ancestors) and could
  # break the install by closing our pipes. Re-run in the background, owned by launchd, and return at once.
  HUB_DETACHED=1 nohup /bin/bash "$0" --install "${2:-}" </dev/null >/dev/null 2>&1 &
  exit 0
fi
if [ -n "${HUB_DETACHED:-}" ]; then   # wait until the caller has let go of us (parent → launchd)
  for _ in $(seq 1 50); do [ "$(ps -o ppid= -p $$ | tr -d ' ')" = 1 ] && break; sleep 0.1; done
fi
BASE=$(cat "$DIR/base" 2>/dev/null) || exit 0
[ "$MODE" = --now ] || exec >> "$DIR/update.log" 2>&1
log() { echo "$(date '+%F %T') $*"; }

refresh_self() {   # keep this script current
  curl -fsSL -m 30 "$BASE/update.sh" -o "$DIR/update.sh.new" && [ -s "$DIR/update.sh.new" ] \
    && mv "$DIR/update.sh.new" "$DIR/update.sh" && chmod +x "$DIR/update.sh"
}

VERS=$(curl -fsSL -m 30 "$BASE/versions.txt") || { log "сайт недоступен ($BASE)"; exit 0; }

ver_gt() {   # $1 > $2
  local IFS=. i; local a=($1) b=($2)
  for i in 0 1 2; do
    local x=${a[$i]:-0} y=${b[$i]:-0}
    if (( x > y )); then return 0; fi
    if (( x < y )); then return 1; fi
  done
  return 1
}

installed() {   # type app home → installed version (empty = not installed)
  if [ "$1" = dmg ]; then
    local d dirs=(/Applications "$HOME/Applications")
    [ -n "${HUB_APPS_DIR:-}" ] && dirs=("$HUB_APPS_DIR")    # test mode, same as install.sh
    for d in "${dirs[@]}"; do
      [ -f "$d/$2/Contents/Info.plist" ] && { /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$d/$2/Contents/Info.plist" 2>/dev/null; return; }
    done
  else
    cat "$3/VERSION" 2>/dev/null
  fi
}

esc() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '%s' "$s"; }

install_one() {   # id name version
  if curl -fsSL -m 60 "$BASE/install.sh" | HUB_AUTO=1 HUB_URL="$BASE" bash -s -- "$1"; then
    log "$2 обновлён до $3"
    osascript -e "display notification \"$2 обновлён до $3\" with title \"Studio Hub\"" >/dev/null 2>&1
  else
    log "✗ $2: обновление до $3 не удалось"
  fi
}

# Available updates → pending.json (apps read it to show «Доступно обновление»)
IDS=(); NAMES=(); NEWV=(); CURV=(); NOTES=(); JSON=""
while IFS=$'\t' read -r id ver type app home name note; do
  [ -n "$id" ] || continue
  grep -qx "$id" "$DIR/apps" 2>/dev/null || continue
  home="${home/#\~/$HOME}"
  cur=$(installed "$type" "$app" "$home")
  [ -n "$cur" ] || continue          # removed by the person — don't bring it back
  ver_gt "$ver" "$cur" || continue
  [ "$note" = "-" ] && note=""
  IDS+=("$id"); NAMES+=("$name"); NEWV+=("$ver"); CURV+=("$cur"); NOTES+=("$note")
  JSON+="${JSON:+,}\"$id\":{\"name\":\"$(esc "$name")\",\"version\":\"$ver\",\"current\":\"$cur\",\"notes\":\"$(esc "$note")\"}"
done <<< "$VERS"
printf '{%s}\n' "$JSON" > "$DIR/pending.json"

if [ "$MODE" = --install ]; then
  log "установка ${2:-?} по запросу приложения (ppid=$(ps -o ppid= -p $$ | tr -d ' '))"
  for i in "${!IDS[@]}"; do
    [ "${IDS[$i]}" = "${2:-}" ] && { install_one "${IDS[$i]}" "${NAMES[$i]}" "${NEWV[$i]}"; exec "$0" --check; }
  done
  log "${2:-?}: обновлений нет"
  exit 0
fi
if [ "$MODE" = --check ] || [ ${#IDS[@]} -eq 0 ]; then refresh_self; exit 0; fi

# «Позже» snoozes this version for 4 h (no answer: 1 h)
NOW=$(date +%s); ASK=()
for i in "${!IDS[@]}"; do
  until=$(awk -v id="${IDS[$i]}" -v v="${NEWV[$i]}" '$1==id && $2==v {print $3}' "$DIR/snooze" 2>/dev/null | tail -1)
  [ -n "$until" ] && [ "$NOW" -lt "$until" ] && continue
  ASK+=("$i")
done
if [ ${#ASK[@]} -eq 0 ]; then refresh_self; exit 0; fi

TEXT="Вышли обновления:"
for i in "${ASK[@]}"; do
  TEXT+=$'\n\n'"• ${NAMES[$i]} ${NEWV[$i]} (у тебя ${CURV[$i]})"
  [ -n "${NOTES[$i]}" ] && TEXT+=$'\n'"  ${NOTES[$i]}"
done
TEXT+=$'\n\n'"Приложение закроется на секунду и откроется снова, настройки сохранятся."
log "предлагаю: $(for i in "${ASK[@]}"; do printf '%s %s; ' "${NAMES[$i]}" "${NEWV[$i]}"; done)"
ANS=$(osascript -e 'on run argv' -e 'activate' \
  -e 'display dialog (item 1 of argv) with title "Studio Hub" buttons {"Позже", "Обновить"} default button "Обновить" with icon note giving up after 900' \
  -e 'end run' "$TEXT" 2>/dev/null)
if [[ "$ANS" == *"Обновить"* && "$ANS" != *"gave up:true"* ]]; then
  for i in "${ASK[@]}"; do install_one "${IDS[$i]}" "${NAMES[$i]}" "${NEWV[$i]}"; done
  "$0" --check
else
  wait_s=14400; [[ "$ANS" == *"gave up:true"* || -z "$ANS" ]] && wait_s=3600
  for i in "${ASK[@]}"; do
    grep -v "^${IDS[$i]} " "$DIR/snooze" 2>/dev/null > "$DIR/snooze.new"
    echo "${IDS[$i]} ${NEWV[$i]} $((NOW + wait_s))" >> "$DIR/snooze.new"
    mv "$DIR/snooze.new" "$DIR/snooze"
  done
  log "отложено на $((wait_s / 3600)) ч"
fi
refresh_self
