# 2026-08-21 — encodeHeader: тест на non-exhaustive enum

Продолжение серии 08-17…08-20 про `encodeHeader`. Взяли кандидата №4 из
списка в хвосте `sway.adapter.test.zig` — non-exhaustive enum значения.

## Путь к рабочей версии

Шли итеративно, каждая версия правилась по одному конкретному багу:

1. **Первый черновик** — только сборка `header`, без единого
   `testing.expect*`. Технически зелёный тест, но ничего не проверяет
   (`encodeHeader` мог бы делать что угодно). Разобрали разницу между
   `std.debug.assert` (прод, паника на false) и `std.testing.expect*`
   (тестовый API этого файла: `expectEqual`, `expectEqualSlices`,
   `expectError`).

2. **Добавили assert, но `@intFromEnum(9999)`** — не компилируется:
   `9999` это `comptime_int`, а не enum-значение, `@intFromEnum` работает
   в обратную сторону (enum → число). Плюс забыт бит event (`| 0x80000000`)
   — вариант был на `.event`, а без OR ожидание не совпадёт с тем, что
   реально шьёт `encodeHeader` в event-ветке.

3. **Переключились на `.message`** — снимает вопрос про OR полностью:
   `.message => |m| @intFromEnum(m)` кодирует без флага, так что тест
   остаётся сфокусирован ровно на одном свойстве (non-exhaustive enum
   кодируется как есть), не смешиваясь с логикой event-бита. Хорошее
   разделение забот, отдельно от чистой механики.

4. **`expectEqual(9999, decoded_raw_type)` — не типизируется.** Сигнатура
   `expectEqual(expected, actual: @TypeOf(expected))` требует совпадения
   типов; голый литерал `9999` — `comptime_int`, а `decoded_raw_type` —
   рантайм `u32`. Рантайм-значение не может стать аргументом типа
   `comptime_int`. Прецедент уже был в файле (строка 33,
   `@as(u32, example_json.len)`).

5. **Финал** — вынесли `9999` в `const non_exhaustive_value: u32 = 9999;`
   и использовали в обоих местах: `@enumFromInt(non_exhaustive_value)` и
   `expectEqual(non_exhaustive_value, decoded_raw_type)`. Это убрало
   дублирование магического числа **и** попутно закрыло проблему типов —
   константа с явным `u32` подставляется как `u32` в обоих местах, без
   отдельного `@as`.

Рабочая версия:

```zig
test "encodeHeader: non-exhaustive enum value" {
    const non_exhaustive_value: u32 = 9999;
    const header: adapter_mod.Header = .{ .payload_length = example_json.len, .payload_type = .{ .message = @enumFromInt(non_exhaustive_value) } };
    const frame: [constants_mod.header_length]u8 = adapter_mod.encodeHeader(header);
    const decoded_raw_type = std.mem.readInt(u32, frame[constants_mod.payload_raw_type_offset..][0..constants_mod.payload_raw_type_size], endian);
    try testing.expectEqual(non_exhaustive_value, decoded_raw_type);
}
```

Написан и вставлен в `sway.adapter.test.zig`, **не собран** (`zig build
test` — за пользователем) и не закоммичен (см. `git status`).

## Побочная правка

Комментарий-кандидат №3 ("payload_length — граничные значения") в хвосте
файла убран отдельно — устарел ещё с 08-20, тесты под ним уже были
написаны. Комментарий-кандидат №4 (non-exhaustive enum) теперь в том же
состоянии — тест написан, но комментарий над ним пока не убран.

## Round-trip тест (пункт 5) — закрыт

```zig
test "round trip" {
    const header: adapter_mod.Header = .{ .payload_length = 0, .payload_type = .{ .event = constants_mod.EventType.window } };
    const encoded_header_frame: [constants_mod.header_length]u8 = adapter_mod.encodeHeader(header);
    const decoded_header = try adapter_mod.decodeHeader(&encoded_header_frame);
    try testing.expectEqual(header, decoded_header);
}
```

Вопрос "как сравнивать `header` и `decoded_header` целиком" решили через
прямой `testing.expectEqual(header, decoded_header)` — `std.testing.expectEqual`
умеет рекурсивно сравнивать struct (по полям) и tagged union (сначала тег,
потом активное поле), так что `Header`/`PayloadType` сравниваются целиком
одним вызовом, без ручного разбора `.event`/`.message`. Альтернатива
(поле-за-полем, как в decodeHeader-тестах) обсуждена и отклонена в пользу
краткости.

Написан, вставлен в файл, **собран и зелёный** (`zig build test` — все
тесты проходят, гонял пользователь).

## Ревизия покрытия

Прошлись по всему списку кандидатов (1–5) — все закрыты: valid
message/event frame (decode+encode), payload_length границы,
non-exhaustive enum, round-trip. Error-пути `decodeHeader` (buffer too
short, invalid magic) тоже закрыты; у `encodeHeader` error-путей нет
(сигнатура не возвращает `!`).

Осознанно оставлено непокрытым (не баги, а "было бы чуть полнее",
не критично):
- round-trip проверен только для `.event`/`payload_length=0`; `.message`
  и/или `payload_length=maxInt(u32)` через round-trip не проверялись —
  комбинация уже закрытых по отдельности сценариев, не новый риск.
- non-exhaustive enum протестирован только на `.message` (осознанно,
  чтобы не мешать с OR-логикой) — `.event`-вариант с non-exhaustive
  значением отдельно не тестировался.
- строка в хвосте файла про "event + уже занятый 31-й бит в исходном
  enum-значении" — явно помечена как необязательный теоретический край,
  решили пропустить.

## Где остановились

Серия тестов для `encodeHeader`/`decodeHeader` (заголовок i3-ipc)
закрыта по всем пунктам плана. Все тесты зелёные. Не закоммичено (см.
`git status` — modified: `sway.adapter.test.zig`).

Пользователь на сегодня закончил с тестами, следующая сессия —
возврат к написанию кода (не тестов).

### Дальше (следующая сессия)

1. **Мелкие правки перед коммитом**:
   - убрать устаревший комментарий-пункт "4." над тестом non-exhaustive
     enum (аналогично тому, что сделали с пунктом "3." сегодня)
   - строка про round-trip (комментарий-пункт "5.") тоже устарела —
     тест написан, комментарий не убран
2. Закоммитить весь diff (non-exhaustive enum тест + round-trip тест +
   убранные комментарии-пункты 3/4/5)
3. **Следующий слой — не тесты, а код**: payload (`std.json`) или полный
   `encode` (заголовок + тело), как планировали 08-17/08-18. Конкретная
   форма API (что принимает `encode`, как сериализуется JSON-тело) не
   обсуждалась — с этого и начать следующую сессию.

Отдельно, вне этой серии, в `docs/planning.md` продолжает висеть
незакрытый пункт про `cli.move-window` (left/right), бьющий напрямую в
`adapters.sway` мимо application-порта — разрыв инверсии зависимостей —
и стилистику id `"move-window (direction)"`.
