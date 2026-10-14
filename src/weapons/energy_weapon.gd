extends "res://src/weapons/weapon_base.gd"
class_name EnergyWeapon

## Energy-based weapon system for DroneWorld
## SPEC: Only TWO weapon types - Laser (hitscan) and Energy Burst (projectile)
## All weapons use energy system, NO ammo, NO heat, NO reload

## Energy weapon type
enum EnergyType {
	LASER,         # Instant hit beam weapon (hitscan)
	ENERGY_BURST   # Fast-moving energy projectiles
}

@export var energy_type: EnergyType = EnergyType.LASER

## Laser-specific settings
@export var beam_width: float = 0.1
@export var beam_duration: float = 0.1  # Visual beam duration
@export var beam_color: Color = Color(1.0, 0.2, 0.2, 1.0)

## Energy Burst-specific settings
@export var burst_projectile_scene: PackedScene
@export var burst_projectile_lifetime: float = 3.0
@export var burst_color: Color = Color(0.2, 0.5, 1.0, 1.0)

## Visual effects
@export var muzzle_glow_scene: PackedScene
@export var impact_spark_scene: PackedScene

## Audio
@export var fire_sound: AudioStream
@export var impact_sound: AudioStream

## Internal components
var raycast: RayCast3D
var beam_mesh: MeshInstance3D
var audio_player: AudioStreamPlayer3D

func _ready() -> void:
	super._ready()

	# Set weapon type based on energy type
	weapon_type = "laser" if energy_type == EnergyType.LASER else "energy_burst"
	damage_type = "energy"

	# Setup raycast for laser weapons
	if energy_type == EnergyType.LASER:
		setup_raycast()
		setup_beam_mesh()

	# Create audio player
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.max_distance = 500.0
	audio_player.bus = "SFX"

func _process(delta: float) -> void:
	super._process(delta)

	# Update beam visualization (fade out)
	if beam_mesh and beam_mesh.visible:
		var material = beam_mesh.get_active_material(0) as StandardMaterial3D
		if material:
			var alpha = material.albedo_color.a
			alpha = max(0.0, alpha - delta * 10.0)
			material.albedo_color.a = alpha

			if alpha <= 0.0:
				beam_mesh.visible = false

## Setup raycast for instant-hit laser weapons
func setup_raycast() -> void:
	raycast = RayCast3D.new()
	add_child(raycast)
	raycast.target_position = Vector3(0, 0, -max_range)
	raycast.enabled = false
	raycast.hit_from_inside = false
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true

	# Set collision mask to hit world and enemies
	raycast.collision_mask = 1 | 4  # Layer 1 (World) | Layer 3 (Enemy)

## Setup beam visualization mesh
func setup_beam_mesh() -> void:
	beam_mesh = MeshInstance3D.new()
	add_child(beam_mesh)

	# Create beam mesh (cylinder)
	var mesh = CylinderMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.top_radius = beam_width
	mesh.bottom_radius = beam_width
	mesh.height = 1.0  # Will be scaled

	beam_mesh.mesh = mesh

	# Create emissive material
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = beam_color
	material.emission_enabled = true
	material.emission = beam_color
	material.emission_energy_multiplier = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	beam_mesh.material_override = material
	beam_mesh.visible = false

## Override fire method
func fire() -> void:
	match energy_type:
		EnergyType.LASER:
			fire_laser()
		EnergyType.ENERGY_BURST:
			fire_energy_burst()

## Fire instant-hit laser
func fire_laser() -> void:
	var fire_origin = get_fire_origin()
	var fire_direction = get_fire_direction()
	var spread_direction = apply_spread(fire_direction)

	var hit_position: Vector3
	var hit_normal: Vector3 = Vector3.UP
	var collider: Node3D = null

	# World-space query keeps hitscan aligned with reticle/camera-based aim.
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		fire_origin,
		fire_origin + spread_direction * max_range
	)
	# Only exclude owner_drone if it's valid (avoid NodePath error)
	if owner_drone and is_instance_valid(owner_drone):
		query.exclude = [owner_drone]
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.collision_mask = 1 | 4 | 16  # Layer 1 (World) | Layer 3 (Enemy) | Layer 5 (Pickup/Resources)
	var result := space_state.intersect_ray(query)

	if not result.is_empty():
		hit_position = result.get("position", fire_origin)
		hit_normal = result.get("normal", Vector3.UP)
		collider = result.get("collider")

		# Calculate damage
		var distance = fire_origin.distance_to(hit_position)
		var distance_modifier = calculate_distance_modifier(distance)
		var final_damage = base_damage * distance_modifier

		# Apply damage to target's HealthSystem
		var health_system = null
		if collider and collider.has_node("HealthSystem"):
			health_system = collider.get_node("HealthSystem")
		elif collider and collider.has_method("take_damage"):
			health_system = collider

		if health_system and health_system.has_method("take_damage"):
			# Pass owner_drone as attacker (not damage type enum)
			health_system.take_damage(final_damage, owner_drone)
			hit_target.emit(collider, final_damage, hit_position)
			print("[EnergyWeapon] HIT! Dealt %.1f damage to %s" % [final_damage, collider.name])
			if impact_sound:
				play_sound_at(impact_sound, hit_position, randf_range(0.9, 1.1), -10.0)
		else:
			if collider:
				print("[EnergyWeapon] Hit %s but no HealthSystem found" % collider.name)

		# Spawn impact effect
		if impact_spark_scene:
			spawn_impact_effect(hit_position, hit_normal)
	else:
		# No hit - beam goes to max range
		hit_position = fire_origin + spread_direction * max_range

	# Visualize beam
	show_beam(fire_origin, hit_position)

	# Play sound
	if fire_sound and audio_player:
		audio_player.stream = fire_sound
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()

