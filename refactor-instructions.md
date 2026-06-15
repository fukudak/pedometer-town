# Refactoring Instructions

## Objective
Increase change-ability of the "万歩計タウン" (Pedometer Town) Flutter app **without altering any observable behavior that is currently covered by tests or fixed by `doc/ai-implementation-spec.md`**.
Target end-state:
- A **single source of truth** for derived game values (battery capacity, energy coefficient) so building effects cannot silently diverge between providers.
- Provider wiring that is honest about its dependencies (no decorative `ChangeNotifierProxyProvider` whose `update` is a no-op).
- A safety net of **provider-level tests** for the step-sync / daily-cap / build-effect flows, plus an injectable clock so date-dependent logic becomes testable.
- No dead code paths presented as features (notably the park coefficient effect and `EnergyProvider.refreshDisplay`).

This is a structural refactor, not a feature change. Game-balance numbers in `lib/constants/` must not be tuned here.

## Project Understanding
- **Overview**: Fully offline Flutter app. Real-world steps (from HealthKit / Health Connect via the `health` package) are converted to "movement energy" (Wh), stored in a battery, and spent to construct buildings that develop a town. Spec of record: `doc/ai-implementation-spec.md` (Flutter version supersedes the React-era `doc/設計書.md`).
- **Key Workflows & Data Flow**:
  1. **Sync**: `HomeScreen` → `EnergyProvider.syncStepsFromHealth()` → `HealthService.getTodaySteps()` → delta steps → `EnergyCalculator.calculateEnergyWh` + `clampDailyEnergy` (5000 Wh/day cap) → `BatteryState.addEnergy` → persist `BatteryState` + `DailyStepRecord` via `LocalStorage`.
  2. **Build**: `TownScreen` → `TownProvider.buildBuilding(type)` → `BatteryState.consumeEnergy(cost)` → append `Building` → recompute capacity → `EnergyProvider.applyBatteryState` → persist `TownState`.
  3. **Settings**: `SettingsScreen` → `SettingsProvider.updateWeight/updateSpeed` (range-validated) → persist `PlayerSettings`.
- **Entry Points & Modules**:
  - `lib/main.dart` — `configure()` health, load `SharedPreferences`, `runApp`.
  - `lib/app.dart` — `MultiProvider` + `MaterialApp`; home = `HomeScreen`.
  - `lib/domain/` — pure logic (`EnergyCalculator`, `TownLogic`) + models. **Test target / source of truth.**
  - `lib/data/local_storage.dart` — `SharedPreferences` wrapper (keys fixed by spec §4).
  - `lib/services/health_service.dart` — `health` package wrapper; throws `HealthServiceException`.
  - `lib/providers/` — `SettingsProvider`, `EnergyProvider`, `TownProvider` (`ChangeNotifier`).
  - `lib/screens/` — `HomeScreen`, `SettingsScreen`, `TownScreen`.
- **External Dependencies**: `health ^11.0.0` (HealthKit / Health Connect — permission + steps), `provider ^6.1.0` (state), `shared_preferences ^2.3.0` (persistence). No network, billing, auth, or backend (offline by spec §0.3).

## Baseline Commands
Run and record results **before** and **after** every phase:
```bash
flutter analyze            # must stay: "No issues found!"
flutter test               # must stay: all tests passed (currently 32)
flutter pub get            # only if pubspec changes (it should NOT for this refactor)
```
Do not introduce new build/lint/test tooling.

## Behaviors To Preserve
- Energy formula and the two spec example values (§3.2): `70kg,5km/h,1000steps → 10.0 Wh`; `84kg,6km/h,5000steps → 72.0 Wh`. Daily cap = 5000 Wh.
- Battery: initial stored 0 Wh, initial capacity 10000 Wh; overflow is lost; `consumeEnergy` fails (returns `success:false`, unchanged state) when insufficient.
- Building costs (house 500 / powerPlant 1000 / park 800) and capacity effect (+2000 Wh per power plant). Multiple buildings of same type allowed.
- `SharedPreferences` **key names and JSON shapes** in `lib/data/local_storage.dart` (spec §4) — these are persisted-data contracts. Changing a key or shape breaks existing installs and **requires a Stop-and-Ask** (see below).
- All currently passing tests in `test/` must remain green and unmodified in intent. Tests are the source of truth; if implementation conflicts with a test, fix the implementation.
- `HealthService` public surface (`configure`, `requestPermissions`, `getTodaySteps`, `HealthServiceException`) and the `HomeScreen` SnackBar error UX.

