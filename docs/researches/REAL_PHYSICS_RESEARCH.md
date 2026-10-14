# Real Physics Implementation Research for DroneWorld

## Executive Summary

This document presents research on implementing **real force-based physics** for hover vehicles in Godot 4, replacing the current heuristic approach with true physics simulation where:

1. **Gravity affects all structures** (unless anchored)
2. **Drones emit actual upward forces** to counter gravity (not fake hover stabilization)
3. Physics feel smooth and momentum-based, not jerky

## Current Implementation Analysis

**File:** `src/components/drone_physics.gd`

**Current Approach:** Uses `CharacterBody3D` with manual velocity manipulation:
- Gravity applied directly to velocity: `velocity.y -= GRAVITY * delta` (line 119)
- Hover force applied as velocity offset: `velocity.y += hover_thrust` (line 129)
- Drag applied as velocity reduction: `velocity += drag_force` (line 197)
- Movement uses kinematic `move_and_slide()` (line 107)

**Problem:** This is **kinematic simulation**, not dynamic physics. Velocity is manually calculated, not derived from forces acting on a mass.

## Recommended Solution: Switch to RigidBody3D

### Why RigidBody3D?

Godot's `RigidBody3D` is a **dynamic physics body** directly controlled by the physics engine. It simulates:
- **Mass and inertia** (real momentum)
- **Gravity** as a world force affecting all bodies
- **Forces and impulses** applied to the body
- **Collisions with realistic bounce/friction**

### Physics Engine Options

#### 1. **Godot Physics 3D (Default)**
- Built into Godot 4
- Works with `RigidBody3D` out of the box
- Methods: `apply_force()`, `apply_central_force()`, `apply_torque()`
- **Pros:** No additional setup, stable, well-documented
- **Cons:** Can have performance issues with complex scenes

#### 2. **Jolt Physics (Officially Supported Since Godot 4.4)**
- Drop-in replacement for Godot Physics
- Enable via `physics/3d/physics_engine = "Jolt Physics"` in project settings
- **Significantly better performance** and stability
- Same API as Godot Physics (uses same nodes like `RigidBody3D`)
- **Recommended for production use**
- GitHub: https://github.com/godot-jolt/godot-jolt
- Official docs: https://docs.godotengine.org/en/latest/tutorials/physics/using_jolt_physics.html

**Installation (Godot 4.4+):**
Jolt Physics is built into Godot 4.4 as an alternative physics engine. To enable:
1. Project Settings → Physics → 3D → Physics Engine
2. Change from "Default" to "Jolt Physics"
3. Restart project

## Hover Vehicle Physics Implementation

### Architecture: RigidBody3D + Raycast Suspension

This is the **industry-standard approach** for hover vehicles used in games:

```gdscript
extends RigidBody3D
class_name HoverDrone

## Hover Configuration
@export var hover_height: float = 3.0  # Target height above ground
@export var hover_force: float = 50.0  # Spring force strength
@export var hover_damping: float = 10.0  # Spring damping (prevents oscillation)
@export var max_raycast_distance: float = 10.0

## Thrust Configuration
@export var forward_thrust: float = 30.0
@export var strafe_thrust: float = 20.0
@export var upward_thrust: float = 15.0

## Raycasts (one per "hover engine")
var hover_raycasts: Array[RayCast3D] = []

func _ready() -> void:
	# Create raycasts for hover engines (4 corners typical)
	var positions = [
		Vector3(-1, 0, -1),  # Front-left
		Vector3(1, 0, -1),   # Front-right
		Vector3(-1, 0, 1),   # Back-left
		Vector3(1, 0, 1)     # Back-right
	]

	for pos in positions:
		var raycast = RayCast3D.new()
		raycast.position = pos
		raycast.target_position = Vector3(0, -max_raycast_distance, 0)
		raycast.enabled = true
		add_child(raycast)
		hover_raycasts.append(raycast)

	# Enable continuous collision detection for fast-moving drones
	continuous_cd = true

	# Set mass (affects all forces)
	mass = 800.0  # kg

func _physics_process(delta: float) -> void:
	# 1. Apply hover forces at each raycast point
	apply_hover_forces()

	# 2. Apply player input thrust
	apply_thrust_forces()

	# 3. Air drag is handled automatically by RigidBody3D if configured
	# Or manually apply: apply_central_force(-linear_velocity * drag_coefficient)

func apply_hover_forces() -> void:
	for raycast in hover_raycasts:
		if not raycast.is_colliding():
			continue

		# Get distance to ground
		var ground_distance = raycast.global_position.distance_to(
			raycast.get_collision_point()
		)

		# Calculate spring force (Hooke's Law: F = -kx)
		var height_error = hover_height - ground_distance
		var spring_force = height_error * hover_force

		# Calculate damping force (opposes vertical velocity)
		# This prevents bouncing/oscillation
		var damping_force = -linear_velocity.y * hover_damping

		# Total upward force at this point
		var total_force = spring_force + damping_force

		# Apply force at raycast position (creates realistic tilting)
		var force_position = raycast.global_position - global_position
		apply_force(Vector3(0, total_force, 0), force_position)

func apply_thrust_forces() -> void:
	var input = Vector3.ZERO

	# Get input
	input.z = Input.get_axis("move_forward", "move_back")
	input.x = Input.get_axis("move_right", "move_left")
	input.y = Input.get_axis("move_up", "move_down")

	# Transform to world space based on drone orientation
	var thrust_direction = global_transform.basis * input.normalized()

	# Calculate thrust magnitude per axis
	var thrust = Vector3(
		thrust_direction.x * strafe_thrust,
		thrust_direction.y * upward_thrust,
		thrust_direction.z * forward_thrust
	)

	# Apply thrust force at center of mass
	apply_central_force(thrust)
```

