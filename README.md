# YAFA — Yet Another Financial App

A privacy-friendly, fully offline income and expense tracker for Android and
iOS, built with Flutter. All data lives in a SQLite database on the device and
is never sent anywhere.

The app is available in **English** and **Turkish**. It follows the phone's
language by default; you can also pick one in Settings.

## Features (v0.1)

- **Income / expense records** — month-by-month list grouped by day,
  swipe to delete (with undo), monthly income/expense/balance summary.
- **Categories** — name, colour, icon or emoji; archiving.
- **Statistics** — monthly/yearly category breakdown (pie chart with
  percentages) and daily/monthly trend chart.
- **Recurring transactions** — "every N days/weeks/months/years"; due records
  are created automatically when the app starts. Month ends are handled
  correctly (Jan 31 → Feb 28 → Mar 31).
- **Migrate from Oinkoin** — imports an Oinkoin `.json` backup: categories
  (colour, emoji), records and recurring transactions (including custom
  intervals). Importing the same backup twice does not duplicate records.

## Install

Download the latest `YAFA-x.y.z.apk` from
[Releases](https://github.com/xlulx/Yet-Another-Financial-App/releases) and
install it on your Android phone (64-bit / arm64).

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter run --flavor dev   # run on a connected device/emulator
```

### Flavors

| Flavor | App name | Package | Built by |
|---|---|---|---|
| `dev`  | YAFA Dev | `io.github.xlulx.yafa.dev` | Locally, for testing |
| `prod` | YAFA     | `io.github.xlulx.yafa`     | The Release APK workflow only |

Both can be installed side by side and keep separate data. Test builds are
signed with the intentionally public `android/keystores/dev.jks`.

```bash
flutter build apk --release --flavor dev --target-platform android-arm64
```

### Releases

The only GitHub Actions workflow, `.github/workflows/release.yml`, runs when
it is started manually (**Actions → Release APK → Run workflow**, with a
version such as `0.1.0`) or when a `v*` tag is pushed. It runs the tests,
creates the release if needed and attaches a signed `YAFA-x.y.z.apk`
(~8 minutes). It needs the `RELEASE_KEYSTORE_BASE64` and
`RELEASE_KEYSTORE_PASSWORD` repository secrets; the release key is **not**
stored in the repository.

## Architecture

```
lib/
  models/      Category, Record, RecurringRule (plain data classes)
  data/        AppDatabase — sqflite schema and queries
  services/    recurrence (date maths), recurring_service, oinkoin_import, stats
  state/       AppState (ChangeNotifier, via provider)
  ui/          pages and shared widgets
  utils/       money formatting/parsing, icon and colour lists
  l10n/        translations (app_en.arb, app_tr.arb) and generated code
```

- Amounts are stored as **integers in minor units** (no rounding errors).
  An amount is always positive; the category type (income/expense) gives
  its sign.
- Enum indexes are stored in the database: **only append** new values.
- UI texts live in `lib/l10n/*.arb`. After editing them run `flutter gen-l10n`
  (it also runs automatically on `flutter pub get` / `flutter run`). To add a
  language, add `app_<code>.arb` next to the others.

## Roadmap (ideas)

- Own backup/restore (JSON) and CSV export
- Budgets and limit alerts
- Multiple wallets / transfers between accounts
- Tags and search
- Home screen widget, app lock (biometric)
- More languages

## License

Copyright (C) 2026 xlulx

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. See [LICENSE](LICENSE) for the full text.
