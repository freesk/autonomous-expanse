extends Node
class_name AimSystem

## AimSystem - Handles weapon aiming, target tracking, and crosshair UI
## Only active for player-controlled drones

## Aim Configuration
@export_group("Aim Settings")
@export var reticle_radius_ratio: float = 0.28  ## Reticle max radius from screen center
@export var reticle_sensitivity: float = 1.0  ## Mouse sensitivity
@export var aim_raycast_distance: float = 2500.0  ## Max world aim distance
@export var aim_collision_mask: int = 1 | 4  ## World + enemy
@export var aim_rotation_smoothing: float = 8.0  ## Higher = faster response
@export var aim_target_jitter_deg: float = 0.45  ## Ignore tiny target changes

## Crosshair Configuration
@export_group("Crosshair")
@export var crosshair_base_gap: float = 8.0
@export var crosshair_max_expand_speed: float = 18.0
@export var crosshair_move_expand_factor: float = 0.18
@export var crosshair_fire_expand: float = 7.0
@export var crosshair_fire_decay: float = 10.0

## State
var reticle_offset: Vector2 = Vector2.ZERO
var reticle_radius_px: float = 140.0
var aim_world_position: Vector3 = Vector3.ZERO
var aim_hit_target: Node3D = null
var aim_target_yaw: float = 0.0
var has_aim_target_yaw: bool = false
var crosshair_fire_timer: float = 0.0

## UI References
var crosshair_layer: CanvasLayer = null
var crosshair_root: Control = null
var crosshair_h: ColorRect = null
var crosshair_v: ColorRect = null

## Parent drone reference
var drone: RigidBody3D = null
var input_controller: Node = null
var crosshair_initialized: bool = false


func _ready() -> void:
	drone = get_parent() as RigidBody3D
	if not drone:
		push_error("[AimSystem] Parent must be RigidBody3D")
		return

	# Get MotionController reference
	input_controller = drone.get_node_or_null("MotionController")


func _is_player_controlled() -> bool:
	## Check if this drone is player-controlled
	## Done dynamically because control_mode may change
	if not input_controller:
		return false
	return input_controller.control_mode == 0  # 0 = PLAYER mode


func _input(event: InputEvent) -> void:
	## Mouse drives reticle (constrained around screen center)
	## ONLY for player-controlled drones
	if not _is_player_controlled():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var viewport_size := get_viewport().get_visible_rect().size
		reticle_radius_px = minf(viewport_size.x, viewport_size.y) * reticle_radius_ratio
		reticle_offset += event.relative * reticle_sensitivity
		reticle_offset = reticle_offset.limit_length(reticle_radius_px)


func _physics_process(delta: float) -> void:
	# ONLY run aim system for player-controlled drones
	if not _is_player_controlled():
		return

	# Setup crosshair UI on first frame for player (after control_mode is set)
	if not crosshair_initialized:
		_setup_crosshair_ui()
		crosshair_initialized = true

	if not drone:
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	# Update reticle and aim
	_update_aim_raycast(camera, delta)
	_update_crosshair_visual(delta)


func _update_aim_raycast(camera: Camera3D, delta: float) -> void:
	## Cast ray from reticle to find aim point
	var viewport_size := get_viewport().get_visible_rect().size
	reticle_radius_px = minf(viewport_size.x, viewport_size.y) * reticle_radius_ratio
	reticle_offset = reticle_offset.limit_length(reticle_radius_px)

	var screen_center := viewport_size * 0.5
	var reticle_screen_pos := screen_center + reticle_offset

	var ray_origin := camera.project_ray_origin(reticle_screen_pos)
	var ray_dir := camera.project_ray_normal(reticle_screen_pos)
	var ray_to := ray_origin + ray_dir * aim_raycast_distance

	_update_aim_target_yaw(ray_dir, delta)

	# Raycast to find aim target
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_to)
	query.exclude = [drone]
	query.collision_mask = aim_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result := drone.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		aim_world_position = ray_to
		aim_hit_target = null
	else:
		aim_world_position = result.get("position", ray_to)
		aim_hit_target = result.get("collider")


