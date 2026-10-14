class_name CommandQueue extends RefCounted
## Priority queue for AI commands with overflow protection
##
## Manages a queue of AI commands, executing them in priority order.
## Includes execution history for debugging and replay.

const MAX_QUEUE_SIZE = 100

var commands: Array[AICommand] = []
var execution_history: Array[Dictionary] = []
var max_history: int = 50

## Add a command to the queue
## @return true if enqueued, false if queue was full
func enqueue(command: AICommand) -> bool:
	if commands.size() >= MAX_QUEUE_SIZE:
		push_warning("CommandQueue overflow - dropping oldest command")
		commands.pop_front()

	# Insert by priority (higher priority first)
	var insert_idx = commands.size()
	for i in range(commands.size()):
		if command.priority > commands[i].priority:
			insert_idx = i
			break

	commands.insert(insert_idx, command)
	return true

## Execute the next valid command in the queue
## @return true if a command was executed, false if queue empty
func execute_next(context: AICommandContext) -> bool:
	while not commands.is_empty():
		var cmd = commands.pop_front()

		if cmd.is_cancelled:
			continue

		if cmd.can_execute(context):
			cmd.execute(context)
			_record_execution(cmd)
			return true

	return false

## Execute all commands in the queue
## @return Number of commands executed
func execute_all(context: AICommandContext) -> int:
	var executed = 0
	while execute_next(context):
		executed += 1
	return executed

## Clear all pending commands
func clear() -> void:
	for cmd in commands:
		cmd.cancel()
	commands.clear()

## Peek at next command without executing it
func peek() -> AICommand:
	if commands.is_empty():
		return null
	return commands[0]

## Get number of pending commands
func size() -> int:
	return commands.size()

## Check if queue is empty
func is_empty() -> bool:
	return commands.is_empty()

## Record command execution in history
func _record_execution(cmd: AICommand) -> void:
	execution_history.append(cmd.to_dict())
	if execution_history.size() > max_history:
		execution_history.pop_front()

## Get execution history for debugging/replay
func get_execution_history() -> Array[Dictionary]:
	return execution_history.duplicate()

## Clear execution history
func clear_history() -> void:
	execution_history.clear()
