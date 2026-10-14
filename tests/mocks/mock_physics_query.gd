class_name MockPhysicsQuery extends IPhysicsQuery
## Mock physics query for testing - NO Godot dependencies
##
## Allows pre-configuring raycast results for testing

var raycast_results: Dictionary = {}  ## Key: "from->to", Value: result dict
var terrain_heights: Dictionary = {}  ## Key: "x,z", Value: height
var sphere_cast_results: Dictionary = {}  ## Key: "pos,radius", Value: Array

# Counters for metrics
var raycast_count: int = 0
var sphere_cast_count: int = 0
var terrain_query_count: int = 0

## Configure a raycast result for testing
func set_raycast_result(from: Vector3, to: Vector3, result: Dictionary) -> void:
	var key = _make_raycast_key(from, to)
	raycast_results[key] = result

## Configure terrain height for testing
func set_terrain_height(x: float, z: float, height: float) -> void:
	var key = "%d,%d" % [int(x), int(z)]
	terrain_heights[key] = height

## Configure sphere cast result for testing
func set_sphere_cast_result(position: Vector3, radius: float, result: Array) -> void:
	var key = "%s,%.1f" % [str(position), radius]
	sphere_cast_results[key] = result

func raycast(from: Vector3, to: Vector3, exclude: Array = []) -> Dictionary:
	raycast_count += 1
	var key = _make_raycast_key(from, to)
	if raycast_results.has(key):
		return raycast_results[key]
	return {}  ## No hit by default

func sphere_cast(position: Vector3, radius: float, exclude: Array = []) -> Array:
	sphere_cast_count += 1
	var key = "%s,%.1f" % [str(position), radius]
	if sphere_cast_results.has(key):
		return sphere_cast_results[key]
	return []  ## No hits by default

func get_terrain_height(x: float, z: float) -> float:
	terrain_query_count += 1
	var key = "%d,%d" % [int(x), int(z)]
	if terrain_heights.has(key):
		return terrain_heights[key]
	return 0.0  ## Default to sea level

func clear_cache() -> void:
	# Optional for mocks
	pass

func reset() -> void:
	raycast_results.clear()
	terrain_heights.clear()
	sphere_cast_results.clear()
	raycast_count = 0
	sphere_cast_count = 0
	terrain_query_count = 0

func get_metrics() -> Dictionary:
	return {
		"raycast_count": raycast_count,
		"sphere_cast_count": sphere_cast_count,
		"terrain_query_count": terrain_query_count,
		"total_queries": raycast_count + sphere_cast_count + terrain_query_count
	}

func _make_raycast_key(from: Vector3, to: Vector3) -> String:
	return "%s->%s" % [str(from), str(to)]
