extends Node
class_name CargoSystem

## Cargo Management System for Cargo Drone
## Handles pickup, storage, and delivery of cargo
## Applies speed penalty based on cargo load
## Supports different cargo sizes and types

signal cargo_added(item: Dictionary)
signal cargo_removed(item: Dictionary)
signal cargo_capacity_changed(current: int, maximum: int)
signal cargo_full()
signal cargo_empty()
signal speed_penalty_changed(penalty_percent: float)

enum CargoType {
	RESOURCE,      # Standard resources (1 unit)
	COMPONENT_SMALL,  # Small components (2 units)
	COMPONENT_LARGE,  # Large components (3 units)
	ARTIFACT       # Artifacts (1 unit, high value)
}

## Cargo Capacity
@export var max_cargo_capacity: int = 12  # Maximum units
@export var pickup_range: float = 8.0  # Meters

var current_cargo_used: int = 0
var cargo_items: Array[Dictionary] = []

## Speed Penalty Configuration
@export var speed_penalty_enabled: bool = true
@export var speed_penalty_per_50_percent: float = 0.10  # -10% per 50% capacity

var current_speed_penalty: float = 0.0

## Pickup Settings
@export var auto_pickup_enabled: bool = true
@export var pickup_area: Area3D = null  # Set this to an Area3D for automatic detection


func _ready() -> void:
	if pickup_area:
		pickup_area.body_entered.connect(_on_pickup_area_entered)


func _process(_delta: float) -> void:
	_update_speed_penalty()


## Cargo Management
func add_cargo(item: Dictionary) -> bool:
	var item_size: int = _get_item_size(item)

	if not can_add_cargo(item_size):
		cargo_full.emit()
		return false

	cargo_items.append(item)
	current_cargo_used += item_size

	cargo_added.emit(item)
	cargo_capacity_changed.emit(current_cargo_used, max_cargo_capacity)

	print("[CargoSystem] Added cargo: %s (size: %d)" % [item.get("name", "Unknown"), item_size])

	return true


func remove_cargo(index: int) -> Dictionary:
	if index < 0 or index >= cargo_items.size():
		push_error("[CargoSystem] Invalid cargo index: " + str(index))
		return {}

	var item: Dictionary = cargo_items[index]
	var item_size: int = _get_item_size(item)

	cargo_items.remove_at(index)
	current_cargo_used -= item_size

	cargo_removed.emit(item)
	cargo_capacity_changed.emit(current_cargo_used, max_cargo_capacity)

	if cargo_items.is_empty():
		cargo_empty.emit()

	print("[CargoSystem] Removed cargo: %s" % item.get("name", "Unknown"))

	return item


func drop_cargo(index: int) -> void:
	var item: Dictionary = remove_cargo(index)
	if item.is_empty():
		return

	# Spawn the item in the world
	_spawn_cargo_in_world(item)


func drop_all_cargo() -> void:
	var items_to_drop: Array[Dictionary] = cargo_items.duplicate()

	for i in range(items_to_drop.size()):
		drop_cargo(0)  # Always drop the first item since array shrinks


func transfer_all_to_storage() -> Array[Dictionary]:
	var items: Array[Dictionary] = cargo_items.duplicate()
	cargo_items.clear()
	current_cargo_used = 0

	cargo_capacity_changed.emit(current_cargo_used, max_cargo_capacity)
	cargo_empty.emit()

	print("[CargoSystem] Transferred all cargo to storage (%d items)" % items.size())

	return items


## Cargo Queries
func can_add_cargo(size: int) -> bool:
	return (current_cargo_used + size) <= max_cargo_capacity


func is_cargo_full() -> bool:
	return current_cargo_used >= max_cargo_capacity


func is_cargo_empty() -> bool:
	return cargo_items.is_empty()


func get_cargo_count() -> int:
	return cargo_items.size()


func get_cargo_capacity_used() -> int:
	return current_cargo_used


func get_cargo_capacity_percentage() -> float:
	return (float(current_cargo_used) / float(max_cargo_capacity)) * 100.0


func get_cargo_data() -> Array[Dictionary]:
	return cargo_items.duplicate()


