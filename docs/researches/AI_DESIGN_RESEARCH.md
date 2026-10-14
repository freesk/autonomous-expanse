# DroneWorld AI Design Document

## Comprehensive AI Architecture for Jolt Physics-Based Hover Drones

**Version:** 1.0
**Date:** 2026-02-28
**Engine:** Godot 4.4+ with Jolt Physics
**Game Type:** 3D Hover Drone Combat/Exploration Sandbox

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Jolt Physics Considerations](#jolt-physics-considerations)
3. [AI Architecture Overview](#ai-architecture-overview)
4. [State Machine Implementation](#state-machine-implementation)
5. [Detection & Perception System](#detection--perception-system)
6. [Combat AI Behaviors](#combat-ai-behaviors)
7. [Vertical Navigation & Altitude Management](#vertical-navigation--altitude-management)
8. [Navigation & Pathfinding](#navigation--pathfinding)
9. [Targeting & Prediction System](#targeting--prediction-system)
10. [Performance Optimization](#performance-optimization)
11. [Implementation Roadmap](#implementation-roadmap)
12. [Code Examples](#code-examples)
13. [Testing & Validation](#testing--validation)

---

## Executive Summary

This document provides a comprehensive AI design for DroneWorld, a 3D hover drone game using **Jolt Physics** for realistic force-based physics simulation. The AI system is designed to:

- **Leverage Jolt Physics**: Use RigidBody3D with real forces (no kinematic shortcuts)
- **Maintain Simplicity**: Simple, learnable behaviors aligned with AI_SPEC.md targets
- **Optimize Performance**: LOD system supporting 10 combat + 20 total active enemies
- **Modular Architecture**: Component-based design integrating with existing InputController interface
- **Predictable & Fair**: Clear visual indicators, fair combat, player always has escape options

**Key Design Principle**: The AI uses the **same physics, weapons, and energy systems** as the player, controlled through the existing `InputController` API. This ensures consistency, balance, and realism.

---

## Jolt Physics Considerations

### Why Jolt Physics Matters for AI

**Jolt Physics** is a high-performance, multi-core physics engine integrated into Godot 4.4+. It offers:

1. **Better Performance**: 2-4x faster than Godot Physics for complex simulations
2. **Stable Simulation**: More predictable behavior for force-based hover systems
3. **Multi-core Support**: Distributes physics across CPU cores
4. **Drop-in Replacement**: Same API as Godot Physics (RigidBody3D, Area3D, etc.)

### Critical Jolt-Specific Constraints

#### 1. **Force-Based Movement Only**

Drones use **real RigidBody3D physics** with applied forces, NOT kinematic movement:

```gdscript
# CORRECT: Apply forces via HoverPhysics
hover_physics.apply_central_force(thrust_vector * thrust_force)
hover_physics.apply_torque(turn_vector * turn_torque)

# WRONG: Direct velocity manipulation (breaks physics simulation)
hover_physics.linear_velocity = target_velocity  # DON'T DO THIS
```

**Implication for AI**: AI cannot instantly change direction or velocity. All movement has:

- **Acceleration delays** (force / mass = acceleration)
- **Momentum** (velocity persists until countered by opposing force)
- **Energy constraints** (boost/jump drain unified energy pool)

#### 2. **Scale & Mass Considerations**

Jolt performs best with objects **0.1 to 10 meters in size**. DroneWorld drones are:

- **Size**: ~2-4 meters (well within optimal range)
- **Mass**: 800-2000 kg (realistic hover vehicle mass)
- **Forces**: 8,000-25,000 N (tuned for mass and gravity)

**AI Design Impact**: Movement inputs must account for drone mass when predicting position/velocity.

#### 3. **Multi-Core Physics Processing**

Jolt distributes physics across CPU cores automatically. This means:

- **Parallel AI Updates**: Multiple drones can compute AI simultaneously
- **Physics Batching**: RigidBody3D updates happen in parallel
- **Cache-Friendly**: AI should minimize per-frame physics queries (raycasts, shape queries)

**Optimization Strategy**: Use **spatial partitioning** and **LOD** to limit active AI count, not physics performance.

#### 4. **Area3D Detection Limitations**

Jolt's Area3D does **not detect StaticBody3D overlaps by default** (for performance). For AI:

- Use **Raycasts** for player detection (line-of-sight required per spec)
- Use **Area3D** only for trigger zones (no overlap with static geometry needed)
- Use **NavigationAgent3D** for obstacle avoidance (separate from physics)

#### 5. **Contact Reporting Performance**

Jolt's contact reporting for kinematic bodies is expensive. Since drones use **RigidBody3D** (not kinematic), this is not an issue, but:

- Avoid switching between RigidBody3D and kinematic modes during gameplay
- All drones remain RigidBody3D at all times

### Hover Physics Spring-Damper System

The drone hover system uses **real spring-damper suspension** at 4 hover points:

```
For each hover point:
1. Raycast down to ground (max 10m)
2. Compression = (hover_height - ground_distance)
3. Spring Force = compression * spring_strength (8000 N/m)
4. Damping Force = -vertical_velocity * damping (2000 N·s/m)
5. Apply combined force upward
```

**AI Implications**:

- Drones naturally **hover at 3m altitude** without AI intervention
- AI only needs to apply **horizontal thrust** and **vertical climb/descent forces**
- Hovering consumes **no energy** (passive spring forces)
- Jumping/boosting are **separate impulse forces** (consume energy)

**Key Insight**: AI does NOT need to manage altitude stabilization—the physics system handles it automatically via spring-damper suspension.

---

## AI Architecture Overview

### Component-Based Design

The AI system integrates with DroneWorld's existing component architecture:

```
EnemyDrone (RigidBody3D)
├── HoverPhysics            # Physics simulation (existing)
├── InputController         # Input abstraction (existing)
│   └── control_mode = 1    # 0 = PLAYER, 1 = AI
├── WeaponController        # Weapon management (existing)
├── HealthSystem            # HP/shields (existing)
├── EnergySystem            # Energy pool (existing)
├── PatrolNavigation        # Simple patrol waypoints (existing)
└── CombatAI                # NEW: State machine + combat behaviors
    ├── StateMachine        # PATROL → ALERT → COMBAT → RETREAT
    ├── DetectionSystem     # Player detection (raycasts, FOV)
    ├── CombatBehavior      # Attack patterns, movement tactics
    └── TargetingSystem     # Predictive aiming, lead shots
```

**Design Philosophy**:

- **Additive, Not Replacive**: New `CombatAI` component works alongside existing systems
- **InputController Interface**: AI sets inputs (`ai_move_input`, `ai_climb_input`, `ai_fire_primary`) just like the player
- **Shared Resources**: AI uses same weapons, energy, health as player (balance enforced by design)

### Data Flow

```
CombatAI (State Machine)
    ↓
[State Logic] → Compute desired movement/actions
    ↓
InputController.set_ai_movement(move: Vector2, climb: float)
InputController.set_ai_fire(primary: bool, secondary: bool)
InputController.set_ai_boost(enabled: bool)
WeaponController.set_aim_target(target_pos: Vector3)
    ↓
HoverPhysics.apply_forces()
WeaponController.handle_weapon_input()
    ↓
Jolt Physics Simulation
    ↓
EnergySystem.drain() / HealthSystem.take_damage()
```

**Key Point**: AI never directly manipulates physics—it only sets **inputs** that get processed by the same systems the player uses.

---

## State Machine Implementation

### State Architecture: Simple Enum-Based

Per research and AI_SPEC.md, we use a **single-variable enum state machine** for simplicity:

```gdscript
enum State {
    PATROL,   # Follow waypoints, scan for player
    ALERT,    # Lock on, 1-second warning
    COMBAT,   # Chase, fire, evade
    RETREAT   # Flee when health < 25%
}

var current_state: State = State.PATROL
var state_timer: float = 0.0
```

**Why Not Node-Based States?**

- **Simplicity**: Enemy behaviors are straightforward (per spec: "Simple AI, predictable patterns")
- **Performance**: No node tree overhead, single script per enemy
- **Prototyping Speed**: Faster iteration, less boilerplate
- **Codebase Consistency**: Aligns with existing drone scripts (single GDScript per drone type)

**When to Refactor to Node-Based**:

- If states exceed ~200 lines each
- If multiple enemy types share identical state logic (extract to reusable State nodes)
- If designers need visual state editing in scene tree

### State Transitions (Per AI_SPEC.md)

```
PATROL → ALERT:
  - Player in detection range AND line-of-sight
  - Player fires weapon (alert all enemies in 300m)

ALERT → COMBAT:
  - 1 second elapsed (state_timer >= 1.0)
  - Player attacks (instant transition)

COMBAT → RETREAT:
  - Health < 25%

COMBAT → PATROL:
  - Player out of combat range for 10 seconds
  - Player destroyed

RETREAT → PATROL:
  - Reaches safe distance (300m from player)

RETREAT → COMBAT:
  - Cornered (no retreat path) OR health recovered (future)
```

### State Update Logic

```gdscript
func _physics_process(delta: float) -> void:
    state_timer += delta

    match current_state:
        State.PATROL:
            _update_patrol(delta)
        State.ALERT:
            _update_alert(delta)
        State.COMBAT:
            _update_combat(delta)
        State.RETREAT:
            _update_retreat(delta)
```

**Best Practice**: Use `_physics_process()` for AI logic (matches physics tick rate, ensures deterministic behavior with Jolt).

### State-Specific Data

```gdscript
# PATROL state
var patrol_waypoints: Array[Vector3] = []
var current_waypoint: int = 0

# ALERT state
var alert_target: Node3D = null  # Player drone being locked onto

# COMBAT state
var combat_behavior: CombatPattern = CombatPattern.CHASE
var last_player_position: Vector3
var time_since_player_visible: float = 0.0

# RETREAT state
var retreat_direction: Vector3
var retreat_boost_used: bool = false
```

---

## Detection & Perception System

### Core Requirements (from AI_SPEC.md)

**Detection Parameters by Enemy Type**:
| Enemy Type | Range | FOV | Speed |
|------------|-------|-----|-------|
| Scout | 200m | 180°| Instant |
| Enforcer | 150m | 120°| Instant |
| Heavy | 100m | 90° | Instant |
| Interceptor| 300m | 360°| Instant |

**Detection Modifiers**:

- Stealth Cloak (Explorer): Not detected
- Boost: +50m detection range
- Firing Weapons: +100m detection range (alerts nearby enemies)
- Fog/Rain: -25% range
- Night: -15% range
- Behind Obstacles: Not detected (LOS required)

### Implementation: Raycast-Based Detection

**Why Raycasts Over Area3D?**

1. **Line-of-Sight Requirement**: Per spec, detection needs obstacle checking
2. **Jolt Physics Compatibility**: Area3D has limitations with StaticBody3D
3. **Predictable Performance**: Single raycast per frame vs continuous overlap queries
4. **Field-of-View Control**: Easy to compute FOV cone with dot product

**Detection Pseudocode**:

```gdscript
func detect_player() -> bool:
    var player = _get_player_drone()
    if not player:
        return false

    var to_player = player.global_position - global_position
    var distance = to_player.length()

    # 1. Range check (with modifiers)
    var detection_range = base_detection_range
    if player.is_boosting:
        detection_range += 50.0
    if player.is_firing:
        detection_range += 100.0
    if world_manager.is_foggy:
        detection_range *= 0.75

    if distance > detection_range:
        return false

    # 2. FOV check (dot product)
    var forward = -global_transform.basis.z  # Forward direction
    var direction_to_player = to_player.normalized()
    var dot = forward.dot(direction_to_player)
    var fov_threshold = cos(deg_to_rad(field_of_view / 2.0))

    if dot < fov_threshold:
        return false

    # 3. Line-of-sight raycast
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        global_position,
        player.global_position
    )
    query.exclude = [self]  # Don't hit self
    query.collision_mask = collision_layer_world | collision_layer_drones

    var result = space_state.intersect_ray(query)
    if result and result.collider == player:
        return true  # Clear line of sight

    return false  # Blocked by obstacle
```

**Performance Optimization**:

- **Detection Frequency**: Check every 0.1s in PATROL, every frame in COMBAT
- **Early Exit**: Return false as soon as any check fails (most frames skip raycast)
- **Collision Mask**: Only check relevant layers (world geometry + drones)

### Alert Broadcast System

Per spec: "Firing Weapons: +100m detection range (all nearby enemies alerted)"

```gdscript
# In CombatAI component
func alert_nearby_allies(alert_position: Vector3, alert_range: float = 300.0):
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if enemy == self:
            continue

        var distance = enemy.global_position.distance_to(alert_position)
        if distance <= alert_range:
            enemy.on_ally_alert(alert_position)

# Called by other enemies when they detect player
func on_ally_alert(threat_position: Vector3):
    if current_state == State.PATROL:
        alert_target = _get_player_drone()
        transition_to_state(State.ALERT)
```

**Design Note**: Use Godot's **group system** for efficient enemy lookups (avoid `get_tree()` queries in hot loops).

---

## Combat AI Behaviors

### Combat Patterns (from AI_SPEC.md)

**Movement Patterns**:

1. **CHASE**: Fly directly toward player, maintain optimal weapon range
2. **STRAFE**: Circle player while firing, alternate left/right
3. **EVASIVE**: Random direction changes when player aims/fires
4. **FLEE**: Boost away from player (RETREAT state)

### Chase Behavior (Most Common)

```gdscript
func _update_combat_chase(delta: float):
    var player = _get_player_from_reference()
    if not player:
        return

    # 1. Compute direction to player
    var to_player = player.global_position - global_position
    var distance = to_player.length()
    var direction = to_player.normalized()

    # 2. Determine optimal range based on weapon type
    var optimal_range = weapon_controller.get_optimal_range()  # e.g., 50m
    var range_error = distance - optimal_range

    # 3. Approach or retreat to maintain range
    var move_input = Vector2.ZERO
    if abs(range_error) > 10.0:  # Dead zone to prevent jittering
        if range_error > 0:
            # Too far, move toward player
            move_input = Vector2(direction.x, direction.z)
        else:
            # Too close, back away
            move_input = -Vector2(direction.x, direction.z)

    # 4. Normalize and apply to InputController
    if move_input.length() > 1.0:
        move_input = move_input.normalized()

    input_controller.set_ai_movement(move_input, 0.0)  # Horizontal only

    # 5. Fire weapons if in range
    if distance <= weapon_controller.get_max_range():
        input_controller.set_ai_fire(true, false)  # Primary weapon
```

**Key Insights**:

- **Optimal Range**: Different weapons need different distances (heavy = long, light = close)
- **Dead Zone**: Prevents AI from oscillating around target range
- **Horizontal Movement**: Vertical handled separately (or by spring-damper auto-hover)

### Strafe Behavior (Advanced Enemies)

```gdscript
var strafe_direction: int = 1  # 1 = right, -1 = left
var strafe_switch_timer: float = 0.0

func _update_combat_strafe(delta: float):
    var player = _get_player_from_reference()
    if not player:
        return

    # 1. Circle around player
    var to_player = player.global_position - global_position
    var forward = to_player.normalized()
    var right = forward.cross(Vector3.UP).normalized()

    # 2. Alternate strafe direction every 2 seconds
    strafe_switch_timer += delta
    if strafe_switch_timer >= 2.0:
        strafe_direction *= -1
        strafe_switch_timer = 0.0

    # 3. Combine forward movement + perpendicular strafe
    var move_vector = forward * 0.5 + right * strafe_direction
    var move_input = Vector2(move_vector.x, move_vector.z).normalized()

    input_controller.set_ai_movement(move_input, 0.0)
    input_controller.set_ai_fire(true, false)
```

**When to Use**: Enforcer drones, Heavy drones (per AI_SPEC.md attack patterns)

### Evasive Behavior (Reactive)

```gdscript
var evasive_timer: float = 0.0
var evasive_direction: Vector2 = Vector2.ZERO

func _update_combat_evasive(delta: float):
    # Trigger on player firing (20% chance per spec)
    if player_fired_this_frame and randf() < 0.2:
        # Random perpendicular direction
        var angle = randf_range(0, TAU)
        evasive_direction = Vector2(cos(angle), sin(angle))
        evasive_timer = 0.5  # Evade for 0.5 seconds

    if evasive_timer > 0.0:
        evasive_timer -= delta
        input_controller.set_ai_movement(evasive_direction, 0.0)
        # Don't fire during evasion (focus on dodging)
    else:
        # Return to primary behavior (chase/strafe)
        _update_combat_chase(delta)
```

**Integration Point**: Requires detecting when player fires (subscribe to player weapon signals or track weapon effects).

### Retreat Behavior (RETREAT State)

```gdscript
func _update_retreat(delta: float):
    var player = _get_player_from_reference()
    if not player:
        transition_to_state(State.PATROL)
        return

    # 1. Flee directly away from player
    var away_from_player = (global_position - player.global_position).normalized()
    var move_input = Vector2(away_from_player.x, away_from_player.z)

    # 2. Use boost if available (one-time per retreat)
    if not retreat_boost_used and energy_system.current_energy > 20.0:
        input_controller.set_ai_boost(true)
        retreat_boost_used = true

    # 3. Stop firing (focus on escape)
    input_controller.set_ai_fire(false, false)

    # 4. Check if reached safe distance
    var distance = global_position.distance_to(player.global_position)
    if distance >= 300.0:
        transition_to_state(State.PATROL)
        retreat_boost_used = false

    input_controller.set_ai_movement(move_input, 0.0)
```

**Spec Compliance**: "Speed boost", "No attacking", "300m safe distance"

### Behavior Selection Logic

```gdscript
enum CombatPattern { CHASE, STRAFE, EVASIVE }

func _select_combat_behavior() -> CombatPattern:
    match enemy_type:
        EnemyType.SCOUT:
            return CombatPattern.STRAFE  # "Strafe while shooting" per spec
        EnemyType.ENFORCER:
            # Mix of chase and strafe (60% chase, 40% strafe)
            return CombatPattern.CHASE if randf() < 0.6 else CombatPattern.STRAFE
        EnemyType.HEAVY:
            return CombatPattern.CHASE  # "Stay stationary or slow" = chase to optimal range then stop
        EnemyType.INTERCEPTOR:
            return CombatPattern.CHASE  # Fast pursuit

    return CombatPattern.CHASE  # Default
```

**Dynamic Switching**: Re-evaluate behavior every 3-5 seconds for variety.

---

## Vertical Navigation & Altitude Management

### Why Vertical Navigation Matters

In 3D aerial combat, **vertical space is a critical tactical dimension**. Unlike ground-based AI that operates on a 2D plane with occasional jumps, hover drones must make constant altitude decisions that affect:

1. **Tactical Positioning**: High ground advantage, better visibility and firing angles
2. **Threat Management**: Climbing to escape, descending for cover
3. **Combat Effectiveness**: Optimal weapon ranges vary by altitude/angle
4. **Energy Management**: Balancing climb energy costs with tactical benefits

**Design Philosophy**: AI should use vertical space **purposefully**, not just hover at player's altitude. Vertical maneuvers should feel intentional and tactical, not random. Hover drones maintain position using thrust, so altitude changes are deliberate tactical decisions, not momentum-based maneuvers.

---

### Altitude Decision System: Utility-Based Evaluation

Since DroneWorld uses physics-based movement (not traditional 3D pathfinding), altitude control is **input-driven** via `input_controller.set_ai_movement(move_h, climb_input)`. The AI evaluates vertical positioning using a **utility scoring system**.

#### Climb Input Calculation

```gdscript
# In CombatAI component
var desired_altitude: float = 0.0  # Target altitude above ground
var altitude_tolerance: float = 5.0  # Dead zone to prevent oscillation

func _compute_climb_input(delta: float) -> float:
    # 1. Get current altitude (raycast down or use spring-damper hover height)
    var current_altitude = _get_altitude_above_ground()

    # 2. Determine desired altitude based on state and tactics
    desired_altitude = _evaluate_tactical_altitude()

    # 3. Compute error
    var altitude_error = desired_altitude - current_altitude

    # 4. Dead zone (prevent jittering)
    if abs(altitude_error) < altitude_tolerance:
        return 0.0

    # 5. Proportional control with clamping
    var climb_input = clamp(altitude_error / 20.0, -1.0, 1.0)

    return climb_input
```

#### Tactical Altitude Evaluation

```gdscript
func _evaluate_tactical_altitude() -> float:
    var player = _get_player_drone()
    if not player:
        return 3.0  # Default hover height

    var player_altitude = player.global_position.y
    var current_altitude = global_position.y
    var altitude_difference = current_altitude - player_altitude
    var distance_to_player = global_position.distance_to(player.global_position)

    # PATROL: Maintain default hover height
    if current_state == State.PATROL:
        return 3.0  # Spring-damper natural height

    # ALERT: Match player altitude (neutral positioning)
    if current_state == State.ALERT:
        return player_altitude

    # COMBAT: Tactical altitude based on enemy type and situation
    if current_state == State.COMBAT:
        return _compute_combat_altitude(player, altitude_difference, distance_to_player)

    # RETREAT: Climb high for escape (harder to hit, more escape options)
    if current_state == State.RETREAT:
        return player_altitude + 30.0  # 30m above player

    return current_altitude  # Maintain current
```

#### Combat Altitude Strategy (Per Enemy Type)

```gdscript
func _compute_combat_altitude(player: Node3D, alt_diff: float, distance: float) -> float:
    var player_alt = player.global_position.y

    match enemy_type:
        EnemyType.SCOUT:
            # Agile fighter: Maintain altitude advantage for better visibility
            return player_alt + 15.0

        EnemyType.ENFORCER:
            # Balanced: Maintain slight altitude advantage
            return player_alt + 10.0

        EnemyType.HEAVY:
            # Stable platform: Match altitude for optimal firing solution
            return player_alt + 5.0

        EnemyType.INTERCEPTOR:
            # Fast pursuit: High altitude advantage for better visibility
            return player_alt + 20.0

    return player_alt  # Fallback: match player
```

---

### Energy State Management: Altitude as Advantage

#### Energy Advantage Concept

In hover drone combat, **altitude provides tactical advantages**:

- Better visibility and firing angles
- Harder target for ground-based threats
- More escape options (can descend to cover or climb to extend range)
- Positional control (dictate engagement distance)

**AI Implementation**: Track relative tactical state and use it for decision-making.

```gdscript
var energy_state: float = 0.0  # -1.0 (disadvantage) to 1.0 (advantage)

func _compute_energy_state() -> float:
    var player = _get_player_drone()
    if not player:
        return 0.0

    # 1. Altitude advantage (tactical positioning)
    var altitude_diff = global_position.y - player.global_position.y
    var altitude_score = clamp(altitude_diff / 50.0, -1.0, 1.0)  # ±50m = full score

    # 2. Speed advantage (maneuverability)
    var my_speed = hover_physics.linear_velocity.length()
    var player_speed = player.linear_velocity.length()
    var speed_diff = my_speed - player_speed
    var speed_score = clamp(speed_diff / 30.0, -1.0, 1.0)  # ±30 m/s = full score

    # 3. Combined energy state (weighted: altitude 60%, speed 40%)
    energy_state = altitude_score * 0.6 + speed_score * 0.4

    return energy_state
```

---

### Vertical Evasion Tactics

#### When to Evade Vertically

Vertical evasion should trigger when:

- Player is firing at AI (reactive dodge)
- AI health < 50% (add unpredictability)
- Energy state is disadvantaged (break away vertically)

```gdscript
var evasion_vertical_timer: float = 0.0
var evasion_vertical_direction: float = 0.0  # -1.0 = descend, 1.0 = climb

func _trigger_vertical_evasion():
    # Random choice: climb or descend
    evasion_vertical_direction = 1.0 if randf() < 0.5 else -1.0

    # Prefer descending if high, climbing if low (stay in playable space)
    var altitude = global_position.y
    if altitude > 80.0:
        evasion_vertical_direction = -1.0  # Descend
    elif altitude < 10.0:
        evasion_vertical_direction = 1.0  # Climb

    evasion_vertical_timer = randf_range(1.0, 2.0)  # Evade for 1-2 seconds

func _update_vertical_evasion(delta: float):
    if evasion_vertical_timer > 0.0:
        evasion_vertical_timer -= delta

        # Apply evasive climb/descend input
        var climb_input = evasion_vertical_direction * 0.8  # 80% intensity
        input_controller.set_ai_movement(
            _compute_horizontal_movement(),  # Still move horizontally
            climb_input  # Add vertical evasion
        )
    else:
        # Resume normal altitude control
        input_controller.set_ai_movement(
            _compute_horizontal_movement(),
            _compute_climb_input(delta)
        )
```

#### Vertical Wobble (Advanced)

For advanced enemies (Enforcer+), implement vertical wobble (slight altitude oscillation to make targeting harder):

```gdscript
var wobble_timer: float = 0.0

func _update_vertical_wobble(delta: float):
    wobble_timer += delta

    # Sine wave wobble with 2-second period
    var wobble_input = sin(wobble_timer * PI) * 0.3  # ±30% climb input

    var base_climb = _compute_climb_input(delta)
    var final_climb = base_climb + wobble_input

    input_controller.set_ai_movement(_compute_horizontal_movement(), final_climb)
```

---

### Terrain Following & Obstacle Avoidance

#### Ground Clearance Check

The existing spring-damper system provides **passive terrain following** (hovers at 3m above ground). For active low-altitude flight:

```gdscript
var min_safe_altitude: float = 5.0  # Never go below 5m AGL

func _ensure_ground_clearance() -> float:
    # Raycast down to find ground
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        global_position,
        global_position + Vector3.DOWN * 100.0  # Check 100m down
    )
    query.collision_mask = collision_layer_world

    var result = space_state.intersect_ray(query)
    if result:
        var ground_distance = global_position.y - result.position.y

        # If too close to ground, force climb
        if ground_distance < min_safe_altitude:
            return 1.0  # Full climb input

    return 0.0  # No correction needed
```

#### Ceiling Avoidance

For indoor/cave environments or low-hanging obstacles:

```gdscript
var max_safe_altitude: float = 90.0  # Don't go above 90m (world ceiling)

func _ensure_ceiling_clearance() -> float:
    # Raycast up to find ceiling
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        global_position,
        global_position + Vector3.UP * 50.0  # Check 50m up
    )
    query.collision_mask = collision_layer_world

    var result = space_state.intersect_ray(query)
    if result:
        var ceiling_distance = result.position.y - global_position.y

        # If too close to ceiling, force descent
        if ceiling_distance < 10.0:
            return -1.0  # Full descent input

    # Also check absolute altitude limit
    if global_position.y > max_safe_altitude:
        return -0.5  # Gentle descent

    return 0.0  # No correction needed
```

#### Combined Vertical Obstacle Avoidance

```gdscript
func _compute_safe_climb_input(desired_climb: float) -> float:
    # Check ground/ceiling constraints
    var ground_correction = _ensure_ground_clearance()
    var ceiling_correction = _ensure_ceiling_clearance()

    # Override desired input if safety critical
    if ground_correction != 0.0:
        return ground_correction  # Priority: don't crash into ground
    if ceiling_correction != 0.0:
        return ceiling_correction

    return desired_climb  # Safe to use desired input
```

---

### Integration with Existing Combat Behaviors

#### Updated Chase Behavior (with Vertical)

```gdscript
func _update_combat_chase(delta: float):
    var player = _get_player_drone()
    if not player:
        return

    var to_player = player.global_position - global_position
    var distance = to_player.length()
    var direction = to_player.normalized()

    # Horizontal movement (existing)
    var optimal_range = 50.0
    var range_error = distance - optimal_range
    var move_input = Vector2.ZERO

    if abs(range_error) > 10.0:
        if range_error > 0:
            move_input = Vector2(direction.x, direction.z)
        else:
            move_input = -Vector2(direction.x, direction.z)

    if move_input.length() > 1.0:
        move_input = move_input.normalized()

    # NEW: Vertical movement (tactical altitude)
    var climb_input = _compute_climb_input(delta)
    climb_input = _compute_safe_climb_input(climb_input)  # Safety check

    input_controller.set_ai_movement(move_input, climb_input)

    # Fire if in range
    if distance <= weapon_controller.get_max_range():
        input_controller.set_ai_fire(true, false)
```

#### Updated Strafe Behavior (with Vertical)

```gdscript
func _update_combat_strafe(delta: float):
    var player = _get_player_drone()
    if not player:
        return

    # Horizontal strafe (existing)
    var to_player = player.global_position - global_position
    var forward = to_player.normalized()
    var right = forward.cross(Vector3.UP).normalized()

    strafe_switch_timer += delta
    if strafe_switch_timer >= 2.0:
        strafe_direction *= -1
        strafe_switch_timer = 0.0

    var move_vector = forward * 0.5 + right * strafe_direction
    var move_input = Vector2(move_vector.x, move_vector.z).normalized()

    # NEW: Vertical strafe (add vertical wobble for harder targeting)
    var vertical_wobble = sin(state_timer * 2.0) * 0.3  # Sine wave altitude oscillation
    var climb_input = _compute_climb_input(delta) + vertical_wobble
    climb_input = _compute_safe_climb_input(climb_input)

    input_controller.set_ai_movement(move_input, climb_input)
    input_controller.set_ai_fire(true, false)
```

---

### Performance Considerations

#### Vertical Raycast Optimization

- **Ground check**: Only cast down once per 0.2s (5 FPS) when altitude > 20m
- **Ceiling check**: Only cast up when altitude > 60m or in known indoor areas
- **LOD integration**: Distant enemies skip vertical safety checks (assume safe altitude)

```gdscript
var vertical_check_timer: float = 0.0
var vertical_check_interval: float = 0.2  # 5 FPS

func _should_check_vertical_clearance() -> bool:
    vertical_check_timer += get_physics_process_delta_time()
    if vertical_check_timer >= vertical_check_interval:
        vertical_check_timer = 0.0
        return true
    return false
```

---

### Testing Vertical Navigation

#### Test Scenarios

1. **Altitude Matching**: Spawn enemy, fly to different altitudes, verify enemy follows
2. **Altitude Advantage**: Engage Scout/Interceptor, observe them maintaining higher altitude
3. **Vertical Evasion**: Fire at enemy, verify it climbs or descends to evade
4. **Ground Collision**: Fly low over hills, verify enemies maintain clearance
5. **Energy Advantage**: Start at low altitude, watch enemy climb to gain advantage
6. **Retreat Climb**: Damage enemy to <25% health, verify it climbs while fleeing

#### Debug Visualization

```gdscript
func _draw_vertical_debug():
    if not OS.is_debug_build():
        return

    # Draw desired altitude plane
    var desired_pos = Vector3(global_position.x, desired_altitude, global_position.z)
    DebugDraw.draw_line(global_position, desired_pos, Color.CYAN)

    # Draw energy state indicator
    var energy_color = Color.GREEN if energy_state > 0 else Color.RED
    DebugDraw.draw_sphere(global_position + Vector3.UP * 10, 2.0, energy_color)

    # Draw vertical tactic label
    var tactic_name = VerticalTactic.keys()[vertical_tactic]
    DebugDraw.draw_text_3d(global_position + Vector3.UP * 8, tactic_name, Color.YELLOW)
```

---

## Navigation & Pathfinding

### Current System: NavigationAgent3D

The existing `patrol_navigation.gd` uses **NavigationAgent3D** for waypoint following and collision avoidance. This system is **compatible with Jolt Physics** (NavigationAgent is separate from physics engine).

**Strengths**:

- Automatic obstacle avoidance
- Smooth velocity computation
- Works with Godot's navigation mesh system

**Limitations for Combat**:

- Designed for ground-based agents (NavMesh is typically ground plane)
- 3D aerial navigation needs volumetric NavMesh (complex to author)
- Overhead for simple "fly toward player" behaviors

### Hybrid Approach: Direct Flight + NavAgent Fallback

**Recommendation**:

1. **PATROL State**: Use existing NavigationAgent3D for waypoint routes
2. **COMBAT State**: Direct vector-based movement (no pathfinding)
3. **Obstacle Avoidance**: Raycast-based simple avoidance (not NavAgent)

**Rationale**:

- Open-world aerial combat doesn't need complex pathfinding (few obstacles at flight altitude)
- Direct flight is faster and more responsive (critical for combat AI)
- Simple raycasts can handle occasional obstacles (buildings, cliffs)

### Simple Raycast Avoidance

```gdscript
func _compute_avoidance_vector(desired_direction: Vector3) -> Vector3:
    # Check for obstacles ahead
    var ray_length = 20.0  # Look 20m ahead
    var ray_target = global_position + desired_direction * ray_length

    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(global_position, ray_target)
    query.exclude = [self]
    query.collision_mask = collision_layer_world

    var result = space_state.intersect_ray(query)
    if result:
        # Obstacle detected, steer perpendicular
        var normal = result.normal
        var avoidance = desired_direction + normal * 2.0  # Bias away from obstacle
        return avoidance.normalized()

    return desired_direction  # No obstacle, continue as planned
```

**When to Use**:

- COMBAT state when chasing player through complex terrain
- RETREAT state when fleeing (panic mode, ignore obstacles per spec)

**Performance**: Single raycast per frame is negligible with Jolt's multi-core processing.

### NavigationAgent3D Best Practices (for PATROL)

```gdscript
# In PatrolNavigation component (existing)
func _physics_process(delta):
    if navigation_agent.is_navigation_finished():
        _advance_to_next_waypoint()
        return

    # Get next velocity from NavigationAgent
    var next_velocity = navigation_agent.get_next_path_position()
    var direction = (next_velocity - global_position).normalized()

    # Convert 3D direction to 2D input for InputController
    var move_input = Vector2(direction.x, direction.z)
    input_controller.set_ai_movement(move_input, direction.y)
```

**Key Point**: NavigationAgent computes **target velocity**, AI converts it to **input** for physics system (force-based movement).

---

## Targeting & Prediction System

### Challenge: Projectile-Based Weapons

Per AI_SPEC.md: "Enemies fire where player will be (simple prediction)"

**Why Prediction is Required**:

- Energy burst weapons are **projectile-based** (travel time)
- Player can move at high speed (boost, strafe)
- Without prediction, shots miss fast-moving targets

### Predictive Targeting Algorithm

```gdscript
func _compute_intercept_point(
    target_position: Vector3,
    target_velocity: Vector3,
    projectile_speed: float
) -> Vector3:
    # 1. Relative position
    var to_target = target_position - global_position

    # 2. Quadratic equation for intercept time
    # |target_pos + target_vel * t - shooter_pos| = projectile_speed * t
    var a = target_velocity.length_squared() - projectile_speed * projectile_speed
    var b = 2.0 * to_target.dot(target_velocity)
    var c = to_target.length_squared()

    # Solve: at^2 + bt + c = 0
    var discriminant = b * b - 4.0 * a * c
    if discriminant < 0:
        # No intercept possible (target too fast or outside range)
        return target_position  # Fall back to current position

    var t1 = (-b + sqrt(discriminant)) / (2.0 * a)
    var t2 = (-b - sqrt(discriminant)) / (2.0 * a)
    var t = min(t1, t2) if t1 > 0 and t2 > 0 else max(t1, t2)

    if t < 0:
        return target_position

    # 3. Predicted intercept point
    return target_position + target_velocity * t
```

**Source**: Standard intercept problem solution (used in real-time strategy games, space sims)

### Accuracy Modifiers (Per AI_SPEC.md)

| Enemy Type | Base Accuracy |
| ---------- | ------------- |
| Scout      | 60%           |
| Enforcer   | 70%           |
| Heavy      | 80%           |
| Turret     | 90%           |

**Implementation**:

```gdscript
func _apply_accuracy_spread(perfect_aim: Vector3, accuracy: float) -> Vector3:
    # accuracy = 0.6 to 0.9 (60% to 90%)
    # spread inversely proportional to accuracy
    var max_spread_degrees = (1.0 - accuracy) * 15.0  # 0-6 degrees

    # Random offset within cone
    var spread_angle = randf_range(-max_spread_degrees, max_spread_degrees)
    var spread_rotation = deg_to_rad(spread_angle)

    # Rotate aim vector by random amount (simplified for 2D horizontal plane)
    var horizontal_aim = Vector2(perfect_aim.x, perfect_aim.z)
    horizontal_aim = horizontal_aim.rotated(spread_rotation)

    return Vector3(horizontal_aim.x, perfect_aim.y, horizontal_aim.y)
```

### Complete Weapon Targeting Flow

```gdscript
func _update_weapon_targeting():
    var player = _get_player_from_reference()
    if not player:
        return

    # 1. Get player velocity (for prediction)
    var player_velocity = player.linear_velocity  # RigidBody3D property

    # 2. Get weapon projectile speed
    var projectile_speed = weapon_controller.get_projectile_speed()  # e.g., 50 m/s

    # 3. Compute perfect intercept point
    var intercept = _compute_intercept_point(
        player.global_position,
        player_velocity,
        projectile_speed
    )

    # 4. Apply accuracy spread
    var aim_target = _apply_accuracy_spread(intercept, base_accuracy)

    # 5. Set weapon aim target
    weapon_controller.set_aim_target(aim_target)
```

**Call Frequency**: Update every frame in COMBAT state (required for tracking fast-moving targets).

### Hitscan vs Projectile Handling

**Laser Weapons** (hitscan, instant hit):

- No prediction needed
- Accuracy spread applied directly to aim direction
- Lower spread = higher accuracy

**Energy Burst** (projectile):

- Full prediction algorithm
- Accuracy affects both prediction and final aim offset

```gdscript
func _get_weapon_aim_target() -> Vector3:
    var weapon_type = weapon_controller.get_primary_weapon_type()

    if weapon_type == "laser":
        # Hitscan: aim at current position with spread
        return _apply_accuracy_spread(player.global_position, base_accuracy)
    else:
        # Projectile: predict future position
        return _compute_intercept_point(player.global_position, player.linear_velocity, projectile_speed)
```

---

## Performance Optimization

### LOD System (Per AI_SPEC.md)

**AI Performance Budgets**:
| Range | Update Rate | Behaviors |
|------------|-------------|-----------|
| < 100m | 60 FPS | Full AI |
| 100-300m | 10 FPS | Simplified|
| > 300m | 1 FPS | Paused |

**Max Active AI**: 10 in combat, 20 total

### LOD Implementation

```gdscript
class_name CombatAI extends Node

enum LODLevel { FULL, REDUCED, MINIMAL, PAUSED }

var current_lod: LODLevel = LODLevel.FULL
var lod_update_timer: float = 0.0
var lod_update_interval: float = 1.0 / 60.0  # Default 60 FPS

func _physics_process(delta: float):
    # Update LOD based on distance to player
    _update_lod_level()

    # Accumulate time for LOD-based updates
    lod_update_timer += delta
    if lod_update_timer < lod_update_interval:
        return  # Skip this frame

    lod_update_timer = 0.0

    # Run AI update
    _update_state_machine(delta)

func _update_lod_level():
    var player = _get_player_drone()
    if not player:
        current_lod = LODLevel.PAUSED
        return

    var distance = global_position.distance_to(player.global_position)

    if distance < 100.0:
        current_lod = LODLevel.FULL
        lod_update_interval = 1.0 / 60.0  # 60 FPS
    elif distance < 300.0:
        current_lod = LODLevel.REDUCED
        lod_update_interval = 1.0 / 10.0  # 10 FPS
    else:
        current_lod = LODLevel.MINIMAL
        lod_update_interval = 1.0 / 1.0   # 1 FPS
```

**Simplified Behaviors for REDUCED LOD**:

- Skip evasive maneuvers (pure chase)
- Skip raycast avoidance (NavigationAgent only)
- Lower accuracy (increase spread)
- No formation coordination

### Spatial Partitioning: Octree or Grid

For efficient "find nearby enemies" queries:

```gdscript
# In WorldManager autoload
var enemy_grid: Dictionary = {}  # Key: grid_cell, Value: Array[Enemy]
var grid_cell_size: float = 100.0

func register_enemy(enemy: Node3D):
    var cell = _get_grid_cell(enemy.global_position)
    if not enemy_grid.has(cell):
        enemy_grid[cell] = []
    enemy_grid[cell].append(enemy)

func get_nearby_enemies(position: Vector3, radius: float) -> Array:
    var nearby = []
    var cells_to_check = _get_cells_in_radius(position, radius)

    for cell in cells_to_check:
        if enemy_grid.has(cell):
            nearby.append_array(enemy_grid[cell])

    return nearby
```

**When to Use**: Alert broadcasts, formation coordination, LOD calculations.

### Multi-Threading Considerations (Jolt Physics)

**What Jolt Handles Automatically**:

- RigidBody3D physics updates
- Collision detection
- Constraint solving

**What AI Must Handle on Main Thread**:

- State machine logic
- Detection raycasts (PhysicsDirectSpaceState3D is not thread-safe)
- Input updates (InputController must be called from main thread)

**Optimization Strategy**: Use Godot's **WorkerThreadPool** for **expensive calculations** only:

- Formation path planning (complex A\*)
- Large-scale alert broadcasts (100+ enemies)

**Not Recommended for This Game**: AI logic is simple enough to run on main thread with LOD system.

### Memory Optimization

**Pooling Strategy**:

- Pre-allocate 20 enemy instances at scene load
- Reuse destroyed enemies (reset state, teleport to new spawn)
- Avoid `new()` calls during gameplay

```gdscript
# In WorldManager
var enemy_pool: Array[EnemyDrone] = []
var active_enemies: Array[EnemyDrone] = []

func spawn_enemy(type: EnemyType, position: Vector3) -> EnemyDrone:
    var enemy = _get_pooled_enemy(type)
    enemy.global_position = position
    enemy.reset_state()
    enemy.show()
    active_enemies.append(enemy)
    return enemy

func _get_pooled_enemy(type: EnemyType) -> EnemyDrone:
    for enemy in enemy_pool:
        if enemy.enemy_type == type and not enemy.is_active():
            return enemy

    # Pool exhausted, create new (should rarely happen)
    return _create_new_enemy(type)
```

**Cache Physics Queries**:

- Store `get_world_3d().direct_space_state` reference (don't re-fetch every frame)
- Reuse `PhysicsRayQueryParameters3D` objects

---

## Implementation Roadmap

### Phase 1: Core State Machine (Week 1)

**Goal**: Get basic state transitions working

**Tasks**:

1. Create `combat_ai.gd` component script
2. Implement State enum and transition logic
3. Add simple PATROL → ALERT → COMBAT flow
4. Test state transitions with debug prints

**Acceptance Criteria**:

- Enemy enters ALERT when player within range
- Enemy enters COMBAT after 1 second
- Enemy returns to PATROL when player leaves range

**Files to Create**:

- `/Users/dkurbatov/Desktop/DroneWorld/src/components/combat_ai.gd`

**Files to Modify**:

- `/Users/dkurbatov/Desktop/DroneWorld/scenes/enemies/*.tscn` (add CombatAI node)

### Phase 2: Detection System (Week 1-2)

**Goal**: Implement player detection with FOV and LOS

**Tasks**:

1. Add raycast-based player detection
2. Implement FOV cone check (dot product)
3. Add detection modifiers (boost, weather, etc.)
4. Add alert broadcast system (notify nearby allies)

**Acceptance Criteria**:

- Enemy detects player within spec ranges (100-300m)
- FOV correctly filters out-of-view targets
- Obstacles block detection (LOS raycast)
- Firing weapons alerts nearby enemies

**Testing**:

- Place enemy in scene, approach from different angles
- Verify detection ranges with debug spheres
- Test with and without obstacles

### Phase 3: Combat Behaviors (Week 2-3)

**Goal**: Implement chase, strafe, retreat movement with vertical navigation

**Tasks**:

1. Implement CHASE behavior (move toward player)
2. Implement STRAFE behavior (circle player)
3. Implement RETREAT behavior (flee at low health)
4. **NEW: Add vertical navigation system (altitude decision-making)**
5. **NEW: Implement energy state tracking (altitude + speed)**
6. **NEW: Add basic vertical positioning behaviors per enemy type**
7. Add weapon firing logic (set_ai_fire)
8. Test with different enemy types (Scout, Enforcer, Heavy)

**Acceptance Criteria**:

- Scout: Fast approach + strafe **+ altitude advantage for better visibility**
- Enforcer: Balanced chase/strafe mix **+ maintains 10m altitude advantage**
- Heavy: Slow chase to optimal range **+ stable altitude matching**
- All enemies retreat at <25% health **+ climb to escape**
- **Energy state correctly tracks altitude and speed advantages**
- **Enemies use vertical space purposefully, not just matching player altitude**

**Testing**:

- Spawn each enemy type, trigger combat
- Monitor health, verify retreat activation
- Check energy drain during boost/firing

### Phase 4: Targeting System (Week 3-4)

**Goal**: Implement predictive aiming for projectiles

**Tasks**:

1. Add intercept point calculation
2. Implement accuracy spread system
3. Integrate with WeaponController aim target
4. Tune accuracy values per enemy type

**Acceptance Criteria**:

- Enemies hit moving player >60% of time (Scout)
- Heavy enemies hit >80% of time (slower, more accurate)
- Projectiles lead player movement visibly

**Testing**:

- Strafe at high speed, count hit rate
- Compare laser (hitscan) vs burst (projectile) accuracy

### Phase 5: Optimization & Polish (Week 4-5)

**Goal**: Implement LOD system, test performance

**Tasks**:

1. Add LOD distance-based update rates
2. Implement enemy pooling system
3. Add visual indicators (lights, health bars)
4. Performance profiling with 20 active enemies

**Acceptance Criteria**:

- 60 FPS with 10 enemies in combat
- 60 FPS with 20 enemies total (10 distant on 1 FPS LOD)
- Visual indicators match spec (green/yellow/red lights)

**Tools**:

- Godot Profiler (Monitor > Debugger > Profiler)
- Check physics time, script time

### Phase 6: Advanced Vertical Tactics (Week 5)

**Goal**: Implement advanced vertical maneuvers (vertical evasion, vertical wobble)

**Tasks**:

1. Implement tactical altitude positioning per enemy type
2. Add vertical evasion (reactive climb/descent when under fire)
3. Add vertical scissors maneuver (Enforcer advanced combat)
4. Implement terrain following/ceiling avoidance safety systems
5. Add ground clearance checks with raycasts
6. Tune energy state calculations and thresholds

**Acceptance Criteria**:

- Scouts/Interceptors maintain higher altitude advantage during combat
- Enemies dodge vertically when player fires (visible climb/descent reaction)
- No ground collisions during low-altitude combat
- Enemies respect altitude limits (5m min, 90m max)
- Energy state advantage correctly influences aggression

**Testing**:

- Engage Scout at various altitudes, verify altitude advantage is maintained
- Fire at enemies, count vertical evasion triggers
- Chase enemies at low altitude over hills, verify no crashes
- Test ceiling avoidance in confined spaces

### Phase 7: Advanced Features (Week 6)

**Goal**: Formations, dynamic spawns, advanced patterns

**Tasks**:

1. Implement pair/squad patrol formations
2. Add dynamic spawn triggers (reinforcements)
3. Add horizontal evasive maneuvers (reactive dodging)
4. Interceptor special pursuit behavior
5. Squad coordination with vertical stacking

**Acceptance Criteria**:

- Pair patrols engage from different angles
- Destroying enemy triggers reinforcements (max 3 waves)
- Scouts dodge player fire 20% of time (horizontal + vertical)
- Squads use vertical separation (don't all fly at same altitude)

---

## Code Examples

### Complete CombatAI Component Structure

```gdscript
# combat_ai.gd
class_name CombatAI extends Node

## State machine and combat behavior for enemy drones
## Integrates with existing InputController, WeaponController, HealthSystem

# ============================================================================
# ENUMS & CONSTANTS
# ============================================================================

enum State {
    PATROL,
    ALERT,
    COMBAT,
    RETREAT
}

enum CombatPattern {
    CHASE,
    STRAFE,
    EVASIVE
}

enum EnemyType {
    SCOUT,
    ENFORCER,
    HEAVY,
    INTERCEPTOR
}

# ============================================================================
# EXPORTS (Designer-Adjustable)
# ============================================================================

@export var enemy_type: EnemyType = EnemyType.ENFORCER
@export var base_detection_range: float = 150.0
@export var field_of_view: float = 120.0  # Degrees
@export var base_accuracy: float = 0.7    # 0.0 to 1.0

# ============================================================================
# STATE MACHINE
# ============================================================================

var current_state: State = State.PATROL
var state_timer: float = 0.0

# PATROL state
var patrol_waypoints: Array[Vector3] = []
var current_waypoint: int = 0

# ALERT state
var alert_target: Node3D = null

# COMBAT state
var combat_pattern: CombatPattern = CombatPattern.CHASE
var last_player_position: Vector3
var time_since_player_visible: float = 0.0
var strafe_direction: int = 1
var strafe_switch_timer: float = 0.0

# RETREAT state
var retreat_boost_used: bool = false

# ============================================================================
# COMPONENT REFERENCES
# ============================================================================

var hover_physics: RigidBody3D
var input_controller: Node
var weapon_controller: Node
var health_system: Node
var energy_system: Node

# ============================================================================
# PERFORMANCE (LOD)
# ============================================================================

enum LODLevel { FULL, REDUCED, MINIMAL, PAUSED }
var current_lod: LODLevel = LODLevel.FULL
var lod_update_timer: float = 0.0
var lod_update_interval: float = 1.0 / 60.0

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
    # Get component references
    hover_physics = get_parent() as RigidBody3D
    input_controller = hover_physics.get_node("InputController")
    weapon_controller = hover_physics.get_node("WeaponController")
    health_system = hover_physics.get_node("HealthSystem")
    energy_system = hover_physics.get_node("EnergySystem")

    # Set InputController to AI mode
    input_controller.control_mode = 1  # 0 = PLAYER, 1 = AI

    # Connect health signal for retreat trigger
    health_system.health_changed.connect(_on_health_changed)

    # Add to enemies group for alert broadcasts
    add_to_group("enemies")

    # Initialize patrol waypoints
    _generate_patrol_waypoints()

# ============================================================================
# MAIN UPDATE LOOP
# ============================================================================

func _physics_process(delta: float):
    _update_lod_level()

    # LOD-based update throttling
    lod_update_timer += delta
    if lod_update_timer < lod_update_interval:
        return
    lod_update_timer = 0.0

    # State machine update
    state_timer += delta

    match current_state:
        State.PATROL:
            _update_patrol(delta)
        State.ALERT:
            _update_alert(delta)
        State.COMBAT:
            _update_combat(delta)
        State.RETREAT:
            _update_retreat(delta)

# ============================================================================
# STATE UPDATES
# ============================================================================

func _update_patrol(delta: float):
    # Check for player detection
    if _detect_player():
        alert_target = _get_player_drone()
        _transition_to_state(State.ALERT)
        return

    # Continue patrol (handled by existing PatrolNavigation component)
    # This component only triggers state changes, movement handled elsewhere

func _update_alert(delta: float):
    # Lock onto player, 1-second warning
    if not alert_target:
        _transition_to_state(State.PATROL)
        return

    # Face player
    _face_target(alert_target.global_position)

    # Transition to combat after 1 second
    if state_timer >= 1.0:
        _transition_to_state(State.COMBAT)

func _update_combat(delta: float):
    var player = _get_player_drone()
    if not player:
        _transition_to_state(State.PATROL)
        return

    # Check if player escaped (out of range for 10 seconds)
    var distance = global_position.distance_to(player.global_position)
    if distance > base_detection_range * 2.0:  # 2x range for escape
        time_since_player_visible += delta
        if time_since_player_visible >= 10.0:
            _transition_to_state(State.PATROL)
            return
    else:
        time_since_player_visible = 0.0

    # Execute combat behavior
    match combat_pattern:
        CombatPattern.CHASE:
            _update_combat_chase(delta)
        CombatPattern.STRAFE:
            _update_combat_strafe(delta)

    # Update weapon targeting
    _update_weapon_targeting()

func _update_retreat(delta: float):
    var player = _get_player_drone()
    if not player:
        _transition_to_state(State.PATROL)
        return

    # Flee away from player
    var away_from_player = (global_position - player.global_position).normalized()
    var move_input = Vector2(away_from_player.x, away_from_player.z)

    # Use boost once
    if not retreat_boost_used and energy_system.current_energy > 20.0:
        input_controller.set_ai_boost(true)
        retreat_boost_used = true

    # Stop firing
    input_controller.set_ai_fire(false, false)

    # Check if reached safety
    var distance = global_position.distance_to(player.global_position)
    if distance >= 300.0:
        _transition_to_state(State.PATROL)
        retreat_boost_used = false

    input_controller.set_ai_movement(move_input, 0.0)

# ============================================================================
# COMBAT BEHAVIORS
# ============================================================================

func _update_combat_chase(delta: float):
    var player = _get_player_drone()
    if not player:
        return

    var to_player = player.global_position - global_position
    var distance = to_player.length()
    var direction = to_player.normalized()

    # Maintain optimal weapon range
    var optimal_range = 50.0  # TODO: Get from weapon_controller
    var range_error = distance - optimal_range

    var move_input = Vector2.ZERO
    if abs(range_error) > 10.0:
        if range_error > 0:
            move_input = Vector2(direction.x, direction.z)
        else:
            move_input = -Vector2(direction.x, direction.z)

    if move_input.length() > 1.0:
        move_input = move_input.normalized()

    input_controller.set_ai_movement(move_input, 0.0)

    # Fire if in range
    if distance <= 150.0:  # Max weapon range
        input_controller.set_ai_fire(true, false)

func _update_combat_strafe(delta: float):
    var player = _get_player_drone()
    if not player:
        return

    var to_player = player.global_position - global_position
    var forward = to_player.normalized()
    var right = forward.cross(Vector3.UP).normalized()

    # Alternate strafe direction
    strafe_switch_timer += delta
    if strafe_switch_timer >= 2.0:
        strafe_direction *= -1
        strafe_switch_timer = 0.0

    var move_vector = forward * 0.5 + right * strafe_direction
    var move_input = Vector2(move_vector.x, move_vector.z).normalized()

    input_controller.set_ai_movement(move_input, 0.0)
    input_controller.set_ai_fire(true, false)

# ============================================================================
# DETECTION SYSTEM
# ============================================================================

func _detect_player() -> bool:
    var player = _get_player_drone()
    if not player:
        return false

    var to_player = player.global_position - global_position
    var distance = to_player.length()

    # Range check
    var detection_range = base_detection_range
    # TODO: Add modifiers (boost, firing, weather)

    if distance > detection_range:
        return false

    # FOV check
    var forward = -global_transform.basis.z
    var direction_to_player = to_player.normalized()
    var dot = forward.dot(direction_to_player)
    var fov_threshold = cos(deg_to_rad(field_of_view / 2.0))

    if dot < fov_threshold:
        return false

    # Line-of-sight raycast
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        global_position,
        player.global_position
    )
    query.exclude = [hover_physics]

    var result = space_state.intersect_ray(query)
    if result and result.collider == player.hover_physics:
        return true

    return false

# ============================================================================
# TARGETING SYSTEM
# ============================================================================

func _update_weapon_targeting():
    var player = _get_player_drone()
    if not player:
        return

    var player_velocity = player.hover_physics.linear_velocity
    var projectile_speed = 50.0  # TODO: Get from weapon

    var intercept = _compute_intercept_point(
        player.global_position,
        player_velocity,
        projectile_speed
    )

    var aim_target = _apply_accuracy_spread(intercept, base_accuracy)
    weapon_controller.set_aim_target(aim_target)

func _compute_intercept_point(
    target_position: Vector3,
    target_velocity: Vector3,
    projectile_speed: float
) -> Vector3:
    var to_target = target_position - global_position

    var a = target_velocity.length_squared() - projectile_speed * projectile_speed
    var b = 2.0 * to_target.dot(target_velocity)
    var c = to_target.length_squared()

    var discriminant = b * b - 4.0 * a * c
    if discriminant < 0:
        return target_position

    var t1 = (-b + sqrt(discriminant)) / (2.0 * a)
    var t2 = (-b - sqrt(discriminant)) / (2.0 * a)
    var t = min(t1, t2) if t1 > 0 and t2 > 0 else max(t1, t2)

    if t < 0:
        return target_position

    return target_position + target_velocity * t

func _apply_accuracy_spread(perfect_aim: Vector3, accuracy: float) -> Vector3:
    var max_spread = (1.0 - accuracy) * 15.0
    var spread = randf_range(-max_spread, max_spread)

    # Simple horizontal spread only
    var horizontal_aim = Vector2(perfect_aim.x, perfect_aim.z)
    horizontal_aim = horizontal_aim.rotated(deg_to_rad(spread))

    return Vector3(horizontal_aim.x, perfect_aim.y, horizontal_aim.y)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _transition_to_state(new_state: State):
    if current_state == new_state:
        return

    # Exit current state
    match current_state:
        State.RETREAT:
            input_controller.set_ai_boost(false)

    # Enter new state
    current_state = new_state
    state_timer = 0.0

    match new_state:
        State.ALERT:
            # Alert nearby allies
            _alert_nearby_allies()
        State.COMBAT:
            # Select combat pattern
            combat_pattern = _select_combat_pattern()

func _select_combat_pattern() -> CombatPattern:
    match enemy_type:
        EnemyType.SCOUT:
            return CombatPattern.STRAFE
        EnemyType.ENFORCER:
            return CombatPattern.CHASE if randf() < 0.6 else CombatPattern.STRAFE
        EnemyType.HEAVY:
            return CombatPattern.CHASE
        EnemyType.INTERCEPTOR:
            return CombatPattern.CHASE
    return CombatPattern.CHASE

func _get_player_drone() -> Node3D:
    # TODO: Get from GameManager
    return get_tree().get_first_node_in_group("player")

func _face_target(target_pos: Vector3):
    var to_target = target_pos - global_position
    var direction = Vector2(to_target.x, to_target.z).normalized()
    input_controller.set_ai_movement(direction * 0.1, 0.0)  # Gentle turn

func _alert_nearby_allies():
    var enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in enemies:
        if enemy == self:
            continue
        var distance = global_position.distance_to(enemy.global_position)
        if distance <= 300.0:
            enemy.on_ally_alert(alert_target.global_position if alert_target else global_position)

func _on_health_changed(new_health: float, max_health: float):
    if current_state == State.COMBAT and new_health < max_health * 0.25:
        _transition_to_state(State.RETREAT)

func on_ally_alert(threat_position: Vector3):
    if current_state == State.PATROL:
        alert_target = _get_player_drone()
        _transition_to_state(State.ALERT)

func _update_lod_level():
    var player = _get_player_drone()
    if not player:
        current_lod = LODLevel.PAUSED
        return

    var distance = global_position.distance_to(player.global_position)

    if distance < 100.0:
        current_lod = LODLevel.FULL
        lod_update_interval = 1.0 / 60.0
    elif distance < 300.0:
        current_lod = LODLevel.REDUCED
        lod_update_interval = 1.0 / 10.0
    else:
        current_lod = LODLevel.MINIMAL
        lod_update_interval = 1.0

func _generate_patrol_waypoints():
    # TODO: Implement or use existing PatrolNavigation waypoints
    pass
```

---

## Testing & Validation

### Unit Testing Checklist

**Detection System**:

- [ ] Enemy detects player at exact detection range (±5m tolerance)
- [ ] FOV cone correctly filters targets (test at 0°, 45°, 90°, 180°)
- [ ] Line-of-sight blocked by obstacles (place wall between enemy and player)
- [ ] Boost detection modifier works (+50m range when player boosting)
- [ ] Firing detection modifier works (+100m range, alerts nearby enemies)

**State Transitions**:

- [ ] PATROL → ALERT when player detected
- [ ] ALERT → COMBAT after 1 second
- [ ] COMBAT → RETREAT when health < 25%
- [ ] COMBAT → PATROL after player escapes 10 seconds
- [ ] RETREAT → PATROL at 300m safe distance

**Combat Behaviors**:

- [ ] Scout uses STRAFE pattern (circle player)
- [ ] Enforcer uses mixed CHASE/STRAFE (verify randomness)
- [ ] Heavy uses CHASE to optimal range then stops
- [ ] Retreat uses boost (once per retreat)
- [ ] Energy drains during boost/firing

**Vertical Navigation**:

- [ ] Enemies gain altitude advantage in combat (climb above player)
- [ ] Scout/Interceptor maintain altitude advantage during combat
- [ ] Vertical evasion triggers when player fires (climb or descent)
- [ ] Ground clearance maintained at <5m altitude
- [ ] Ceiling avoidance works in confined spaces
- [ ] Retreat state climbs 30m above player
- [ ] Energy state calculation includes altitude + speed
- [ ] Different enemy types use different altitude strategies

**Targeting System**:

- [ ] Projectiles lead player movement (visual confirmation)
- [ ] Accuracy matches spec (Scout 60%, Heavy 80%)
- [ ] Hitscan weapons (lasers) hit instantly
- [ ] Accuracy spread visible (shots don't all hit center mass)

**Performance**:

- [ ] 60 FPS with 10 enemies in combat at <100m
- [ ] 60 FPS with 20 enemies total (10 distant)
- [ ] LOD system reduces update rate at distance
- [ ] No frame drops when spawning 3 reinforcement waves

### Integration Testing Scenarios

**Scenario 1: Patrol Detection**

1. Place Scout drone on patrol route
2. Approach from behind (outside FOV)
3. Verify no detection
4. Move into FOV cone
5. Verify ALERT transition (yellow light, lock-on sound)
6. Wait 1 second
7. Verify COMBAT transition (red light, firing)

**Scenario 2: Multi-Enemy Alert**

1. Place 3 Enforcer drones in formation
2. Trigger detection on 1 drone
3. Verify all 3 transition to ALERT (alert broadcast)
4. Verify all engage player

**Scenario 3: Retreat Behavior**

1. Engage Heavy drone
2. Reduce health to 30%
3. Verify no retreat yet
4. Reduce health to 24%
5. Verify RETREAT transition (flashing light, boost activation)
6. Verify enemy flees away from player
7. Follow for 250m, verify still retreating
8. Stop following, wait for 300m distance
9. Verify return to PATROL

**Scenario 4: Performance Stress Test**

1. Spawn 20 enemies in scene
2. Keep 10 within 100m (FULL LOD)
3. Keep 10 beyond 300m (MINIMAL LOD)
4. Monitor FPS in Godot profiler
5. Verify physics time < 8ms (for 60 FPS)
6. Verify script time < 8ms
7. Destroy 5 close enemies
8. Verify reinforcements spawn (dynamic spawn system)

### Debugging Tools

**Visual Debug Overlays**:

```gdscript
# Add to CombatAI for debugging
func _draw_debug_info():
    if not OS.is_debug_build():
        return

    # Detection range sphere
    DebugDraw.draw_sphere(global_position, base_detection_range, Color.YELLOW)

    # FOV cone
    DebugDraw.draw_cone(global_position, -global_transform.basis.z, field_of_view, base_detection_range, Color.GREEN)

    # Current target line
    if alert_target:
        DebugDraw.draw_line(global_position, alert_target.global_position, Color.RED)

    # State indicator
    var state_color = Color.WHITE
    match current_state:
        State.PATROL: state_color = Color.GREEN
        State.ALERT: state_color = Color.YELLOW
        State.COMBAT: state_color = Color.RED
        State.RETREAT: state_color = Color.ORANGE

    DebugDraw.draw_text_3d(global_position + Vector3.UP * 5, State.keys()[current_state], state_color)
```

**Performance Profiling**:

- Monitor > Debugger > Profiler
- Check "ScriptFunctions" for `_physics_process` time
- Check "Physics" for Jolt simulation time
- Target: <16ms total frame time (60 FPS)

**Logging**:

```gdscript
func _log_state_transition(from: State, to: State):
    if OS.is_debug_build():
        print("[%s] %s → %s | Health: %.1f%% | Distance: %.1fm" % [
            name,
            State.keys()[from],
            State.keys()[to],
            health_system.current_health / health_system.max_health * 100.0,
            global_position.distance_to(_get_player_drone().global_position)
        ])
```

---

## Conclusion

This AI design document provides a comprehensive, production-ready architecture for DroneWorld's enemy AI system. Key takeaways:

1. **Jolt Physics Integration**: Use force-based movement via InputController API, leverage spring-damper hover system, no kinematic shortcuts

2. **Simplicity First**: Enum-based state machine, predictable behaviors, clear visual indicators

3. **Performance Optimized**: LOD system supporting 20 active enemies, spatial partitioning, minimal per-frame queries

4. **Modular & Extensible**: Component-based design, easy to add new enemy types, formation behaviors, advanced patterns

5. **Spec-Compliant**: All behaviors match AI_SPEC.md requirements (detection ranges, accuracy, state transitions)

**Next Steps**:

1. Review this document with team
2. Begin Phase 1 implementation (core state machine)
3. Iterate through phases, testing at each milestone
4. Tune parameters based on playtesting feedback

**Estimated Timeline**: 5-6 weeks for full implementation (solo developer, part-time)

---

**Document Maintained By**: AI System Designer
**Last Updated**: 2026-02-28
**Version**: 1.0 (Initial Draft)
**Status**: Ready for Implementation
