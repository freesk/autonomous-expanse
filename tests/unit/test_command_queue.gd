extends GutTest
## Unit tests for CommandQueue - pure logic, NO Godot dependencies
##
## These tests verify the command queue system with 100% coverage

# Preload all required classes
const IDrone = preload("res://scripts/ai/interfaces/i_drone.gd")
const IPhysicsQuery = preload("res://scripts/ai/interfaces/i_physics_query.gd")
const IMotionSystem = preload("res://scripts/ai/interfaces/i_motion_system.gd")
const IWeaponSystem = preload("res://scripts/ai/interfaces/i_weapon_system.gd")
const MockDrone = preload("res://tests/mocks/mock_drone.gd")
const MockPhysicsQuery = preload("res://tests/mocks/mock_physics_query.gd")
const MockMotionSystem = preload("res://tests/mocks/mock_motion_system.gd")
const MockWeaponSystem = preload("res://tests/mocks/mock_weapon_system.gd")
const AICommand = preload("res://scripts/ai/commands/ai_command.gd")
const AICommandContext = preload("res://scripts/ai/commands/ai_command_context.gd")
const CommandQueue = preload("res://scripts/ai/commands/command_queue.gd")
const MoveCommand = preload("res://scripts/ai/commands/move_command.gd")
const FireWeaponCommand = preload("res://scripts/ai/commands/fire_weapon_command.gd")

# Simple test command that doesn't require context
class TestCommand extends AICommand:
	var was_executed: bool = false
	var can_exec: bool = true

	func _init():
		command_type = CommandType.MOVE

	func can_execute(_context: AICommandContext) -> bool:
		return can_exec and not is_cancelled

	func execute(_context: AICommandContext) -> void:
		was_executed = true
		is_completed = true

var queue: CommandQueue
var mock_context: AICommandContext

func before_each():
	queue = CommandQueue.new()
	# Create mock context with mocks
	var mock_drone = MockDrone.new()
	var mock_physics = MockPhysicsQuery.new()
	var mock_motion = MockMotionSystem.new()
	var mock_weapon = MockWeaponSystem.new()
	mock_context = AICommandContext.new(mock_drone, mock_physics, mock_motion, mock_weapon)

	# Verify context is properly initialized
	assert_not_null(mock_context, "Context should not be null")
	assert_not_null(mock_context.drone, "Context drone should not be null")
	assert_not_null(mock_context.motion_system, "Context motion_system should not be null")
	assert_not_null(mock_context.weapon_system, "Context weapon_system should not be null")
	assert_not_null(mock_context.physics_query, "Context physics_query should not be null")

# ===== enqueue tests =====

func test_enqueue_adds_command_to_queue():
	# Arrange
	var cmd = TestCommand.new()

	# Act
	var result = queue.enqueue(cmd)

	# Assert
	assert_true(result, "Should return true on successful enqueue")
	assert_eq(queue.size(), 1, "Queue should have one command")

func test_enqueue_multiple_commands():
	# Arrange
	var cmd1 = TestCommand.new()
	var cmd2 = TestCommand.new()

	# Act
	queue.enqueue(cmd1)
	queue.enqueue(cmd2)

	# Assert
	assert_eq(queue.size(), 2, "Queue should have two commands")

func test_enqueue_respects_priority_order():
	# Arrange
	var low_priority = TestCommand.new()
	low_priority.priority = 1

	var high_priority = TestCommand.new()
	high_priority.priority = 10

	var medium_priority = TestCommand.new()
	medium_priority.priority = 5

	# Act - enqueue in random order
	queue.enqueue(low_priority)
	queue.enqueue(high_priority)
	queue.enqueue(medium_priority)

	# Assert - should be sorted by priority (high to low)
	assert_eq(queue.peek().priority, 10, "Highest priority should be first")
	queue.execute_next(mock_context)
	assert_eq(queue.peek().priority, 5, "Medium priority should be second")
	queue.execute_next(mock_context)
	assert_eq(queue.peek().priority, 1, "Lowest priority should be last")

func test_enqueue_drops_oldest_when_full():
	# Arrange - fill queue to max
	for i in range(CommandQueue.MAX_QUEUE_SIZE):
		var cmd = TestCommand.new()
		queue.enqueue(cmd)

	assert_eq(queue.size(), CommandQueue.MAX_QUEUE_SIZE, "Queue should be at max")

	# Act - enqueue one more
	var overflow_cmd = TestCommand.new()
	overflow_cmd.priority = 100  # High priority
	queue.enqueue(overflow_cmd)

	# Assert
	assert_eq(queue.size(), CommandQueue.MAX_QUEUE_SIZE, "Queue should still be at max")
	assert_eq(queue.peek().priority, 100, "New high priority command should be in queue")

