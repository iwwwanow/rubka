# 2026-08-27 — decodeReply: подтверждение оркестратора; полная цепочка sendCommand; смена сигнатуры порта

Продолжение серии decode (после 08-24, `docs/diary/2026-08-24_decodeReply-neyming-i-diagram-aktualizaciya.md`).
Сессия снова дискуссионная — но с конкретными решениями по архитектуре на сегодня и следующую сессию.

## decodeReply — подтверждено

Оркестратор/тонкий guard, как и было спроектировано 08-24: смотрит на `payload_type`,
при `message.run_command` зовёт `decodeRunCommandReply`, иначе — ошибка. Уточнение
нейминга: вторая функция — `decodeRunCommandReply`, не `decodeCommand` (сокращение
в разговоре, не по коду).

**`Header` — параметром, не пересчитывать внутри.** Решено на 100%: `decodeReply`
получает уже декодированный `Header` от вызывающей стороны (будущего
sendCommand-оркестратора), не вызывает `decodeHeader` сам. Логика та же, что уже
применили к `decodeRunCommandReply` в 08-24 (не передавать `payload_length`
отдельно, раз `buf` уже нарезан вызывающей стороной) — теперь то же правило и для
`Header`.

## Полная цепочка (псевдокод, сверху вниз)

```
CLI → MoveWindowUseCase.execute → WindowManagerPort.move
  → SwayWindowManagerAdapter.move_fn
      → commandString(direction)              [switch Direction → "move left" и т.п.]
      → encodeHeader + write в сокет
      → read(header_length) → decodeHeader → Header
      → read(header.payload_length) → body
      → decodeReply(header, body) → CommandResult
          → decodeRunCommandReply(body) → CommandResult
      → CommandResult → возврат наверх через порт
```

Ключевое имя для верхнеуровневой функции внутри `move_fn` — `sendCommand` (или
`runCommand`) — она и делает encode→write→read→decode за один вызов. У этого
"entrypoint" нет термина в `man sway-ipc` (протокол описывает только формат
сообщений, не то, как клиент дёргает сокет) — значит по правилу нейминга из
`CLAUDE.md` называем по смыслу и фиксируем явно, а не оставляем безымянным.

**Два разных switch, не путать:**
- encode-сторона: `Direction` → сырая командная строка — новый switch, живёт в
  маленьком хелпере (`commandString`), не в `decodeReply`.
- decode-сторона: `payload_type` → `decodeRunCommandReply`/ошибка — уже
  спроектированный switch внутри `decodeReply` (08-24), не трогаем.

Идея: `sendCommand` сам — прямая линия без ветвления, оба switch'а делегированы
вниз в маленькие функции.

## Разделение файлов — решено

Кодек (`encodeHeader`/`decodeHeader`/`decodeReply`/`decodeRunCommandReply`) —
чистые функции без I/O, остаются в `sway.adapter.zig`. Сокет-I/O —
**новый файл `sway.adapter.socket.zig`** (схема имён: `sway.adapter.*`, как уже
есть `.constants.zig`/`.test.zig`).

## Сигнатура порта меняется — решено

`WindowManagerPort.move_fn` сейчас `void` (fire-and-forget,
`window-manager.port.zig:6`) — будет возвращать результат (`!void` или `bool`,
конкретика — на детализацию). Мотивация та же, что в 08-24: move-window не знает,
сработала ли команда, а теперь `CommandResult` появляется по всей цепочке —
терять его на границе порта бессмысленно.

**Следствие: `stub.adapter.zig` сломается на компиляции**, не тихо — тип
`move_fn` там (`stub.adapter.zig:7`) перестанет совпадать с полем структуры
порта. Значит стаб тоже правится в ту же сессию, когда меняется сигнатура порта
(должен возвращать "всегда успех", раз реально ничего не делает).

## Побочное: `@tagName`

Builtin, возвращает имя активного тега enum'а/`union(enum)` как
`[:0]const u8`, комптайм, синхронизируется с объявлением автоматически (см.
`stub.adapter.zig:11`, `Zig Language Reference` → `@tagName`).

## `move_fn` — псевдокод последовательности вызовов (подтверждено)

```
move_fn(ptr, direction):
    self = cast ptr
    command_string = moveCommandString(direction)   // switch #1, encode-сторона
    result = sendCommand(command_string)
    return result

sendCommand(command_string):
    header_out = encodeHeader({ payload_length: len(command_string), payload_type: message.run_command })
    write(socket, header_out)
    write(socket, command_string)

    header_bytes = read(socket, header_length)
    header_in = decodeHeader(header_bytes)

    body_bytes = read(socket, header_in.payload_length)  // размер известен только после header_in

    result = decodeReply(header_in, body_bytes)          // switch #2, decode-сторона (уже спроектирован 08-24)
    return result
```

