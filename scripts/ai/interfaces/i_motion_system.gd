class_name IMotionSystem extends RefCounted
## Interface for drone movement control
##
## Abstracts the motion controller so AI can issue movement commands
## without coupling to the specific implementation.

## Set movement direction and climb rate
## @param direction: XZ movement direction (normalized)
## @param climb: Y movement (-1 to 1)
## @param speed_fraction: Speed multiplier (0 to 1)
func set_movement(direction: Vector2, climb: float, speed_fraction: float = 1.0) -> void:
	assert(false, "Must implement set_movement()")