func _update_aim_target_yaw(ray_dir: Vector3, delta: float) -> void:
	## Update target yaw from aim direction
	var flat_dir := Vector3(ray_dir.x, 0.0, ray_dir.z)
	if flat_dir.length_squared() < 0.0001:
		return

	var raw_yaw := atan2(flat_dir.x, flat_dir.z)
	if not has_aim_target_yaw:
		aim_target_yaw = raw_yaw
		has_aim_target_yaw = true
		return

	var raw_delta := absf(_angle_difference(raw_yaw, aim_target_yaw))
	if raw_delta < deg_to_rad(aim_target_jitter_deg):
		return

	var smoothing_alpha := clampf(aim_rotation_smoothing * delta, 0.0, 1.0)
	aim_target_yaw = lerp_angle(aim_target_yaw, raw_yaw, smoothing_alpha)


func _update_crosshair_visual(delta: float) -> void:
	## Update crosshair position and appearance
	if not crosshair_root or not crosshair_h or not crosshair_v:
		return

	crosshair_fire_timer = maxf(0.0, crosshair_fire_timer - delta * crosshair_fire_decay)

	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var pos := center + reticle_offset

	var speed := drone.linear_velocity.length()
	var speed_expand := minf(speed, crosshair_max_expand_speed) * crosshair_move_expand_factor
	var fire_expand := crosshair_fire_timer * crosshair_fire_expand
	var gap := crosshair_base_gap + speed_expand + fire_expand
	var arm_len := 10.0
	var arm_thickness := 2.0

	# Color changes when on target
	var color := Color(0.2, 1.0, 0.55, 0.95) if aim_hit_target != null else Color(0.95, 0.98, 1.0, 0.95)
	crosshair_h.color = color
	crosshair_v.color = color

	crosshair_h.size = Vector2(arm_len + gap * 2.0, arm_thickness)
	crosshair_v.size = Vector2(arm_thickness, arm_len + gap * 2.0)

	crosshair_h.position = Vector2(pos.x - crosshair_h.size.x * 0.5, pos.y - arm_thickness * 0.5)
	crosshair_v.position = Vector2(pos.x - arm_thickness * 0.5, pos.y - crosshair_v.size.y * 0.5)


func _setup_crosshair_ui() -> void:
	## Create crosshair UI overlay
	if crosshair_layer and is_instance_valid(crosshair_layer):
		return

	crosshair_layer = CanvasLayer.new()
	crosshair_layer.layer = 100

	crosshair_root = Control.new()
	crosshair_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_layer.add_child(crosshair_root)

	crosshair_h = ColorRect.new()
	crosshair_h.color = Color(0.95, 0.98, 1.0, 0.95)
	crosshair_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_root.add_child(crosshair_h)

	crosshair_v = ColorRect.new()
	crosshair_v.color = Color(0.95, 0.98, 1.0, 0.95)
	crosshair_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_root.add_child(crosshair_v)

	# Boundary ring
	var boundary_ring = Control.new()
	boundary_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	boundary_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_root.add_child(boundary_ring)

	var circle_segments = 64
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var radius := minf(viewport_size.x, viewport_size.y) * reticle_radius_ratio

	for i in range(circle_segments):
		var angle1 := (i / float(circle_segments)) * TAU
		var angle2 := ((i + 1) / float(circle_segments)) * TAU

		var p1 := center + Vector2(cos(angle1), sin(angle1)) * radius
		var p2 := center + Vector2(cos(angle2), sin(angle2)) * radius

		var line := ColorRect.new()
		line.color = Color(0.5, 0.5, 0.5, 0.3)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.size = Vector2((p2 - p1).length(), 1.0)
		line.position = p1
		line.rotation = (p2 - p1).angle()
		boundary_ring.add_child(line)

	get_tree().root.call_deferred("add_child", crosshair_layer)


func on_weapon_fired() -> void:
	## Called when weapon fires to expand crosshair
	crosshair_fire_timer = 1.0


func get_aim_position() -> Vector3:
	## Get current aim world position
	return aim_world_position


func set_aim_position(position: Vector3) -> void:
	## Set aim position manually (for AI control)
	## Used by CombatAI to set intercept point
	aim_world_position = position


func get_aim_target_yaw() -> float:
	## Get target yaw for drone rotation
	return aim_target_yaw if has_aim_target_yaw else drone.rotation.y


func _angle_difference(target: float, current: float) -> float:
	## Calculate shortest angle difference
	var diff := fmod(target - current + PI, TAU) - PI
	return diff if diff > -PI else diff + TAU


func _exit_tree() -> void:
	if crosshair_layer and is_instance_valid(crosshair_layer):
		crosshair_layer.queue_free()
