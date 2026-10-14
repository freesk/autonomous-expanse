extends Node3D
class_name Mothership

## Faction Mothership - Spawns squads and stores resources
## Part of the faction AI simulation system
## Each faction has 3 motherships distributed across the world
##
## ARCHITECTURE:
## - Central mothership model with mesh collision only
## - 3 assembly zones positioned around the mothership (120° apart)
## - Labels for mothership and each assembly zone
## - Fully reusable and instantiable component

## Identity
var mothership_id: int = -1
var mothership_name: String = "Alpha"  # Alpha, Beta, Gamma, etc.
var owning_faction: int = -1
var faction_name: String = "Unknown Faction"
var faction_color: Color = Color.WHITE

## Resource Management
var resource_storage: int = 0
var max_storage: int = 10000

## Squad Spawning
var spawn_cooldown: float = 0.0
var min_spawn_interval: float = 30.0

## Child Node References
@onready var mothership_label: Label3D = $Label3D
@onready var visual_mesh: MeshInstance3D = _find_visual_mesh()
@onready var assembly_zones: Node3D = $AssemblyZones
@onready var assembly_zone_1: Node3D = $AssemblyZones/AssemblyZone1
@onready var assembly_zone_2: Node3D = $AssemblyZones/AssemblyZone2
@onready var assembly_zone_3: Node3D = $AssemblyZones/AssemblyZone3

func _ready() -> void:
	_setup_zones()
	_setup_assembly_zones()
	_update_mothership_label()
	# Don't apply faction color here - it will be applied after faction is set by world_generator
	# _apply_faction_color()

func _process(delta: float) -> void:
	# Handle spawn cooldown
	if spawn_cooldown > 0.0:
		spawn_cooldown -= delta

func _setup_zones() -> void:
	"""Initialize assembly zones and terrain placement"""
	# NOTE: Terrain raycasting is handled by MothershipPlacer during spawn
	# We only need to position assembly zones relative to already-placed mothership
	call_deferred("_position_assembly_zones_on_terrain")

func _setup_assembly_zones() -> void:
	"""Configure assembly zones with zone IDs and references"""
	var zones := [assembly_zone_1, assembly_zone_2, assembly_zone_3]

	for i in range(zones.size()):
		var zone = zones[i]
		if not zone:
			continue

		# Set zone ID
		if zone.has_method("set") and "zone_id" in zone:
			zone.zone_id = i + 1

		# Set owning mothership reference
		if "owning_mothership" in zone:
			zone.owning_mothership = self

		# Connect signals
		if zone.has_signal("mothership_entry_triggered"):
			zone.mothership_entry_triggered.connect(_on_mothership_entry_triggered.bind(zone))

func _position_assembly_zones_on_terrain() -> void:
	"""Use vertical raycasting to position assembly zones on terrain

	NOTE: Mothership position is already set by MothershipPlacer.
	This only adjusts assembly zone Y positions to sit on terrain.
	"""
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		push_warning("[Mothership] Cannot raycast - physics space not ready")
		return

	# Raycast for each assembly zone
	_raycast_and_position_zones(space_state)

func _raycast_and_position_zones(space_state: PhysicsDirectSpaceState3D) -> void:
	"""Raycast downward to find terrain height for each assembly zone"""
	var zones := [assembly_zone_1, assembly_zone_2, assembly_zone_3]

	for zone in zones:
		if not zone:
			continue

		var zone_global_pos: Vector3 = zone.global_position
		var ray_origin: Vector3 = zone_global_pos + Vector3.UP * 500.0
		var ray_end: Vector3 = zone_global_pos + Vector3.DOWN * 500.0

		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collision_mask = 1  # Terrain layer

		var result := space_state.intersect_ray(query)
		if result:
			# Position zone slightly above terrain surface so ring is visible
			zone.global_position.y = result.position.y + 0.5

func _update_mothership_label() -> void:
	"""Update the mothership label with current name and faction"""
	if mothership_label:
		mothership_label.text = "Mothership %s [%s]" % [mothership_name, faction_name]
		mothership_label.modulate = faction_color