### Why This Works (Real Physics)

1. **Gravity:** Applied automatically by physics engine to all `RigidBody3D` nodes (9.8 m/s² downward)

2. **Hover Force:** Real spring force applied at raycast points
   - When drone is below target height: `height_error > 0` → force pushes up
   - When drone is above target height: `height_error < 0` → force pulls down
   - **This is a real force countering gravity**, not a fake offset

3. **Damping:** Opposes vertical velocity to prevent bouncing
   - PD controller (Proportional-Derivative)
   - P term: `height_error * hover_force` (position correction)
   - D term: `-linear_velocity.y * hover_damping` (velocity damping)

4. **Thrust:** Real forces applied based on player input
   - `apply_central_force()`: force at center of mass (no torque)
   - `apply_force(force, position)`: force at specific point (creates torque/tilt)

5. **Momentum:** Automatically handled by physics engine
   - F = ma → heavier drones accelerate slower
   - Velocity persists until forces change it
   - Smooth acceleration/deceleration from force integration

## Comparison: CharacterBody3D vs RigidBody3D

| Aspect | CharacterBody3D (Current) | RigidBody3D (Recommended) |
|--------|---------------------------|---------------------------|
| **Physics Type** | Kinematic (manual) | Dynamic (engine-controlled) |
| **Gravity** | Manual `velocity.y -= GRAVITY * delta` | Automatic world force |
| **Hover** | Fake velocity offset | Real spring forces |
| **Momentum** | Simulated via drag calculation | Natural from mass + forces |
| **Collisions** | Slide only (kinematic) | Bounce, friction, realistic |
| **Feel** | Can be jerky | Smooth, realistic |
| **Forces** | No real forces | True F = ma physics |
| **Complexity** | High (manual everything) | Low (engine handles it) |

## Migration Path

### Step 1: Convert Base Drone to RigidBody3D

**File:** `scenes/drones/base_drone.tscn`

Change root node from `CharacterBody3D` to `RigidBody3D`:
```
[node name="BaseDrone" type="RigidBody3D"]
script = ExtResource("1_physics")
mass = 800.0
continuous_cd = true
can_sleep = false
```

### Step 2: Create New Physics Script

**File:** `src/components/hover_physics.gd`

Replace manual velocity manipulation with force-based physics (see code example above).

### Step 3: Update DroneStats for Force-Based Physics

**File:** `src/resources/drone_stats.gd`

Update parameters:
- Replace `acceleration` with `thrust_force` (Newtons)
- Add `hover_force` and `hover_damping` per drone type
- Keep `mass` (more important now - directly affects acceleration via F=ma)

### Step 4: Test and Tune

Parameters to tune for "gentle hover" feel:
- **`hover_force`**: 30-60 N/m (spring stiffness)
- **`hover_damping`**: 8-15 N·s/m (damping coefficient)
- **`mass`**: 600-1000 kg (lighter = more responsive)
- **`hover_height`**: 2-4 m (comfortable flight altitude)

