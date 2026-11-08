# YASBA

*Yet Another Simple Budget App* — a simple, private budget tracker.

A privacy-friendly, fully offline income and expense tracker for Android and
iOS, built with Flutter. All data lives in a SQLite database on the device and
is never sent anywhere.

The app is available in **English** and **Turkish**. It follows the phone's
language by default; you can also pick one in Settings.

## Features

- **Income / expense records** — month-by-month list grouped by day,
  swipe to delete (with undo), monthly income/expense/balance summary.
- **Wallets** — cash, bank accounts, credit cards...: each with a colour,
  icon and starting balance (negative for debt). See every wallet's current
  balance and the total, and filter records and statistics by wallet.
- **Transfers between wallets** — move money from one wallet to another.
  Transfers change balances but count as neither income nor expense.
- **Debts** — money you lent or borrowed, per person, with an optional due
  date. Record partial repayments; a debt closes itself when fully paid (or
  close it by hand). Debts move wallet balances but are not income or expense;
  they can also be noted without touching any wallet.
- **Categories** — name, colour, icon or emoji; archiving.
- **Statistics** — monthly/yearly category breakdown (pie chart with
  percentages) and daily/monthly trend chart.
- **Recurring transactions** — "every N days/weeks/months/years"; due records
  are created automatically when the app starts. Month ends are handled
  correctly (Jan 31 → Feb 28 → Mar 31).
- **Backup and restore** — save all data to a `.json` file anywhere (e.g.
  Google Drive) and restore it later or on another phone. Restoring replaces
  all current data, after a confirmation.
- **Automatic backups** (off by default) — daily, weekly or monthly, taken
  when the app is opened and saved to Documents/YASBA; the last 5 are kept.
- **CSV export** — all records and transfers as a spreadsheet for Excel or
  Google Sheets.
- **Migrate from Oinkoin** — imports an Oinkoin `.json` backup: wallets,
  categories (colour, emoji), records, transfers and recurring transactions
  (including custom intervals). Importing the same backup twice does not
  duplicate anything. YASBA is not affiliated with Oinkoin; it only reads its
  backup format.

All wallets currently share one currency, chosen in Settings.

## Install

Download the latest `YASBA-x.y.z.apk` from
[Releases](https://github.com/xlulx/Yet-Another-Simple-Budget-App/releases) and
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
| `dev`  | YASBA Dev | `io.github.xlulx.yasba.dev` | Locally, for testing |
| `prod` | YASBA    | `io.github.xlulx.yasba`    | The Release APK workflow only |

Both can be installed side by side and keep separate data. Test builds are
signed with the intentionally public `android/keystores/dev.jks`.

```bash
flutter build apk --release --flavor dev --target-platform android-arm64
```

### Releases

The only GitHub Actions workflow, `.github/workflows/release.yml`, runs when
it is started manually (**Actions → Release APK → Run workflow**, with a
version such as `0.1.0`) or when a `v*` tag is pushed. It runs the tests,
creates the release if needed and attaches a signed `YASBA-x.y.z.apk`
(~8 minutes). It needs the `RELEASE_KEYSTORE_BASE64` and
`RELEASE_KEYSTORE_PASSWORD` repository secrets; the release key is **not**
stored in the repository.

## Architecture

```
lib/
  models/      Category, Record, RecurringRule, Wallet, Transfer
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
- Schema changes go through `onUpgrade` in `AppDatabase` (bump `_version`
  and add a `_upgradeToVn` step); the tests open a version 1 database to
  check the upgrade path.
- UI texts live in `lib/l10n/*.arb`. After editing them run `flutter gen-l10n`
  (it also runs automatically on `flutter pub get` / `flutter run`). To add a
  language, add `app_<code>.arb` next to the others.

## Roadmap (ideas)

- Budgets and limit alerts
- A currency per wallet, with exchange rates for transfers
- Tags and search
- Home screen widget, app lock (biometric)
- More languages

## License

Copyright (C) 2026 xlulx

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. See [LICENSE](LICENSE) for the full text.

---

YASBA is developed with the help of [Claude](https://claude.ai), Anthropic's
AI assistant.
