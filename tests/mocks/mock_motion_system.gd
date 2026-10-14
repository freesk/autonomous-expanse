class_name MockMotionSystem extends IMotionSystem
## Mock motion system for testing - NO Godot dependencies
##
## Records movement commands for verification in tests

var last_direction: Vector2 = Vector2.ZERO
var last_climb: float = 0.0
var last_speed_fraction: float = 1.0
var command_count: int = 0

func set_movement(direction: Vector2, climb: float, speed_fraction: float = 1.0) -> void:
	last_direction = direction
	last_climb = climb
	last_speed_fraction = speed_fraction
	command_count += 1

func reset() -> void:
	last_direction = Vector2.ZERO
	last_climb = 0.0
	last_speed_fraction = 1.0
	command_count = 0
