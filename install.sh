#!/bin/bash
# Studio Hub installer.  curl -fsSL https://mthought13.github.io/studio-hub/install.sh | bash -s -- <id> [<id> …]
# Downloads with curl (no Gatekeeper quarantine), puts the app into /Applications (or ~/Applications), opens it.
set -euo pipefail
BASE="${HUB_URL:-https://mthought13.github.io/studio-hub}"
UPDATE_BASE="${HUB_URL:-https://mthought13.github.io/studio-hub}"   # the auto-updater always checks the public copy

usage() {
  cat <<EOF
Studio Hub — установка:  curl -fsSL $BASE/install.sh | bash -s -- <приложение> […]

  reftray   RefTray 1.1 — Плавающая панель референсов для генераций
  toolbox   Toolbox 1.2 — Звук по приложениям, раскладка окон, цвет экранов
  dial      Dial 0.3 — Плавающий пульт: громкость, плеер, голосовой ввод
  tgfetch   TgFetch 1.0 — Файлы из Telegram по просьбе словами
EOF
}

app_info() {
  STEPS=()
  case "$1" in
  reftray) NAME='RefTray' TYPE=dmg FILE='RefTray-1.1.dmg' VER='1.1' APP='RefTray.app' EXE='RefTray' HOMEDIR="$HOME/RefTray" MINOS='14.0' CLI='' CLIEXEC='' FOLDER='' SETUP='' KILL='' STEPS=('   • Разреши доступ к Рабочему столу и Загрузкам, когда macOS спросит.' '   • Скажи агенту: «Прочитай ~/RefTray/AGENT.md и подключи RefTray».') ;;
  toolbox) NAME='Toolbox' TYPE=dmg FILE='Toolbox-1.2.dmg' VER='1.2' APP='Toolbox.app' EXE='Toolbox' HOMEDIR="$HOME/Toolbox" MINOS='14.2' CLI='toolbox' CLIEXEC='Contents/MacOS/Toolbox' FOLDER='' SETUP='' KILL='' STEPS=('   • Включи разрешения, когда macOS спросит: системный звук и Универсальный доступ.' '   • Скажи агенту: «Прочитай ~/Toolbox/AGENT.md и подключи Toolbox».') ;;
  dial) NAME='Dial' TYPE=dmg FILE='Dial-0.3.dmg' VER='0.3' APP='Dial.app' EXE='Dial' HOMEDIR="$HOME/Dial" MINOS='13.0' CLI='' CLIEXEC='' FOLDER='' SETUP='' KILL='Dial.app/Contents/Resources/Dial/mac/dial_bridge.py' STEPS=('   • Разреши «Универсальный доступ», когда macOS спросит.' '   • Скажи агенту: «Прочитай ~/Dial/AGENT.md и подключи Dial».') ;;
  tgfetch) NAME='TgFetch' TYPE=zip FILE='TgFetch-1.0.zip' VER='1.0' APP='' EXE='' HOMEDIR="$HOME/TgFetch" MINOS='0' CLI='' CLIEXEC='' FOLDER='TgFetch' SETUP='setup.sh' KILL='' STEPS=('   • Войди в Telegram сам, в Терминале: ~/TgFetch/login.sh' '   • Скажи агенту: «Прочитай ~/TgFetch/AGENT.md и подключи TgFetch».') ;;
  *) return 1 ;;
  esac
}

ver_ge() {   # $1 >= $2 (dotted versions)
  local IFS=. i; local a=($1) b=($2)
  for i in 0 1 2; do
    local x=${a[$i]:-0} y=${b[$i]:-0}
    if (( x > y )); then return 0; fi
    if (( x < y )); then return 1; fi
  done
  return 0
}

TMP=$(mktemp -d)
cleanup() {   # must not fail: under set -e a failing trap would turn a good install into exit 1
  local m
  for m in "$TMP"/mnt-*; do
    if [ -d "$m" ] && mount | grep -q " on $m "; then hdiutil detach "$m" -quiet -force 2>/dev/null || true; fi
  done
  rm -rf "$TMP" 2>/dev/null || true
}
trap cleanup EXIT

fetch() {   # url dest
  curl -fL --progress-bar "$1" -o "$2" || { echo "✗ Не скачалось: $1 (сайт доступен? $BASE)"; return 1; }
}

