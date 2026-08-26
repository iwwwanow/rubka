- [x] диаграмма (`docs/diagram.d2`): оба пункта фидбека закрыты коммитом `090e874`
      (30.07) — прямая стрелка cli→adapters.sway убрана (cli идёт только через
      use-case→port), id очищен до `move-window`, параметр вынесен в
      label/комментарий. Проверено 2026-08-24, расхождений с текущим кодом
      (`cli/move-window.cli.zig` → use-case → port) нет.

- [ ] payload сериализация в `sway.adapter.zig` (header уже готов —
      `encodeHeader`/`decodeHeader`, `a5a90fc`/`1f61539`). Скоуп — только под
      `move-window`, без генерализации на весь i3-ipc протокол заранее
      (обоснование — `docs/diary/2026-08-23_json-payload-scope-i-allocator-diskussiya.md`).
      Развилка на старт сессии: (а) минимальный `encode` под `run_command`
      без `std.json` (тело запроса — сырая строка) — самый короткий путь до
      рабочего end-to-end `move-window`; (б) сразу `std.json` под
      `subscribe`/ответ `run_command`, если важна надёжность (success/error)
      раньше, чем голый happy path.
