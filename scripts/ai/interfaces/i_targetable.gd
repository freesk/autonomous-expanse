class_name ITargetable extends RefCounted
## Interface for anything that can be targeted by AI
##
## Allows AI to target drones, squads, or any other entity without
## coupling to specific implementation types.

## Get current world position of target
func get_position() -> Vector3:
	assert(false, "Must implement get_position()")
	return Vector3.ZERO

## Get current velocity of target (for prediction)
func get_velocity() -> Vector3:
	assert(false, "Must implement get_velocity()")
	return Vector3.ZERO

## Check if target is still valid (not destroyed/freed)
func is_valid() -> bool:
	assert(false, "Must implement is_valid()")
	return false

## Get faction ID of target
func get_faction_id() -> String:
	assert(false, "Must implement get_faction_id()")
	return ""

## Get approximate radius/size of target (for aiming)
func get_radius() -> float:
	assert(false, "Must implement get_radius()")
	return 1.0