# ===== execute_next tests =====

func test_execute_next_executes_and_removes_command():
	# Arrange
	var cmd = TestCommand.new()
	queue.enqueue(cmd)

	# Act
	var executed = queue.execute_next(mock_context)

	# Assert
	assert_true(executed, "Should return true when command executed")
	assert_eq(queue.size(), 0, "Queue should be empty after execution")
	assert_true(cmd.is_completed, "Command should be marked completed")
	assert_true(cmd.was_executed, "Command execute() should have been called")

func test_execute_next_false_when_queue_empty():
	# Act
	var executed = queue.execute_next(mock_context)

	# Assert
	assert_false(executed, "Should return false when queue empty")

func test_execute_next_skips_cancelled_commands():
	# Arrange
	var cmd1 = TestCommand.new()
	var cmd2 = TestCommand.new()
	queue.enqueue(cmd1)
	queue.enqueue(cmd2)
	cmd1.cancel()  # Cancel first command

	# Act
	var executed = queue.execute_next(mock_context)

	# Assert
	assert_true(executed, "Should skip cancelled and execute next valid command")
	assert_true(cmd2.is_completed, "Second command should be executed")
	assert_false(cmd1.is_completed, "First command should not be executed")
	assert_false(cmd1.was_executed, "First command execute() should not have been called")
	assert_true(cmd2.was_executed, "Second command execute() should have been called")

func test_execute_next_records_in_history():
	# Arrange
	var cmd = TestCommand.new()
	queue.enqueue(cmd)

	# Act
	queue.execute_next(mock_context)

	# Assert
	var history = queue.get_execution_history()
	assert_eq(history.size(), 1, "Should have one entry in history")
	assert_eq(history[0]["type"], "MOVE", "History should record command type")

func test_execute_next_skips_command_that_cant_execute():
	# Arrange
	var cmd = TestCommand.new()
	cmd.can_exec = false  # Make it fail can_execute()
	queue.enqueue(cmd)

	# Act
	var executed = queue.execute_next(mock_context)

	# Assert
	assert_false(executed, "Should not execute command that fails can_execute()")
	assert_false(cmd.is_completed, "Command should not be completed")
	assert_false(cmd.was_executed, "Command execute() should not have been called")

# ===== execute_all tests =====

func test_execute_all_executes_all_commands():
	# Arrange
	var cmd1 = TestCommand.new()
	var cmd2 = TestCommand.new()
	var cmd3 = TestCommand.new()
	queue.enqueue(cmd1)
	queue.enqueue(cmd2)
	queue.enqueue(cmd3)

	# Act
	var count = queue.execute_all(mock_context)

	# Assert
	assert_eq(count, 3, "Should execute all three commands")
	assert_eq(queue.size(), 0, "Queue should be empty")
	assert_true(cmd1.was_executed and cmd2.was_executed and cmd3.was_executed,
		"All commands should have been executed")

func test_execute_all_returns_zero_when_empty():
	# Act
	var count = queue.execute_all(mock_context)

	# Assert
	assert_eq(count, 0, "Should return zero when no commands to execute")

func test_execute_all_skips_cancelled_commands():
	# Arrange
	var cmd1 = TestCommand.new()
	var cmd2 = TestCommand.new()
	var cmd3 = TestCommand.new()
	queue.enqueue(cmd1)
	queue.enqueue(cmd2)
	queue.enqueue(cmd3)
	cmd2.cancel()  # Cancel middle command

	# Act
	var count = queue.execute_all(mock_context)

	# Assert
	assert_eq(count, 2, "Should execute only non-cancelled commands")
	assert_true(cmd1.is_completed, "First command should be completed")
	assert_false(cmd2.is_completed, "Second command should not be completed")
	assert_true(cmd3.is_completed, "Third command should be completed")
	assert_true(cmd1.was_executed and cmd3.was_executed, "Non-cancelled commands should execute")
	assert_false(cmd2.was_executed, "Cancelled command should not execute")

# ===== clear tests =====

func test_clear_empties_queue():
	# Arrange
	queue.enqueue(TestCommand.new())
	queue.enqueue(TestCommand.new())
	assert_eq(queue.size(), 2, "Queue should have two commands")

	# Act
	queue.clear()

	# Assert
	assert_eq(queue.size(), 0, "Queue should be empty after clear")