func _apply_faction_color() -> void:
	"""Apply faction color to the mothership visual"""
	print("[Mothership] Applying faction color: ", faction_color, " to mothership ", mothership_id)

	if not visual_mesh:
		print("[Mothership] ERROR: visual_mesh is null!")
		return

	# Apply color to all surfaces by modifying the existing material
	# This preserves textures while tinting with the faction color
	if visual_mesh.mesh == null:
		print("[Mothership] ERROR: visual_mesh.mesh is null!")
		return

	var surface_count = visual_mesh.mesh.get_surface_count()
	print("[Mothership] Found %d surfaces to colorize" % surface_count)

	for i in range(surface_count):
		# Get the original material (check override first, then mesh material)
		var original_material = visual_mesh.get_surface_override_material(i)
		if original_material == null:
			original_material = visual_mesh.mesh.surface_get_material(i)

		# Only work with StandardMaterial3D
		if original_material == null or not original_material is StandardMaterial3D:
			print("[Mothership] Surface %d: No StandardMaterial3D found, skipping" % i)
			continue

		# CRITICAL: Duplicate the material to avoid all motherships sharing the same material
		var material = (original_material as StandardMaterial3D).duplicate()

		# Modify the duplicated material to preserve textures
		material.albedo_color = faction_color
		material.emission_enabled = true
		material.emission = faction_color * 0.3  # Subtle glow
		material.emission_energy_multiplier = 0.5
		material.metallic = 0.7
		material.roughness = 0.3

		# Apply as override so each mothership has its own material
		visual_mesh.set_surface_override_material(i, material)

	print("[Mothership] Material applied successfully")

func initialize(id: int, faction: int, color: Color, name: String = "Alpha", faction_name_str: String = "Unknown Faction") -> void:
	"""Initialize the mothership with faction data

	Args:
		id: Unique mothership identifier
		faction: Faction ID (0, 1, or 2)
		color: Faction's color for visual identification
		name: Mothership name (Alpha, Beta, Gamma, etc.)
		faction_name_str: Human-readable faction name
	"""
	mothership_id = id
	mothership_name = name
	owning_faction = faction
	faction_name = faction_name_str
	faction_color = color

	# Apply color to all components immediately if ready
	if is_node_ready():
		_apply_faction_color()
		_update_mothership_label()
		_apply_faction_color_to_zones()

func can_spawn() -> bool:
	"""Check if this mothership can spawn a new squad

	Returns:
		bool: True if spawn cooldown has expired
	"""
	return spawn_cooldown <= 0.0

func spawn_squad() -> void:
	"""Spawn a new squad from this mothership

	This method delegates to FactionManager to handle the actual spawning,
	then sets the cooldown timer to prevent immediate respawning.
	"""
	if not can_spawn():
		push_warning("[Mothership %d] Cannot spawn - cooldown active (%.1fs remaining)" % [mothership_id, spawn_cooldown])
		return

	# Get spawn position from assembly zones
	var spawn_pos: Vector3 = get_spawn_position()

	print("[Mothership %d] SPAWNING SQUAD | Mothership at: %v | Spawn point at: %v" % [
		mothership_id, global_position, spawn_pos
	])

	# Delegate to FactionManager to create and register the squad
	if FactionManager and FactionManager.has_method("spawn_squad_from_mothership"):
		var squad = FactionManager.spawn_squad_from_mothership(owning_faction, spawn_pos, self)
		if squad:
			# Set spawn cooldown
			spawn_cooldown = min_spawn_interval
			print("[Mothership %d] ✓ Squad spawned successfully at %v" % [mothership_id, spawn_pos])
		else:
			push_warning("[Mothership %d] ✗ Failed to spawn squad" % mothership_id)
	else:
		push_error("[Mothership] FactionManager not available or missing spawn method")

