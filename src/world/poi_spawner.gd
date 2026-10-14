extends Node
class_name POISpawner

## Point of Interest (POI) spawner using FastNoiseLite
## Uses noise-based placement for organic, terrain-aware distribution
## Ensures minimum spacing from motherships and other POIs

## Noise configuration
var noise: FastNoiseLite

## Noise settings for POI placement
@export var noise_frequency: float = 0.02
@export var noise_threshold: float = 0.3 # Spawn POIs where noise > this value (lowered for easier placement)

## Maximum spawn attempts to prevent infinite loops
@export var max_spawn_attempts: int = 1000

## Debug mode for logging
@export var debug_mode: bool = true


func _ready() -> void:
	_initialize_noise()


## Initialize FastNoiseLite with default settings
func _initialize_noise() -> void:
	noise = FastNoiseLite.new()

	# Random seed for variation
	noise.seed = randi()

	# Noise type (Perlin is good for organic distribution)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	# Frequency (lower = larger features, higher = more clustered)
	noise.frequency = noise_frequency

	# Fractal settings for more interesting distribution
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	if debug_mode:
		print("[POISpawner] Noise initialized with seed: %d" % noise.seed)


## Place POIs using noise-based distribution
## Returns array of spawned POI nodes
## poi_scene_or_scenes can be a single PackedScene or Array of PackedScenes
## world_generator is optional - if provided, POI heights will be set based on terrain
## poi_seed is optional - if provided (non-zero), will be used for reproducible generation
func place_pois_noise(
	count: int,
	bounds: Rect2,
	existing_motherships: Array,
	min_spacing: float,
	poi_scene_or_scenes: Variant, # PackedScene or Array[PackedScene]
	world_generator: Node = null, # Optional: WorldGenerator for terrain height queries
	poi_seed: int = 0 # Optional: Seed for reproducible generation
) -> Array[Node3D]:
	# Initialize noise if not already initialized (e.g., when created via new() instead of scene tree)
	if noise == null:
		_initialize_noise()

	# Set seed if provided for reproducible generation
	if poi_seed != 0:
		noise.seed = poi_seed

	if debug_mode:
		print("[POISpawner] Placing %d POIs..." % count)
		print("  - Seed: %d" % noise.seed)
		print("  - Bounds: %s" % bounds)
		print("  - Min spacing: %.1fm" % min_spacing)
		print("  - Existing motherships: %d" % existing_motherships.size())

	# Add margin to bounds to prevent spawning at the edge of the map
	const BOUNDARY_MARGIN := 100.0 # Keep resources 100m away from map edge
	var safe_bounds := bounds.grow(-BOUNDARY_MARGIN)

	if debug_mode:
		print("  - Safe bounds (with %dm margin): %s" % [BOUNDARY_MARGIN, safe_bounds])

	var spawned_pois: Array[Node3D] = []
	var spawn_attempts := 0

	while spawned_pois.size() < count and spawn_attempts < max_spawn_attempts:
		spawn_attempts += 1

		# Generate random position within safe bounds
		var x := randf_range(safe_bounds.position.x, safe_bounds.position.x + safe_bounds.size.x)
		var z := randf_range(safe_bounds.position.y, safe_bounds.position.y + safe_bounds.size.y)

		# Sample noise at this position
		var noise_value := noise.get_noise_2d(x, z)

		# Only spawn if noise value is above threshold
		if noise_value > noise_threshold:
			var candidate_pos := Vector3(x, 0, z)

			# Validate position (check spacing)
			if _is_valid_position(candidate_pos, existing_motherships, spawned_pois, min_spacing):
				# Spawn POI - randomly choose between available resource types
				var chosen_scene: PackedScene
				if poi_scene_or_scenes is Array:
					chosen_scene = poi_scene_or_scenes[randi() % poi_scene_or_scenes.size()]
				else:
					chosen_scene = poi_scene_or_scenes

				var poi := _spawn_poi(candidate_pos, chosen_scene, world_generator)
				if poi:
					spawned_pois.append(poi)

					if debug_mode and spawned_pois.size() % 5 == 0:
						print("  - Spawned %d/%d POIs..." % [spawned_pois.size(), count])

	if debug_mode:
		print("[POISpawner] Placement complete:")
		print("  - Successfully placed: %d/%d POIs" % [spawned_pois.size(), count])
		print("  - Total attempts: %d" % spawn_attempts)

		if spawned_pois.size() < count:
			push_warning("[POISpawner] Could not place all POIs. Try adjusting noise_threshold or min_spacing.")

	return spawned_pois


