extends Area3D
class_name Projectile

## Base projectile class for physical projectiles
## Handles movement, collision detection, and damage application

## Projectile properties
var damage: float = 10.0
var damage_type: String = "kinetic"
var speed: float = 80.0
var max_distance: float = 400.0
var owner_node: Node3D = null
var weapon = null  # WeaponBase type (avoid circular dependency)
var impact_sound: AudioStream = null

## Internal state
var velocity: Vector3 = Vector3.ZERO
var distance_traveled: float = 0.0
var start_position: Vector3 = Vector3.ZERO
var has_hit: bool = false

## Visual effects
var trail_particles: GPUParticles3D = null
var glow_mesh: MeshInstance3D = null

## Signals
signal hit_target(target: Node3D, damage: float, position: Vector3)
signal projectile_destroyed()

func _ready() -> void:
	start_position = global_position

	# Connect collision signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Set up collision layers (hardcoded to avoid GameConstants dependency)
	collision_layer = 8  # Layer 4 (Projectile)
	collision_mask = 1 | 4  # Layers 1 (World) and 3 (Enemy)

	# Find glow mesh for color updates
	if has_node("OuterGlow"):
		glow_mesh = get_node("OuterGlow")
	elif has_node("InnerCore"):
		glow_mesh = get_node("InnerCore")
	elif has_node("MeshInstance3D"):
		glow_mesh = get_node("MeshInstance3D")

	# Orient projectile to velocity direction
	if velocity.length() > 0:
		look_at(global_position + velocity.normalized(), Vector3.UP)

func _physics_process(delta: float) -> void:
	if has_hit:
		return

	# Move projectile
	var movement = velocity * delta
	global_position += movement

	# Track distance
	distance_traveled += movement.length()

	# Check if exceeded max distance
	if distance_traveled >= max_distance:
		destroy()
		return

	# Optional: Apply gravity for ballistic projectiles
	# Uncomment if you want gravity-affected projectiles
	# velocity += Vector3.DOWN * 9.8 * delta

## Set projectile velocity and initial direction
func set_velocity(vel: Vector3) -> void:
	velocity = vel
	speed = vel.length()

	# Orient to velocity
	if velocity.length() > 0:
		look_at(global_position + velocity.normalized(), Vector3.UP)

## Set weapon data from the firing weapon
func set_weapon_data(data: Dictionary) -> void:
	if data.has("damage"):
		damage = data.damage
	if data.has("damage_type"):
		damage_type = data.damage_type
	if data.has("owner"):
		owner_node = data.owner
	if data.has("weapon"):
		weapon = data.weapon
	if data.has("speed"):
		speed = data.speed
	if data.has("max_range"):
		max_distance = data.max_range
	if data.has("impact_sound"):
		impact_sound = data.impact_sound

## Called when projectile hits a body
func _on_body_entered(body: Node3D) -> void:
	if has_hit:
		return

	# Don't hit owner
	if body == owner_node:
		return

	_hit_target(body)

## Called when projectile hits an area
func _on_area_entered(area: Area3D) -> void:
	if has_hit:
		return

	# Don't hit owner
	if area == owner_node:
		return

	_hit_target(area)

## Handle hitting a target
func _hit_target(target: Node) -> void:
	has_hit = true

	# Apply damage to target's HealthSystem
	# Target is typically the RigidBody3D drone, need to find its HealthSystem
	var health_system = null
	if target.has_node("HealthSystem"):
		health_system = target.get_node("HealthSystem")
	elif target.has_method("take_damage"):
		# Direct take_damage method (legacy support)
		health_system = target

	if health_system and health_system.has_method("take_damage"):
		# HealthSystem.take_damage(amount, attacker: Node3D)
		# Pass owner_node as the attacker (the drone that fired the weapon)
		health_system.take_damage(damage, owner_node)

	# Play impact sound (detached from this node, which is about to be freed)
	if impact_sound and is_inside_tree():
		var one_shot := AudioStreamPlayer3D.new()
		one_shot.stream = impact_sound
		one_shot.bus = "SFX"
		one_shot.max_distance = 300.0
		one_shot.pitch_scale = randf_range(0.9, 1.1)
		get_tree().root.add_child(one_shot)
		one_shot.global_position = global_position
		one_shot.finished.connect(one_shot.queue_free)
		one_shot.play()

	# Emit signals
	hit_target.emit(target, damage, global_position)

	if weapon:
		weapon.hit_target.emit(target, damage, global_position)

	# Destroy projectile
	destroy()

## Destroy the projectile
func destroy() -> void:
	# Could spawn impact effect here
	projectile_destroyed.emit()
	queue_free()

## Set projectile glow color
func set_glow_color(color: Color) -> void:
	# Update outer glow
	if has_node("OuterGlow"):
		var outer = get_node("OuterGlow") as MeshInstance3D
		var material = outer.get_active_material(0) as StandardMaterial3D
		if material:
			material.albedo_color = color
			material.emission = color

	# Update inner core
	if has_node("InnerCore"):
		var inner = get_node("InnerCore") as MeshInstance3D
		var material = inner.get_active_material(0) as StandardMaterial3D
		if material:
			var bright_color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, color.a)
			material.albedo_color = bright_color
			material.emission = bright_color

	# Update light color
	if has_node("OmniLight3D"):
		var light = get_node("OmniLight3D") as OmniLight3D
		light.light_color = color

	# Update particle colors
	if has_node("Trail"):
		var trail = get_node("Trail") as GPUParticles3D
		var mat = trail.process_material as ParticleProcessMaterial
		if mat:
			mat.color = color

	if has_node("PlasmaParticles"):
		var plasma = get_node("PlasmaParticles") as GPUParticles3D
		var mat = plasma.process_material as ParticleProcessMaterial
		if mat:
			mat.color = color

	# Legacy support
	if glow_mesh:
		var material = glow_mesh.get_active_material(0) as StandardMaterial3D
		if material:
			material.albedo_color = color
			material.emission = color