## Fire energy burst projectile
func fire_energy_burst() -> void:
	if not burst_projectile_scene:
		push_warning("Energy burst projectile scene not set, using default")
		create_default_burst_projectile()
		return

	var fire_origin = get_fire_origin()
	var fire_direction = get_fire_direction()
	var spread_direction = apply_spread(fire_direction)

	# Spawn energy burst projectile
	var projectile = burst_projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = fire_origin

	# Set velocity
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(spread_direction * projectile_speed)
	elif projectile is RigidBody3D:
		projectile.linear_velocity = spread_direction * projectile_speed

	# Set weapon data
	if projectile.has_method("set_weapon_data"):
		projectile.set_weapon_data({
			"damage": base_damage,
			"damage_type": "energy",
			"owner": owner_drone,
			"weapon": self,
			"speed": projectile_speed,
			"max_range": max_range,
			"impact_sound": impact_sound
		})

	# Set projectile color
	if projectile.has_method("set_glow_color"):
		projectile.set_glow_color(burst_color)

	# Lifetime
	get_tree().create_timer(burst_projectile_lifetime).timeout.connect(func():
		if is_instance_valid(projectile):
			projectile.queue_free()
	)

	# Play sound (heavier shot: slight downward pitch variance)
	if fire_sound and audio_player:
		audio_player.stream = fire_sound
		audio_player.pitch_scale = randf_range(0.92, 1.0)
		audio_player.play()

## Create default energy burst projectile (fallback)
func create_default_burst_projectile() -> void:
	var fire_origin = get_fire_origin()
	var fire_direction = get_fire_direction()
	var spread_direction = apply_spread(fire_direction)

	# Use raycast for instant hit if no projectile scene
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(fire_origin, fire_origin + spread_direction * max_range)
	# Only exclude owner_drone if it's valid (avoid NodePath error)
	if owner_drone and is_instance_valid(owner_drone):
		query.exclude = [owner_drone]
	query.collision_mask = 1 | 4  # Layer 1 (World) | Layer 3 (Enemy)

	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		var hit_position: Vector3 = result.get("position", fire_origin)
		var hit_normal: Vector3 = result.get("normal", Vector3.UP)
		var collider: Node3D = result.get("collider")

		# Calculate damage with falloff
		var distance: float = fire_origin.distance_to(hit_position)
		var distance_modifier: float = calculate_distance_modifier(distance)
		var final_damage: float = base_damage * distance_modifier

		# Apply damage
		if collider and collider.has_method("take_damage"):
			collider.take_damage(final_damage, damage_type, hit_position)

		# Emit hit signal
		if collider:
			hit_target.emit(collider, final_damage, hit_position)

		# Spawn impact effect
		if impact_spark_scene:
			spawn_impact_effect(hit_position, hit_normal)

## Show beam visualization
func show_beam(start: Vector3, end: Vector3) -> void:
	if not beam_mesh:
		return

	beam_mesh.visible = true

	# Calculate beam transform
	var beam_length = start.distance_to(end)

	# Shorten beam slightly so it ends AT the target, not through it
	var direction = (end - start).normalized()
	var shortened_end = end - direction * 0.1  # Pull back 10cm from impact point
	var beam_center = (start + shortened_end) * 0.5
	beam_length = start.distance_to(shortened_end)

	beam_mesh.global_position = beam_center

	# Orient beam
	if direction.length() > 0:
		beam_mesh.look_at(shortened_end, Vector3.UP)
		beam_mesh.rotate_object_local(Vector3.RIGHT, PI / 2)  # Orient cylinder

	# Scale beam
	beam_mesh.scale = Vector3(1, beam_length, 1)

	# Reset alpha
	var material = beam_mesh.get_active_material(0) as StandardMaterial3D
	if material:
		material.albedo_color.a = 1.0

## Play a one-shot 3D sound at a world position, detached from any node lifecycle
func play_sound_at(stream: AudioStream, position: Vector3, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not stream or not is_inside_tree():
		return
	var one_shot := AudioStreamPlayer3D.new()
	one_shot.stream = stream
	one_shot.bus = "SFX"
	one_shot.max_distance = 300.0
	one_shot.pitch_scale = pitch
	one_shot.volume_db = volume_db
	get_tree().root.add_child(one_shot)
	one_shot.global_position = position
	one_shot.finished.connect(one_shot.queue_free)
	one_shot.play()

## Spawn impact effect
func spawn_impact_effect(position: Vector3, normal: Vector3) -> void:
	if not impact_spark_scene:
		return

	var effect = impact_spark_scene.instantiate()
	get_tree().root.add_child(effect)
	effect.global_position = position
	effect.look_at(position + normal, Vector3.UP)

	# Auto-cleanup
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(effect):
			effect.queue_free()
	)