## Known Issues and Solutions

### Issue 1: apply_force() at Position Causes Spinning

**Problem:** Using `apply_force(force, position)` in `_physics_process` can cause uncontrolled angular velocity buildup.

**Solution:**
```gdscript
# Instead of:
apply_force(Vector3.UP * force, hover_point_position)

# Use:
apply_central_force(Vector3.UP * force)
# AND
apply_torque((hover_point_position - center_of_mass).cross(Vector3.UP * force))
```

Or simply use `apply_central_force()` if you don't need realistic tilting.

### Issue 2: Drone Bounces When Hovering

**Problem:** Insufficient damping causes spring to oscillate.

**Solution:** Increase `hover_damping` to 10-20. The damping term `-linear_velocity.y * hover_damping` should be strong enough to quickly dissipate oscillations.

### Issue 3: Feels Too Floaty/Unresponsive

**Problem:** Mass too high or thrust too low.

**Solution:**
- Decrease `mass` (try 500-700 kg)
- Increase thrust forces (try 50-80 N)
- Decrease `hover_damping` slightly (more responsive, but may bounce)

## Example Implementation: Complete Hover Drone

```gdscript
extends RigidBody3D
class_name RealHoverDrone

## Hover System (Spring-Based)
@export var hover_height: float = 3.0  # meters above ground
@export var hover_spring_strength: float = 40.0  # N/m
@export var hover_damping: float = 12.0  # N·s/m
@export var num_hover_points: int = 4  # 4-point suspension

## Movement Forces
@export var thrust_force: float = 60.0  # Forward/backward thrust (N)
@export var strafe_force: float = 40.0  # Left/right thrust (N)
@export var climb_force: float = 25.0  # Up/down thrust (N)

## Physics Properties
@export var drag_coefficient: float = 0.3  # Air resistance
@export var angular_drag: float = 5.0  # Rotation resistance

var hover_raycasts: Array[RayCast3D] = []

func _ready() -> void:
	# Configure RigidBody
	mass = 800.0
	gravity_scale = 1.0  # Full gravity
	continuous_cd = true  # Prevent tunneling at high speeds
	can_sleep = false  # Always active
	linear_damp = drag_coefficient
	angular_damp = angular_drag

	# Create hover suspension raycasts
	setup_hover_raycasts()

func setup_hover_raycasts() -> void:
	# 4 hover engines at corners
	var radius = 1.0  # Distance from center
	var positions = [
		Vector3(-radius, 0, -radius),
		Vector3(radius, 0, -radius),
		Vector3(-radius, 0, radius),
		Vector3(radius, 0, radius)
	]

	for pos in positions:
		var raycast = RayCast3D.new()
		raycast.position = pos
		raycast.target_position = Vector3(0, -hover_height * 2, 0)
		raycast.enabled = true
		raycast.collision_mask = 1  # Collide with world geometry
		add_child(raycast)
		hover_raycasts.append(raycast)

func _physics_process(delta: float) -> void:
	# Real physics: apply forces, engine calculates motion
	apply_hover_suspension()
	apply_player_input_forces()

func apply_hover_suspension() -> void:
	"""
	Real spring-damper suspension system.
	Each hover engine acts as an independent spring-damper
	pushing against the ground to maintain altitude.
	"""
	for raycast in hover_raycasts:
		raycast.force_raycast_update()

		if not raycast.is_colliding():
			# No ground nearby, no hover force
			continue

		# Measure distance to ground
		var collision_point = raycast.get_collision_point()
		var ground_distance = raycast.global_position.distance_to(collision_point)

		# Spring force: F = k * (target - current)
		var compression = hover_height - ground_distance
		var spring_force = compression * hover_spring_strength

		# Damper force: F = -c * velocity (opposes motion)
		var damper_force = -linear_velocity.y * hover_damping

		# Total upward force at this hover engine
		var total_force = spring_force + damper_force

		# Apply force at hover engine position (creates realistic tilting)
		var force_world = Vector3(0, total_force, 0)
		var force_offset = raycast.global_position - global_position

		# Use apply_central_force to avoid spinning issues
		# (simplified - no torque, but stable)
		apply_central_force(force_world / num_hover_points)

func apply_player_input_forces() -> void:
	"""
	Player input translates to thrust forces.
	Not instant velocity - real forces that accelerate the drone.
	"""
	var input_dir = Vector3.ZERO

	# Get input axes
	input_dir.z = Input.get_axis("move_forward", "move_back")
	input_dir.x = Input.get_axis("move_right", "move_left")
	input_dir.y = Input.get_axis("move_up", "move_down")

	# Transform to world space based on drone orientation
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	var up = Vector3.UP  # Vertical thrust always world-up

	# Calculate thrust vector
	var thrust = Vector3.ZERO
	thrust += forward * input_dir.z * thrust_force
	thrust += right * input_dir.x * strafe_force
	thrust += up * input_dir.y * climb_force

	# Apply thrust at center of mass
	apply_central_force(thrust)

func get_altitude() -> float:
	"""Returns average altitude above ground from all hover raycasts"""
	var total_distance = 0.0
	var valid_casts = 0

	for raycast in hover_raycasts:
		if raycast.is_colliding():
			var ground_distance = raycast.global_position.distance_to(
				raycast.get_collision_point()
			)
			total_distance += ground_distance
			valid_casts += 1

	if valid_casts > 0:
		return total_distance / valid_casts
	else:
		return 0.0  # Not above ground
```

