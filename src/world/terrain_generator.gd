extends RefCounted
class_name TerrainGenerator

## Handles procedural terrain generation with multi-octave noise
## Generates heightmap meshes with collision for the world

## Terrain generation constants
const MESH_SUBDIVISIONS := 80

# Fractal noise parameters for mountain generation
const BASE_FREQUENCY := 0.0005  # Base frequency for first octave
const OCTAVES := 7  # Number of noise layers to combine
const LACUNARITY := 2.0  # Frequency multiplier per octave (2.0 = double frequency)
const GAIN := 0.5  # Amplitude multiplier per octave (0.5 = half amplitude)

# Mountain shaping parameters
const MAX_HEIGHT := 400.0  # Maximum peak height
const MOUNTAIN_EXPONENT := 2.2  # Power curve for mountain distribution (higher = more flat valleys, sharper peaks)
const FUDGE_FACTOR := 1.15  # Pre-power multiplier to adjust distribution

# Domain warping for organic shapes
const WARP_FREQUENCY := 0.001
const WARP_OCTAVES := 3
const WARP_STRENGTH := 180.0

# Flat area detection
const FLAT_THRESHOLD := 40.0  # Max height for "flat" areas
const FLAT_VARIATION := 5.0  # Max height variation in flat areas

## Reference to the terrain mesh instance for raycasting
var _terrain_mesh_instance: MeshInstance3D = null

## World size of the generated terrain (needed to compute grid cell size for flattening)
var _world_size: float = 0.0


## Generate a complete procedural terrain mesh with collision
func generate_terrain(world_size: float, terrain_seed: int = 0) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	_world_size = world_size

	# Use provided seed or generate random one
	var actual_seed := terrain_seed if terrain_seed != 0 else randi()

	# Create noise generators for each octave
	var noise_octaves := _create_noise_octaves(actual_seed)
	var warp_noise := _create_domain_warp_noise(actual_seed)

	# Generate the heightmap mesh
	var array_mesh := _generate_heightmap_mesh(world_size, noise_octaves, warp_noise)
	mesh_instance.mesh = array_mesh

	# Apply material
	_apply_terrain_material(mesh_instance)

	# Add collision
	_add_terrain_collision(mesh_instance, array_mesh)

	# Cache mesh instance for raycasting
	_terrain_mesh_instance = mesh_instance

	return mesh_instance


## Get terrain height at a specific 2D position (x, z)
## Raycasts down from above to find the exact terrain height
func get_terrain_height_at(pos_x: float, pos_z: float) -> float:
	if not _terrain_mesh_instance or not _terrain_mesh_instance.is_inside_tree():
		return 0.0

	var world_3d: World3D = _terrain_mesh_instance.get_world_3d()
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state

	# Raycast from high above down to below terrain
	var ray_origin := Vector3(pos_x, 1000.0, pos_z)
	var ray_target := Vector3(pos_x, -100.0, pos_z)

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	query.collision_mask = 1  # Layer 1 (terrain)

	var result: Dictionary = space_state.intersect_ray(query)

	if result:
		return result.position.y

	return 0.0


## Check if a position is in a flat area (height < threshold and low slope)
func is_flat_area(pos_x: float, pos_z: float, radius: float = 50.0) -> bool:
	var center_height := get_terrain_height_at(pos_x, pos_z)

	# Check if too high (mountains/hills)
	if center_height > FLAT_THRESHOLD:
		return false

	# Sample nearby points to check for slope
	var sample_offsets := [
		Vector2(radius, 0), Vector2(-radius, 0),
		Vector2(0, radius), Vector2(0, -radius)
	]

	for offset in sample_offsets:
		var sample_height: float = get_terrain_height_at(pos_x + offset.x, pos_z + offset.y)
		var height_diff: float = abs(sample_height - center_height)

		# If height varies too much, not flat
		if height_diff > FLAT_VARIATION:
			return false

	return true