`move_fn` вызывает только `moveCommandString` и `sendCommand` — оба switch'а
делегированы вниз, сама `move_fn`/`sendCommand` линейны.

## `commandString` → `moveCommandString` — переименование, решено

`commandString(direction)` строит не абстрактную "команду", а конкретно текст
sway-command-language для `move` (`"move left"`/`"move right"`) — это **не**
sway-ipc wire-протокол (тот в `sway.adapter.constants.zig`, из `man 7
sway-ipc`), а отдельная спека — command language sway (`man 5 sway`, раздел
Commands). Раз функция специфична для одной команды — переименована в
`moveCommandString`, без попытки обобщить на другие sway-команды заранее
(`resize`/`workspace`/`kill` принимают структурно разные аргументы — обобщать
по одному примеру рано, велик шанс угадать не ту абстракцию).

**Структура вместо типов**: расширяемость закладывается на уровне файлов, не
типов. Новый файл `sway.adapter.command-string.zig` (по схеме `sway.adapter.*`)
— туда `moveCommandString` сейчас, `resizeCommandString` и т.п. позже, каждая
отдельной маленькой функцией. Полиморфный `Command`-union не вводим.

Литерал `"left"`/`"right"` отдельной константой не нужен — это уже
`@tagName(direction)`. Под вопросом только литерал `"move "` сам по себе (не
решено, нужна ли ему константа отдельно от `moveCommandString`).

**Уточнена роль `move_fn` относительно порта**: `move_fn` — реализация метода
порта (`WindowManagerPort.move`), то есть typed entrypoint на границе
use-case/адаптер. Идея "принимать с клиента сырые `команда`+`модификатор` и
слать прямо в `commandString`, тогда `move_fn` не нужна" — отклонена: это
стёрло бы границу порта (use case начал бы говорить на языке sway-команд
вместо доменного `Direction`), а port существует именно чтобы это
предотвратить (сегодня sway-адаптер, завтра, скажем, hyprland — use case не
должен меняться).

## Где остановились

В `sway.adapter.zig` (не закоммичено):
- добавлены `SwayWindowManagerAdapter` (пустая структура), `wrap()`, `move_fn` —
  но тело `move_fn` пока буквальная копия стаба (debug-print, `void`), это
  плейсхолдер, не финальная реализация;
- `decodeReply`/`decodeRunCommandReply` закомментированы (не компилировались без
  return-типов).

Не написано и не решено в деталях:
1. Конкретный error set для `decodeReply`/`decodeRunCommandReply` (можно
   отложить: `!CommandResult` без явного error set даст Zig вывести его из
   тела функции — это снимает часть срочности с этого пункта).
2. Форма `CommandResult` (`success: bool`, `error: ?[]const u8`, возможно
   `parse_error`).
3. Новый файл `sway.adapter.socket.zig` — не создан, содержимое не обсуждалось
   (connect, write, read — с чего начинать). Два открытых вопроса внутри
   `sendCommand`: (i) кто владеет соединением — сама открывает/закрывает
   сокет за вызов, или принимает уже открытый `std.net.Stream` параметром;
   (ii) буфер под `body_bytes` — через `Allocator` (размер известен только в
   рантайме, после чтения заголовка) или фиксированный буфер с проверкой
   переполнения.
4. Точный тип возврата у `WindowManagerPort.move`/`move_fn` (`!void` vs `bool`
   vs что-то с самим `CommandResult`).
5. Новый файл `sway.adapter.command-string.zig` — не создан; `moveCommandString`
   не написана (тело не обсуждалось, только имя и роль).
6. Тело `sendCommand` — не написано, но последовательность вызовов внутри неё
   зафиксирована псевдокодом выше.

## Следующая сессия

Начать с: `commandString()` → `moveCommandString()` — переименование/оформление
как первый конкретный шаг. Дальше кандидаты, по возрастанию связности с
остальным:
- (а) `CommandResult` + error set — разблокирует тело `decodeRunCommandReply`
  через `std.json.parseFromSlice`;
- (б) сигнатура `WindowManagerPort.move` + правка `stub.adapter.zig` — раз
  решение принято, можно закрыть отдельно от `std.json`;
- (в) `sway.adapter.socket.zig` (connect/write/read) и тело `sendCommand` —
  зависят от (а)/(б) по типам; решить сначала владение соединением и буфер
  под тело ответа (см. п.3 выше).
