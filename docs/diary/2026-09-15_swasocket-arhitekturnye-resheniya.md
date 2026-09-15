# 2026-09-15 — SwaySocket: методы vs top-level, владение соединением, план на runCommand

Продолжение серии после 09-01 (`docs/diary/2026-09-01_allocator-vladenie-i-tip-literaly.md`).
Двухнедельный перерыв (последний код-коммит — `74b8d8a`, 01.09). Сессия — чисто обсуждение
архитектуры, без написания кода (пользователь внёс только две мелкие точечные правки сам,
см. ниже), закрыты все накопившиеся открытые вопросы про сокетный слой.

## Решено: `SwaySocket` — методы на структуре, не top-level функции

Развилка стояла с 08-31. Выбор — методы (`socket.write(data)`, `socket.readInto(buffer)`),
не top-level `write(io, stream, data)`. Причина выбора зафиксирована в ходе обсуждения: если
функции остаются top-level, `SwaySocket` как тип ничего не даёт — его всё равно пришлось бы
распаковывать обратно в `io`/`stream` внутри каждой функции. Структура окупается только когда
`self` внутри метода реально используется вместо ручной распаковки параметров.

`SwaySocket` определять в `socket.zig` — тот же уровень абстракции (транспорт, не протокол),
что и остальное содержимое файла (protocol-agnostic обёртка над `Stream`).

## Решено: соединение — eager, хранится в адаптере

Развилка "когда открывается `self.socket`" (eager в `wrap()` vs lazy при первом `move_fn`) —
выбран **eager в `wrap()`**. Причины: ошибка подключения к sway всплывает рано (при старте
программы), а не посреди работы; `self.socket` не нужно делать optional.

Следствия для контрактов, разобранные отдельно:
- `wrap()` становится fallible (`!port_mod.WindowManagerPort` или похоже) — сейчас сигнатура
  без `!`, `connect()` может упасть.
- Composition root (`main.zig`) — его новая обязанность: передать `io` в адаптер (единственный,
  у кого есть доступ к `init.io`) и обернуть вызов `wrap()` в `try`. Но **не** знать деталей
  протокола — сам `UnixAddress.init(path).connect(io)` остаётся внутри `sway.adapter.zig`,
  наружу не протекает. Разделили явно: "кто вызывает `connect()`" (адаптер) vs "кто даёт `io`
  и ловит ошибку" (composition root) — это две разные ответственности, не одна.

## Осознанно не решаем: переподключение при обрыве

Обрыв `self.socket` между вызовами `move_fn` (sway перезапустился, сокет моргнул) —
не обрабатываем сейчас. `readExact`/`readInto`/`write` и так вернут `error`, `runCommand`
пробросит через `try`, `move_fn`/CLI увидит ошибку и упадёт. Переподключение/retry-политика —
несоразмерная сложность для текущего шага, вынесено в
`docs/backlog/2026-09-15_sway-socket-reconnection.md`.

## Мелкие правки в код за сессию (не через обсуждение, точечно пользователем)

`git status` на конец сессии — незакоммичено:
- `sway.adapter.socket.zig`: `readExact(io, stream, allocator, bytes_length) ![]const u8` →
  переименован в `readInto`, сигнатура частично обновлена (`allocator`/`bytes_length` →
  `buffer: []u8`), но **тип возврата всё ещё `![]const u8`, надо `!void`** (раз пишем в чужой
  буфер, а не возвращаем новый слайс) — не доделано, первый пункт следующей сессии.
- `sway.adapter.zig`: `constants_mod.Message.run_command` → `constants_mod.MessageType.run_command`
  — опечатка с 08-31 исправлена.

## Где остановились технически

Обе структуры (`SwaySocket` как метод-хост, `self.socket` в адаптере) — только решения на
словах, в коде ещё не появились. `runCommand` — всё ещё тело смешано с комментариями-псевдокодом
из чата (см. 09-01), не переписано под сегодняшние решения.

## Следующая сессия

Начать с:
1. `socket.zig` — доделать `readInto`: тип возврата `![]const u8` → `!void` (пишем в переданный
   `buffer`, ничего не возвращаем). Переопределить `write`/`readInto` как методы на `SwaySocket`
   (`self: SwaySocket`), убрать `io`/`stream` как отдельные параметры каждой функции.
2. `sway.adapter.zig` — `wrap()`: создать `SwaySocket` (`UnixAddress.init(path).connect(io)`),
   сохранить в `self.socket` (новое поле `SwayWindowManagerAdapter`), сделать `wrap()` fallible.
3. `runCommand` — переписать по актуальному плану реальным кодом (не комментариями):
   - вызовы `socket_mod.write(...)` → `self.socket.write(...)` (по итогам п.1);
   - `body_bytes = allocator.alloc(u8, header_in.payload_length)` + `defer allocator.free(...)`
     прямо в `runCommand`, дальше `self.socket.readInto(body_bytes)`;
   - реальный error union в сигнатуре вместо `void`.
4. `main.zig` (composition root) — передать `io` в адаптер/`wrap()`, обернуть вызов в `try`.
5. (низкий приоритет, независимо от 1-4) `sway.adapter.test.zig` — переключить импорт
   header-символов (`decodeHeader`/`encodeHeader`/`Header`/`FrameError`) на `header_mod`, чтобы
   `zig build test` перестал падать на импортах.
