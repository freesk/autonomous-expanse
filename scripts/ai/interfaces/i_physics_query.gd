class_name IPhysicsQuery extends RefCounted
## Interface for physics queries - allows mocking in tests
##
## This interface abstracts all physics interactions so AI logic can be
## tested without requiring Godot's physics engine.

## Perform a raycast from one point to another
## @param from: Starting position
## @param to: End position
## @param exclude: Array of objects to ignore
## @return Dictionary with "collider" and "position" keys if hit, empty if miss
func raycast(from: Vector3, to: Vector3, exclude: Array = []) -> Dictionary:
	assert(false, "Must implement raycast()")
	return {}

## Perform a sphere cast to detect objects in radius
## @param position: Center of sphere
## @param radius: Radius to check
## @param exclude: Array of objects to ignore
## @return Array of collision results
func sphere_cast(position: Vector3, radius: float, exclude: Array = []) -> Array:
	assert(false, "Must implement sphere_cast()")
	return []

## Get terrain height at a given XZ position
## @param x: X coordinate
## @param z: Z coordinate
## @return Height of terrain at that position
func get_terrain_height(x: float, z: float) -> float:
	assert(false, "Must implement get_terrain_height()")
	return 0.0

## Clear any cached query results (for performance optimization)
func clear_cache() -> void:
	# Optional to implement
	pass
