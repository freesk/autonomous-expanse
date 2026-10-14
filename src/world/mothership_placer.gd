extends RefCounted
class_name MothershipPlacer

## Handles mothership placement logic with faction territories and flat area detection

const FactionTerritory = preload("res://src/world/faction_territory.gd")

const MOTHERSHIP_HOVER_HEIGHT := 25.0 # Hover altitude above terrain
const ASSEMBLY_ZONE_RADIUS := 15.0 # Default assembly zone radius
const MOTHERSHIP_RADIUS := 60.0 # Approximate mothership + zones footprint
const FLATTEN_RADIUS := MOTHERSHIP_RADIUS + ASSEMBLY_ZONE_RADIUS # Area that must be perfectly flat (covers all assembly zones)
const FLATTEN_BLEND_RADIUS := FLATTEN_RADIUS * 2.0 # Smooth transition back to natural terrain
const FACTION_COLORS := [Color.RED, Color.BLUE, Color.GREEN]
const FACTION_NAMES := ["Red Faction", "Blue Faction", "Green Faction"]
const MOTHERSHIP_NAMES := ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"]

var terrain_generator: RefCounted # TerrainGenerator
var mothership_scene: PackedScene
var container: Node3D
var spawned_motherships: Array[Node3D] = []
var n_factions: int = 3 # Number of factions (for territory division)
var world_size: float = 1000.0 # World size for boundary checks


## Place motherships across all faction territories
func place_motherships(
	p_world_size: float,
	min_spacing: float,
	num_factions: int = 3,
	n_motherships_per_faction: int = 3,
	n_squads_per_mothership: int = 3
) -> Array[Node3D]:
	if not terrain_generator:
		push_error("[MothershipPlacer] terrain_generator is null! Cannot place motherships.")
		return []

	# Store world size and faction count for boundary and territory checks
	self.world_size = p_world_size
	self.n_factions = num_factions

	print("[MothershipPlacer] Placing motherships in faction territories...")
	print("  - Factions: %d" % num_factions)
	print("  - Motherships per faction: %d" % n_motherships_per_faction)
	print("  - Squads per mothership: %d (will be spawned later)" % n_squads_per_mothership)
	print("  - World size: %.1f" % p_world_size)

	const MAX_PLACEMENT_ATTEMPTS := 200

	spawned_motherships.clear()

	# Phase 1: pick all mothership positions (no spawning yet)
	var planned_positions: Array[Vector2] = []
	var planned_factions: Array[int] = []
	for faction_id in range(num_factions):
		_plan_faction_motherships(faction_id, n_motherships_per_faction, MAX_PLACEMENT_ATTEMPTS, min_spacing, planned_positions, planned_factions)

	# Phase 2: flatten the terrain under each site BEFORE placing buildings,
	# so the mothership and all assembly zones sit on perfectly level ground
	var flat_heights: Array[float] = terrain_generator.flatten_areas(planned_positions, FLATTEN_RADIUS, FLATTEN_BLEND_RADIUS)

	# Phase 3: spawn motherships on the flattened terrain
	var per_faction_index := {}
	for i in range(planned_positions.size()):
		var faction_id: int = planned_factions[i]
		var mothership_index: int = per_faction_index.get(faction_id, 0)
		per_faction_index[faction_id] = mothership_index + 1

		var mothership_name: String = MOTHERSHIP_NAMES[mothership_index % MOTHERSHIP_NAMES.size()]
		var mothership := _spawn_mothership(planned_positions[i], faction_id, mothership_index, mothership_name, flat_heights[i])
		if mothership:
			spawned_motherships.append(mothership)
			print("  - Placed mothership '%s' at (%.1f, %.1f) on flattened ground (%.1fm) - Faction %d" % [
				mothership_name, planned_positions[i].x, planned_positions[i].y, flat_heights[i], faction_id
			])

	return spawned_motherships


## Pick valid positions for a faction's motherships (positions only, spawning happens later)
func _plan_faction_motherships(
	faction_id: int,
	target_count: int,
	max_attempts: int,
	min_spacing: float,
	planned_positions: Array[Vector2],
	planned_factions: Array[int]
) -> void:
	print("  - Planning mothership sites for faction %d in territory %d" % [faction_id, faction_id])

	var half_size := world_size / 2.0
	var planned_count := 0

	for attempt in range(max_attempts):
		if planned_count >= target_count:
			break

		# Generate random position in the entire map
		var pos := Vector2(
			randf_range(-half_size, half_size),
			randf_range(-half_size, half_size)
		)

		# Validate position (includes boundary check)
		if not _is_valid_mothership_position(pos, faction_id, min_spacing, planned_positions):
			continue

		planned_positions.append(pos)
		planned_factions.append(faction_id)
		planned_count += 1

	if planned_count < target_count:
		push_warning("[MothershipPlacer] Only planned %d/%d mothership sites for faction %d" % [planned_count, target_count, faction_id])


