- [x] диаграмма (`docs/diagram.d2`): оба пункта фидбека закрыты коммитом `090e874`
      (30.07) — прямая стрелка cli→adapters.sway убрана (cli идёт только через
      use-case→port), id очищен до `move-window`, параметр вынесен в
      label/комментарий. Проверено 2026-08-24, расхождений с текущим кодом
      (`cli/move-window.cli.zig` → use-case → port) нет.

- [x] payload сериализация в `sway.adapter.zig` — выбран вариант (а): тело
      `run_command` — сырая строка (`commands.zig`), без `std.json`. Скоуп —
      только под `move-window`. 2026-10-04: `zig build run -- left` под живым
      sway двигает окно — первый рабочий end-to-end. Подробности —
      `docs/diary/2026-10-04_sway-adapter-end-to-end-move-window.md`.

- [ ] чтение ответа sway в `runCommand`: заголовок (14 байт, `decodeHeader`,
      проверка `payload_type`) → аллокатор (`init.gpa` в адаптер) → тело →
      сначала лог как есть, потом `std.json` (`decodeReply`, `success: false`
      → ошибка). План по шагам — в дневнике 2026-10-04.
