extends PanelContainer
## Minimap component with fog-of-war
## Shows player position, nearby objects, and waypoints

@onready var map_center: Control = $MarginContainer/MapContainer/MapCenter
@onready var player_marker: ColorRect = $MarginContainer/MapContainer/MapCenter/PlayerMarker
@onready var object_markers: Control = $MarginContainer/MapContainer/MapCenter/ObjectMarkers

@export var map_range: float = 200.0  # Range in meters
@export var map_scale: float = 0.45  # Scale factor for world to minimap coordinates

var player: CharacterBody3D = null
var tracked_objects: Array[Dictionary] = []

# Marker colors
const COLOR_ENEMY := Color(1, 0, 0, 1)
const COLOR_ALLY := Color(0, 0, 1, 1)
const COLOR_OBJECTIVE := Color(1, 1, 0, 1)
const COLOR_POI := Color(0, 1, 1, 1)
const COLOR_RESOURCE := Color(1, 0.5, 0, 1)


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	if player != null:
		_update_player_marker()
		_update_object_markers()


func set_player(new_player: CharacterBody3D) -> void:
	## Set the player to track
	player = new_player


func add_tracked_object(object: Node3D, marker_type: String) -> void:
	## Add an object to track on the minimap
	## marker_type: "enemy", "ally", "objective", "poi", "resource"
	tracked_objects.append({
		"object": object,
		"type": marker_type,
		"marker": null
	})
	_create_marker_for_object(tracked_objects[-1])


func remove_tracked_object(object: Node3D) -> void:
	## Remove an object from tracking
	for i in range(tracked_objects.size() - 1, -1, -1):
		if tracked_objects[i]["object"] == object:
			if tracked_objects[i]["marker"] != null:
				tracked_objects[i]["marker"].queue_free()
			tracked_objects.remove_at(i)


func clear_tracked_objects() -> void:
	## Clear all tracked objects
	for obj in tracked_objects:
		if obj["marker"] != null:
			obj["marker"].queue_free()
	tracked_objects.clear()


func _create_marker_for_object(obj_data: Dictionary) -> void:
	## Create a visual marker for a tracked object
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(6, 6)
	marker.size = Vector2(6, 6)
	marker.color = _get_marker_color(obj_data["type"])
	object_markers.add_child(marker)
	obj_data["marker"] = marker


func _get_marker_color(marker_type: String) -> Color:
	## Get color based on marker type
	match marker_type:
		"enemy":
			return COLOR_ENEMY
		"ally":
			return COLOR_ALLY
		"objective":
			return COLOR_OBJECTIVE
		"poi":
			return COLOR_POI
		"resource":
			return COLOR_RESOURCE
		_:
			return Color.WHITE


func _update_player_marker() -> void:
	## Update player marker rotation
	if player == null:
		return

	# Rotate marker to match player rotation
	player_marker.rotation = -player.global_rotation.y + PI / 4  # +45° for diamond shape


func _update_object_markers() -> void:
	## Update positions of all tracked object markers
	if player == null:
		return

	var player_pos := player.global_position

	for i in range(tracked_objects.size() - 1, -1, -1):
		var obj_data := tracked_objects[i]
		var obj: Node3D = obj_data["object"]
		var marker: ColorRect = obj_data["marker"]

		# Remove if object is invalid
		if not is_instance_valid(obj):
			if marker != null:
				marker.queue_free()
			tracked_objects.remove_at(i)
			continue

		if marker == null:
			continue

		# Calculate relative position
		var relative_pos := obj.global_position - player_pos
		var distance := Vector2(relative_pos.x, relative_pos.z).length()

		# Hide if out of range
		if distance > map_range:
			marker.visible = false
			continue

		marker.visible = true

		# Convert to minimap coordinates
		var map_pos := Vector2(relative_pos.x, relative_pos.z) * map_scale
		marker.position = map_pos - marker.size / 2


func set_map_range(range_meters: float) -> void:
	## Set the minimap range
	map_range = range_meters


func world_to_minimap(world_pos: Vector3) -> Vector2:
	## Convert world position to minimap coordinates
	if player == null:
		return Vector2.ZERO

	var relative_pos := world_pos - player.global_position
	return Vector2(relative_pos.x, relative_pos.z) * map_scale