## Tuning Guide for "Gentle Hover" Feel

Based on real spring-damper physics principles:

### Target Feel: Smooth, Floaty, Gentle
```gdscript
mass = 700.0                    # Light (800-1000 feels heavier)
hover_spring_strength = 35.0    # Gentle spring (40-60 is stiffer)
hover_damping = 15.0            # Heavy damping (prevents bounce)
thrust_force = 45.0             # Moderate thrust
linear_damp = 0.2               # Low air drag (slides more)
```

### Target Feel: Responsive, Snappy, Arcade
```gdscript
mass = 500.0                    # Very light
hover_spring_strength = 60.0    # Stiff spring
hover_damping = 8.0             # Light damping (more bounce)
thrust_force = 80.0             # High thrust
linear_damp = 0.5               # High drag (stops quickly)
```

### Testing Checklist
- [ ] Drone gently rises to hover height (not instant snap)
- [ ] Small oscillation/bob when hovering is acceptable (realistic)
- [ ] Drone smoothly accelerates when thrust applied (not instant)
- [ ] Drone gradually slows when thrust released (not instant stop)
- [ ] Feels like it has weight and momentum
- [ ] Tilts realistically when moving (if multi-point suspension)
- [ ] Can come to complete stable hover
- [ ] Responsive enough for combat/gameplay

## References and Resources

### Official Documentation
- **Godot RigidBody3D Docs:** https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html
- **Using Jolt Physics in Godot 4.4:** https://docs.godotengine.org/en/latest/tutorials/physics/using_jolt_physics.html
- **Godot Jolt GitHub:** https://github.com/godot-jolt/godot-jolt

### Community Resources
- **Godot Easy Vehicle Physics (Raycast System):** https://github.com/DAShoe1/Godot-Easy-Vehicle-Physics
- **GDCustomRaycastVehicle:** https://github.com/Tobalation/GDCustomRaycastVehicle
- **Floating Capsule Method:** Discussed in Godot forums as standard approach for hover mechanics

### Physics Principles
- **Hooke's Law (Springs):** F = -kx (force proportional to displacement)
- **Damping Force:** F = -cv (force proportional to velocity)
- **PD Controller:** Combined spring (P) + damper (D) = stable hover
- **Newton's Second Law:** F = ma (force creates acceleration based on mass)

## Conclusion

**Current implementation uses CharacterBody3D with manual velocity manipulation** - this is NOT real physics. It's a kinematic approximation that can feel jerky.

**Recommended approach: RigidBody3D with spring-based hover suspension** - this provides:
1. ✅ Real gravity affecting all bodies
2. ✅ Real upward forces countering gravity (spring forces)
3. ✅ Natural momentum from mass and force integration
4. ✅ Smooth, gentle hover feel when tuned correctly
5. ✅ Industry-standard approach used in professional games

**Next Steps:**
1. Enable Jolt Physics in project settings (better performance)
2. Convert base_drone.tscn to RigidBody3D
3. Implement hover_physics.gd with spring suspension system
4. Test and tune parameters for desired feel
5. Update all drone scenes to use new physics

**This is a complete architectural change** from kinematic to dynamic physics, but it will provide the "real physics" the project requires.