## Non-Negotiables & Constraints (Boundaries)
The implementation model MUST strictly obey:
- Run `git status` first; do not mix your changes with any pre-existing uncommitted work. (Note: at time of writing the whole Flutter project is still untracked/uncommitted — coordinate with the human before committing.)
- Record baseline verification output before editing.
- Split changes into small, revertible commits (one concern per commit).
- No unrelated reformatting and no opportunistic "while I'm here" refactors.
- Do not change existing behavior. Do not tune any numeric constant in `lib/constants/`.
- 💡 **No unrequested self-initiated artifacts**: do not create defensive git-branch backups, undocumented helper docs, email drafts, etc. Only create files this brief explicitly authorizes (a clock abstraction, new test files, and a `.claudelog/lessons-learned.md`).
- Run the Baseline Commands after every code change / at every phase boundary.

## Stop And Ask Conditions
Interrupt and ask the human **only** when one of these is hit; otherwise proceed autonomously:
1. A **destructive / irreversible** operation would be required (e.g., changing a `SharedPreferences` key or JSON shape that would invalidate already-persisted user data, with no migration path).
2. The **true scope/goal changes** (e.g., the refactor would require wiring the park coefficient into sync, which alters game behavior — a product decision, see Q1/Q2 below).
3. Information **only the human can provide** is missing (intended semantics of an ambiguous spec field).

## Memory System (Lessons Log)
Maintain `.claudelog/lessons-learned.md`. Append one lesson per file/context as a single line + short note: errors hit and their fix, or a confirmed-good pattern. Externalize memory as you go so a later context can resume safely.

## Debt Map
Legend — **Authority**: `IMPLEMENT` = safe to do now within this brief; `PROPOSE-ONLY` = design and write up, do **not** change behavior without human approval.

| # | Evidence (file) | Issue | Reason / Risk | Fix proposal | Verification | Authority |
|---|---|---|---|---|---|---|
| D1 | `lib/providers/energy_provider.dart` (`syncStepsFromHealth` uses default coefficient) + `lib/providers/town_provider.dart` (`effectiveCoefficient` getter) | **Park effect is dead.** `TownLogic.effectiveCoefficient` is computed and exposed but never used; sync always uses `GameConstants.energyCoefficient`. Park's "+10% coefficient" (spec §6.1) has no runtime effect. | Functional gap vs spec; a getter with zero readers is misleading dead code. Wiring it changes energy output → game balance. | Decide intended behavior (see Q1). If "apply": invert/introduce dependency so the energy calc reads the town-effective coefficient (without creating a Provider cycle — e.g., pass a coefficient supplier into `EnergyProvider`, or read via `context` at call site). If "do not apply in MVP": remove the dead `effectiveCoefficient` getter and document park as cosmetic/future. | New provider test asserting chosen behavior; `flutter test` green. | **PROPOSE-ONLY** |
| D2 | `lib/data/local_storage.dart` key `battery_base_capacity_wh`; `lib/providers/town_provider.dart` `buildBuilding`; `lib/providers/energy_provider.dart` load | **Capacity has two sources of truth.** Spec §4.2 says the key stores **base** capacity (effect-free) and effective is derived at runtime. Implementation instead writes the **effective** capacity into that key and reloads it as `capacityWh`. Works today only because build always recomputes from the constant base, but the persisted field contradicts its spec'd meaning. | Latent contract drift; future code reading `capacityWh` as "base" would be wrong; capacity duplicated between `TownState` (true source) and persisted battery. | Make capacity **derived**: persist only base + buildings; compute effective capacity in one place (`TownLogic.effectiveCapacity`) wherever capacity is read. Keeps key meaning = base. **Touching the persisted key shape requires Stop-and-Ask (Q2) / migration.** | Add provider test: build power plant → capacity 12000; restart (reload from storage) → capacity still 12000 derived. `flutter test` green. | **PROPOSE-ONLY** |
| D3 | `lib/app.dart` `ChangeNotifierProxyProvider` for `EnergyProvider` and `TownProvider` | `update` callbacks are no-ops (`previous ?? ...`); dependencies are actually captured via `context.read` in `create`. The proxy advertises a reactive dependency that does not exist. | Misleading abstraction; future maintainer may assume settings/energy changes propagate through `update`. | Replace with plain `ChangeNotifierProvider` (deps via `context.read` in `create`) **iff** behavior is identical, OR make `update` genuinely meaningful. Confirm no rebuild semantics are lost. | `flutter analyze` + `flutter test` green; widget smoke test still passes. | **IMPLEMENT** (behavior-preserving) |
| D4 | `lib/providers/energy_provider.dart` `refreshDisplay()` | Dead code: defined, no caller. But spec §5.4 lists it as an `EnergyProvider` method. | Removing may violate spec API list; keeping leaves untested dead code. | See Q3. Either keep + add a test that exercises it, or remove with human sign-off that the spec API list is non-binding. | If kept: provider test calling `refreshDisplay`. `flutter test` green. | **PROPOSE-ONLY** |
| D5 | `lib/providers/energy_provider.dart` `_todayKey()` uses `DateTime.now()` directly; same in constructor | Date logic (day rollover branch in `syncStepsFromHealth`, daily-cap carryover) is **untestable** because time is not injectable. | Test gap on a correctness-critical path (cap reset at midnight, delta-step accounting). | Introduce a minimal injectable clock (e.g., `DateTime Function() now` defaulted to `DateTime.now`) into `EnergyProvider`. Behavior-preserving (default identical). | New tests: day-rollover resets daily record; multiple syncs within a day accumulate and respect the 5000 Wh cap. `flutter test` green. | **IMPLEMENT** (additive) |
| D6 | `test/` (only domain + storage + one widget smoke test) | No provider-level tests; build→capacity wiring, sync delta + daily cap across calls, and error propagation are uncovered. | Refactors D1–D5 are risky without a behavioral net. | Add provider tests using mocked `SharedPreferences` and a fake `HealthService` (inject via existing constructor `HealthService({Health? health})` or a small interface). | New test files green; total count increases; existing 32 unaffected. | **IMPLEMENT** |
| D7 | `lib/main.dart` `await healthService.configure()` unguarded | If `configure()` throws, the app crashes before `runApp`. | Robustness only; not currently spec'd. Low priority. | Note as future hardening; do **not** add fallback behavior beyond spec in this refactor. | n/a | **PROPOSE-ONLY** |

