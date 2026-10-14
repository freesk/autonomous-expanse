extends Node

## Drone Colorizer Component
## Applies color tinting to drone models with greyscale textures
## Automatically finds MeshInstance3D nodes and applies the greyscale color shader

@export var tint_color: Color = Color.WHITE
@export var color_intensity: float = 1.0
@export var metallic: float = 0.6
@export var roughness: float = 0.4
@export var rim_enabled: bool = true
@export var rim_strength: float = 0.5

var shader_material: ShaderMaterial
var applied_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	# Wait a frame for the scene tree to be fully loaded
	await get_tree().process_frame
	apply_color()


## Apply the color to all mesh instances in the parent node
func apply_color() -> void:
	# Find and apply to all mesh instances
	var parent = get_parent()
	if parent:
		_apply_to_meshes(parent)

	if applied_meshes.is_empty():
		push_warning("[DroneColorizer] No mesh instances found to colorize")
	else:
		print("[DroneColorizer] Applied color to %d meshes with color: %s" % [applied_meshes.size(), tint_color])


## Recursively find and apply material to mesh instances
func _apply_to_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		_apply_to_mesh_instance(mesh_instance)

	for child in node.get_children():
		_apply_to_meshes(child)


## Apply color using StandardMaterial3D with texture color mix
func _apply_to_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return

	# Ensure shadow casting is enabled at the node level
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Get the number of surfaces in the mesh
	var surface_count = mesh_instance.mesh.get_surface_count()

	# Apply color to all surfaces
	for i in range(surface_count):
		# Get the original material (check override first, then mesh material)
		var original_material = mesh_instance.get_surface_override_material(i)
		if original_material == null:
			original_material = mesh_instance.mesh.surface_get_material(i)

		# Only work with StandardMaterial3D
		if original_material == null or not original_material is StandardMaterial3D:
			continue

		# CRITICAL: Duplicate the material so each drone has its own instance
		# This prevents all drones from sharing the same material
		var material = (original_material as StandardMaterial3D).duplicate()

		# Apply color to the duplicated material
		material.albedo_color = tint_color
		material.metallic = metallic
		material.roughness = roughness

		# Set as override so this drone uses its own material
		mesh_instance.set_surface_override_material(i, material)

	applied_meshes.append(mesh_instance)


## Set a new color dynamically (useful for random colors)
func set_color(new_color: Color) -> void:
	tint_color = new_color
	# Update all applied meshes
	for mesh_instance in applied_meshes:
		var surface_count = mesh_instance.mesh.get_surface_count()
		for i in range(surface_count):
			var mat = mesh_instance.get_surface_override_material(i)
			if mat == null:
				mat = mesh_instance.mesh.surface_get_material(i)

			if mat and mat is StandardMaterial3D:
				var std_mat = mat as StandardMaterial3D
				std_mat.albedo_color = tint_color


## Generate a random bright color (excluding black/dark colors)
static func get_random_bright_color() -> Color:
	var hue: float = randf()  # Random hue (0-1)
	var saturation: float = randf_range(0.6, 1.0)  # High saturation for vibrant colors
	var value: float = randf_range(0.7, 1.0)  # High value to avoid dark colors

	# Convert HSV to RGB
	return Color.from_hsv(hue, saturation, value)


## Generate a random color excluding specific ranges
static func get_random_color_exclude_dark() -> Color:
	var color: Color
	var attempts: int = 0
	var max_attempts: int = 10

	# Keep generating until we get a sufficiently bright color
	while attempts < max_attempts:
		color = get_random_bright_color()

		# Check if color is too dark (close to black)
		var brightness: float = (color.r + color.g + color.b) / 3.0
		if brightness > 0.3:  # Avoid very dark colors
			return color

		attempts += 1

	# Fallback to a safe bright color
	return Color(randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0))
