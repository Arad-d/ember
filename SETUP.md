# Setup

## Demo mode

Use Flutter 3.38.3 (Dart 3.10.1) or a compatible newer SDK.

```sh
flutter pub get
flutter run -d chrome
```

A fresh installation opens fictional demo accounts, transactions, bills, and expected income. Demo changes are saved in local device/browser storage. The app has no default database URL, publishable key, or hosted domain. Each browser/device has its own demo; there is no cloud sync in demo mode.

## Optional: connect your own Supabase project

1. Create your own [Supabase project](https://supabase.com/dashboard). Keep its database password and secret keys private.
2. In that new project's SQL Editor, run these files **once, in order**:
   - `supabase/schema.sql` — accounts, entries, currencies, ownership policies, and transfer validation.
   - `supabase/add_expense_reminders.sql` — bill reminders and atomic payment recording.
   - `supabase/add_cash_flow_plan.sql` — expected income, forecast settings, and atomic income recording.
3. Create a user in Supabase Authentication. Ember supports existing users; it does not provide public sign-up. Use a strong password. If you use a recovery email, set the Supabase Site URL and allowed redirect URLs to your own app address.
4. Copy your project URL and **publishable** key. A legacy `anon` key is supported for compatibility. Never use `service_role` or `sb_secret_` in this client.
5. Open **Settings → Connect your workspace** and enter your project URL, publishable key, email, and password.

`add_account_currencies.sql` is an upgrade for older Ember schemas. A new database using the included `schema.sql` already has those currency changes and does not need that upgrade.

Cloud accounts start empty. Demo records are not copied into the cloud. Add your accounts and opening balances, then record transactions. Cloud writes require an internet connection; unsuccessful saves leave the form open so you can retry. The app fetches a consistent snapshot after writes, when returning to the app, and approximately every 20 seconds while active. Settings includes **Sync now**.

To embed your own public configuration into a build instead of entering it in Settings:

```sh
flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

These values are visible in the compiled client. Access control comes from Supabase Auth, database grants, and row-level security, not from hiding the publishable key.

Before using cloud sync with real information, inspect your project's Security Advisor and verify that signed-out requests and other users cannot access each user's rows. Passwords are not stored by the app, but signed-in sessions persist on the device. Sign out on shared devices.

## Build and host the web app

```sh
flutter build web --release --no-web-resources-cdn --pwa-strategy=none
```

Serve the contents of `build/web` on an HTTPS static host of your choice. No hosting account, project manifest, domain, or deployment automation is configured in this repository. No backend is needed to host demo mode.

If serving from a subdirectory, pass the appropriate `--base-href`, for example `--base-href=/ember/`. A phone can open the hosted address and use its browser's **Add to Home Screen** option. The installed shortcut has its own browser storage behavior.

## Native platform scaffolding

The source includes iOS and macOS projects. Use your own bundle identifier and Apple signing team for device/distribution builds. Xcode must be installed and configured.

```sh
flutter run -d macos
flutter build ios --release
```

Native builds and signing have not been validated. Calendar export currently targets web; native builds display guidance to use the web version.

## Run checks

```sh
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn --pwa-strategy=none
```

Optional screenshot output for the What if? widget workflow:

```sh
mkdir -p /tmp/ember-screenshots
EMBER_SCREENSHOT_DIR=/tmp/ember-screenshots flutter test test/what_if_widget_test.dart
```

The test suite uses fictional fixtures and mocked cloud requests. It does not need credentials for any live project.

## GitHub Pages demo

The demo is hosted at https://arad-d.github.io/ember/. The workflow scans secrets, runs analysis and tests, then builds with `--base-href /ember/` and deploys the `build/web` artifact. No database build defines or deployment credentials are supplied. Pull requests are checked but cannot deploy.

Publishing source is **GitHub Actions** in repository Settings → Pages. The `github-pages` environment is restricted to `main`. Updates reach the demo after the main-branch checks pass.

## Appearance and calendar

In Settings, choose Dark or Light (pistachio and vanilla), and Gregorian or Solar Hijri (Shamsi). Shamsi dates use English month names and digits. Monthly summaries and chart days follow the selected calendar. Preferences are saved on the current device. Stored dates and exported calendar events remain Gregorian for compatibility. Use the currency chooser in the top header to switch account currencies.
