# Savings Goals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users track savings goals in Plan and preview how contributions affect the cash-flow forecast.

**Architecture:** A focused goal module derives progress from account balances. LedgerStore persists goals locally or in the connected workspace; dedicated widgets display goals and temporary contribution previews using the existing forecast engine.

**Tech Stack:** Flutter/Dart, shared_preferences, existing PostgREST requests, Supabase/Postgres.

**Spec:** ../specs/2026-10-13-savings-goals-design.md

## Global Constraints

- One savings account per active goal; only Savings accounts in the selected currency are eligible.
- Names are trimmed, nonempty, and at most 120 characters. Targets are positive and within the ledger's existing supported amount range.
- Future-dated transactions do not count as money already saved.
- Removing a goal never removes its account or transactions.
- Currency and calendar preferences apply throughout; English-digit money formatting and existing date pickers are reused.
- The preview does not create a transaction or increase saved progress.
- Both dark and pistachio/vanilla themes must work on phones and desktop.
- Database changes must be installed before enabling cloud goal writes; publication follows verification.

## Review Focus

- An account linked on another device must not accept a second goal: Task 2 tests uniqueness at database level.
- A linked account's kind or currency changes must not invalidate a goal silently: Task 2 tests guarded account edits.
- Switching currencies with a form open must not change that form's saved currency: Task 3 tests a captured currency.
- Editing an overdue goal's name must remain possible without changing its past deadline: Task 2 tests unchanged overdue dates.
- A contribution on today must affect the forecast once, despite actual balance excluding future records: Task 4 tests same-day adjustments.

## Files and responsibilities

Create `lib/savings_goal.dart` for the model/progress calculations, `lib/savings_goal_preview.dart` for forecast comparisons, and `lib/savings_goals_view.dart` for cards/forms/preview sheets. Modify `lib/store.dart` for persistence and guarded mutations, `lib/plan.dart` and `lib/main.dart` for navigation callbacks, and existing schema/setup documentation for installation. Add focused tests named below. Keep general forecast and what-if behavior intact.

### Task 1: Goal model and progress

**Files:** Create lib/savings_goal.dart, test/savings_goal_test.dart.
**Interfaces:** `SavingsGoal({required String id, required String name, required int target, required String currency, required DateTime deadline, required String accountId})`, `fromJson`, `toJson`; `GoalProgress calculateGoalProgress(SavingsGoal goal, Account account, Iterable<Entry> entries, DateTime now, AppCalendar calendar)` returns saved, remaining, fraction, monthlySuggestion, reached, overdue.

- [ ] Write failing tests with these assertions: saved balance 120 / target 300 gives remaining 180 and fraction .4; negative balance gives saved 0; balance 400 gives reached true/fraction 1; tomorrow's transfer does not increase today's saved amount; remaining 10 across 3 calendar months suggests 4; overdue dates produce no suggestion; Gregorian and Shamsi boundary examples follow their month counts; JSON round trips preserve all fields.
- [ ] Run `flutter test test/savings_goal_test.dart`; confirm failures come from the missing feature.
- [ ] Implement the model and pure calculation. Use existing balance calculation with entries through today and calendar helpers; calculate inclusive calendar-month count without assuming 30-day months.
- [ ] Rerun the focused tests; require all assertions passing. Commit only Task 1 files.

### Task 2: Persistence and owner-safe database behavior

**Files:** Modify lib/store.dart, supabase/schema.sql, SETUP.md; create test/savings_goal_store_test.dart and database regression SQL under supabase/tests/. Generate the migration filename using `supabase migration new savings_goals`; if the CLI is unavailable, resolve its supported setup before creating a migration.
**Interfaces:** LedgerStore exposes `List<SavingsGoal> savingsGoals`, `bool savingsGoalsAvailable`, `Future<void> saveSavingsGoal(SavingsGoal goal)`, and `Future<void> removeSavingsGoal(String id)`. Task 1 types are consumed unchanged.

- [ ] Write failing store tests for local reload, old records without goals, clearing workspace on sign-out, goal save/edit/remove, invalid targets and accounts, duplicate account links, deleting a linked account, and unchanged overdue-date edits. Removing a goal must preserve account and entries. Test failed requests preserve the previous state and surface errors.
- [ ] Run `flutter test test/savings_goal_store_test.dart`; confirm expected failures.
- [ ] Verify current Supabase docs/changelog per the Supabase skill. Implement goal loading through the ledger snapshot and mutations through the existing authenticated store workflow. Missing goals schema sets availability false without blocking the ledger; demo state supports goals.
- [ ] Add additive owner-scoped schema/RPCs: authenticated ownership in policies, SELECT plus UPDATE USING/WITH CHECK, a unique (user_id, account_id) constraint, foreign-key deletion protection, and server validation of target/name/account kind/currency. Guard changes to linked account kind/currency. Preserve existing snapshot response fields and migrations. Document installation order.
- [ ] Test database behavior with two synthetic authenticated users inside rollback transactions: cross-user reads/writes and account links rejected; duplicate links rejected; linked account deletion/kind/currency edits rejected; valid owner CRUD succeeds. Run advisors and focused store tests; commit Task 2 files only after results pass.

