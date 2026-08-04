# 2026-08-04 — план сборки composition root

- Подтвердили порядок сборки composition root в `main.zig`: снизу вверх —
  сначала конкретный адаптер (`StubWindowManagerAdapter`), затем оборачивание
  его в `Port` и передача в `MoveWindowUseCase`, затем сам use-case передаётся
  в `MoveWindowCli`. Это ровно то, что было записано во вчерашнем "На завтра"
  (`docs/dairy/2026-08-04_stub-adapter-vtable.md`).
- Разобрали первый практический шаг — импорт `StubWindowManagerAdapter` в
  `main.zig`. Выбрали относительный `@import` (а не реэкспорт через
  `root.zig`) как временное решение. Модули/баррель-файлы на слой (по
  аналогии с `index.ts` в TS — один файл на слой, реэкспортирующий всё
  наружу) отложили на потом, когда дойдёт очередь бить проект на отдельные
  Zig-модули.
- Отметили нюанс относительного пути: `main.zig` лежит в корне `src/`, а не
  на два уровня глубже, как `move-window.cli.zig` (у которого путь
  `../../application/...`). Путь от `main.zig` до
  `infrastructure/adapters/stub.adapter.zig` короче — без `../` вообще.
- Повторили нюанс `var` vs `const` для инстанса адаптера в `main.zig`:
  `wrap` принимает `*StubWindowManagerAdapter` (указатель), значит нужен
  `var`-инстанс с адресуемой памятью, а не `const`.

- Написали и поправили первую часть composition root в `main.zig` — адаптер
  → use-case. По пути разобрали три ошибки подряд:
  - `wrap(adapter_mod.StubWindowManagerAdapter)` — передавали **тип**, а не
    инстанс. `wrap` ждёт `*StubWindowManagerAdapter` (указатель на значение),
    типу указывать не на что.
  - `= {}` вместо `= .{}` — `{}` в Zig это пустой *блок* (`void`), не литерал
    структуры. Литерал (даже пустой, для типа без полей) — всегда с точкой
    впереди: `.{}`.
  - `*adapter_impl` вместо `&adapter_impl` — `*T` синтаксис *типа* (указатель
    на тип), а не оператор взятия адреса. Взять адрес значения — это `&`.
  - Была попытка положить результат `wrap` обратно в `adapter_impl` — не
    сработало бы: `var` не меняет тип на лету, `adapter_impl` объявлен как
    `StubWindowManagerAdapter`, а `wrap` возвращает `WindowManagerPort`.
    Завели отдельную `const port_impl` под результат.
  - Итоговая рабочая форма:
    ```
    var adapter_impl: adapter_mod.StubWindowManagerAdapter = .{};
    const port_impl = adapter_mod.wrap(&adapter_impl);
    const use_case_impl: use_case_mod.MoveWindowUseCase = .{ .window_manager = port_impl };
    ```
    Шаг 2 из трёх (адаптер → use-case) закрыт.

## Справка: все смыслы точки `.` в проекте (повторить завтра первым делом)

В коде проекта точка используется в нескольких *не связанных друг с другом*
синтаксически ролях. Путаница между ними — источник сегодняшних ошибок
(`{}` vs `.{}`) и вчерашних (`x.foo()` vs обычный вызов). Разбор по примерам
из наших файлов:

1. **Доступ к полю/декларации namespace** — `имя.имя`, где слева —
   значение или сам импортированный модуль (модуль в Zig — это тоже
   struct-подобный namespace). Примеры:
   `adapter_mod.StubWindowManagerAdapter`, `port_mod.Direction`,
   `self.window_manager` (`move-window.use-case.zig:7`). Точка тут — просто
   "зайти внутрь и достать по имени".

2. **Сахар вызова метода через точку** — `x.foo(args)` компилятор
   переписывает в `T.foo(x, args)`, **если** `foo` объявлена внутри
   `struct`/`namespace` типа `T`, и её первый параметр по типу — `T`/`*T`/
   `*const T`. Пример: `self.window_manager.move(direction)`
   (`move-window.use-case.zig:7`) разворачивается в
   `WindowManagerPort.move(self.window_manager, direction)`, потому что
   `move` объявлен внутри `WindowManagerPort` первым параметром `self:
   WindowManagerPort` (`window-manager.port.zig:8`). Без этого условия
   (как было с `move_fn` в `stub.adapter.zig` — та функция лежит *рядом* со
   структурой, не внутри её namespace, и первый параметр там `*anyopaque`,
   не `*StubWindowManagerAdapter`) сахар не сработает, нужен обычный вызов
   функции.

3. **Литерал структуры** — `.{ .поле = значение, ... }`, точка перед
   скобкой запускает построение значения структуры, тип которой выводится
   из контекста (тип объявленной переменной, возвращаемый тип функции и
   т.п.), явно его писать не нужно. Примеры: `.{ .ptr = self, .move_fn =
   move_fn }` в `wrap` (`stub.adapter.zig:16`), `.{ .window_manager =
   port_impl }` для `use_case_impl` (сегодня), `.{}` — тот же литерал, но
   без полей, для типа без полей (`StubWindowManagerAdapter`). `{}` без
   точки — это блок, который даёт `void`, не структуру: похожие по буквам,
   разные конструкции.

4. **Enum-литерал с выводом типа** — `.left`, `.right` без явного имени
   типа `Direction` перед точкой. Пример: `self.move_window_use_case.execute(.left)`
   (`move-window.cli.zig:8`) — тип `Direction` выводится из сигнатуры
   `execute(self, direction: Direction)`, поэтому писать `Direction.left`
   не нужно, `.left` достаточно.

## На завтра / дальше

Начать с повторения точки — пройтись по всем четырём пунктам справки выше
на реальном коде, желательно вслух объяснить каждый пример своими словами.
Дальше — шаг 3: передать `use_case_impl` в `MoveWindowCli` (тот же
литерал-паттерн, поле `move_window_use_case`), и после того как это
соберётся — разобрать парсинг `argv` (`std.process.args`) и вызов
`left`/`right` по аргументу командной строки.