## Flatten terrain around the given XZ centers so buildings sit on level ground.
## Each area is leveled to the local average height (NOT reset to zero), with a
## smooth blend from flat_radius out to blend_radius to avoid cliffs.
## The flat zone is expanded by one grid cell so every triangle touching the
## requested radius is guaranteed to be perfectly flat.
## Returns the flat height for each center, in the same order.
func flatten_areas(centers: Array, flat_radius: float, blend_radius: float) -> Array[float]:
	var flat_heights: Array[float] = []

	if not _terrain_mesh_instance or not _terrain_mesh_instance.mesh:
		push_warning("[TerrainGenerator] flatten_areas called before terrain was generated")
		for center in centers:
			flat_heights.append(0.0)
		return flat_heights

	var array_mesh: ArrayMesh = _terrain_mesh_instance.mesh
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)

	# Grid cell size of the heightmap plane (vertex spacing).
	# Expand by the cell diagonal: any triangle touching the flat circle has
	# all its vertices within flat_radius + cell diagonal, so flattening that
	# far guarantees the surface inside flat_radius is perfectly level.
	var cell_size := _world_size / float(MESH_SUBDIVISIONS + 1)
	var inner_radius := flat_radius + cell_size * sqrt(2.0)
	var outer_radius: float = max(blend_radius, inner_radius + cell_size)

	for center_variant in centers:
		var center: Vector2 = center_variant

		# Pass 1: find the level height = average of vertices inside the flat zone
		var height_sum := 0.0
		var vertex_count := 0
		for i in range(mdt.get_vertex_count()):
			var vertex := mdt.get_vertex(i)
			if Vector2(vertex.x, vertex.z).distance_to(center) <= inner_radius:
				height_sum += vertex.y
				vertex_count += 1

		var flat_height := height_sum / vertex_count if vertex_count > 0 else 0.0
		flat_heights.append(flat_height)

		# Pass 2: flatten the inner zone and blend smoothly out to the outer radius
		for i in range(mdt.get_vertex_count()):
			var vertex := mdt.get_vertex(i)
			var dist := Vector2(vertex.x, vertex.z).distance_to(center)

			if dist <= inner_radius:
				vertex.y = flat_height
				mdt.set_vertex(i, vertex)
			elif dist < outer_radius:
				var t := (dist - inner_radius) / (outer_radius - inner_radius)
				vertex.y = lerpf(flat_height, vertex.y, smoothstep(0.0, 1.0, t))
				mdt.set_vertex(i, vertex)

	# Commit modified vertices and regenerate normals
	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)

	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(array_mesh, 0)
	surface_tool.generate_normals()
	var new_mesh := surface_tool.commit()

	_terrain_mesh_instance.mesh = new_mesh
	_rebuild_terrain_collision(new_mesh)

	print("[TerrainGenerator] Flattened %d areas (flat radius %.0fm, blend to %.0fm)" % [
		centers.size(), inner_radius, outer_radius
	])

	return flat_heights


## Replace the terrain collision shape after the mesh has been modified
func _rebuild_terrain_collision(array_mesh: ArrayMesh) -> void:
	var static_body := _terrain_mesh_instance.get_node_or_null("TerrainCollision")
	if not static_body:
		_add_terrain_collision(_terrain_mesh_instance, array_mesh)
		return

	var collision_shape: CollisionShape3D = static_body.get_node_or_null("CollisionShape")
	if not collision_shape:
		push_warning("[TerrainGenerator] CollisionShape not found; terrain collision not rebuilt")
		return

	var shape := array_mesh.create_trimesh_shape()
	if shape:
		collision_shape.shape = shape
	else:
		push_warning("[TerrainGenerator] Failed to rebuild trimesh collision after flattening")


## Create individual noise generators for each octave
## Returns array of {noise: FastNoiseLite, amplitude: float, frequency: float}
func _create_noise_octaves(base_seed: int) -> Array:
	var octaves := []

	var amplitude := 1.0
	var frequency := BASE_FREQUENCY
	var total_amplitude := 0.0

	for i in range(OCTAVES):
		var noise := FastNoiseLite.new()
		noise.seed = base_seed + i * 100
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = frequency
		noise.fractal_octaves = 1  # Single octave per generator

		octaves.append({
			"noise": noise,
			"amplitude": amplitude,
			"frequency": frequency
		})

		total_amplitude += amplitude

		# Prepare next octave
		amplitude *= GAIN  # Reduce amplitude (typically halve it)
		frequency *= LACUNARITY  # Increase frequency (typically double it)

	# Store total amplitude for normalization
	octaves.append({"total_amplitude": total_amplitude})

	return octaves


## Create domain warping noise for organic shapes
func _create_domain_warp_noise(base_seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = base_seed + 1000
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = WARP_FREQUENCY
	noise.fractal_octaves = WARP_OCTAVES
	return noise


## Generate heightmap mesh by modifying vertex positions
func _generate_heightmap_mesh(world_size: float, noise_octaves: Array, warp_noise: FastNoiseLite) -> ArrayMesh:
	# Create base plane mesh
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(world_size, world_size)
	plane_mesh.subdivide_depth = MESH_SUBDIVISIONS
	plane_mesh.subdivide_width = MESH_SUBDIVISIONS

	# Convert to mesh data tool for vertex manipulation
	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(plane_mesh, 0)
	var array_mesh := surface_tool.commit()

	var mdt := MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)

	# Apply heightmap to each vertex
	for i in range(mdt.get_vertex_count()):
		var vertex := mdt.get_vertex(i)
		var height := _calculate_terrain_height(vertex, noise_octaves, warp_noise)

		vertex.y = height
		mdt.set_vertex(i, vertex)

	# Commit changes and regenerate normals
	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)

	surface_tool.clear()
	surface_tool.create_from(array_mesh, 0)
	surface_tool.generate_normals()
	return surface_tool.commit()


