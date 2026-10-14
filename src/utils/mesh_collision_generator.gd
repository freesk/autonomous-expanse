extends Node

## Mesh Collision Generator
## Automatically creates trimesh collision shapes for all MeshInstance3D nodes
## Attach this to a StaticBody3D parent

func _ready() -> void:
	await get_tree().process_frame
	generate_collision()


func generate_collision() -> void:
	var parent = get_parent()
	if not parent is StaticBody3D:
		push_warning("[MeshCollisionGenerator] Parent must be StaticBody3D")
		return

	# Find all mesh instances
	var meshes = _find_all_meshes(parent)

	print("[MeshCollisionGenerator] Found %d mesh instances" % meshes.size())

	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue

		# Create trimesh collision shape from the mesh
		var shape = mesh_instance.mesh.create_trimesh_shape()
		if shape:
			var collision_shape = CollisionShape3D.new()
			collision_shape.shape = shape

			# Get relative transform from parent StaticBody3D to mesh instance
			var relative_transform = parent.global_transform.affine_inverse() * mesh_instance.global_transform
			collision_shape.transform = relative_transform

			parent.add_child(collision_shape)
			collision_shape.owner = parent.owner
			print("[MeshCollisionGenerator] Created collision for: ", mesh_instance.name, " at transform: ", relative_transform)
		else:
			push_warning("[MeshCollisionGenerator] Failed to create shape for: ", mesh_instance.name)


func _find_all_meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		# Ensure shadow casting is enabled
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		result.append(node)

	for child in node.get_children():
		result.append_array(_find_all_meshes(child))

	return result
