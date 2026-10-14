extends Node3D
class_name AssemblyZone

## Assembly zone for faction motherships
## Serves as: spawn point, resource offload location, and retreat destination
## Detects player occupancy and triggers entry events after 3 seconds

signal player_entered
signal player_exited
signal entry_timer_started
signal entry_timer_cancelled
signal mothership_entry_triggered

## Zone Configuration
@export var zone_id: int = 1  # 1, 2, or 3
@export var zone_radius: float = 15.0
@export var entry_delay: float = 3.0  # Seconds player must remain in zone

## Visual Configuration
@export var neon_color: Color = Color(0.2, 0.8, 1.0, 1.0)  # Cyan by default
@export var tube_radius: float = 15.0
@export var tube_height: float = 1.0

## State
var player_inside: bool = false
var entry_timer: float = 0.0
var owning_mothership: Node3D = null

## Child Node References
@onready var zone_area: Area3D = $ZoneArea
@onready var label: Label3D = $Label3D
@onready var neon_tube: MeshInstance3D = $NeonTube


func _ready() -> void:
	_setup_zone_area()
	_setup_label()
	_setup_visual()


func _process(delta: float) -> void:
	# Handle entry timer
	if player_inside and entry_timer < entry_delay:
		entry_timer += delta

		if entry_timer >= entry_delay:
			_trigger_mothership_entry()


func _setup_zone_area() -> void:
	"""Configure the area detection zone (sphere, half in ground)"""
	if not zone_area:
		push_error("[AssemblyZone] ZoneArea node not found!")
		return

	# Connect signals
	zone_area.body_entered.connect(_on_body_entered)
	zone_area.body_exited.connect(_on_body_exited)

	# Configure collision shape radius (sphere)
	var collision_shape := zone_area.get_node_or_null("CollisionShape3D")
	if collision_shape and collision_shape.shape is SphereShape3D:
		collision_shape.shape.radius = zone_radius


func _setup_label() -> void:
	"""Configure the zone label"""
	if label:
		label.text = "Zone %d" % zone_id
		label.modulate = neon_color


func _setup_visual() -> void:
	"""Configure the neon tube visual (short wide cylinder at ground level)"""
	if not neon_tube:
		return

	# Update cylinder dimensions
	if neon_tube.mesh is CylinderMesh:
		neon_tube.mesh.top_radius = tube_radius
		neon_tube.mesh.bottom_radius = tube_radius
		neon_tube.mesh.height = tube_height

	# Apply neon color to material
	var material := neon_tube.get_surface_override_material(0)
	if not material:
		material = StandardMaterial3D.new()
		neon_tube.set_surface_override_material(0, material)

	if material is StandardMaterial3D:
		material.albedo_color = neon_color
		material.emission_enabled = true
		material.emission = neon_color
		material.emission_energy_multiplier = 2.0
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Double-sided for hollow tube


func set_faction_color(color: Color) -> void:
	"""Update zone color to match faction"""
	neon_color = color

	if label:
		label.modulate = color

	if neon_tube:
		_setup_visual()


func _on_body_entered(body: Node3D) -> void:
	"""Handle entity entering the zone"""
	if body.is_in_group("player"):
		player_inside = true
		entry_timer = 0.0
		player_entered.emit()
		entry_timer_started.emit()
		print("[AssemblyZone %d] Player entered - entry timer started" % zone_id)


func _on_body_exited(body: Node3D) -> void:
	"""Handle entity leaving the zone"""
	if body.is_in_group("player"):
		player_inside = false
		entry_timer = 0.0
		player_exited.emit()
		entry_timer_cancelled.emit()
		print("[AssemblyZone %d] Player exited - entry timer cancelled" % zone_id)


func _trigger_mothership_entry() -> void:
	"""Trigger the mothership entry event"""
	print("[AssemblyZone %d] Entry timer complete - triggering mothership entry!" % zone_id)
	mothership_entry_triggered.emit()

	# Reset timer so it doesn't trigger repeatedly
	entry_timer = 0.0

	# Notify owning mothership if set
	if owning_mothership and owning_mothership.has_method("on_player_entered"):
		owning_mothership.on_player_entered(self)


func get_entry_progress() -> float:
	"""Get current entry timer progress (0.0 to 1.0)"""
	if not player_inside:
		return 0.0
	return clamp(entry_timer / entry_delay, 0.0, 1.0)


func get_spawn_position() -> Vector3:
	"""Get the world position for squad spawning

	Returns position above the zone for safe spawning
	"""
	var spawn_pos := global_position + Vector3.UP * 15.0
	print("[AssemblyZone %d] Spawn position: %v (zone at: %v)" % [zone_id, spawn_pos, global_position])
	return spawn_pos
