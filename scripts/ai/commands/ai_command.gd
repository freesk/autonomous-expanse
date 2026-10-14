class_name AICommand extends RefCounted
## Base class for all AI commands - enables queuing, testing, replay
##
## Commands represent atomic AI actions that can be:
## - Queued for execution
## - Tested in isolation
## - Recorded for replay/debugging
## - Serialized for analysis

enum CommandType {
	MOVE,
	FIRE_WEAPON,
	TARGET,
	SET_SPEED,
	RETREAT
}

var command_type: CommandType
var timestamp: float
var priority: int = 0  ## Higher = more important
var is_completed: bool = false
var is_cancelled: bool = false

## Execute this command
## Must be implemented by subclasses
func execute(context: AICommandContext) -> void:
	assert(false, "Must implement execute()")

## Check if this command can execute given current context
## Override to add precondition checks
func can_execute(context: AICommandContext) -> bool:
	return not is_cancelled

## Cancel this command (will not execute)
func cancel() -> void:
	is_cancelled = true

## Serialize command to dictionary for debugging/replay
## Override to add command-specific data
func to_dict() -> Dictionary:
	return {
		"type": CommandType.keys()[command_type],
		"timestamp": timestamp,
		"priority": priority,
		"completed": is_completed,
		"cancelled": is_cancelled
	}

## Create command from dictionary (for replay)
static func from_dict(data: Dictionary) -> AICommand:
	assert(false, "Must implement from_dict() in subclass")
	return null
