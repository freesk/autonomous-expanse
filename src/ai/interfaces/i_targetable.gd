## Interface for targetable entities
##
## This interface allows AI systems to interact with targets (drones, players, buildings, etc.)
## without depending on specific Node3D types, enabling unit testing with mock implementations.
class_name ITargetable extends RefCounted

## Gets the current global position of the target
func get_position() -> Vector3:
	assert(false, "get_position() must be implemented by subclass")
	return Vector3.ZERO

## Gets the current velocity of the target (for leading shots)
func get_velocity() -> Vector3:
	assert(false, "get_velocity() must be implemented by subclass")
	return Vector3.ZERO

## Checks if the target is still valid (not freed/destroyed)
func is_valid() -> bool:
	assert(false, "is_valid() must be implemented by subclass")
	return false

## Gets the faction ID of the target
func get_faction_id() -> int:
	assert(false, "get_faction_id() must be implemented by subclass")
	return -1

## Checks if the target is hostile to the given faction
func is_hostile_to(faction_id: int) -> bool:
	assert(false, "is_hostile_to() must be implemented by subclass")
	return false

## Gets the health percentage of the target (0.0 to 100.0)
## Returns -1 if health is not applicable or unknown
func get_health_percentage() -> float:
	assert(false, "get_health_percentage() must be implemented by subclass")
	return -1.0

## Gets the approximate size/radius of the target (for hit detection)
func get_radius() -> float:
	assert(false, "get_radius() must be implemented by subclass")
	return 1.0

## Gets the target priority/threat level (higher = more important target)
func get_threat_level() -> float:
	assert(false, "get_threat_level() must be implemented by subclass")
	return 0.0

## Gets the underlying Node3D (for production code that still needs it)
## This will be phased out as we complete the refactoring
func get_node() -> Node3D:
	assert(false, "get_node() must be implemented by subclass")
	return null