func receive_resources(amount: int) -> void:
	"""Accept resources from a returning squad

	Args:
		amount: Amount of resources to add to storage
	"""
	var old_storage := resource_storage
	resource_storage = mini(max_storage, resource_storage + amount)
	var actual_added := resource_storage - old_storage

	# Update faction total resources if FactionManager exists
	if FactionManager and FactionManager.has_method("add_faction_resources"):
		FactionManager.add_faction_resources(owning_faction, actual_added)

	print("[Mothership %d] Received %d resources (storage: %d/%d)" % [mothership_id, actual_added, resource_storage, max_storage])

func is_in_defense_zone(position: Vector3) -> bool:
	"""Check if a position is within this mothership's defense zone

	Args:
		position: World position to check

	Returns:
		bool: True if position is within defense range (100m default)
	"""
	const DEFENSE_RANGE := 100.0
	return global_position.distance_to(position) <= DEFENSE_RANGE

func is_in_landing_zone(position: Vector3) -> bool:
	"""Check if a position is within any assembly zone

	Args:
		position: World position to check

	Returns:
		bool: True if position is within any assembly zone radius
	"""
	const LANDING_RANGE := 20.0
	var zones := _get_assembly_zones()
	for zone in zones:
		if zone and zone.global_position.distance_to(position) <= LANDING_RANGE:
			return true
	return false

func get_spawn_position() -> Vector3:
	"""Get the position where squads should spawn

	Returns a random assembly zone position for variety

	Returns:
		Vector3: World position for squad spawning
	"""
	var zones := _get_assembly_zones()
	if zones.is_empty():
		return global_position + Vector3.UP * 20.0

	# Pick a random zone
	var zone = zones[randi() % zones.size()]
	if zone.has_method("get_spawn_position"):
		return zone.get_spawn_position()

	return zone.global_position + Vector3.UP * 10.0

func get_all_assembly_zones() -> Array[Node3D]:
	"""Get all assembly zones for this mothership

	Returns:
		Array of assembly zone nodes
	"""
	return _get_assembly_zones()

func _get_assembly_zones() -> Array[Node3D]:
	"""Internal helper to get all valid assembly zones"""
	var zones: Array[Node3D] = []

	if assembly_zone_1:
		zones.append(assembly_zone_1)
	if assembly_zone_2:
		zones.append(assembly_zone_2)
	if assembly_zone_3:
		zones.append(assembly_zone_3)

	return zones

func _apply_faction_color_to_zones() -> void:
	"""Apply faction color to all assembly zones"""
	var zones := _get_assembly_zones()

	for zone in zones:
		if zone.has_method("set_faction_color"):
			zone.set_faction_color(faction_color)

func _on_mothership_entry_triggered(zone: Node3D) -> void:
	"""Handle player triggering mothership entry from an assembly zone

	Args:
		zone: The assembly zone that triggered the entry
	"""
	print("[Mothership %d] Player entered mothership via %s!" % [mothership_id, zone.name])

	# TODO: Implement mothership entry behavior
	# This could open a UI, teleport player, change game state, etc.
	# Placeholder for now - emit signal or trigger event

func on_player_entered(zone: Node3D) -> void:
	"""Called by assembly zones when player enters the mothership

	Args:
		zone: The assembly zone the player entered from
	"""
	_on_mothership_entry_triggered(zone)

func _find_visual_mesh() -> MeshInstance3D:
	"""Dynamically find the mesh instance in the Visual node hierarchy

	Searches for MeshInstance3D in $Visual and its children (e.g., GLB models)
	Returns null if not found
	"""
	var visual_node := get_node_or_null("Visual")
	if not visual_node:
		push_warning("[Mothership] Visual node not found")
		return null

	# Check direct children (e.g., MeshInstance3D)
	for child in visual_node.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D

	# Check nested children (e.g., GLBModel -> mesh children)
	for child in visual_node.get_children():
		for nested_child in child.get_children():
			if nested_child is MeshInstance3D:
				return nested_child as MeshInstance3D

	push_warning("[Mothership] No MeshInstance3D found in Visual hierarchy")
	return null
