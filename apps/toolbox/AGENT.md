# Toolbox — инструкция для агента (Claude Code / Codex)

Ты работаешь на Mac, где установлен **Toolbox** — виджет в строке меню (значок — сетка 2×2) с системными инструментами на вкладках: **Звук**, **Окна**, **Цвет**. Человек пользуется им мышкой, а ты управляешь тем же самым из терминала командой `toolbox`. Прочитай файл целиком, потом выполни раздел «Подключение» в конце.

## Где что лежит
| Что | Путь |
|---|---|
| Приложение | `/Applications/Toolbox.app` (или `~/Applications/Toolbox.app`) |
| Команда | `~/Toolbox/toolbox …` — обёртка над бинарником приложения; если её нет: `/Applications/Toolbox.app/Contents/MacOS/Toolbox …` |
| Эта инструкция | `~/Toolbox/AGENT.md` |
| Данные | `~/Library/Application Support/Toolbox/` — `audio-rules.json`, `audio-state.json`, `windows-state.json`, `color.json`, `color-state.json` |
| Автозапуск | `~/Library/LaunchAgents/local.toolbox.plist` (`toolbox autostart on|off`) |

Команды работают, только когда приложение запущено (`open -a Toolbox`). Если `toolbox audio list` ничего не отвечает — запусти его.

## Звук — каждое приложение на своё устройство
Для каждой программы: устройство вывода (колонки, наушники, аудиокарта, BlackHole…), громкость, mute и пара каналов многоканальной карты. Работает через Core Audio process tap (macOS 14.2+). Если Toolbox выйдет, программы сразу звучат как раньше.
```bash
toolbox audio list                                   # устройства, приложения, правила, активные маршруты
toolbox audio route "Музыка" "AirPods" --volume 0.8  # APP — имя или bundle id, DEVICE — имя/UID или "default"
toolbox audio route resolve "Scarlett" --channels 3-4
toolbox audio route Telegram default --mute
toolbox audio clear "Музыка"                         # или: clear all
```
- Правило хранится по bundle ID и срабатывает, когда приложение начнёт звучать.
- Отвалилось устройство (Bluetooth) — программа играет в системный выход, при подключении маршрут восстановится сам.
- Нужно разрешение «Запись экрана и системного звука» → «Только системный звук». Без него маршруты не создаются, в `audio-state.json` будет ошибка — скажи человеку включить Toolbox там.

## Окна — раскладка по шаблонам
Горячие клавиши **⌃⌥1…⌃⌥8**: 2 рядом, 2 друг над другом, 2/3 + 1/3, 1 + 2, 3 колонки, 4 сеткой, 6 сеткой, на весь экран. Берутся последние активные окна экрана, повтор того же шаблона меняет окна местами по кругу.
```bash
toolbox windows layouts          # id шаблонов
toolbox windows apply grid4
toolbox windows list             # окна спереди назад → windows-state.json
```
Нужно разрешение «Универсальный доступ» (Accessibility).

## Цвет — коррекция экранов
Баланс белого, яркость, контраст, гамма, уровень чёрного, по-канальная настройка, подсветка дисплеев Apple и цветовые профили.
```bash
toolbox color list
toolbox color set "LG" temp=5500 brightness=0.9
toolbox color reset all
toolbox color backlight "Встроенный" 0.6
toolbox color profile "LG" p3            # srgb | p3 | dci | 709 | 2020 | adobe | factory | ФАЙЛ.icc
```
Коррекция живёт, пока запущен Toolbox; при выходе macOS возвращает экраны к профилю.

## Панель
```bash
toolbox show audio|windows|color   # открыть нужную вкладку
toolbox hide
```

## Обновления
Если Toolbox ставили с хаба, в шестерёнке панели появляется «Доступно обновление X.Y» (и красная точка на значке).
Клик ставит новую версию: Toolbox на секунду закроется и откроется снова, настройки сохранятся.
То же из терминала: `~/.studio-hub/update.sh --install toolbox`.

## Правила
- Не меняй маршруты звука и цвет экранов без просьбы человека: это сразу слышно и видно.
- Перед `audio route` посмотри `audio list`, чтобы взять точные имена приложения и устройства.
- Системные разрешения включает только человек (Системные настройки → Конфиденциальность и безопасность). Ты можешь открыть нужный раздел: `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`.

## Подключение
1. Проверь, что приложение стоит и отвечает: `~/Toolbox/toolbox audio list`.
2. Добавь в глобальные инструкции человека (`~/.claude/CLAUDE.md` для Claude Code, `~/.codex/AGENTS.md` для Codex) блок:
   ```markdown
   ## Toolbox — системный виджет в строке меню
   - Звук по приложениям, раскладка окон, цвет экранов. CLI: `~/Toolbox/toolbox audio|windows|color …`, справка `~/Toolbox/toolbox --help`.
   - Подробности: `~/Toolbox/AGENT.md`. Маршруты звука и цвет меняю только по просьбе.
   ```
3. Предложи включить автозапуск: `~/Toolbox/toolbox autostart on`.