## Implementation Phases
Each phase ends with the Baseline Commands and a commit. Stop at the first failing verification.

**Phase 0 — Establish baseline (no code change)**
- `git status`, then run `flutter analyze` and `flutter test`; record outputs (currently: analyze clean, 32 tests pass) into `.claudelog/lessons-learned.md`.

**Phase 1 — Safety net first (D6, D5-additive)**
- Add an injectable clock to `EnergyProvider` (default `DateTime.now`) — additive, behavior-preserving (D5).
- Add provider tests (D6): build→capacity (12000 after one power plant), multi-sync daily-cap accumulation, day-rollover reset, `HealthServiceException` propagation from `syncStepsFromHealth`. Use the existing `HealthService({Health? health})` seam or a thin fake.
- Verify green. These tests become the net for later phases.

**Phase 2 — Low-risk honest-abstraction cleanup (D3)**
- Replace the no-op `ChangeNotifierProxyProvider`s with plain providers (or make `update` meaningful), keeping behavior identical. Re-run widget smoke + provider tests.

**Phase 3 — Single source of truth for derived values (D1, D2, D4) — PROPOSE-ONLY until approved**
- Do **not** change persisted key shapes or energy output without resolving Q1/Q2/Q3.
- Produce a concrete design (in the lessons log or a short PR description) for: deriving capacity (D2), wiring-or-removing the park coefficient (D1), and the fate of `refreshDisplay` (D4). Implement only the parts the human approves; anything touching `SharedPreferences` keys/shapes or energy output is gated.

Large design changes beyond the above are forbidden without explicit approval; capture them as proposals only.

## Verification Requirements
- Per phase: `flutter analyze` → "No issues found!"; `flutter test` → all green; the 32 pre-existing tests remain green and semantically unchanged.
- For D1/D2/D5 changes: the two energy example values (10.0 Wh, 72.0 Wh) and capacity example (12000 after one power plant) must still hold via tests.
- Final: total test count ≥ 32 (strictly greater, since Phase 1 adds tests); no persisted-key/JSON change unless explicitly approved via Stop-and-Ask.

## Out-of-scope Items
- Numeric tuning of any constant in `lib/constants/game_constants.dart` / `building_definitions.dart`.
- Phase 3/4 product features from the spec (daily-history UI, 7-day streak bonus, town-level UI, difficulty switch, GPS speed).
- Native config under `android/` and `ios/` (Health permission manifests/Info.plist), `pubspec.yaml` dependency versions, and `doc/` specs — read-only references.
- Adding any networking, backend, Riverpod/Bloc migration, or rich animation (forbidden by spec §0.3).
- Migrating `doc/設計書.md` (superseded; leave as-is).

## Reporting Format
On completion or interruption, report:
1. **Last command run** and its full result (analyze + test summary line).
2. **`git status --short`** and a one-line-per-commit list of what changed.
3. **Phase status**: which phases done, which gated on Q1–Q3.
4. **Open questions** still blocking (Q1–Q3 or new ones), with the exact decision needed.
5. **`.claudelog/lessons-learned.md`** contents (the accumulated lessons).