func load_cargo_data(data: Array) -> void:
	cargo_items.clear()
	current_cargo_used = 0

	for item in data:
		if item is Dictionary:
			add_cargo(item)


## Speed Penalty Calculation
func _update_speed_penalty() -> void:
	if not speed_penalty_enabled:
		if current_speed_penalty != 0.0:
			current_speed_penalty = 0.0
			speed_penalty_changed.emit(0.0)
		return

	var capacity_percentage: float = get_cargo_capacity_percentage()
	var new_penalty: float = 0.0

	# Calculate penalty: -10% per 50% capacity
	# 0-50% capacity = 0% penalty
	# 50-100% capacity = -10% penalty
	# 100% capacity = -20% penalty (if over-capacity is possible)
	if capacity_percentage > 50.0:
		var excess_percentage: float = capacity_percentage - 50.0
		new_penalty = (excess_percentage / 50.0) * speed_penalty_per_50_percent

	if new_penalty != current_speed_penalty:
		current_speed_penalty = new_penalty
		speed_penalty_changed.emit(current_speed_penalty)


func get_speed_multiplier() -> float:
	return 1.0 - current_speed_penalty


## Item Size Calculation
func _get_item_size(item: Dictionary) -> int:
	if item.has("size"):
		return item["size"]

	# Determine size from type
	var item_type: CargoType = item.get("cargo_type", CargoType.RESOURCE)

	match item_type:
		CargoType.RESOURCE:
			return 1
		CargoType.COMPONENT_SMALL:
			return 2
		CargoType.COMPONENT_LARGE:
			return 3
		CargoType.ARTIFACT:
			return 1
		_:
			return 1


## Pickup System
func try_pickup_nearby_items() -> void:
	if not pickup_area:
		push_warning("[CargoSystem] No pickup area configured")
		return

	var overlapping_bodies: Array[Node3D] = pickup_area.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body.has_method("get_pickup_data"):
			var item_data: Dictionary = body.get_pickup_data()
			if add_cargo(item_data):
				body.queue_free()  # Remove from world


func _on_pickup_area_entered(body: Node3D) -> void:
	if not auto_pickup_enabled:
		return

	if body.has_method("get_pickup_data"):
		var item_data: Dictionary = body.get_pickup_data()
		if add_cargo(item_data):
			body.queue_free()


func _spawn_cargo_in_world(item: Dictionary) -> void:
	# This should be implemented by the game to spawn the actual cargo object
	# For now, just emit a signal that can be connected to from the drone
	var parent: Node = get_parent()
	if parent and parent.has_method("spawn_dropped_cargo"):
		parent.spawn_dropped_cargo(item)
	else:
		print("[CargoSystem] Warning: Cannot spawn cargo in world, no spawn method available")


## Capacity Upgrades
func increase_capacity(amount: int) -> void:
	max_cargo_capacity += amount
	cargo_capacity_changed.emit(current_cargo_used, max_cargo_capacity)
	print("[CargoSystem] Capacity increased to: %d" % max_cargo_capacity)


## Utility Functions
func get_cargo_display_string() -> String:
	return "%d/%d" % [current_cargo_used, max_cargo_capacity]


func get_cargo_list_for_ui() -> Array[Dictionary]:
	var display_list: Array[Dictionary] = []

	for i in range(cargo_items.size()):
		var item: Dictionary = cargo_items[i]
		display_list.append({
			"index": i,
			"name": item.get("name", "Unknown"),
			"type": CargoType.keys()[item.get("cargo_type", CargoType.RESOURCE)],
			"size": _get_item_size(item),
			"icon": item.get("icon", ""),
			"value": item.get("value", 0)
		})

	return display_list


## Debug
func print_cargo_status() -> void:
	print("[CargoSystem] === Cargo Status ===")
	print("  Capacity: %s" % get_cargo_display_string())
	print("  Items: %d" % cargo_items.size())
	print("  Speed Penalty: %.1f%%" % (current_speed_penalty * 100.0))
	print("  Cargo List:")
	for i in range(cargo_items.size()):
		var item: Dictionary = cargo_items[i]
		print("    [%d] %s (size: %d)" % [i, item.get("name", "Unknown"), _get_item_size(item)])