### Task 3: Discoverable cards and goal creation

**Files:** Create lib/savings_goals_view.dart, test/savings_goals_widget_test.dart; modify lib/plan.dart, lib/main.dart.
**Interfaces:** `SavingsGoalsView({required LedgerStore store, required String currency, required VoidCallback openAccounts, required VoidCallback openForecastSettings})`; PlanView forwards these callbacks from Home. It consumes Task 1 progress and Task 2 mutations.

- [ ] Write failing widget tests at widths 320, 390, and 1440, in both themes: find Savings goals near the forecast summary; open Add goal; save/edit/remove; empty currency state; no eligible account routes to Accounts; cancel returns to Plan; scroll with keyboard open; invalid fields remain visible; captured currency persists when the parent selection changes.
- [ ] Run `flutter test test/savings_goals_widget_test.dart`; confirm expected missing-widget failures.
- [ ] Build the section before long bill/income lists. Cards show name/deadline/progress/saved/remaining/monthly suggestion. Use one phone column and at most two desktop columns; no extra navigation destination. Phone forms use scrollable sheets; desktop forms use dialogs. Capture form currency and use existing amount/date components. Add overflow Edit/Remove; require confirmation for removing a goal. Show reached/overdue states and migration-required state clearly.
- [ ] Rerun widget tests; inspect that labels, primary actions and form errors fit without overflow. Commit Task 3 files.

### Task 4: Contribution preview

**Files:** Create lib/savings_goal_preview.dart, test/savings_goal_preview_test.dart; modify lib/savings_goals_view.dart, test/savings_goals_widget_test.dart.
**Interfaces:** `GoalContribution({required String sourceAccountId, required int amount, required DateTime date})`; `GoalForecastComparison previewGoalContribution(WhatIfSnapshot snapshot, SavingsGoal goal, GoalContribution contribution)` returns before/after ScenarioProjection. Reuse snapshot inputs and CashForecast/ScenarioProjection without changing existing scenario contracts.

- [ ] Write failing tests: source-only inclusion lowers combined balance; both accounts included leaves combined balance unchanged; destination-only raises it; neither leaves it unchanged; same-day contribution applies once; both comparison horizons extend equally to a later date; invalid amount/date/currency/source rejected; ledger entries and goal progress remain unchanged. Assert buffer warnings match the resulting lowest balance.
- [ ] Run `flutter test test/savings_goal_preview_test.dart`; confirm expected failures.
- [ ] Build ephemeral transfer projections with the same date horizon and baseline inputs. Today contributions adjust the opening amount rather than adding an actual ledger record. Future contributions use the existing forecast transfer calculation. Both-included transfers must have zero net effect, avoiding an artificial temporary dip from split debit/credit events.
- [ ] Add Try in forecast sheet with amount/date/source; source choices are included same-currency accounts excluding destination. Defaults follow the spec. Show before/after available spending, lowest balance/date and buffer warning. Exact copy: “A preview only. Record the transfer when you move the money.” No source routes to forecast settings. Extend widget tests for preview/close/back navigation and changing inputs.
- [ ] Run preview and widget tests; commit Task 4 files.

### Task 5: Verification and publication

**Files:** Update SETUP.md and feature documentation if present. Use existing Sites source and standalone GitHub checkouts for release, keeping their respective configuration.
**Interfaces:** All previous interfaces are integrated; no new public API.

- [ ] Run `flutter analyze` and the complete existing test suite. Require no analysis issues and all tests passing; inspect any new failure before making changes.
- [ ] Build web release and inspect the working UI on phone/desktop in both themes. Exercise creation through the goal preview and return path, plus currency/calendar changes. Save representative screenshots using fictional demo data. Correct observed usability defects only.
- [ ] Have one independent reviewer check the final implementation against the spec and database ownership/transfer invariants. Resolve actionable findings and rerun affected checks.
- [ ] Apply and verify the additive database migration before cloud publication using the supported Supabase workflow. Preserve site audience. Publish the verified Sites archive; verify terminal successful deployment.
- [ ] Update the standalone GitHub version with selected source changes only, use the protected PR/check workflow, and verify GitHub Pages serves the new build. Keep production database defaults and private records out of public source/demo.
- [ ] Report links, test/build results, and any real verification limits. Stop after the feature is verified and published.
