# 2026-08-08 — Таблица MessageType/EventType и контракт Header для sway-декодера

Продолжили sway-адаптер: после фрейминга/magic-проверки перешли к тому, что
конкретно должен возвращать `decodeHeader` — структуре `Header` и типу для
поля `payload-type`. Заодно закрыли пробел из дневника 07-08: там список
событий был неполным (взят по памяти/остаточным знаниям), сегодня подняли
официальный man sway-ipc и он оказался шире.

## Таблица — источник `man 7 sway-ipc` (актуальный на этой машине)

Два раздела man-страницы:
- **MESSAGES AND REPLIES** — таблица `TYPE NUMBER | MESSAGE NAME` → это `MessageType`.
- **EVENTS** — таблица `EVENT TYPE | NAME` → это `EventType`.

### MessageType — 13 подряд + 2 sway-расширения (15 значений)

```
0  RUN_COMMAND
1  GET_WORKSPACES
2  SUBSCRIBE
3  GET_OUTPUTS
4  GET_TREE
5  GET_MARKS
6  GET_BAR_CONFIG
7  GET_VERSION
8  GET_BINDING_MODES
9  GET_CONFIG
10 SEND_TICK
11 SYNC
12 GET_BINDING_STATE
100 GET_INPUTS   ← sway-расширение, не из i3
101 GET_SEATS    ← sway-расширение, не из i3
```

### EventType — 8 подряд + 2 sway-расширения (10 значений)

Маска старшего бита (`0x80000000`) уже снята — это то, что окажется в руках
после `raw_type & 0x7FFFFFFF`:

```
0  workspace
1  output
2  mode
3  window
4  barconfig_update
5  binding
6  shutdown
7  tick
20 bar_state_update  ← 0x80000014, sway-расширение
21 input             ← 0x80000015, sway-расширение
```

Важно: список **не подряд** — разрыв между 12 и 100 у сообщений, между 7 и 20
у событий. Это прямой аргумент в пользу non-exhaustive enum (`_,`) — список
неполный уже сейчас, новые версии sway могут добавить что-то ещё за его
пределами. Финального решения exhaustive/non-exhaustive пока не приняли —
открытый вопрос на следующую сессию.

## Архитектурные решения по контракту Header

- Поле `payload-type` из заголовка — не сырое число, а сразу интерпретированное
  значение. Обсуждали два подхода (плоский enum на все значения сразу, или
  разделение по смыслу) — выбрали разделение: reply/message и event живут в
  разных числовых доменах (различаются только старшим битом), значит и типы
  должны быть разные, объединённые тегированным union'ом:

  ```
  const Header = struct {
      payload_length: u32,
      payload_type: PayloadType,
  };

  const PayloadType = union(enum) {
      message: MessageType,
      event: EventType,
  };

  const MessageType = enum(u32) {};  // теги пока не заполнены
  const EventType = enum(u32) {};    // теги пока не заполнены
  ```

- **Нейминг**: договорились держать имена полей/типов консистентными с
  терминологией man-страницы, а не изобретать свои — `payload_length`,
  `payload_type` (не `length`/`raw_type`/`type`). Зафиксировано отдельным
  правилом в `CLAUDE.md` проекта.
- Раскладка по битам: старший бит (позиция 31, вес `0x80000000`) — флаг
  "это событие, а не ответ". `raw_type & 0x80000000 != 0` — проверка флага.
  `raw_type & 0x7FFFFFFF` — маска, снимающая флаг и оставляющая чистый индекс
  события для конвертации в `EventType`.
- `Header.payload_length`/`payload_type` не хранят `magic` — она только
  проверяется (`InvalidMagic` при несовпадении), в структуру результата не
  попадает.

## Zig-заметки за сессию

- `test { ... }` — блок, компилируется только под `zig test`/`zig build test`.
  Тесты можно колоцировать в том же файле, что и код (как в самой stdlib).
- `std.testing`: `expect(bool)`, `expectEqual(expected, actual)`,
  `expectEqualSlices(T, expected, actual)`, `expectError(expected_error, union)`.
- Discovery тестов в `zig build test` идёт по графу `@import`, а не по файлам
  на диске — файл, который никто не импортирует, не тестируется. Раз
  `main.zig` теперь импортирует `sway.adapter.zig`, тесты внутри него попадают
  в `exe_tests`.
- Отдельный тест-файл (`sway.adapter.test.zig`) сам по себе не в графе — его
  затащили через `test { _ = @import("sway.adapter.test.zig"); }` прямо в
  `sway.adapter.zig`.
- `error{ A, B }` — error set: закрытый набор именованных тегов-ошибок без
  payload. `X!Y` — либо ошибка из `X`, либо значение `Y`.
- `union(enum) { a: A, b: B }` — тегированный union, доступ к неактивному
  полю — safety-checked panic, не UB. Разбор — через `switch`.
- `enum(u32) { name = N, ... }` — явные числовые значения тегов. `_,` в конце
  делает enum non-exhaustive (разрешает непоименованные значения).
  Конвертация числа в такой enum — `@enumFromInt` (паникует на невалидном
  значении, если enum exhaustive) или `std.meta.intToEnum` (безопасно,
  возвращает `!EnumType`).
- `std.mem.readInt(comptime T, buffer: *const [N]u8, endian)` — второй
  аргумент технически указатель на массив, но слайс с comptime-известными
  границами (`buf[6..10]`) коэрсится в него сам.
- `type` как идентификатор — не жёсткое ключевое слово, а примитив: полем
  структуры быть может (`type: u32,` компилируется), а вот локальной
  переменной/константой — нет (`error: name shadows primitive 'type'`).
- `@panic("msg")` — builtin, тип `noreturn`, годится как временная заглушка
  тела функции с любым возвращаемым типом, пока реализация не готова.

## Текущее состояние файлов (на конец сессии)

`src/infrastructure/adapters/sway.adapter.zig` — есть заготовка типов
(`Header`, `PayloadType`, `MessageType`, `EventType`, `FrameError`), но:
- `MessageType`/`EventType` — пустые enum'ы, теги из таблицы выше ещё не
  перенесены в код.
- `decodeHeader` — проверяет только magic, не читает `payload_length`/
  `payload_type`, и не возвращает `Header` на успешном пути (сейчас не
  скомпилируется как есть).
- `Header`, `PayloadType`, `MessageType`, `EventType` без `pub` — если тесту
  в отдельном файле понадобится конструировать/сравнивать эти типы напрямую,
  видимость нужно будет открыть.

`src/infrastructure/adapters/sway.adapter.test.zig` — создан, пустой, тестов
пока нет ни одного.

## Дальше

Следующая сессия начинается с переноса таблицы выше в код: заполнить теги
`MessageType`/`EventType` реальными значениями, решить exhaustive/
non-exhaustive для обоих, поправить `pub`-видимость по потребности теста,
дописать тело `decodeHeader` (length-guard, чтение `payload_length` и
`payload_type` через `readInt`, сборка `PayloadType` через маску+
`intToEnum`/`@enumFromInt`, `return` на успешном пути) и написать первый
реальный тест на фикстуре `GET_VERSION`-ответа.
