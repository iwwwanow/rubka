# Автоверсионирование и публикация в AUR

Идея: автоверсионирование через GitHub Actions под публикацию в AUR. Не
блокер, после того как есть рабочий `move-window` и появится смысл в
релизах.

- AUR сам по себе бесплатный, пуш через SSH-ключ, привязанный к аккаунту
  на aur.archlinux.org (`ssh://aur@aur.archlinux.org/<pkgname>.git`) —
  не требует денег, только PKGBUILD + `.SRCINFO`.
- `semantic-release` (как в TS-проектах) language-agnostic сам по себе,
  в Zig-репо работает так же (`npx semantic-release`, GH runner уже
  с Node). Специфика Zig — синхронизировать поле `.version` в
  `build.zig.zon` (аналог `version` в `package.json`):
  `@semantic-release/exec` (sed правит `build.zig.zon` на стадии prepare)
  + `@semantic-release/git` (коммитит файл обратно перед тегом).
- Альтернатива попроще: без conventional-commits дисциплины, версия
  только из git-тега (`git describe --tags`), тег руками
  (`gh release create`), Action на push тега просто собирает бинарник.
- Синергия с AUR: `-git`-пакет (`rubka-git`) с `pkgver()` из
  `git describe --tags` сам подхватывает новый тег при следующей сборке
  пользователем — ручное обновление PKGBUILD под каждый релиз не нужно,
  если версии идут через git-теги.
