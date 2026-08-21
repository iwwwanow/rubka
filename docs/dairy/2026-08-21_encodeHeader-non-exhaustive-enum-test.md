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

## Где остановились

Тест на non-exhaustive enum написан, не собран, не закоммичен.

### Дальше (следующая сессия)

1. **Мелкая правка**: убрать устаревший комментарий-пункт "4." над новым
   тестом (аналогично тому, что сделали с пунктом "3." сегодня).
2. Собрать (`zig build test`) и закоммитить пункты 3 (payload_length
   boundary — уже был закоммичен в `e0994ef`, но убедиться, что и текущий
   diff собирается) и 4 (non-exhaustive enum).
3. **Round-trip тест** (`decodeHeader(&encodeHeader(header))`) — пункт 5,
   последний кандидат в списке. С оговоркой из 08-19/08-20: дополняет, но
   не заменяет тесты с явно прописанными байтами — не поймает
   симметричный баг, сидящий одинаково в encode и decode.
4. После этого — payload (`std.json`) или полный `encode` (заголовок +
   тело), как планировали 08-17/08-18.

Отдельно, вне этой серии, в `docs/planning.md` продолжает висеть
незакрытый пункт про `cli.move-window` (left/right), бьющий напрямую в
`adapters.sway` мимо application-порта — разрыв инверсии зависимостей —
и стилистику id `"move-window (direction)"`.
