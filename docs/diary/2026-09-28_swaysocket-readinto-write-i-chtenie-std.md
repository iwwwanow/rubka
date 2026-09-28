# 2026-09-28 — SwaySocket: readInto/write дописаны, try, как читать std

Продолжение после 09-15 (`docs/diary/2026-09-15_swasocket-arhitekturnye-resheniya.md`).
Сессия — разбор находок ревью `dc13234` и дописывание методов `SwaySocket`. Весь код писал
пользователь, Claude объяснял и сверял с исходниками std 0.16.

## Состояние находок 1-10 по `dc13234`

Закрыты все, что касались `sway.adapter.socket.zig`:
- `connect(self: *SwaySocket, ...)` — теперь указатель, самоссылка через буфер больше не ломается.
- `try` на `UnixAddress.init(path)` и на `.connect(io)`.
- `Reader.init`/`Writer.init` — присваивание, `&self.read_buf`/`&self.write_buf`.
- Лишние `;` после методов убраны, старые свободные `write`/`readInto` внизу файла удалены.
- Открытый вопрос `undefined` vs `?T = null` для `reader`/`writer` закрыт в пользу **`undefined`**
  (пользователь проставил дефолты `= undefined`, отдельно не обсуждали — дёшево, `self.socket = .{}`
  в адаптере теперь собирается).

Осталось только в `sway.adapter.zig` — находка 10: `try self.socket.connect(io)` в `wrap` без `path`.

## `try` — как работает

`try x` ≡ `x catch |err| return err`: разворачивает `E!T` в `T` или пробрасывает ошибку наверх.
Отсюда требование — функция с `try` внутри сама обязана возвращать error union (`!void` у
`connect`). Ещё Zig не даёт молча проигнорировать error union: `readSliceAll(buffer)` без `try`
не компилируется — на этом пользователь споткнулся в первой версии `readInto`.

## `readInto` и `write` — готовы

```
readInto(self: *SwaySocket, buffer: []u8) !void   — сокет → буфер вызывающего
write(self: *SwaySocket, bytes: []const u8) !void — байты вызывающего → сокет
```

- `readInto` → `self.reader.interface.readSliceAll(buffer)` (std `Io/Reader.zig:660`). Выбран вместо
  `readSliceShort` (`:675`, возвращает `usize`), потому что в sway-ipc длины всегда известны заранее
  (14 байт заголовок, `payload_length` тело), и недочитанное сообщение — ошибка, а не норма.
- `write` → `writeAll(bytes)` + `flush()` (`Io/Writer.zig:549`, `:312`). Тип параметра — `[]const u8`,
  не `[]u8`: метод байты только читает, а `command_payload` и литералы — const.
- **Flush внутри каждого `write`** — решение пользователя. Цена: заголовок и тело уходят двумя
  syscall'ами; sway читает поток, ему всё равно. Плюс — забыть flush невозможно. Вынести flush
  наружу можно позже (оставлен `// INFO` в коде).
- Подводный камень, из-за которого flush обязателен: writer буферизованный, 14 + пара десятков байт
  команды не заполнят 4096-байтный склад, без flush ничего не уйдёт в сокет, и `readInto` повиснет
  в ожидании ответа.
- При сбое сокета наружу прилетает общий `error.ReadFailed`/`error.WriteFailed`, реальная причина —
  в `self.reader.err`/`self.writer.err` (`net.zig:1305`, `:1378`). Пока не используем.

## Разобранные непонятки

- **Где поле `interface`.** Не у нас — внутри std-типа: `SwaySocket.reader` имеет тип
  `std.Io.net.Stream.Reader` (`net.zig:1256`), у которого поля `io`, `interface: Io.Reader`,
  `stream`, `err`. Все удобные методы (`readSliceAll`, `writeAll`, `flush`) — на `interface`.
- **Почему не `readVec`/`streamImpl`.** Они без `pub` — это реализация vtable, которую
  `Stream.Reader.init` кладёт в `interface.vtable`. Тот же ручной vtable-паттерн, что наш `wrap()`.
- **`read_buf`/`write_buf`.** Внутренние склады reader/writer, лежат прямо внутри структуры
  (массив, не указатель). `= undefined` — нормально: reader/writer сами отслеживают заполненную
  часть (`seek`/`end`), мусор не читается. Снаружи не инициализируются — только передаются
  в `init` внутри `connect`.
- **Куда пишет `write` без переданного адресата.** Адресат зашит один раз в `connect`
  (`Writer.init(stream, ...)` запоминает `stream`). Путь: `bytes → write_buf → (flush) → сокет`.

## Как читать std (шпаргалка для себя)

1. Исходник = документация, путь — `zig env` → `std_dir` (у нас `/usr/lib/zig/std/`).
2. Смотреть только `pub`. Первая команда — `grep -n "pub fn" <файл>`.
3. Файл может быть типом (`Io/Reader.zig` — это `Io.Reader`, поля на верхнем уровне).
4. Поле `interface` + vtable + `@fieldParentPtr` → методы ищи у типа `interface`.
5. Сигнатура — контракт: `*T` = нужен изменяемый указатель; буфер параметром = память даёт
   вызывающий; `Error!void` = результата нет, только ошибки.
6. `///` + «See also» ведут к соседним вариантам; `test` внизу файла — примеры использования.
7. Идти от типа, который уже держишь, по полям; в nvim — `gd` через zls.

## `SWAYSOCK` — откуда путь (не решено)

`SWAYSOCK` выставляет сам sway и передаёт своим потомкам (sway → терминал → шелл → rubka). Не
системная: из tty/ssh/cron её нет (запасной вариант — `sway --get-socketpath`, не сейчас).
Достаётся из `std.process.Init.environ_map: *Environ.Map` (`process.zig:44`); getter —
найти самому в `process/Environ.zig`, скорее всего возвращает optional → `orelse return error...`.

**Открытый вопрос:** кто читает `SWAYSOCK` — `main.zig` (читает и передаёт `path` в `wrap(io, path)`)
или адаптер (получает `environ_map` и сам знает имя переменной)? Упирается в решение 09-15
«composition root не знает деталей протокола»: имя `SWAYSOCK` — это деталь протокола или
конфигурация запуска? Пользователь не ответил.

## Где остановились

`sway.adapter.socket.zig` — `SwaySocket` полностью дописан (`connect`/`readInto`/`write`),
**сборку ещё не проверяли** (`zig build` — за пользователем). Всё закоммичено, рабочая копия чистая.

`sway.adapter.zig` — не тронут: `wrap` зовёт `connect(io)` без `path`; `move_fn` ссылается на
несуществующий `self.stream` и необъявленные `command_payload`/`result`; `runCommand` — всё ещё
псевдокод в комментариях, сигнатура `void` и старые вызовы `socket_mod.write(stream, ...)`.

## Следующая сессия

1. `zig build` — посмотреть, что компилятор скажет про `socket.zig` (ошибки из `sway.adapter.zig`
   будут точно, отделить их).
2. Решить вопрос про `SWAYSOCK` (main vs адаптер) и починить `wrap` (находка 10).
3. `runCommand` реальным кодом: `self.socket.write(header)`, `self.socket.write(payload)`,
   `readInto` заголовка (14 байт) → `decodeHeader` → `alloc(u8, payload_length)` + `defer free`
   → `readInto(body)`; error union в сигнатуре; `move_fn` — через `self.socket`, не `self.stream`.
4. Затем `main.zig`: `init.io` в `wrap`, `try`, переключение со стаба на sway-адаптер.
5. (низкий приоритет) импорты в `sway.adapter.test.zig` → `header_mod`.
