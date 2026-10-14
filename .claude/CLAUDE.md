# DroneWorld — Test Coverage Mandate

## EVERY CHANGE MUST BE COVERED BY TESTS. NO EXCEPTIONS.

Any change to game logic — AI decisions, physics calculations, navigation,
combat, resource handling — ships WITH tests in the same change set. Code
without tests is not done, even if it runs.

### The workflow for every change

1. **Put decision logic in a pure brain**, not in a Node. Testable logic lives
   in `scripts/ai/brains/` as `RefCounted` classes (or static functions) with
   NO Godot node/scene/physics dependencies. Nodes in `src/` stay thin glue:
   they read state, call the brain, apply the result.
2. **Write GUT tests** in `tests/unit/` (pure logic) or `tests/integration/`
   (component wiring, using `tests/mocks/`). Cover the happy path, the
   boundary values, and degenerate inputs (zero/negative/empty/invalid).
   When fixing a bug, add a regression test that fails on the old code —
   name it or comment it so the old defect is documented.
3. **Run the full suite yourself** before presenting anything:
   ```
   godot --headless --path . -s addons/gut/gut_cmdln.gd
   ```
   All tests must pass. Also reimport (`godot --headless --path . --import`)
   after adding scripts, and when behavior at runtime matters, do a headless
   game run (`godot --headless --path . --quit-after 900`) and check the
   AIDebugLogger output for errors.
4. If logic genuinely cannot be extracted into a testable unit (pure
   rendering, input plumbing), say so explicitly in your summary and explain
   how it was verified instead. This is the rare exception, not a loophole.

### Existing patterns to follow

- Brains: `scripts/ai/brains/drone_weapon_brain.gd`, `drone_combat_brain.gd`,
  `squad_cohesion_brain.gd` — pure, static-friendly, fully unit-tested.
- Tests: `tests/unit/test_drone_weapon_brain.gd`,
  `tests/unit/test_squad_cohesion_brain.gd` — Arrange/Act/Assert, one
  behavior per test, regression tests annotated with what they prevent.
- Config: `.gutconfig.json` defines the test dirs; `test_results_*.xml` is
  gitignored output.

A presented change that lacks tests for new or modified logic is an
incomplete change. Do not present it.
