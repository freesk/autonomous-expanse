extends Node
class_name WorldGenerator

## Procedural world generation orchestrator
## Coordinates terrain generation, mothership placement, and POI placement
## World size is ~4km x 4km with 9 motherships and 15-20 POIs

const TerrainGenerator = preload("res://src/world/terrain_generator.gd")
const MothershipPlacer = preload("res://src/world/mothership_placer.gd")
const FactionTerritory = preload("res://src/world/faction_territory.gd")
const POISpawner = preload("res://src/world/poi_spawner.gd")

signal generation_started()
signal generation_completed()
signal motherships_placed(count: int)
signal pois_placed(count: int)

## World dimensions (±1000m = 2000m x 2000m)
@export var world_size: float = 2000.0

## Number of POIs to spawn
@export var poi_count: int = 18

## Minimum spacing between POIs
@export var min_poi_spacing: float = 200.0

## Minimum spacing between motherships
@export var min_mothership_spacing: float = 400.0

## World generation seed (0 = random)
@export var world_seed: int = 0

## Terrain mesh for the flat ground plane
@export var terrain_mesh: MeshInstance3D

## Scene references
@export var mothership_scene: PackedScene
@export var copper_resource_scene: PackedScene
@export var iron_resource_scene: PackedScene

## Container nodes for organization
var motherships_container: Node3D
var pois_container: Node3D

## Component systems
var terrain_generator: RefCounted
var mothership_placer: RefCounted
var poi_spawner: POISpawner

## Generated objects tracking
var spawned_motherships: Array[Node3D] = []
var spawned_pois: Array[Node3D] = []

## Faction metadata
const FACTION_NAMES := ["Alpha Swarm", "Beta Collective", "Gamma Hive"]


func _ready() -> void:
	_setup_containers()
	_setup_components()


## Setup component systems
func _setup_components() -> void:
	terrain_generator = TerrainGenerator.new()
	poi_spawner = POISpawner.new()
	add_child(poi_spawner)


## Main world generation orchestrator
func generate_world(
	n_factions: int = 3,
	n_motherships_per_faction: int = 3,
	n_squads_per_mothership: int = 3,
	size: float = 4000.0,
	n_resources: int = 18,
	seed_value: int = 0  # 0 = use world_seed export value, otherwise use provided seed
) -> void:
	# Determine the actual seed to use
	var actual_seed := seed_value if seed_value != 0 else world_seed
	if actual_seed == 0:
		actual_seed = randi()  # Generate random seed if none provided

	# Set the global random seed for reproducible generation
	seed(actual_seed)

	print("[WorldGenerator] Starting procedural world generation...")
	print("  - Seed: %d" % actual_seed)
	print("  - Factions: %d" % n_factions)
	print("  - Motherships per faction: %d" % n_motherships_per_faction)
	print("  - Squads per mothership: %d" % n_squads_per_mothership)
	print("  - World size: %.0fm" % size)
	print("  - Resources: %d" % n_resources)
	generation_started.emit()

	# Update world parameters
	world_size = size
	poi_count = n_resources

	# Clear any existing world
	_clear_world()

	# Phase 1: Generate terrain
	_generate_terrain(actual_seed)

	# Phase 2: Place motherships
	_place_motherships(n_factions, n_motherships_per_faction, n_squads_per_mothership)

	# Phase 3: Place POIs
	_place_pois(actual_seed)

	# Phase 4: Register with FactionManager
	_register_with_faction_manager()

	print("[WorldGenerator] World generation complete!")
	print("  - Motherships: %d" % spawned_motherships.size())
	print("  - POIs: %d" % spawned_pois.size())
	generation_completed.emit()


## Generate procedural terrain
func _generate_terrain(terrain_seed: int) -> void:
	print("[WorldGenerator] Generating procedural terrain...")

	if not terrain_mesh:
		var mesh_instance: MeshInstance3D = terrain_generator.generate_terrain(world_size, terrain_seed)
		add_child(mesh_instance)
		terrain_mesh = mesh_instance

		print("  - Created procedural terrain: %.0fm x %.0fm" % [world_size, world_size])
		print("  - Multi-octave FBM terrain with domain warping and power redistribution")
		print("  - Height distribution: Mostly flat plains (0-20m), rolling hills (20-100m), rare mountains (100-300m)")

		# VERIFICATION: Test if terrain collision is actually detectable by raycasts
		await get_tree().process_frame # Wait for physics to update
		_verify_terrain_collision()
	else:
		print("  - Using existing terrain mesh")


## Get terrain height (delegates to terrain generator)
func get_terrain_height_at(pos_x: float, pos_z: float) -> float:
	return terrain_generator.get_terrain_height_at(pos_x, pos_z)


## Check if area is flat (delegates to terrain generator)
func is_flat_area(pos_x: float, pos_z: float, radius: float = 50.0) -> bool:
	return terrain_generator.is_flat_area(pos_x, pos_z, radius)


## Place motherships in faction territories
func _place_motherships(n_factions: int, n_motherships_per_faction: int, n_squads_per_mothership: int) -> void:
	if not terrain_generator:
		push_error("[WorldGenerator] terrain_generator is null! Cannot place motherships.")
		return

	# Initialize placer with current components
	var placer_script: GDScript = MothershipPlacer
	mothership_placer = placer_script.new()
	mothership_placer.terrain_generator = terrain_generator
	mothership_placer.mothership_scene = mothership_scene
	mothership_placer.container = motherships_container

	print("[WorldGenerator] Initialized MothershipPlacer with terrain_generator: %s" % terrain_generator)

	# Place all motherships
	spawned_motherships = mothership_placer.place_motherships(
		world_size,
		min_mothership_spacing,
		n_factions,
		n_motherships_per_faction,
		n_squads_per_mothership
	)

	motherships_placed.emit(spawned_motherships.size())