## Validate if a position is suitable for POI placement
## Checks spacing from motherships and other POIs
func _is_valid_position(
	pos: Vector3,
	motherships: Array,
	existing_pois: Array,
	min_spacing: float
) -> bool:
	# Check distance from motherships
	for mothership in motherships:
		if not is_instance_valid(mothership):
			continue

		# Get position - use global_position if in tree, otherwise use position
		var mothership_pos: Vector3
		if mothership.is_inside_tree():
			mothership_pos = mothership.global_position
		else:
			mothership_pos = mothership.position

		var distance := pos.distance_to(mothership_pos)
		if distance < min_spacing:
			return false

	# Check distance from other POIs
	for poi in existing_pois:
		if not is_instance_valid(poi):
			continue

		# Get position - use global_position if in tree, otherwise use position
		var poi_pos: Vector3
		if poi.is_inside_tree():
			poi_pos = poi.global_position
		else:
			poi_pos = poi.position

		var distance := pos.distance_to(poi_pos)
		if distance < min_spacing * 0.5: # POIs can be closer to each other than to motherships
			return false

	return true


## Spawn a single POI at the given position
func _spawn_poi(position: Vector3, poi_scene: PackedScene, world_generator: Node = null) -> Node3D:
	if not poi_scene:
		push_error("[POISpawner] POI scene not assigned!")
		return null

	var poi := poi_scene.instantiate() as Node3D
	if not poi:
		push_error("[POISpawner] Failed to instantiate POI!")
		return null

	# Scale up resources to make them more visible (10x scale - increased from 2x to 5x more = 10x total)
	const SCALE_FACTOR := 10.0
	poi.scale = Vector3(SCALE_FACTOR, SCALE_FACTOR, SCALE_FACTOR)

	# Get terrain height
	var terrain_height: float = world_generator.get_terrain_height_at(position.x, position.z)

	# Get the actual model's bounding box to find its height
	var model_node = poi.get_node_or_null("Model")
	var model_height := 0.0

	if model_node and model_node.get_child_count() > 0:
		var mesh_instance = model_node.get_child(0)
		if mesh_instance is MeshInstance3D and mesh_instance.mesh:
			var aabb: AABB = mesh_instance.mesh.get_aabb()
			# Get the bottom of the model (how far below origin it extends)
			model_height = abs(aabb.position.y) * SCALE_FACTOR

	poi.position = Vector3(position.x, terrain_height + model_height, position.z)

	# Randomize POI properties if applicable
	_randomize_poi_properties(poi)

	return poi


## Randomize POI properties for variety
func _randomize_poi_properties(poi: Node3D) -> void:
	# Randomize resource type if POI has it
	if "resource_type" in poi:
		# Randomly assign resource type (assuming enum ResourceType exists)
		poi.resource_type = randi() % 2 # 0 = IRON, 1 = COPPER

	# Randomize initial resource amount (80-100% of max)
	if "resource_amount" in poi and "max_resources" in poi:
		var max_res: int = poi.max_resources if "max_resources" in poi else 100
		poi.resource_amount = randi_range(int(max_res * 0.8), max_res)

	# Don't randomize scale here - it's already set in _spawn_poi to be 2x
	# var scale_variation := randf_range(0.9, 1.1)
	# poi.scale = Vector3.ONE * scale_variation

	# Random rotation
	poi.rotation.y = randf_range(0, TAU)


## Get noise value at a specific 2D position (useful for debugging)
func get_noise_at(position: Vector2) -> float:
	return noise.get_noise_2d(position.x, position.y)


## Visualize noise map (for debugging - generates a 2D image of the noise)
func generate_noise_visualization(width: int, height: int, bounds: Rect2) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)

	for y in range(height):
		for x in range(width):
			# Map pixel coordinates to world coordinates
			var world_x := bounds.position.x + (float(x) / width) * bounds.size.x
			var world_y := bounds.position.y + (float(y) / height) * bounds.size.y

			# Sample noise
			var noise_value := noise.get_noise_2d(world_x, world_y)

			# Normalize noise (-1 to 1) to (0 to 1)
			var normalized := (noise_value + 1.0) / 2.0

			# Color based on threshold
			var color: Color
			if noise_value > noise_threshold:
				color = Color.GREEN # Valid spawn location
			else:
				color = Color.GRAY.lerp(Color.BLACK, 1.0 - normalized)

			image.set_pixel(x, y, color)

	return image


## Change noise seed for different distribution patterns
func set_noise_seed(new_seed: int) -> void:
	noise.seed = new_seed
	if debug_mode:
		print("[POISpawner] Noise seed changed to: %d" % new_seed)


## Adjust noise frequency (affects clustering)
func set_noise_frequency(freq: float) -> void:
	noise.frequency = freq
	if debug_mode:
		print("[POISpawner] Noise frequency changed to: %.3f" % freq)


## Adjust noise threshold (affects spawn density)
func set_noise_threshold(threshold: float) -> void:
	noise_threshold = clamp(threshold, -1.0, 1.0)
	if debug_mode:
		print("[POISpawner] Noise threshold changed to: %.3f" % noise_threshold)