install_dmg() {
  local id=$1 dmg="$TMP/$id.dmg" mnt="$TMP/mnt-$id" dest
  fetch "$BASE/files/$id/$FILE" "$dmg"
  mkdir -p "$mnt"
  hdiutil attach -nobrowse -readonly -quiet -mountpoint "$mnt" "$dmg"
  if [ -n "${HUB_APPS_DIR:-}" ]; then dest="$HUB_APPS_DIR"; mkdir -p "$dest"    # test mode: no quit, no launch
  elif [ -d "/Applications/$APP" ]; then dest=/Applications
  elif [ -d "$HOME/Applications/$APP" ]; then dest="$HOME/Applications"
  elif [ -w /Applications ]; then dest=/Applications
  else dest="$HOME/Applications"; mkdir -p "$dest"; fi
  # copy next to the old app first, then swap: a failure midway never leaves the person without the app
  rm -rf "$dest/.$APP.new"
  ditto "$mnt/$APP" "$dest/.$APP.new"
  # -a: include our ancestors too — the app itself may have started this update
  local was_running=""
  pgrep -a -x -q "$EXE" && was_running=1
  if [ -z "${HUB_APPS_DIR:-}" ]; then
    pkill -a -x "$EXE" 2>/dev/null && sleep 1 || true
    [ -n "$KILL" ] && pkill -a -f "$KILL" 2>/dev/null || true
  fi
  rm -rf "${dest:?}/$APP"
  mv "$dest/.$APP.new" "$dest/$APP"
  xattr -dr com.apple.quarantine "$dest/$APP" 2>/dev/null || true
  hdiutil detach "$mnt" -quiet -force 2>/dev/null || true
  # Home folder with the agent guide (+ CLI wrapper). A source checkout (has build.sh) is left alone.
  if [ -n "$HOMEDIR" ] && [ ! -e "$HOMEDIR/build.sh" ] && [ ! -e "$HOMEDIR/src" ] && [ ! -e "$HOMEDIR/mac/widget" ]; then
    mkdir -p "$HOMEDIR"
    curl -fsSL "$BASE/apps/$id/AGENT.md" -o "$HOMEDIR/AGENT.md" || true
    if [ -n "$CLI" ]; then
      printf '#!/bin/zsh\n# CLI for the running %s app (installed by Studio Hub)\nexec "%s" "$@"\n' "$NAME" "$dest/$APP/$CLIEXEC" > "$HOMEDIR/$CLI"
      chmod +x "$HOMEDIR/$CLI"
    fi
  fi
  # an auto-update reopens only what was open; a manual install always opens the app
  if [ -z "${HUB_APPS_DIR:-}" ] && { [ -z "${HUB_AUTO:-}" ] || [ -n "$was_running" ]; }; then open "$dest/$APP"; fi
  echo "✓ $NAME $VER → $dest/$APP"
}

install_zip() {
  local id=$1 zip="$TMP/$id.zip"
  fetch "$BASE/files/$id/$FILE" "$zip"
  ditto -x -k "$zip" "$TMP/unz-$id"
  if [ -e "$HOMEDIR/package.sh" ]; then echo "• $HOMEDIR — это исходники, не трогаю"; return 0; fi
  mkdir -p "$HOMEDIR"
  ditto "$TMP/unz-$id/$FOLDER" "$HOMEDIR"      # merges: keeps .venv, logs and settings
  if [ -n "$SETUP" ]; then "$HOMEDIR/$SETUP"; fi
  echo "✓ $NAME $VER → $HOMEDIR"
}

# Auto-update: ~/.studio-hub (list of installed apps + update.sh) and LaunchAgent local.studiohub.update
setup_updater() {
  [ -n "${HUB_APPS_DIR:-}" ] && return 0
  local dir="$HOME/.studio-hub" plist="$HOME/Library/LaunchAgents/local.studiohub.update.plist"
  mkdir -p "$dir"
  touch "$dir/apps"
  grep -qx "$1" "$dir/apps" || echo "$1" >> "$dir/apps"
  [ -n "${HUB_AUTO:-}" ] && return 0
  echo "$UPDATE_BASE" > "$dir/base"
  curl -fsSL "$UPDATE_BASE/update.sh" -o "$dir/update.sh.new" && mv "$dir/update.sh.new" "$dir/update.sh" && chmod +x "$dir/update.sh" || return 0
  mkdir -p "$(dirname "$plist")"
  cat > "$dir/agent.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.studiohub.update</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$dir/update.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>600</integer>
</dict></plist>
PLIST
  if ! cmp -s "$dir/agent.plist" "$plist"; then   # new or changed schedule → (re)load
    mv "$dir/agent.plist" "$plist"
    launchctl bootout "gui/$(id -u)/local.studiohub.update" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || true
  else
    rm -f "$dir/agent.plist"
  fi
  echo "  Автообновление: включено (проверка каждые 10 минут, перед установкой спросит). Выключить: ~/.studio-hub/update.sh off"
}

[ $# -eq 0 ] && { usage; exit 0; }
[ "$(uname)" = Darwin ] || { echo "Эти приложения только для macOS."; exit 1; }
OS=$(sw_vers -productVersion)
for id in "$@"; do
  id=$(echo "$id" | tr '[:upper:]' '[:lower:]')
  if ! app_info "$id"; then echo "✗ Нет приложения «$id»."; usage; exit 1; fi
  if ! ver_ge "$OS" "$MINOS"; then echo "✗ $NAME нужен macOS $MINOS или новее (у тебя $OS)."; continue; fi
  echo "→ $NAME $VER"
  if [ "$TYPE" = dmg ]; then install_dmg "$id"; else install_zip "$id"; fi
  setup_updater "$id"
  [ -n "${HUB_AUTO:-}" ] && continue
  if [ ${#STEPS[@]} -gt 0 ]; then echo "  Дальше:"; printf '%s\n' "${STEPS[@]}"; fi
  echo "  Инструкция: $BASE/apps/$id/"
done
