## Interface for physics query abstraction
##
## This interface allows AI systems to query physics without direct dependency
## on Godot's PhysicsDirectSpaceState3D, enabling unit testing with mock implementations.
class_name IPhysicsQuery extends RefCounted

## Performs a raycast from one point to another
##
## @param from: Starting position of the raycast
## @param to: End position of the raycast
## @param exclude: Array of objects to exclude from the raycast
## @returns Dictionary with raycast result (same format as PhysicsDirectSpaceState3D.intersect_ray)
##          - "position": Vector3 - Hit position
##          - "normal": Vector3 - Surface normal at hit point
##          - "collider": Object - The object that was hit
##          - "collider_id": int - Object ID of the collider
##          - "rid": RID - RID of the hit collision object
##          - "shape": int - Shape index of the hit collision shape
##          Returns empty Dictionary if no hit
func raycast(from: Vector3, to: Vector3, exclude: Array) -> Dictionary:
	assert(false, "raycast() must be implemented by subclass")
	return {}

## Performs a sphere cast from one point to another
##
## @param from: Starting position of the sphere cast
## @param to: End position of the sphere cast
## @param radius: Radius of the sphere
## @param exclude: Array of objects to exclude from the cast
## @returns Dictionary with cast result (same format as raycast)
func sphere_cast(from: Vector3, to: Vector3, radius: float, exclude: Array) -> Dictionary:
	assert(false, "sphere_cast() must be implemented by subclass")
	return {}

## Checks if there is a clear line of sight between two points
##
## @param from: Starting position
## @param to: End position
## @param exclude: Array of objects to exclude
## @returns bool - true if line of sight is clear, false otherwise
func has_line_of_sight(from: Vector3, to: Vector3, exclude: Array) -> bool:
	var result = raycast(from, to, exclude)
	return result.is_empty()
