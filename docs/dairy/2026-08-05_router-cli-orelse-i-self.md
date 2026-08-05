# 2026-08-05 — router.cli.zig: orelse и self ещё не улеглись

- Написали первый черновик роутера команд, `presentation/cli/router.cli.zig`:
  `RouterCli` хранит `move_window_cli: MoveWindowCli`, метод `process`
  парсит `std.process.args()`, матчит строку на `port_mod.Direction` через
  `std.meta.stringToEnum`, и вызывает `.left()`/`.right()` по результату.

- Разобрали `orelse` — и главное, чем он **не является**: это не аналог
  Go-style `if err != nil`. В Zig это два разных механизма:
  - `?T` (optional, "значение или ничего", без причины отсутствия) →
    развязывается `orelse`.
  - `E!T` (error union, есть причина/тип ошибки) → развязывается `catch`
    (или `try` для проброса). Это ближе к Go. Наш `args.next()` и
    `stringToEnum` возвращают optional, не error union — поэтому в
    `router.cli.zig` везде `orelse`, а не `catch`.
  - `x orelse y`: если `x` (`?T`) не `null` — всё выражение равно
    развёрнутому значению `T`. Если `null` — исполняется `y`. `y` не
    обязан быть значением того же типа `T`: он может обрывать поток
    управления (`return`/`break`/`continue`/`unreachable`) и тогда тип
    всего выражения — просто `T`, потому что путь с `null` никогда не
    "довозвращает" значение наружу.
  - `return` внутри блока `orelse { return; }` выходит из **всей функции**
    (`process`), не из блока — блоков, из которых можно выйти отдельно от
    функции, в Zig нет.

- Разобрали ещё раз метод-сахар, но уже на двойной вложенности —
  `self.move_window_cli.left()` внутри `RouterCli.process`:
  1. `self.move_window_cli` — обычный доступ к полю (не вызов). `self`
     тут — параметр `process(self: RouterCli)`, то есть значение типа
     `RouterCli`; `.move_window_cli` достаёт из него поле типа
     `MoveWindowCli`.
  2. `.left()` — вот тут срабатывает сахар: `MoveWindowCli.left`
     объявлен как `fn left(self: MoveWindowCli) void`, и компилятор
     переписывает `(self.move_window_cli).left()` в
     `MoveWindowCli.left(self.move_window_cli)`. То есть `self` внутри
     `left()` — это **не** тот `self`, что в `process()`, это отдельный
     `self` своего метода, и им становится значение поля
     `move_window_cli`.
  - Общий вывод, до которого дошли в конце: чтобы вызвать `.left()`,
    компилятору нужно **любое** доступное в этой точке значение типа
    `MoveWindowCli` — неважно, откуда оно взялось (поле структуры,
    параметр функции, локальная переменная). Поле в `RouterCli` — просто
    конкретный способ, которым это значение сейчас доставляется до места
    вызова.
  - Итог: с первого раза понимание не улеглось, решили не давить дальше
    объяснениями и вместо этого прогнать флоу руками.

- Остался открытым `// TODO: is it needed to pass from composition root?`
  в `router.cli.zig` — ответ да, по аналогии с `MoveWindowCli`:
  `RouterCli` тоже должен собираться в `main.zig`, получая уже готовый
  `cli_impl` как поле, а не строить зависимости сам. Полная цепочка на
  сегодня (шаги 4 и 5 ещё не написаны в `main.zig`):
  ```
  1. adapter_impl : StubWindowManagerAdapter = .{}
  2. port_impl     = wrap(&adapter_impl)
  3. use_case_impl : MoveWindowUseCase = .{ .window_manager = port_impl }
  4. cli_impl      : MoveWindowCli     = .{ .move_window_use_case = use_case_impl }   ← не написан
  5. router_impl   : RouterCli         = .{ .move_window_cli = cli_impl }             ← не написан
  6. router_impl.process()                                                            ← замена printHelloWorld
  ```

- Всплыла развилка дизайна для шага 5 — как зависимость `MoveWindowCli`
  попадает в роутер:
  - **Вариант A (constructor injection, как в черновике)** — `RouterCli`
    хранит `move_window_cli` полем, зависимость привязывается один раз
    при сборке в composition root, `process(self: RouterCli)` берёт её
    из `self`.
  - **Вариант B (method injection, без структуры вообще)** — `process`
    становится свободной функцией модуля (как `wrap()` в
    `stub.adapter.zig`), принимающей `move_window_cli` обычным
    параметром; `RouterCli` как структура не нужна, шаг 5 схлопывается —
    composition root зовёт `router_mod.process(cli_impl)` напрямую.
  - Критерий выбора: поле оправдано, когда зависимость нужна в
    нескольких методах одного долгоживущего объекта; если вызов
    разовый (как здесь — `process` дёргается один раз из `main.zig`),
    структура-обёртка из одного поля — лишняя церемония, вариант B
    короче. Какой брать — решить в моменте сборки завтра.

## На завтра

Дособрать composition root с presentation layer: дописать шаги 4–5 в
`main.zig` (с учётом развилки A/B выше — определиться на месте), заменить
`iwwwanow_rubka.printHelloWorld()` на реальный вызов роутера, собрать и
прогнать с реальными argv (`left`/`right`).

Понимание `orelse` и вложенного self-сахара (см. выше) с первого раза не
улеглось — если по ходу сборки завтра снова начнёт путаться, вернуться к
идее ручной песочницы (простой пример вне `src/`, прогнать оба флоу по
шагам, для self-сахара — рядом явный вызов `Type.method(value)` без
сахара для сравнения) не как отдельная задача, а по необходимости.