func test_clear_cancels_all_commands():
	# Arrange
	var cmd1 = TestCommand.new()
	var cmd2 = TestCommand.new()
	queue.enqueue(cmd1)
	queue.enqueue(cmd2)

	# Act
	queue.clear()

	# Assert
	assert_true(cmd1.is_cancelled, "Commands should be cancelled when cleared")
	assert_true(cmd2.is_cancelled, "Commands should be cancelled when cleared")

# ===== peek tests =====

func test_peek_returns_next_command_without_removing():
	# Arrange
	var cmd = TestCommand.new()
	queue.enqueue(cmd)

	# Act
	var peeked = queue.peek()

	# Assert
	assert_eq(peeked, cmd, "Should return the command")
	assert_eq(queue.size(), 1, "Command should still be in queue")

func test_peek_returns_null_when_empty():
	# Act
	var peeked = queue.peek()

	# Assert
	assert_null(peeked, "Should return null when queue is empty")

# ===== size and is_empty tests =====

func test_size_returns_correct_count():
	# Arrange
	assert_eq(queue.size(), 0, "Should start with size 0")

	queue.enqueue(TestCommand.new())
	assert_eq(queue.size(), 1, "Should have size 1 after one enqueue")

	queue.enqueue(TestCommand.new())
	assert_eq(queue.size(), 2, "Should have size 2 after two enqueues")

	queue.execute_next(mock_context)
	assert_eq(queue.size(), 1, "Should have size 1 after one execution")

func test_is_empty_returns_true_when_empty():
	# Assert
	assert_true(queue.is_empty(), "Should be empty initially")

func test_is_empty_returns_false_when_not_empty():
	# Arrange
	queue.enqueue(TestCommand.new())

	# Assert
	assert_false(queue.is_empty(), "Should not be empty after enqueue")

# ===== execution history tests =====

func test_execution_history_records_commands():
	# Arrange
	queue.enqueue(TestCommand.new())
	queue.enqueue(TestCommand.new())

	# Act
	queue.execute_all(mock_context)

	# Assert
	var history = queue.get_execution_history()
	assert_eq(history.size(), 2, "Should have two entries in history")
	assert_eq(history[0]["type"], "MOVE", "First entry should be MOVE")
	assert_eq(history[1]["type"], "MOVE", "Second entry should be MOVE")

func test_execution_history_limited_by_max():
	# Arrange - execute more than max_history commands
	for i in range(queue.max_history + 10):
		queue.enqueue(TestCommand.new())
		queue.execute_next(mock_context)

	# Act
	var history = queue.get_execution_history()

	# Assert
	assert_eq(history.size(), queue.max_history,
		"History should be limited to max_history entries")

func test_clear_history_empties_history():
	# Arrange
	queue.enqueue(TestCommand.new())
	queue.execute_next(mock_context)
	assert_gt(queue.get_execution_history().size(), 0, "Should have history")

	# Act
	queue.clear_history()

	# Assert
	assert_eq(queue.get_execution_history().size(), 0, "History should be empty")

# ===== Integration tests =====

func test_realistic_command_workflow():
	# Simulate realistic AI command generation and execution

	# Frame 1: AI decides to execute commands
	var cmd1 = TestCommand.new()
	cmd1.priority = 1
	var cmd2 = TestCommand.new()
	cmd2.priority = 2  # Higher priority

	queue.enqueue(cmd1)
	queue.enqueue(cmd2)

	# Execute all commands for this frame
	var executed = queue.execute_all(mock_context)

	# Verify
	assert_eq(executed, 2, "Should execute both commands")
	assert_true(cmd2.is_completed, "High priority command should execute first")
	assert_true(cmd1.is_completed, "Low priority command should execute second")
	assert_true(cmd1.was_executed and cmd2.was_executed, "Both commands should have executed")

func test_command_queue_with_cancellation():
	# Arrange
	var cmd1 = TestCommand.new()
	var cmd2 = TestCommand.new()
	var cmd3 = TestCommand.new()

	queue.enqueue(cmd1)
	queue.enqueue(cmd2)
	queue.enqueue(cmd3)

	# Cancel cmd2 before execution
	cmd2.cancel()

	# Act
	var count = queue.execute_all(mock_context)

	# Assert
	assert_eq(count, 2, "Should execute only non-cancelled commands")
	var history = queue.get_execution_history()
	assert_eq(history.size(), 2, "History should only have executed commands")
	assert_true(cmd1.was_executed and cmd3.was_executed, "Non-cancelled should execute")
	assert_false(cmd2.was_executed, "Cancelled command should not execute")
