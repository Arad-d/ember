# Architecture and design decisions

## Module map

| Module | Responsibility |
| --- | --- |
| `lib/models.dart` | Accounts, entries, reminders, currency parsing/formatting, and ledger balances |
| `lib/amount_input.dart` | English digit input, decimal rules, grouping, and caret behavior |
| `lib/store.dart` | Device demo persistence, optional Auth sessions, cloud requests, and snapshot refresh |
| `lib/main.dart` | Responsive shell, accounts, transactions, charts, and forms |
| `lib/forecast.dart` | Pure forecast calculation from selected accounts and planned movements |
| `lib/plan.dart` | Upcoming bills, expected income, account selection, and buffer settings |
| `lib/forecast_explanation.dart` | Daily breakdowns connected to their source records |
| `lib/what_if.dart` | Immutable scenario changes and comparison calculations |
| `lib/what_if_page.dart` | Purchase, income-delay, and bill-change simulation UI |
| `lib/calendar_export.dart` | Escaped, UTF-8-folded iCalendar events with optional alerts |
| `supabase/` | Optional schema, row ownership, grants, constraints, and transactional functions |

## Exact amounts and currencies

Balances and planned amounts use integer units. IRT uses whole toman; USD and EUR use cents, and GBP uses pence. The parsers avoid floating-point arithmetic for stored amounts. Input fields accept English digits; foreign-currency fields permit up to two fractional digits. Negative opening balances are supported.

A transfer references source and destination accounts belonging to the same user. The UI and database require matching currencies. Reports and forecasts operate within one selected currency; they do not invent exchange rates or combine unrelated currencies.

## Forecast behavior

The forecast starts from the recorded balance of selected accounts. Savings accounts are excluded by default unless selected. It includes outstanding bills, expected income, and future-dated transactions. Overdue bills are reserved today. Late expected income is excluded until its date is corrected or it is recorded as received.

Outflows are processed before inflows on the same day to show a conservative daily low. Daily low and closing balance are separate values. Available money is the minimum projected balance minus the safety buffer, bounded below by zero. A shortfall represents the estimate dropping below zero; a buffer warning represents the estimate dropping below the user's reserve.

The payday-aware summary runs to the next expected income date, or 30 days if there is no pending income. The What if? comparison uses a shared 30- or 60-day window. Neither calculation predicts unrecorded everyday expenses or automatically recurring events.

## What if? isolation

Both comparison plans use the same input snapshot, currency, selected accounts, buffer, and window. A changed bill replaces the original rather than being added twice. Income delayed beyond the window is excluded and flagged. Purchase scenarios add temporary planned outflows.

Scenario calculation has no storage or network operations. Changes live on the simulation screen and are discarded when leaving it. Widget tests verify that applying and editing simulations does not mutate the actual ledger.

## Demo and cloud storage

Demo data is fictional and stored through SharedPreferences. A fresh clone has no configured backend. Cloud integration is optional and requires the user's own Supabase URL, publishable key, and authenticated account. Demo changes are kept separate from cloud rows.

Cloud writes target individual records rather than replacing an entire stale local ledger. `read_ledger` returns one consistent database snapshot. Database ownership policies use `auth.uid()` and foreign keys bind account references to the same owner.

Recording a bill payment or receiving planned income uses a database transaction and row lock. The planned item's ID also identifies its ledger entry, so a repeated request cannot create a second expense or income transaction. Recording a payment does not initiate a bank transfer.

## Calendar copies

The export is a one-time `.ics` file, with a floating local-time event at 9 AM on the due date. Notes and titles are escaped, and long lines are folded by UTF-8 byte length. The user imports the file into their calendar and verifies its alert. The app does not connect to a calendar account or update existing exported events.

## Current tradeoffs

- The Flutter UI and store use a compact architecture suitable for this scope. The main screen module is large; a larger team could extract feature screens and storage interfaces.
- Cloud Auth is implemented through REST requests. It is covered by mocked client tests, but a production rollout should review session handling and add live authorization tests on an isolated backend.
- Native projects are scaffolding; web is the validated build target.
- Calendar import and forecast estimates depend on the user's own calendar settings and recorded plans.
- Automated checks provide regression coverage; they do not establish production financial or security compliance.
