# 2026-10-04 — sway-адаптер: первый рабочий end-to-end `move-window`

Продолжение после 09-28 (`docs/diary/2026-09-28_swaysocket-readinto-write-i-chtenie-std.md`).
Сессия — дописывание `sway.adapter.zig`, `commands.zig` и переключение `main.zig` со стаба на
sway-адаптер. Весь код писал пользователь, Claude ревьюил дифф и объяснял синтаксис.

**Итог: `zig build` проходит, `zig build run -- left` под живым sway двигает окно.** Запись в
сокет работает end-to-end; ответ sway пока не читается.

## Что сделано

- `wrap(self, io, environ_map)` — адаптер сам достаёт `SWAYSOCK` из `environ_map`
  (`environ_map.get(constants_mod.sway_socket) orelse return error.MissingEnvVar`), `main` имя
  переменной не знает. Открытый вопрос 09-28 «main vs адаптер» закрыт в пользу адаптера.
  Имя переменной — `pub const sway_socket = "SWAYSOCK"` в `sway.adapter.constants.zig`.
- `move_fn` — `@ptrCast(@alignCast(ptr))`, `getMoveCommandPayload(direction)`,
  `runCommand(&self.socket, payload) catch |err| std.log.err(...)`. Порт остался `void`:
  **ошибки ловятся и логируются внутри адаптера** (решение пользователя, TODO на рефактор
  к обработке на уровне порта оставлен в коде).
- `runCommand(socket: *SwaySocket, payload: []const u8) !void` — `encodeHeader` с
  `@intCast(payload.len)`, `try socket.write(&header_out)`, `try socket.write(payload)`.
  Старые параметры `io`/`stream` ушли — они уже зашиты в reader/writer сокета.
- `commands.zig` — `const Command = struct { const move_left = "move left"; ... }` (структура как
  пространство имён) + `return switch (direction) { ... }`.
- `main.zig` — `SwayWindowManagerAdapter`, `wrap(&adapter_impl, init.io, init.environ_map) catch
  |err| { log; return; }`, `init.minimal.args` (у `Init` нет `args` — оно в `minimal`; сломалось
  ещё в `fa14a91` при переходе `Init.Minimal` → `Init`, всплыло только сейчас). Импорт стаба убран.

## Разобранное по синтаксису

- **Вызов метода** `self.socket.connect(io, path)` ≡ `SwaySocket.connect(&self.socket, io, path)`:
  первый параметр подставляется из того, что слева от точки, `&` берётся автоматически, если
  метод ждёт `*T` и значение изменяемое. Для обычной функции (`runCommand(&self.socket, ...)`)
  сахара нет — `&` пишется явно.
- **Почему сокет только по указателю.** reader/writer хранят `&self.read_buf`/`&self.write_buf` —
  самоссылка. Копия `SwaySocket` получит свои буферы, а её reader продолжит смотреть в чужие.
  Отсюда же: `adapter_impl` в `main` — `var`, живёт до конца, никуда не копируется.
- **Массив vs слайс.** `[14]u8` — сами байты, длина в типе; `[]const u8` — указатель + `len`.
  Массив по значению в слайс не превращается, `&header_out` (`*[14]u8`) — превращается.
- **Builtin'ы с result location.** `@intCast(x)` — один аргумент (форма `@intCast(u32, x)` —
  до 0.11), тип берётся из того, куда кладут результат. Так же `@ptrCast`, `@alignCast`.
- **`@alignCast`.** `*anyopaque` гарантирует выравнивание 1, адаптер с сокетом внутри — 8.
  `@ptrCast` гарантию не повышает → `cast increases pointer alignment`. В стабе работало, потому что
  `struct {}` имеет выравнивание 1.
- **`enum` только с целочисленным тегом** — `enum([]const u8)` невозможен. Для именованных строк —
  `pub const` или структура-namespace.
- **`error{A}` vs `error.A`** — тип (набор ошибок) vs значение. `return` — со значением.
- **`orelse return error.X`** — разворачивает optional, `null` превращает в ошибку (пара к `try`,
  который разворачивает error union).
- **`catch` при присваивании** (`const x = f() catch |err| { ... };`) — блок либо отдаёт значение
  типа `x`, либо уходит из функции (`return` → `noreturn`).
- **`comptime` в сигнатуре** `print(comptime fmt, args)` — модификатор параметра, не значение;
  передаётся строковый литерал. `{}` для ошибки печатает `error.Name`, `{t}` — `Name`.
- **Ленивый анализ.** Пока `main` использовал стаб, компилятор не смотрел `wrap`/`move_fn`/
  `runCommand` — ошибки там прятались. Всплыли только после переключения.

## Подводный камень: `SWAYSOCK` внутри zellij

Сервер zellij наследует окружение на момент своего запуска. Путь сокета содержит PID sway —
после перезапуска sway в старой сессии zellij будет мёртвый путь → `connect` вернёт
`FileNotFound`. Проверка: `ls -l $SWAYSOCK`; обход —
`SWAYSOCK=$(sway --get-socketpath) zig build run -- left`.

## Остаток / заметки

- **Ответ sway не читается.** Сокет закрывается сразу после `write`; команда всё равно
  выполняется (sway сначала исполняет, потом отвечает), но успех не проверяется.
- `connect` происходит в `wrap`, до разбора аргументов: `rubka` без аргументов вне sway упадёт
  с `MissingEnvVar`. Когда появятся команды без sway (`--help`) — ленивое подключение.
- `close()` у `SwaySocket` — TODO, для одноразового CLI неважно.
- Устаревший TODO-блок про `SWAYSOCK` в `main.zig` — удалить. Комментарии-шаги 1–5 в
  `runCommand` с разъехавшимися отступами — удалятся, когда станут кодом.
- TODO «на каком уровне ловить ошибки» в `move-window.cli.zig`/`router.cli.zig` — сейчас ответ
  «в адаптере», можно сослаться на `move_fn`.
- (низкий приоритет) импорты в `sway.adapter.test.zig` → `header_mod`.
- Изменения на момент записи **не закоммичены** (коммит — за пользователем).

## Следующая сессия — чтение ответа в `runCommand`

1. `readInto` 14 байт заголовка в массив на стеке → `decodeHeader`. Без аллокатора.
2. Проверить, что `payload_type == .{ .message = .run_command }`, иначе — ошибка протокола.
3. Аллокатор в адаптер: `init.gpa` (`process.zig:39`) → скорее всего поле адаптера, заполняемое
   в `wrap`.
4. `alloc(u8, payload_length)` + сразу `defer free` → `readInto(body)`.
5. Промежуточно — вывести тело в лог как есть (`[{"success":true}]`).
6. Потом `std.json` → `decodeReply`: `success: false` → ошибка Zig.
