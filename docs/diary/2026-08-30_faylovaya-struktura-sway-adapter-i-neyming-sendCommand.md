# 2026-08-30 — файловая структура sway.adapter: разбивка на header/commands/socket; нейминг sendCommand → runCommand

Продолжение серии после 08-27 (`docs/diary/2026-08-27_sendCommand-cepochka-i-port-signatura.md`).
Сессия — ревизия того, что было закоммичено WIP-ом (`d0a88fe`), плюс дальнейшая детализация
структуры файлов и нейминга.

## moveCommandString — подтверждено, не звено-лишнее

Обсуждалась гипотеза "не лишнее ли это звено в цепочке". Вывод: нет, не лишнее — функция
остаётся отдельной ради двух вещей: (1) `sendCommand`/`runCommand` остаётся command-agnostic
(просто шлёт строку, не знает sway-command-language), (2) тестируется отдельно без сокета
(`Direction.left → "move left"`). Расширяемость — на уровне файла (рядом появятся
`resizeCommandString` и т.п., каждая отдельной маленькой функцией), не через одну общую
обёртку — `moveCommandString` не "обёртка для всех команд", а специфична только под `move`.

## Разделение кодека на header/commands — решено (заменяет решение от 08-27)

08-27 решили: весь кодек (`encodeHeader`/`decodeHeader`/`decodeReply`/`decodeRunCommandReply`)
остаётся в `sway.adapter.zig`, наружу только сокет-I/O. Сегодня это решение **заменено**:
кодек разбивается ещё и по горизонтали.

- `sway.adapter.header.zig` — `Header`, `PayloadType`, `FrameError`, `encodeHeader`,
  `decodeHeader`. Только про byte-level фрейминг (magic/length/type).
- `sway.adapter.commands.zig` — `CommandResult`, `moveCommandString`, `decodeReply`,
  `decodeRunCommandReply`. Всё, что про содержимое команды туда-обратно (encode-сторона
  и decode-сторона вместе, раз оба "про команды" по смыслу).
- `sway.adapter.socket.zig` — protocol-agnostic обёртка над `std.net.Stream`: только
  `write(stream, bytes)` / `readExact(stream, n) -> bytes`, не знает про `Header`/`CommandResult`.
- `sway.adapter.zig` — координатор: `SwayWindowManagerAdapter`, `wrap()`, `move_fn`,
  `runCommand` (композирует все три файла выше).

Обоснование разреза header/commands — типы и функции, которые с ними работают, остаются
**вместе** в одном файле (не разводятся по оси "данные vs функции" — см. следующий пункт).

## `.utils.` — отклонено, обсуждение оси разбиения файлов

Пользователь самостоятельно создал файлы с префиксом `.utils.`
(`sway.adapter.utils.header.zig` и т.п.), обосновав так: `constants` = неизменяемые данные,
`utils` = функции. Разобрали и отклонили:

- `utils` в большинстве кодовых баз — ярлык "разное, не знаю куда", grab-bag без критерия;
  здесь же header/commands/socket — три чётко определённых предметных куска протокола,
  объединение их общим `utils` стирает то самое разделение, ради которого их разносили.
- Критерий "данные vs функции" не проходит уже на первом файле: `Header`
  (данные) и `encodeHeader`/`decodeHeader` (функции) логически одно целое, разводить их
  по отдельным файлам — хуже, чем держать вместе.
- Ось у существующей схемы (`sway.adapter.constants.zig`) — **о чём файл** (протокольные
  константы из `man 7 sway-ipc`), не **какого рода Zig-декларации внутри**. `utils` вводит
  вторую, параллельную и противоречащую ось.

**Следующий виток**: пользователь предложил `interfaces.zig` — перетащить туда типы из всех
файлов, чтобы граница не размывалась. Тоже отклонено: это не убирает проблему, а
воспроизводит её зеркально (теперь `header.zig` — только функции без своих типов,
`interfaces.zig` — типы без функций, которые с ними работают). Реальной необходимости в общем
файле типов нет — `commands.zig` зависит от `header.zig` (для `Header` как параметра
`decodeReply`) через обычный `import` в одну сторону, это не требует выноса типа в третье
место. Плюс терминологическая накладка: "интерфейс" в проекте уже занято конкретным
hexagonal-architecture смыслом (`WindowManagerPort`, vtable `ptr`+`move_fn`,
`application/ports/window-manager.port.zig`) — переиспользование слова для DTO вроде `Header`
создало бы два разных смысла одного термина в одном проекте.

**Итог: `interfaces.zig` не заводим.** Тип живёт с функциями, которые его кодируют/декодируют,
в одном domain-файле; межфайловые зависимости — обычные `import` там, где они реально есть.

## Нейминг: sendCommand → runCommand

