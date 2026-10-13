# Savings goals connected to the cash-flow forecast

## Intent and agreed scope

Help Ember users work toward a purchase or savings milestone while understanding whether a contribution leaves enough money for upcoming bills. The user selected savings goals connected to the forecast and approved keeping them inside Plan, using one savings account per active goal. The experience must be attractive, easy to discover, and straightforward on phones.

## Navigation and appearance

Plan remains the entry point. Add a clearly titled “Savings goals” section immediately below the forecast summary and before the longer bill/income lists. Show an “Add goal” button beside its title. Reuse Ember’s current theme colors, spacing, rounded cards, and typography in both dark and pistachio/vanilla light themes.

On phones, cards form a single vertical list with no sideways scrolling. On desktop, use up to two columns when space permits. Each card shows the goal name, deadline, saved amount versus target, a progress bar, remaining amount, and monthly saving suggestion. “Try in forecast” is the primary action. Edit and Remove live in a clearly labeled overflow menu. Removing a goal never removes its account or transactions.

An empty state explains “Give your savings a goal” and provides one Add goal action. If no eligible savings account exists, show “Add a savings account first” with a button opening the Accounts page. Returning to Plan retains the selected currency. No new bottom navigation item is needed.

## Creation and editing

Use a scrollable form with a sheet on phones and a dialog on desktop. Fields: goal name, target amount, target date, and savings account. The header currency is the goal currency; show it beside the amount and filter eligible accounts accordingly. Use existing English-digit money formatting and the selected Gregorian or English Shamsi date picker. Save and Cancel remain reachable with the keyboard open.

Only Savings accounts in the selected currency are eligible. An account can back at most one goal. Existing account balance can already exceed the target; allow this and show the goal as reached. Editing preserves the current linked account as a valid option. Display useful validation messages beside fields; disable repeated submissions while saving.

Names are trimmed, nonempty, and at most 120 characters. Targets are positive and within the ledger's existing supported amount range. New deadlines cannot precede today. Existing overdue goals remain visible and editable. Account eligibility and uniqueness are checked in both the app and the database.

## Progress and monthly suggestion

Progress follows the actual linked savings account balance through today, including transfers. Future-dated transactions do not count as money already saved. Display saved amount as max(0, actual balance), remaining as max(0, target minus saved), and cap the progress bar at 100 percent. Clearly state “Progress follows this account’s balance”; withdrawing money may lower progress.

Count calendar months inclusively from the current month through the deadline month using the user's calendar. Monthly suggestion is remaining divided by that count, rounded upward to the smallest currency unit. Label it “Save about … each month” with the deadline. It is a planning suggestion, not a guarantee. If the deadline has passed and money remains, show “Deadline passed” and an Edit date action instead of a monthly suggestion. Reached goals show “Goal reached” and remain editable/removable; the account cannot back another goal until the existing goal is removed.

## Forecast preview

“Try in forecast” opens a sheet showing the goal, a contribution amount, date, and source account. Default the contribution to the monthly suggestion, the date to the next scheduled payday when available (otherwise today), and offer source accounts in the same currency that are included in the forecast, excluding the goal's destination account. Allow a user to adjust the amount and date. For overdue goals, default the amount to the remaining target.

Build an ephemeral transfer scenario using the existing what-if calculation. Show before/after estimated available spending, projected lowest balance and its date, and a clear warning when the proposed contribution dips below the safety buffer. Extend both comparison forecasts through the chosen contribution date when necessary. Apply the source debit and destination credit once: when both accounts are included in the forecast, their combined cash is unchanged; when only the source is included, available spending falls. Explain this result in ordinary language.

The preview does not create a transaction or increase saved progress. Label the action “Preview contribution” and show “A preview only. Record the transfer when you move the money.” Users can close it and return to the same Plan section. If no eligible source account exists, offer a direct route to forecast account settings. Do not create repeated income or contribution schedules in this first version.

## Data and synchronization

Introduce a focused SavingsGoal model and calculation module, separate from general UI code. A goal stores id, owner, name, target amount, currency, target date, linked savings account id, and timestamps. Saved progress is derived from ledger records, not persisted separately.

Persist demo goals alongside existing local demo records, with backward-compatible loading when the field is absent. Connected users store and load their own goals through the existing authenticated store workflow. Preserve demo and connected-workspace separation and normal mutation/error handling.

Provide an additive migration with owner-scoped row security, account ownership and currency/kind validation, and a uniqueness constraint for a user's linked account. Prevent deleting an account that still has a goal; tell the user to remove or relink the goal first. Load missing migration state gracefully: existing ledger features continue to work, and goal controls explain that setup is required. Do not report success for unsaved cloud goals.

## Validation and release

Test current versus future balances, negative balances, reached and overdue goals, monthly rounding, Gregorian/Shamsi month boundaries, and every transfer inclusion combination. Test local persistence, per-user goal isolation, invalid/duplicate account links, and linked-account deletion protection.

Exercise creation, edit, empty states, currency switching, preview and return navigation on narrow phone and desktop sizes in both themes. Verify keyboard accessibility, scrolling, readable labels, and no overflow. Existing reminders, forecast explanations, and what-if scenarios must continue to pass their relevant tests.

Implement and inspect a working preview before publishing. Preserve existing site access and keep public demo data fictional. Database changes must be installed before enabling cloud goal writes; publication follows verification.

## Acceptance

A user can find Savings goals in Plan, create a valid goal, understand its progress and monthly suggestion, preview a contribution's effect on bills and available spending, and return to the goal without losing their place. Currency and calendar preferences apply throughout. Goals persist across reloads and sync in the connected workspace without counting a savings transfer twice.