## Check if a position is valid for mothership placement
func _is_valid_mothership_position(pos: Vector2, faction_id: int, min_spacing: float, planned_positions: Array[Vector2]) -> bool:
	# Check boundary constraints (mothership + all assembly zones must be within bounds)
	if not _is_within_boundaries(pos):
		return false

	# Check if in correct faction territory
	if not FactionTerritory.is_in_faction_territory(pos, faction_id, n_factions):
		return false

	# No flat-terrain requirement - the terrain is flattened under each site before spawning

	# Check spacing from other planned mothership sites
	for existing_pos in planned_positions:
		if pos.distance_to(existing_pos) < min_spacing:
			return false

	return true

## Check if mothership and all assembly zones would be within map boundaries
func _is_within_boundaries(pos: Vector2) -> bool:
	"""Validate that the entire mothership entity (including all assembly zones) fits within boundaries

	Assembly zones are positioned at 60m distance from mothership center in 120° intervals.
	We need to check that the mothership center + assembly zone positions + zone radii all fit.
	"""
	var half_size := world_size / 2.0
	var boundary_margin := MOTHERSHIP_RADIUS + ASSEMBLY_ZONE_RADIUS

	# Check if mothership center is far enough from edges
	if abs(pos.x) > (half_size - boundary_margin):
		return false
	if abs(pos.y) > (half_size - boundary_margin):
		return false

	# Additional check: verify all 3 assembly zone positions
	# Zones are at 60m radius, 120° apart: 0°, 120°, 240°
	var zone_distance := 60.0
	var zone_angles := [0.0, 120.0, 240.0]

	for angle_deg in zone_angles:
		var angle_rad := deg_to_rad(angle_deg)
		var zone_offset := Vector2(
			cos(angle_rad) * zone_distance,
			sin(angle_rad) * zone_distance
		)
		var zone_pos := pos + zone_offset

		# Check if zone + its radius is within bounds
		if abs(zone_pos.x) + ASSEMBLY_ZONE_RADIUS > half_size:
			return false
		if abs(zone_pos.y) + ASSEMBLY_ZONE_RADIUS > half_size:
			return false

	return true


## Spawn a mothership at a given position with faction assignment
## terrain_height is the flattened ground level returned by flatten_areas()
func _spawn_mothership(position_2d: Vector2, faction_id: int, mothership_index: int, mothership_name: String, terrain_height: float) -> Node3D:
	if not mothership_scene:
		push_error("[MothershipPlacer] Mothership scene not assigned!")
		return null

	var mothership := mothership_scene.instantiate() as Node3D
	if not mothership:
		push_error("[MothershipPlacer] Failed to instantiate mothership!")
		return null

	# Add to scene before setting position
	container.add_child(mothership)

	# Position above the flattened terrain
	mothership.global_position = Vector3(
		position_2d.x,
		terrain_height + MOTHERSHIP_HOVER_HEIGHT,
		position_2d.y
	)

	print("[MothershipPlacer] Mothership placed | Name: %s | Faction: %d | 2D pos: %v | Terrain: %.1f | Hover at: %v" % [
		mothership_name, faction_id, position_2d, terrain_height, mothership.global_position
	])

	# Configure faction properties using the new initialize method
	var faction_color: Color = FACTION_COLORS[faction_id % FACTION_COLORS.size()]
	var faction_name: String = FACTION_NAMES[faction_id % FACTION_NAMES.size()]
	var mothership_id := faction_id * 10 + mothership_index # Unique ID per mothership

	if mothership.has_method("initialize"):
		mothership.initialize(mothership_id, faction_id, faction_color, mothership_name, faction_name)
	else:
		# Fallback for older mothership implementations
		_configure_mothership_faction_legacy(mothership, faction_id, faction_color)

	return mothership


## Legacy configuration method (for backwards compatibility)
func _configure_mothership_faction_legacy(mothership: Node3D, faction_id: int, faction_color: Color) -> void:
	# Set faction ID
	if mothership.has_method("set_faction"):
		mothership.set_faction(faction_id)
	elif "owning_faction" in mothership:
		mothership.owning_faction = faction_id

	# Set faction color
	if mothership.has_method("set_faction_color"):
		mothership.set_faction_color(faction_color)
	elif "faction_color" in mothership:
		mothership.faction_color = faction_color

	print("[MothershipPlacer] Set mothership faction %d with color %s (legacy mode)" % [faction_id, faction_color])

	# Apply color (deferred to ensure everything is ready)
	if mothership.has_method("_apply_faction_color"):
		mothership.call_deferred("_apply_faction_color")