## Place POIs using noise-based distribution
func _place_pois(poi_seed: int) -> void:
	print("[WorldGenerator] Placing POIs using noise-based distribution...")

	var half_size := world_size / 2.0
	var bounds := Rect2(-half_size, -half_size, world_size, world_size)

	# Use POISpawner for noise-based placement with both copper and iron resources
	var resource_scenes := [copper_resource_scene, iron_resource_scene]
	spawned_pois = poi_spawner.place_pois_noise(
		poi_count,
		bounds,
		spawned_motherships,
		min_poi_spacing,
		resource_scenes,
		self, # Pass world generator for terrain height queries
		poi_seed # Pass seed for reproducible POI placement
	)

	# Add POIs to container
	for poi in spawned_pois:
		if poi:
			pois_container.add_child(poi)

	print("  - Successfully placed %d resource nodes" % spawned_pois.size())
	pois_placed.emit(spawned_pois.size())


## Register all spawned objects with FactionManager
func _register_with_faction_manager() -> void:
	print("[WorldGenerator] Registering objects with FactionManager...")

	var faction_manager := _get_faction_manager()
	if not faction_manager:
		push_warning("[WorldGenerator] FactionManager not found! Objects will not be registered.")
		return

	# Register all objects
	_register_objects(faction_manager, spawned_motherships, "register_mothership")
	_register_objects(faction_manager, spawned_pois, "register_poi")

	print("  - Registered %d motherships and %d POIs" % [spawned_motherships.size(), spawned_pois.size()])


## Get reference to FactionManager singleton
func _get_faction_manager() -> Node:
	if Engine.has_singleton("FactionManager"):
		return Engine.get_singleton("FactionManager")
	elif has_node("/root/FactionManager"):
		return get_node("/root/FactionManager")
	return null


## Register a list of objects with FactionManager using the specified method
func _register_objects(faction_manager: Node, objects: Array, method_name: String) -> void:
	if not faction_manager.has_method(method_name):
		push_warning("[WorldGenerator] FactionManager missing method: %s" % method_name)
		return

	for obj in objects:
		if obj:
			faction_manager.call(method_name, obj)


## Setup container nodes for organization
func _setup_containers() -> void:
	# Create container for motherships
	motherships_container = Node3D.new()
	motherships_container.name = "Motherships"
	add_child(motherships_container)

	# Create container for POIs
	pois_container = Node3D.new()
	pois_container.name = "POIs"
	add_child(pois_container)


## Clear existing world (for regeneration)
func _clear_world() -> void:
	# Clear motherships
	for mothership in spawned_motherships:
		if is_instance_valid(mothership):
			mothership.queue_free()
	spawned_motherships.clear()

	# Clear POIs
	for poi in spawned_pois:
		if is_instance_valid(poi):
			poi.queue_free()
	spawned_pois.clear()

	# Clear container children
	for child in motherships_container.get_children():
		child.queue_free()

	for child in pois_container.get_children():
		child.queue_free()


## Get all spawned motherships
func get_motherships() -> Array[Node3D]:
	return spawned_motherships


## Get all spawned POIs
func get_pois() -> Array[Node3D]:
	return spawned_pois


## Get world bounds as Rect2
func get_world_bounds() -> Rect2:
	var half_size := world_size / 2.0
	return Rect2(-half_size, -half_size, world_size, world_size)


## Verify that terrain collision is actually detectable by raycasts
## Tests 5 random positions across the terrain
func _verify_terrain_collision() -> void:
	print("[WorldGenerator] VERIFYING TERRAIN COLLISION...")

	# Get the 3D world from the terrain mesh (which is a Node3D)
	if not terrain_mesh or not is_instance_valid(terrain_mesh):
		print("  ❌ Cannot verify - terrain_mesh not available")
		return

	var world_3d: World3D = terrain_mesh.get_world_3d()
	if not world_3d:
		print("  ❌ Cannot verify - World3D not available")
		return

	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if not space_state:
		print("  ❌ Cannot verify - PhysicsDirectSpaceState3D not available")
		return

	# Test 5 random positions across the terrain
	for i in range(5):
		var test_x: float = randf_range(-world_size / 2, world_size / 2)
		var test_z: float = randf_range(-world_size / 2, world_size / 2)
		var terrain_height: float = get_terrain_height_at(test_x, test_z)

		# Create a test raycast from 100m above terrain
		var ray_origin := Vector3(test_x, terrain_height + 100.0, test_z)
		var ray_target := Vector3(test_x, terrain_height - 50.0, test_z)

		var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
		query.collision_mask = 1 # Layer 1 (terrain)

		var result: Dictionary = space_state.intersect_ray(query)

		if result:
			var hit_y: float = result.position.y
			print("  ✅ Test %d: Raycast HIT at Y=%.1f (terrain=%.1f, diff=%.1fm)" % [i + 1, hit_y, terrain_height, abs(hit_y - terrain_height)])
		else:
			print("  ❌ Test %d: Raycast MISSED! (origin: %v, target: %v)" % [i + 1, ray_origin, ray_target])