Вопрос: почему `send`, а не `write`, раз это I/O? Ответ: `write` было бы честно для чистого
примитива (это и есть `socket.zig` — `write`/`readExact`, только байты). Оркестратор же
делает полный round-trip (write+read+decode), и `send` для этого неточен — подразумевает
"отправил и забыл", а тут явно ждём и разбираем ответ.

Отдельно — пересечение слова "command" между `moveCommandString` и `sendCommand`. Разобрано:
это два **разных** "command", каждое из своей спеки, что как раз требует явного разбора по
нейминг-правилу `CLAUDE.md`:
- `moveCommandString` — sway command language (`man 5 sway`, Commands) — текст `"move left"`.
- оркестратор — sway-ipc message type `RUN_COMMAND`/`message.run_command` (`man 7 sway-ipc`,
  уже есть как константа в коде).

**Решено**: переименовать в `runCommand` — привязка к точной протокольной константе
(`run_command`), семантически честнее ("выполнить команду и получить результат", не "отправить
и забыть"). Коллизия слова "command" с `moveCommandString` остаётся, но теперь осознанная —
оба имени точно ссылаются на свою спеку, не совпадают случайно.

## Псевдокод цепочки move_fn (актуальный, вариант "тонкий socket.zig")

```
move_fn(ptr, direction):
    self = cast(ptr)
    command_string = moveCommandString(direction)              // commands.zig
    result = runCommand(self.stream, command_string)           // координатор, sway.adapter.zig
    return result

runCommand(stream, command_string):
    header_out = encodeHeader({                                // header.zig
        payload_length: len(command_string),
        payload_type: message.run_command
    })

    socket.write(stream, header_out)                           // socket.zig — сырые байты
    socket.write(stream, command_string)                       // socket.zig — сырые байты

    header_bytes = socket.readExact(stream, header_length)     // socket.zig
    header_in = decodeHeader(header_bytes)                     // header.zig

    body_bytes = socket.readExact(stream, header_in.payload_length)  // socket.zig

    result = decodeReply(header_in, body_bytes)                // commands.zig
                                                                //   internally → decodeRunCommandReply(body_bytes)
    return result
```

Нерешённые места внутри (перенесены из 08-27, всё ещё открыты):
- `self.stream` — откуда берётся соединение (адаптер открывает сам при `wrap()`/первом вызове,
  или стрим передаётся снаружи параметром) — не решено.
- буфер под `body_bytes` — через `Allocator` (размер известен только в рантайме из
  `header_in.payload_length`) или фиксированный буфер с проверкой переполнения — не решено.

## Где остановились технически (не закоммичено)

Git status на конец сессии:
- `sway.adapter.socket.zig` (старый, пустой) — удалён.
- `sway.adapter.zig` — `Header`/`PayloadType`/`FrameError`/`encodeHeader`/`decodeHeader`
  вынесены (корректно, копия без потерь), `move_fn`/`wrap()` остались, тело `move_fn` и
  `runCommand` — только псевдокод в комментариях, не реализовано.
- Новые untracked-файлы (**неймы будут переименованы**, см. ниже):
  `sway.adapter.utils.header.zig` — содержимое верное (`Header`, `PayloadType`, `FrameError`,
  `encodeHeader`, `decodeHeader` — 1:1 из старого файла), но лежит под неверным именем.
  `sway.adapter.utils.commands.zig` — пустой, ничего не перенесено.
  `sway.adapter.utils.socket.zig` — только два комментария-заглушки (`write`/`readExact`).

**Известная поломка сборки**: `sway.adapter.test.zig` (13 тестов) импортирует `sway.adapter.zig`
как `adapter_mod` и зовёт `adapter_mod.decodeHeader`/`encodeHeader`/`Header`/`FrameError` —
эти символы уже не в `sway.adapter.zig`. `zig build test` красный. Пользователь — "потом
поправлю", осознанно не блокирующий пункт на конец сессии.

## Следующая сессия

Начать с:
1. Переименовать `sway.adapter.utils.{header,commands,socket}.zig` →
   `sway.adapter.{header,commands,socket}.zig` (убрать `.utils.`, см. решение выше).
2. Перенести `moveCommandString`/`CommandResult`/`decodeReply`/`decodeRunCommandReply` —
   тела ещё не написаны нигде, только псевдокод — в `sway.adapter.commands.zig`.
3. Починить `sway.adapter.test.zig` — переключить импорт header-символов на новый файл.
4. Реализовать `runCommand` и тело `move_fn` по псевдокоду выше — упирается в два открытых
   вопроса (владение `stream`, буфер под `body_bytes`) — их решить первыми.
5. Переименовать `sendCommand` → `runCommand` везде, где уже написано (псевдокод/комментарии).
