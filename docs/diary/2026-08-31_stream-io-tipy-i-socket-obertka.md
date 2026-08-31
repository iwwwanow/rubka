# 2026-08-31 — типы stream/io в zig 0.16, обёртка SwaySocket, доразбор пседокода runCommand

Продолжение серии после 08-30 (`docs/diary/2026-08-30_faylovaya-struktura-sway-adapter-i-neyming-sendCommand.md`).
Сессия — доразбор псевдокода `runCommand`/`move_fn` построчно, с уточнением типов под
конкретную версию zig (0.16.0). Коммит на конец сессии — `fa14a91` (детализация псевдокода,
всё ещё не компилируется, осознанный WIP).

## Тип `stream` и `io` — новый Io-стек в zig 0.16

Проверено по `/usr/lib/zig/std/Io/net.zig` (сетевой стек в 0.16 переехал под `std.Io`):

- `std.Io.net.Stream` — открытое соединение (получается через
  `UnixAddress.init(path)` → `.connect(io)`).
- Само чтение/запись — не методы `Stream` напрямую, а через `stream.reader(io, buffer)` /
  `stream.writer(io, buffer)`, обоим нужен ещё и `io: std.Io`.
- `std.Io` — не сокет и не то же самое, что `Stream`. Это абстрактный "исполнитель I/O"
  (через него библиотека дёргает `netRead`/`netWrite` и т.п., независимо от бэкенда). Нужен
  отдельным параметром **вместе** с `stream`, не вместо него — были попытки перепутать/слить
  их в один параметр, разобрано на примерах из stdlib (`stream.reader(io, buffer)` — оба сразу).

**Откуда взять `io`**: только из `std.process.Init` (полный, не `.Minimal` — у `.Minimal` нет
поля `io`). `main.zig` уже переключён на `std.process.Init` в `fa14a91`. Дальше `io` нужно
протащить от `main` до места создания сокета (composition root) — это отдельный провод,
ещё не сделан.

## Решение: обёртка `SwaySocket { io, stream }`

Раз `io` и `stream` в сокетном слое всегда используются парой — решено объединить их в свою
структуру (TODO уже стоит в `sway.adapter.socket.zig`, коммит `fa14a91`):

```
const SwaySocket = struct {
    io: std.Io,
    stream: std.Io.net.Stream,
};
```

Бонус: если `write`/`readExact` объявить внутри этой структуры (а не top-level в модуле),
получаем настоящий method-call sugar — `socket.write(data)` вместо
`socket_mod.write(io, stream, data)` (Zig триггерит сахар, когда функция лежит в namespace
типа и первый параметр — этот тип; в `socket.zig` пока top-level `pub fn`, это осознанно
самый простой вариант "просто функция из модуля" — оба стиля разобраны, финальный выбор
между top-level fn и методом на структуре не сделан).

Оговорка на будущее: `io` концептуально принадлежит всему процессу, не только sway-адаптеру.
Пока больше никто в проекте `io` не просит — объединение с `stream` оправдано без лишней
связанности. Если появится второй потребитель `io` (не через сокет) — решение пересмотреть.

## Уточнения по псевдокоду (ещё не исправлено в коде)

- `constants_mod.Message.run_command` — опечатка в имени типа, в `constants.zig` он называется
  `MessageType`, не `Message`.
- `Header.payload_type` — не голый enum, а тегированный union (`PayloadType` в `header.zig`):
  нужно `.{ .message = constants_mod.MessageType.run_command }`, не голое значение enum.
- `socket_mod.write(stream, header_out)` в текущем коммите — без `io`, хотя сигнатура `write`
  уже принимает `io` первым параметром. Не соответствует друг другу, поправить при следующей
  правке `runCommand`.
- `pub fn write(...) !void` — подтверждено, что `void` без error union был бы неверен (сетевые
  ошибки нельзя тихо терять), в `fa14a91` уже `!void`, тело пустое.
- `runCommand` без явного типа возврата — нужен error union (`!ReplyType` или похоже), пока не
  добавлено.
- `command_string` → `command_payload` — переименование для консистентности с
  `payload_length`/`payload_type` уже сделано в `move_fn` (`command_payload`,
  `getMoveCommandPayload`), но не везде в псевдокоде (`encodeHeader({ ... payload_length: len(command_string) ... })`
  внутри `runCommand` всё ещё старое имя).

## Фрейминг — уточнение (не код, концептуальный вопрос)

Разобрали, чем именно разделяются сообщения в потоке байт сокета: не magic-строкой, а
**длиной** (`payload_length` в заголовке — прочитал заголовок, узнал сколько байт payload'а
дальше, прочитал ровно столько). Magic-строка (`i3-ipc`) — только валидация/resync на границе
кадра, не разделитель. Отдельно от этого — разделение нескольких команд *внутри одного*
`RUN_COMMAND`-payload'а идёт через `;` на уровне sway command language, сокет об этом не знает.

## Известная поломка сборки — не устранена

`sway.adapter.test.zig` всё ещё импортирует `decodeHeader`/`encodeHeader`/`Header`/`FrameError`
как `adapter_mod.*` (`adapter_mod` = `sway.adapter.zig`), а эти символы теперь в
`sway.adapter.header.zig`. `zig build test` красный. Как и в 08-30 — осознанно не блокирующий
пункт, пользователь чинит отдельно.

## Следующая сессия

Начать с:
1. В `runCommand`/`move_fn` — поправить всё из "Уточнения по псевдокоду" выше (имя
   `MessageType`, union-обёртка `payload_type`, `io`-параметр у `socket_mod.write`, вернуть
   `command_payload` вместо `command_string` в `encodeHeader`-вызове).
2. Решить: `SwaySocket` — top-level функции в `socket.zig` (текущий вариант) или методы на
   структуре (`socket.write(data)`) — выбрать один стиль и применить.
3. Протащить `io` от `main.zig` (`init.io`) до места создания `SwaySocket` — где именно
   создаётся соединение с sway (в `wrap()`? при первом вызове `move_fn`?) — открытый вопрос,
   унаследован с 08-30 (`self.stream` — откуда берётся соединение).
4. Буфер под `body_bytes` — Allocator vs фиксированный буфер — всё ещё не решено (с 08-30).
5. Починить `sway.adapter.test.zig` — переключить импорт header-символов на `header_mod`.