## Calculate terrain height for a given vertex using fractal noise
func _calculate_terrain_height(vertex: Vector3, noise_octaves: Array, warp_noise: FastNoiseLite) -> float:
	# Apply domain warping for organic, natural-looking shapes
	var warp_offset_x := warp_noise.get_noise_2d(vertex.x, vertex.z) * WARP_STRENGTH
	var warp_offset_z := warp_noise.get_noise_2d(vertex.x + 1000, vertex.z + 1000) * WARP_STRENGTH
	var warped_x := vertex.x + warp_offset_x
	var warped_z := vertex.z + warp_offset_z

	# Get total amplitude for normalization (stored in last array element)
	var total_amplitude: float = noise_octaves[-1]["total_amplitude"]

	# Manually combine octaves: elevation = Σ(amplitude_i × noise_i)
	var elevation := 0.0

	for i in range(OCTAVES):
		var octave_data: Dictionary = noise_octaves[i]
		var noise: FastNoiseLite = octave_data["noise"]
		var amplitude: float = octave_data["amplitude"]

		# Sample this octave and weight by amplitude
		var noise_value := noise.get_noise_2d(warped_x, warped_z)  # Returns -1 to 1
		elevation += amplitude * noise_value

	# Normalize by total amplitude to get range approximately -1 to 1
	elevation = elevation / total_amplitude

	# Convert to 0-1 range
	elevation = (elevation + 1.0) / 2.0

	# Apply fudge factor and power curve for mountain distribution
	# Higher exponent = flatter valleys with sharper, more dramatic peaks
	elevation = clamp(elevation * FUDGE_FACTOR, 0.0, 1.0)
	elevation = pow(elevation, MOUNTAIN_EXPONENT)

	# Scale to final height range
	return elevation * MAX_HEIGHT


# Sand material parameters
const SAND_TEXTURE_SIZE := 512  # Resolution of generated noise textures
const SAND_UV_SCALE := 0.05  # Triplanar scale: texture repeats every 20 world units
const SAND_RIPPLE_STRENGTH := 2.5  # Normal map bump strength for sand ripples


## Apply visual material to terrain mesh
func _apply_terrain_material(mesh_instance: MeshInstance3D) -> void:
	var material := StandardMaterial3D.new()

	# Base sand tint (multiplied with the albedo noise texture)
	material.albedo_color = Color(0.82, 0.70, 0.52)
	material.albedo_texture = _create_sand_albedo_texture()

	# Ripple/grain relief via procedural normal map
	material.normal_enabled = true
	material.normal_texture = _create_sand_normal_texture()
	material.normal_scale = 1.0

	# Dry sand: fully rough, non-metallic
	material.roughness = 1.0
	material.metallic = 0.0

	# Triplanar mapping avoids UV stretching on dune slopes and mountains
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(SAND_UV_SCALE, SAND_UV_SCALE, SAND_UV_SCALE)

	mesh_instance.set_surface_override_material(0, material)


## Create seamless mottled albedo texture with layered sand tones
func _create_sand_albedo_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 7001
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 2.2

	# Sand color ramp: darker compacted patches through sun-bleached highlights
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.68, 0.56, 0.40))
	ramp.set_color(1, Color(1.0, 0.92, 0.76))
	ramp.add_point(0.45, Color(0.84, 0.72, 0.54))
	ramp.add_point(0.7, Color(0.93, 0.83, 0.65))

	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.seamless = true
	texture.width = SAND_TEXTURE_SIZE
	texture.height = SAND_TEXTURE_SIZE
	return texture


## Create seamless normal map texture for wind ripples and grain relief
func _create_sand_normal_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 7002
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.03
	# Ridged fractal produces elongated crests that read as wind ripples
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55

	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.as_normal_map = true
	texture.bump_strength = SAND_RIPPLE_STRENGTH
	texture.seamless = true
	texture.width = SAND_TEXTURE_SIZE
	texture.height = SAND_TEXTURE_SIZE
	return texture


## Add collision shape to terrain mesh
func _add_terrain_collision(mesh_instance: MeshInstance3D, array_mesh: ArrayMesh) -> void:
	var static_body := StaticBody3D.new()
	static_body.name = "TerrainCollision"
	static_body.collision_layer = 1  # Layer 1 for raycasts
	static_body.collision_mask = 0   # Terrain doesn't detect anything

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape"

	var shape := array_mesh.create_trimesh_shape()
	if shape:
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
		mesh_instance.add_child(static_body)
		print("  - Terrain collision created successfully (StaticBody3D + trimesh on layer 1)")
	else:
		push_warning("  - Failed to create trimesh collision shape!")
