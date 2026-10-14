# Autonomous Expanse Test Suite

Unit tests for the AI systems in Autonomous Expanse.

## Running Tests

### Option 1: Command Line (Headless)
```bash
# From project root
./tests/run_tests.sh

# Or directly with Godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/ai/squad/test_squad_priority_manager.gd
```

### Option 2: Godot Editor
1. Open the project in Godot
2. Open the scene: `tests/run_tests.tscn`
3. Press F5 or click "Run Current Scene"
4. Check the console output for results

### Option 3: Direct Script Execution
```bash
godot --script tests/ai/squad/test_squad_priority_manager.gd
```

## Test Coverage

### SquadPriorityManager (`test_squad_priority_manager.gd`)

**Covered Areas:**
- ✅ Initialization and default state
- ✅ Event handlers
  - `on_enemies_detected()` (attack and retreat)
  - `on_cargo_full()`
  - `on_poi_depleted()`
  - `on_reached_destination()`
  - `on_enemies_cleared()`
  - `on_resources_delivered()`
- ✅ Interrupt/resume logic
  - Goal saving and restoration
  - Multiple interrupts
  - Invalid target handling
  - Combat goal exception
- ✅ Goal validation
  - Valid targets
  - Invalid POI
  - Invalid enemy
- ✅ Edge cases
  - No-change transitions
  - Clear interrupted goal
  - Flag state management
- ✅ Integration scenarios
  - Mining → Combat → Resume Mining
  - Cargo full during combat

**Test Statistics:**
- Total tests: 27
- Test categories: 6
  - Initialization: 2 tests
  - Event handlers: 8 tests
  - Interrupt/resume: 4 tests
  - Validation: 3 tests
  - Edge cases: 3 tests
  - Integration: 2 tests

## Writing New Tests

### Test Structure
```gdscript
func test_my_feature() -> void:
    current_test = "Description of what is being tested"
    setup()

    # Arrange: Set up test conditions
    priority_manager.current_goal = SquadPriorityManager.AIGoal.MOVE_TO

    # Act: Execute the code under test
    var result := priority_manager.on_some_event()

    # Assert: Verify the results
    assert_equal(result.goal, expected_goal)

    teardown()
```

### Assertion Methods
- `assert_equal(actual, expected, message)` - Check equality
- `assert_true(condition, message)` - Check true
- `assert_false(condition, message)` - Check false
- `assert_not_null(value, message)` - Check not null

### Test Lifecycle
- `setup()` - Run before each test (creates fresh priority manager)
- `teardown()` - Run after each test (cleans up objects)
- `run_all_tests()` - Main entry point, calls all test methods

## Adding New Test Files

1. Create test file in appropriate directory:
   ```
   tests/
   ├── ai/
   │   ├── drone/
   │   │   └── test_drone_orchestrator_ai.gd
   │   └── squad/
   │       └── test_squad_priority_manager.gd
   └── run_tests.tscn
   ```

2. Extend `Node` and follow naming convention:
   ```gdscript
   extends Node
   class_name TestMyFeature
   ```

3. Add test file to `run_tests.tscn` or create separate scene

4. Follow the existing test structure with `setup()`/`teardown()`

## Test Best Practices

### DO:
- ✅ Test one thing per test method
- ✅ Use descriptive test names
- ✅ Clean up resources in teardown
- ✅ Test both happy path and edge cases
- ✅ Use mock objects to isolate units
- ✅ Make tests independent (don't rely on execution order)

### DON'T:
- ❌ Test implementation details
- ❌ Rely on external state
- ❌ Use sleep/timers unless necessary
- ❌ Test multiple concerns in one test
- ❌ Leave resources uncleaned
- ❌ Depend on test execution order

## Continuous Integration

To run tests in CI:
```bash
# Headless mode (no display required)
godot --headless --script tests/ai/squad/test_squad_priority_manager.gd

# Check exit code
if [ $? -eq 0 ]; then
    echo "Tests passed"
else
    echo "Tests failed"
    exit 1
fi
```

## Debugging Tests

### Enable Verbose Logging
Uncomment print statements in test methods to see intermediate values.

### Run Single Test
Comment out other tests in `run_all_tests()` to focus on one test.

### Breakpoints
Set breakpoints in the Godot debugger:
1. Open test file in Godot
2. Click line number to add breakpoint
3. Run scene with F5
4. Debugger will pause at breakpoint

## Future Tests

Planned test coverage:
- [ ] `test_drone_orchestrator_ai.gd` - Drone AI state machine
- [ ] `test_squad_navigation_ai.gd` - Squad navigation system
- [ ] `test_squad_mining_ai.gd` - Mining system
- [ ] `test_squad_combat_ai.gd` - Combat coordination
- [ ] `test_drone_combat_ai.gd` - Individual combat behavior
- [ ] `test_drone_pathfinding_ai.gd` - Pathfinding algorithms

## Contributing

When adding new features:
1. Write tests first (TDD approach)
2. Ensure all tests pass before committing
3. Aim for >80% code coverage
4. Document complex test scenarios

---

**Last Updated:** 2026-03-22
