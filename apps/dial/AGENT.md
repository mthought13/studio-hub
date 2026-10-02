# Dial — инструкция для агента (Claude Code / Codex)

Ты работаешь на Mac, где установлен **Dial** — плавающий круглый пульт поверх всех окон (как будущая железка M5Stack Dial). Кольцо крутит громкость, нажатие — play/pause, кнопка 🎙 — голосовой ввод. На круглом экране: трек, статус агента, баланс ToAPIs и генерации, часы. Прочитай файл целиком, потом выполни раздел «Подключение».

## Как устроено
- `/Applications/Dial.app` шлёт Маку настоящие клавиши: медиаклавиши (громкость, play/pause, треки — работает с любым плеером), **F18** — голос, стрелки/Space в режиме Resolve. Фокус у окон не забирает.
- Экран получает данные от **моста** — `http://localhost:8765` (Python 3, без зависимостей). Приложение запускает его само: из `~/Dial/mac/dial_bridge.py`, если папка есть, иначе из своей копии внутри `Dial.app/Contents/Resources/Dial/`.
- Без моста (нет `python3`) пульт всё равно управляет Маком, экран показывает демо-данные. `python3` приходит с Command Line Tools: `xcode-select --install`.
- Состояние виджета: `~/Dial/.widget_state.json` (`trusted` — выдан ли «Универсальный доступ», без него клавиши не уходят; `version`; `update` — новая версия с хаба, если ждёт установки; `menu` — пункты меню).
- Обновления приходят с хаба сами. Если в меню Dial есть «Доступно обновление X», клик по нему ставит новую версию сразу (Dial перезапустится).

## API моста
```bash
curl -s localhost:8765/state                     # громкость, трек, статус агента, баланс, генерации
curl -s -m 1 -X POST localhost:8765/claude -H 'Content-Type: application/json' -d '{"status":"working"}'
curl -s -m 1 -X POST localhost:8765/notify -H 'Content-Type: application/json' -d '{"kind":"gen_done","text":"Сцена 12 готова"}'
```
- Статусы агента: `idle`, `working`, `waiting` (ждёт подтверждения), `done`.
- Уведомления (`kind`): `claude_done`, `claude_waiting`, `gen_done`, `gen_failed` — оверлей на экране и звук.
- Баланс и генерации берутся из `~/RefTray/.live.json`, если установлен RefTray. Без него экран пишет «нет данных».

## Голосовая кнопка (F18)
🎙 на виджете (и кнопка на железке) шлёт **F18**: нажал — down, отпустил — up. Чтобы она включала диктовку, человек привязывает F18 к голосовому вводу своего приложения: в Claude desktop — Настройки → поле горячей клавиши диктовки → кликнуть по 🎙 на виджете, пока поле в фокусе. У MacBook нет F13+, поэтому так проще всего.

## Подключение
1. Проверь, что мост отвечает: `curl -s localhost:8765/state`. Если нет — запусти `open -a Dial`.
2. **Статус агента на экране (по желанию, спроси человека).** Для Claude Code добавь хуки в `~/.claude/settings.json` (слей с существующими, не затирай):
   ```json
   {
     "hooks": {
       "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "curl -s -m 1 -X POST localhost:8765/claude -H 'Content-Type: application/json' -d '{\"status\":\"working\"}' >/dev/null 2>&1 || true"}]}],
       "Notification":     [{"hooks": [{"type": "command", "command": "curl -s -m 1 -X POST localhost:8765/claude -H 'Content-Type: application/json' -d '{\"status\":\"waiting\"}' >/dev/null 2>&1 || true"}]}],
       "Stop":             [{"hooks": [{"type": "command", "command": "curl -s -m 1 -X POST localhost:8765/claude -H 'Content-Type: application/json' -d '{\"status\":\"done\"}' >/dev/null 2>&1 || true"}]}]
     }
   }
   ```
   Для Codex — то же через его `notify` в `~/.codex/config.toml`, если человек хочет.
3. Добавь в глобальные инструкции человека (`~/.claude/CLAUDE.md` / `~/.codex/AGENTS.md`):
   ```markdown
   ## Dial — плавающий пульт
   - `/Applications/Dial.app`: громкость, плеер, F18 = голосовой ввод. Мост `http://localhost:8765` (GET /state, POST /claude {status}, POST /notify {kind, text}).
   - Подробности: `~/Dial/AGENT.md`.
   ```
