# YASBA

*Yet Another Simple Budget App* — a simple, private budget tracker.

A privacy-friendly, fully offline income and expense tracker for Android,
built with Flutter. All data lives in a SQLite database on the device and is
never sent anywhere: the app does not even have internet access.

The app is available in **English** and **Turkish**. It follows the phone's
language by default; you can also pick one in Settings.

## Features

- **Income / expense records** — listed by day for the chosen period, with
  its income, expenses, net and the current balance at the top; swipe to
  move to the previous or next period.
- **Wallets** — cash, bank accounts, credit cards...: each with a colour,
  icon and starting balance (negative for debt). See every wallet's current
  balance and the total, and filter records and statistics by wallet.
- **Transfers between wallets** — move money from one wallet to another.
  Transfers change balances but count as neither income nor expense.
- **Debts** — money you lent or borrowed, per person, with an optional due
  date. Record partial repayments; a debt closes itself when fully paid.
  Debts move wallet balances but are not income or expense; they can also be
  noted without touching any wallet. Closing a debt by hand before it is
  repaid counts what is left as an expense (money lent) or income (money
  borrowed).
- **Categories** — name, colour, icon or emoji; archiving.
- **Statistics** — expenses, income or net for the period, with the
  average per day, week or month. Expenses and income by category as a pie
  chart or over time as a bar chart with an average line; tap a bar to see
  its records. The net can also show income and expenses side by side and
  a running total. Tap a category to see its records and its last 12 months.
- **Periods** — the records and statistics pages share one period: a month,
  a year, the last 3 or 12 months, or any range of days. The Debts page sums
  up the same period.
- **Recurring transactions** — "every N days/weeks/months/years"; due records
  are created automatically when the app opens or comes back to the
  foreground. Month ends are handled
  correctly (Jan 31 → Feb 28 → Mar 31).
- **Reminders** (off by default) — a notification on the day of recurring
  transactions and debt due dates, at a time you choose.
- **Backup and restore** — save all data to a `.json` file anywhere (e.g.
  Google Drive) and restore it later or on another phone. Restoring replaces
  all current data, after a confirmation.
- **Automatic backups** (off by default) — daily, weekly or monthly, taken
  when the app is opened and saved to Documents/YASBA; the last 5 are kept.
- **CSV export** — all records, transfers and debts as a spreadsheet for
  Excel or Google Sheets.
- **Migrate from Oinkoin** — imports an Oinkoin `.json` backup: wallets,
  categories (colour, emoji), records, transfers and recurring transactions
  (including custom intervals). Importing the same backup twice does not
  duplicate anything. YASBA is not affiliated with Oinkoin; it only reads its
  backup format.

- **Welcome screen** — on a fresh install: language and currency, what the
  app does, and restoring a backup from another phone.

All wallets currently share one currency, chosen in Settings.

See the [privacy policy](PRIVACY.md): YASBA collects no data at all.

## Install

Download the latest `YASBA-x.y.z.apk` from
[Releases](https://github.com/xlulx/Yet-Another-Simple-Budget-App/releases) and
install it on your Android phone (Android 7 or later, 64-bit / arm64). A
Google Play release is on the way; both are signed with the same key, so the
Play version updates an installed APK and the other way round.

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
| `prod` | YASBA    | `io.github.xlulx.yasba`    | The Release workflow only |

Both can be installed side by side and keep separate data. Test builds are
signed with the intentionally public `android/keystores/dev.jks`.

```bash
flutter build apk --release --flavor dev --target-platform android-arm64
```

### Releases

The only GitHub Actions workflow, `.github/workflows/release.yml`, runs when
it is started manually (**Actions → Release → Run workflow**, with a version
such as `1.2.3`) or when a `v*` tag is pushed. It runs the tests, creates the
release if needed and attaches a signed `YASBA-x.y.z.apk`. The version code
comes from the version (`1.2.3` → `10203`), so it always grows.

Secrets (the release key is **not** stored in the repository):

- `RELEASE_KEYSTORE_BASE64`, `RELEASE_KEYSTORE_PASSWORD` — the release key.
  It signs the APK and is also Google Play's app signing key, so APKs from
  GitHub and installs from Play update each other.
- `PLAY_SERVICE_ACCOUNT_JSON` (optional) — a Google Cloud service account
  with release rights in the Play Console. When set, the workflow also
  builds an App Bundle and uploads it to Google Play as a draft on a testing
  track (closed testing by default), to be rolled out from the Play Console.
- `UPLOAD_KEYSTORE_BASE64`, `UPLOAD_KEYSTORE_PASSWORD` — needed with the Play
  secret: the upload key that signs the App Bundle. Play requires it to be a
  different key from the app signing key; Play re-signs the app with the
  release key.

### Screenshots and store images

`test_screens/screens_test.dart` renders the main screens with sample data
in English and Turkish; `store/compose.js` turns them into the Google Play
images in `store/images/`. Store texts are in `store/listing.md`, the privacy
policy in `PRIVACY.md`.

```bash
SHOT_DIR=/tmp/raw SHOT_HEIGHT=1920 flutter test test_screens/screens_test.dart
node store/compose.js /tmp/raw   # needs Playwright with Chromium
```

## Architecture

```
lib/
  models/      Category, Record, RecurringRule, Wallet, Transfer, Debt, Period
  data/        AppDatabase — sqflite schema and queries
  services/    backup, auto_backup, csv_export, oinkoin_import, recurrence
               (date maths), recurring_service, reminders, stats
  state/       AppState (ChangeNotifier, via provider)
  ui/          pages and shared widgets
  utils/       money formatting/parsing, icon and colour lists
  l10n/        translations (app_en.arb, app_tr.arb) and generated code
android/       Android project; MainActivity writes automatic backups
store/         Google Play texts and images
test/          unit and widget tests
test_screens/  screenshots (not part of `flutter test`)
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
- Swipe to delete records, with undo
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
