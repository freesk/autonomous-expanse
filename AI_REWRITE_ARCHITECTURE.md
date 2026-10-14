# DroneWorld AI System Rewrite - Testable Queue-Based Architecture

## Executive Summary

Complete rewrite of the AI system to be:
- **Testable**: 100% unit test coverage with no Godot dependencies in core logic
- **Queue-Based**: Command pattern for all AI actions with replay/debugging support
- **Structural**: Clear separation of concerns with interface-driven design
- **Performant**: Spatial partitioning, LOD system, and intelligent caching

## Core Principles

1. **No Godot in Core Logic**: AI brains are pure GDScript RefCounted classes
2. **Interface Everything**: All dependencies are injected through interfaces
3. **Command Pattern**: All actions are commands that can be queued, tested, and replayed
4. **Test-First**: No code accepted without passing unit + integration tests

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Godot Scene Layer (RigidBody3D, PhysicsServer, etc.)       │
└────────────────────┬────────────────────────────────────────┘
                     │ implements
┌────────────────────▼────────────────────────────────────────┐
│  Adapter Layer (GodotPhysicsQuery, GodotDroneAdapter)       │
└────────────────────┬────────────────────────────────────────┘
                     │ satisfies
┌────────────────────▼────────────────────────────────────────┐
│  Interface Layer (IPhysicsQuery, IDrone, ITargetable)       │
└────────────────────┬────────────────────────────────────────┘
                     │ injected into
┌────────────────────▼────────────────────────────────────────┐
│  Command Layer (MoveCommand, FireCommand, TargetCommand)    │
└────────────────────┬────────────────────────────────────────┘
                     │ produced by
┌────────────────────▼────────────────────────────────────────┐
│  AI Brain Layer (DroneCombatBrain, DronePathfindingBrain)   │
│  (PURE LOGIC - NO GODOT DEPENDENCIES)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Interface Layer

### Core Interfaces

```gdscript
# src/ai/interfaces/i_physics_query.gd
class_name IPhysicsQuery extends RefCounted
## Interface for physics queries - allows mocking in tests

func raycast(from: Vector3, to: Vector3, exclude: Array = []) -> Dictionary:
    assert(false, "Must implement raycast()")
    return {}

func sphere_cast(position: Vector3, radius: float, exclude: Array = []) -> Array:
    assert(false, "Must implement sphere_cast()")
    return []

func get_terrain_height(x: float, z: float) -> float:
    assert(false, "Must implement get_terrain_height()")
    return 0.0
```

```gdscript
# src/ai/interfaces/i_drone.gd
class_name IDrone extends RefCounted
## Interface for drone control and queries

func get_position() -> Vector3:
    assert(false, "Must implement get_position()")
    return Vector3.ZERO

func get_velocity() -> Vector3:
    assert(false, "Must implement get_velocity()")
    return Vector3.ZERO

func get_forward() -> Vector3:
    assert(false, "Must implement get_forward()")
    return Vector3.FORWARD

func get_health_percentage() -> float:
    assert(false, "Must implement get_health_percentage()")
    return 100.0

func get_energy() -> float:
    assert(false, "Must implement get_energy()")
    return 100.0

func get_max_speed() -> float:
    assert(false, "Must implement get_max_speed()")
    return 60.0
```

```gdscript
# src/ai/interfaces/i_targetable.gd
class_name ITargetable extends RefCounted
## Interface for anything that can be targeted

func get_position() -> Vector3:
    assert(false, "Must implement get_position()")
    return Vector3.ZERO

func get_velocity() -> Vector3:
    assert(false, "Must implement get_velocity()")
    return Vector3.ZERO

func is_valid() -> bool:
    assert(false, "Must implement is_valid()")
    return false

func get_faction_id() -> String:
    assert(false, "Must implement get_faction_id()")
    return ""
```

```gdscript
# src/ai/interfaces/i_faction_manager.gd
class_name IFactionManager extends RefCounted
## Interface for faction queries

func is_hostile(faction_a: String, faction_b: String) -> bool:
    assert(false, "Must implement is_hostile()")
    return false

func get_all_squads() -> Array:
    assert(false, "Must implement get_all_squads()")
    return []
```

---

## Phase 2: Command Pattern (Queue-Based System)

### Command Base Class

```gdscript
# src/ai/commands/ai_command.gd
class_name AICommand extends RefCounted
## Base class for all AI commands - enables queuing, testing, replay

enum CommandType {
    MOVE,
    FIRE_WEAPON,
    TARGET,
    SET_SPEED,
    RETREAT
}

var command_type: CommandType
var timestamp: float
var priority: int = 0  # Higher = more important
var is_completed: bool = false
var is_cancelled: bool = false

func execute(context: AICommandContext) -> void:
    assert(false, "Must implement execute()")

func can_execute(context: AICommandContext) -> bool:
    return true

func cancel() -> void:
    is_cancelled = true

func to_dict() -> Dictionary:
    ## For debugging/replay
    return {
        "type": CommandType.keys()[command_type],
        "timestamp": timestamp,
        "priority": priority
    }
```

### Concrete Commands

```gdscript
# src/ai/commands/move_command.gd
class_name MoveCommand extends AICommand
## Command to move drone in a direction

var direction: Vector2  # XZ movement
var climb: float  # Y movement
var speed_fraction: float = 1.0

func _init(dir: Vector2, climb_rate: float, speed: float = 1.0):
    command_type = CommandType.MOVE
    direction = dir
    climb = climb_rate
    speed_fraction = speed

func execute(context: AICommandContext) -> void:
    context.motion_system.set_movement(direction, climb, speed_fraction)
    is_completed = true

func to_dict() -> Dictionary:
    var d = super.to_dict()
    d["direction"] = [direction.x, direction.y]
    d["climb"] = climb
    d["speed"] = speed_fraction
    return d
```

```gdscript
# src/ai/commands/fire_weapon_command.gd
class_name FireWeaponCommand extends AICommand
## Command to fire weapons at target

var target_position: Vector3
var fire_primary: bool = true
var fire_secondary: bool = false

func _init(target_pos: Vector3, primary: bool = true, secondary: bool = false):
    command_type = CommandType.FIRE_WEAPON
    target_position = target_pos
    fire_primary = primary
    fire_secondary = secondary

func can_execute(context: AICommandContext) -> bool:
    # Check energy requirements
    if context.drone.get_energy() < 20.0:
        return false
    return true

func execute(context: AICommandContext) -> void:
    context.weapon_system.set_target(target_position)
    context.weapon_system.fire(fire_primary, fire_secondary)
    is_completed = true

func to_dict() -> Dictionary:
    var d = super.to_dict()
    d["target"] = [target_position.x, target_position.y, target_position.z]
    d["primary"] = fire_primary
    d["secondary"] = fire_secondary
    return d
```

### Command Queue System

```gdscript
# src/ai/commands/command_queue.gd
class_name CommandQueue extends RefCounted
## Priority queue for AI commands with overflow protection

const MAX_QUEUE_SIZE = 100

var commands: Array[AICommand] = []
var execution_history: Array[Dictionary] = []
var max_history: int = 50

func enqueue(command: AICommand) -> bool:
    if commands.size() >= MAX_QUEUE_SIZE:
        push_warning("CommandQueue overflow - dropping oldest command")
        commands.pop_front()

    # Insert by priority (higher priority first)
    var insert_idx = commands.size()
    for i in range(commands.size()):
        if command.priority > commands[i].priority:
            insert_idx = i
            break

    commands.insert(insert_idx, command)
    return true

func execute_next(context: AICommandContext) -> bool:
    while not commands.is_empty():
        var cmd = commands.pop_front()

        if cmd.is_cancelled:
            continue

        if cmd.can_execute(context):
            cmd.execute(context)
            _record_execution(cmd)
            return true

    return false

func execute_all(context: AICommandContext) -> int:
    var executed = 0
    while execute_next(context):
        executed += 1
    return executed

func clear() -> void:
    for cmd in commands:
        cmd.cancel()
    commands.clear()

func peek() -> AICommand:
    if commands.is_empty():
        return null
    return commands[0]

func size() -> int:
    return commands.size()

func _record_execution(cmd: AICommand) -> void:
    execution_history.append(cmd.to_dict())
    if execution_history.size() > max_history:
        execution_history.pop_front()

func get_execution_history() -> Array[Dictionary]:
    return execution_history.duplicate()
```

---

## Phase 3: Pure Logic AI Brains (No Godot Dependencies)

### Combat Brain

```gdscript
# src/ai/brains/drone_combat_brain.gd
class_name DroneCombatBrain extends RefCounted
## Pure logic for drone combat decisions - 100% testable

# Configuration
var optimal_range: float = 60.0
var min_range: float = 40.0
var max_range: float = 80.0
var retreat_health_threshold: float = 15.0
var retreat_safe_distance: float = 300.0

# State
enum CombatBehavior { CHASE, STRAFE, RETREAT_FIRE, DISENGAGE }

## Decide combat behavior based on state
func decide_combat_behavior(
    has_los: bool,
    distance: float,
    health_pct: float,
    energy: float
) -> CombatBehavior:

    # Disengage if critically low health
    if health_pct < retreat_health_threshold:
        return CombatBehavior.DISENGAGE

    # Can't fight without energy
    if energy < 20.0:
        return CombatBehavior.DISENGAGE

    # No LOS = must chase
    if not has_los:
        return CombatBehavior.CHASE

    # Too far = chase
    if distance > max_range:
        return CombatBehavior.CHASE

    # In optimal range = strafe
    if distance >= min_range and distance <= max_range:
        return CombatBehavior.STRAFE

    # Too close = back up while firing
    if distance < min_range:
        return CombatBehavior.RETREAT_FIRE

    return CombatBehavior.CHASE

## Calculate movement direction for combat behavior
func calculate_combat_movement(
    behavior: CombatBehavior,
    to_target: Vector3,
    forward: Vector3,
    strafe_direction: float  # -1 to 1
) -> Vector2:

    match behavior:
        CombatBehavior.CHASE:
            # Move toward target
            var dir_xz = Vector2(to_target.x, to_target.z).normalized()
            return dir_xz

        CombatBehavior.STRAFE:
            # Circle around target
            var dir_xz = Vector2(to_target.x, to_target.z).normalized()
            var perpendicular = Vector2(-dir_xz.y, dir_xz.x) * strafe_direction
            return perpendicular.normalized()

        CombatBehavior.RETREAT_FIRE:
            # Back away from target
            var dir_xz = Vector2(to_target.x, to_target.z).normalized()
            return -dir_xz

        CombatBehavior.DISENGAGE:
            # Flee directly away
            var dir_xz = Vector2(to_target.x, to_target.z).normalized()
            return -dir_xz

    return Vector2.ZERO

## Should we fire weapons?
func should_fire_weapons(
    has_los: bool,
    is_aimed: bool,
    energy: float,
    behavior: CombatBehavior
) -> bool:

    if behavior == CombatBehavior.DISENGAGE:
        return false

    if energy < 20.0:
        return false

    if not has_los:
        return false

    if not is_aimed:
        return false

    return true

## Calculate aim point with prediction
func calculate_aim_point(
    target_pos: Vector3,
    target_vel: Vector3,
    projectile_speed: float,
    distance: float
) -> Vector3:

    # Simple linear prediction
    var time_to_impact = distance / projectile_speed if projectile_speed > 0 else 0.0
    return target_pos + (target_vel * time_to_impact)

## Should we retreat to safety?
func should_retreat(health_pct: float, distance_to_safety: float) -> bool:
    if health_pct < retreat_health_threshold:
        return true
    return false

## Have we reached safety?
func is_safe(health_pct: float, distance_to_threat: float) -> bool:
    if health_pct > retreat_health_threshold * 2.0:  # Recovered
        return true
    if distance_to_threat > retreat_safe_distance:
        return true
    return false
```

### Pathfinding Brain

```gdscript
# src/ai/brains/drone_pathfinding_brain.gd
class_name DronePathfindingBrain extends RefCounted
## Pure logic for pathfinding decisions - 100% testable

# Configuration
var waypoint_reached_threshold: float = 5.0
var desired_height_above_terrain: float = 15.0
var max_height_above_terrain: float = 200.0
var obstacle_avoidance_distance: float = 30.0

## Should we generate a new waypoint?
func should_generate_waypoint(distance_to_waypoint: float) -> bool:
    return distance_to_waypoint < waypoint_reached_threshold

## Calculate movement toward waypoint
func calculate_movement_to_waypoint(
    to_waypoint: Vector3
) -> Vector2:
    var dir_xz = Vector2(to_waypoint.x, to_waypoint.z)
    if dir_xz.length() > 0:
        return dir_xz.normalized()
    return Vector2.ZERO

## Calculate climb rate for altitude management
func calculate_climb_rate(
    current_height: float,
    terrain_height: float,
    waypoint_height: float
) -> float:

    var height_above_terrain = current_height - terrain_height
    var target_height = terrain_height + desired_height_above_terrain

    # Force descent if too high
    if height_above_terrain > max_height_above_terrain:
        return -1.0

    # Calculate climb toward target
    var height_error = target_height - current_height

    # Clamp to [-1, 1]
    return clampf(height_error / 10.0, -1.0, 1.0)

## Calculate obstacle avoidance direction
func calculate_obstacle_avoidance(
    obstacles: Array[Vector3],  # List of obstacle directions
    desired_direction: Vector2
) -> Vector2:

    if obstacles.is_empty():
        return desired_direction

    # Find best direction that avoids obstacles
    var avoidance = Vector2.ZERO
    for obstacle_dir in obstacles:
        var obs_xz = Vector2(obstacle_dir.x, obstacle_dir.z).normalized()
        # Push away from obstacle
        avoidance -= obs_xz

    # Combine desired direction with avoidance
    var final_dir = desired_direction + (avoidance.normalized() * 0.5)
    return final_dir.normalized()

## Should we slow down? (approaching waypoint, obstacle ahead, etc.)
func calculate_speed_fraction(
    distance_to_waypoint: float,
    has_obstacles: bool
) -> float:

    # Slow down near waypoint
    if distance_to_waypoint < waypoint_reached_threshold * 3.0:
        return 0.5

    # Slow down if obstacles ahead
    if has_obstacles:
        return 0.6

    return 1.0
```

### Weapon Brain

```gdscript
# src/ai/brains/drone_weapon_brain.gd
class_name DroneWeaponBrain extends RefCounted
## Pure logic for weapon targeting and firing - 100% testable

# Configuration
var aim_tolerance_degrees: float = 5.0
var min_firing_energy: float = 20.0
var burst_fire_duration: float = 0.5
var burst_cooldown_duration: float = 1.0

# State
var burst_timer: float = 0.0
var cooldown_timer: float = 0.0

## Are we aimed at target?
func is_aimed_at_target(
    forward: Vector3,
    to_target: Vector3
) -> bool:
    var angle = forward.angle_to(to_target)
    var angle_deg = rad_to_deg(angle)
    return angle_deg < aim_tolerance_degrees

## Should we fire this frame?
func should_fire_this_frame(
    has_los: bool,
    is_aimed: bool,
    energy: float,
    delta: float
) -> bool:

    # Update timers
    if burst_timer > 0:
        burst_timer -= delta
    if cooldown_timer > 0:
        cooldown_timer -= delta
        return false  # In cooldown

    # Can't fire without prerequisites
    if not has_los or not is_aimed:
        return false

    if energy < min_firing_energy:
        return false

    # Start new burst
    if burst_timer <= 0:
        burst_timer = burst_fire_duration
        cooldown_timer = burst_cooldown_duration
        return true

    # Continue burst
    return burst_timer > 0

## Apply accuracy error to aim point
func apply_accuracy_error(
    aim_point: Vector3,
    accuracy: float  # 0.0 to 1.0
) -> Vector3:

    var error_magnitude = (1.0 - accuracy) * 10.0  # Max 10m error
    var random_offset = Vector3(
        randf_range(-error_magnitude, error_magnitude),
        randf_range(-error_magnitude, error_magnitude),
        randf_range(-error_magnitude, error_magnitude)
    )

    return aim_point + random_offset
```

---

## Phase 4: Adapter Layer (Godot Integration)

```gdscript
# src/ai/adapters/godot_physics_query.gd
class_name GodotPhysicsQuery extends IPhysicsQuery
## Adapter to wrap Godot's physics system

var world_3d: World3D
var exclude_rids: Array[RID] = []

# Caching
var raycast_cache: Dictionary = {}
var cache_duration: float = 0.2
var cache_timer: float = 0.0

func _init(world: World3D, exclude: Array = []):
    world_3d = world
    for node in exclude:
        if node is PhysicsBody3D:
            exclude_rids.append(node.get_rid())

func raycast(from: Vector3, to: Vector3, exclude: Array = []) -> Dictionary:
    # Check cache
    var cache_key = str(from) + "->" + str(to)
    if raycast_cache.has(cache_key):
        return raycast_cache[cache_key]

    # Execute raycast
    var space_state = world_3d.direct_space_state
    var query = PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = exclude_rids

    var result = space_state.intersect_ray(query)

    # Cache result
    raycast_cache[cache_key] = result

    return result

func clear_cache() -> void:
    raycast_cache.clear()

func sphere_cast(position: Vector3, radius: float, exclude: Array = []) -> Array:
    var space_state = world_3d.direct_space_state
    var query = PhysicsShapeQueryParameters3D.new()
    query.shape = SphereShape3D.new()
    query.shape.radius = radius
    query.transform.origin = position
    query.exclude = exclude_rids

    return space_state.intersect_shape(query)

func get_terrain_height(x: float, z: float) -> float:
    # Raycast down from high altitude
    var from = Vector3(x, 1000.0, z)
    var to = Vector3(x, -1000.0, z)
    var result = raycast(from, to)

    if result.has("position"):
        return result.position.y

    return 0.0
```

```gdscript
# src/ai/adapters/godot_drone_adapter.gd
class_name GodotDroneAdapter extends IDrone
## Adapter to wrap Godot's RigidBody3D drone

var drone_node: RigidBody3D
var health_system: Node
var energy_system: Node
var motion_controller: Node

func _init(drone: RigidBody3D):
    drone_node = drone
    # Cache component references
    health_system = drone.get_node_or_null("HealthSystem")
    energy_system = drone.get_node_or_null("EnergySystem")
    motion_controller = drone.get_node_or_null("MotionController")

func get_position() -> Vector3:
    return drone_node.global_position

func get_velocity() -> Vector3:
    return drone_node.linear_velocity

func get_forward() -> Vector3:
    return -drone_node.global_transform.basis.z

func get_health_percentage() -> float:
    if health_system and health_system.has_method("get_health_percentage"):
        return health_system.get_health_percentage()
    return 100.0

func get_energy() -> float:
    if energy_system and energy_system.has_method("get_current_energy"):
        return energy_system.get_current_energy()
    return 100.0

func get_max_speed() -> float:
    if motion_controller and motion_controller.has_method("get_max_speed"):
        return motion_controller.get_max_speed()
    return 60.0
```

---

## Phase 5: AI Controller (Command Generator)

```gdscript
# src/ai/controllers/drone_ai_controller.gd
class_name DroneAIController extends Node
## Generates commands using AI brains - bridges brains to adapters

# Dependencies (injected)
var drone: IDrone
var physics_query: IPhysicsQuery
var command_queue: CommandQueue

# AI Brains (pure logic)
var combat_brain: DroneCombatBrain
var pathfinding_brain: DronePathfindingBrain
var weapon_brain: DroneWeaponBrain

# State
var current_target: ITargetable
var current_waypoint: Vector3
var strafe_direction: float = 1.0

func _init(
    drone_interface: IDrone,
    physics_interface: IPhysicsQuery,
    queue: CommandQueue
):
    drone = drone_interface
    physics_query = physics_interface
    command_queue = queue

    # Create brains
    combat_brain = DroneCombatBrain.new()
    pathfinding_brain = DronePathfindingBrain.new()
    weapon_brain = DroneWeaponBrain.new()

func update(delta: float) -> void:
    # Generate commands based on current state
    if current_target and current_target.is_valid():
        _generate_combat_commands(delta)
    elif current_waypoint:
        _generate_pathfinding_commands(delta)

    # Execute queued commands
    var context = AICommandContext.new(drone, physics_query)
    command_queue.execute_all(context)

func _generate_combat_commands(delta: float) -> void:
    # Gather state
    var my_pos = drone.get_position()
    var target_pos = current_target.get_position()
    var to_target = target_pos - my_pos
    var distance = to_target.length()

    var has_los = _check_line_of_sight(my_pos, target_pos)
    var health_pct = drone.get_health_percentage()
    var energy = drone.get_energy()

    # Decide behavior using brain
    var behavior = combat_brain.decide_combat_behavior(
        has_los, distance, health_pct, energy
    )

    # Generate movement command
    var movement = combat_brain.calculate_combat_movement(
        behavior, to_target, drone.get_forward(), strafe_direction
    )
    var move_cmd = MoveCommand.new(movement, 0.0, 0.8)
    command_queue.enqueue(move_cmd)

    # Generate weapon command
    if combat_brain.should_fire_weapons(
        has_los,
        weapon_brain.is_aimed_at_target(drone.get_forward(), to_target),
        energy,
        behavior
    ):
        var aim_point = combat_brain.calculate_aim_point(
            target_pos,
            current_target.get_velocity(),
            1000.0,  # Projectile speed
            distance
        )
        var fire_cmd = FireWeaponCommand.new(aim_point, true, false)
        command_queue.enqueue(fire_cmd)

func _generate_pathfinding_commands(delta: float) -> void:
    var my_pos = drone.get_position()
    var to_waypoint = current_waypoint - my_pos
    var distance = to_waypoint.length()

    # Check if reached waypoint
    if pathfinding_brain.should_generate_waypoint(distance):
        return  # Let external system set new waypoint

    # Generate movement command
    var movement = pathfinding_brain.calculate_movement_to_waypoint(to_waypoint)

    # Obstacle avoidance
    var obstacles = _detect_obstacles()
    movement = pathfinding_brain.calculate_obstacle_avoidance(obstacles, movement)

    # Altitude management
    var terrain_height = physics_query.get_terrain_height(my_pos.x, my_pos.z)
    var climb = pathfinding_brain.calculate_climb_rate(
        my_pos.y, terrain_height, current_waypoint.y
    )

    var speed = pathfinding_brain.calculate_speed_fraction(
        distance, not obstacles.is_empty()
    )

    var move_cmd = MoveCommand.new(movement, climb, speed)
    command_queue.enqueue(move_cmd)

func _check_line_of_sight(from: Vector3, to: Vector3) -> bool:
    var result = physics_query.raycast(from, to)
    return not result.has("collider") or result.collider == current_target

func _detect_obstacles() -> Array[Vector3]:
    # Implement obstacle detection using physics_query
    return []

## Public API for external control
func set_target(target: ITargetable) -> void:
    current_target = target
    current_waypoint = Vector3.ZERO

func set_waypoint(waypoint: Vector3) -> void:
    current_waypoint = waypoint
    current_target = null

func clear_commands() -> void:
    command_queue.clear()
```

---

## Phase 6: Unit Tests (100% Coverage Required)

### Combat Brain Tests

```gdscript
# tests/unit/test_drone_combat_brain.gd
extends GutTest
## Unit tests for DroneCombatBrain - pure logic, no Godot dependencies

var brain: DroneCombatBrain

func before_each():
    brain = DroneCombatBrain.new()
    # Configure for testing
    brain.optimal_range = 60.0
    brain.min_range = 40.0
    brain.max_range = 80.0
    brain.retreat_health_threshold = 15.0

func test_decide_combat_behavior_disengage_on_low_health():
    # Arrange
    var has_los = true
    var distance = 50.0
    var health_pct = 10.0  # Below threshold
    var energy = 100.0

    # Act
    var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

    # Assert
    assert_eq(behavior, DroneCombatBrain.CombatBehavior.DISENGAGE,
        "Should disengage when health below threshold")

func test_decide_combat_behavior_chase_when_no_los():
    # Arrange
    var has_los = false
    var distance = 50.0
    var health_pct = 100.0
    var energy = 100.0

    # Act
    var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

    # Assert
    assert_eq(behavior, DroneCombatBrain.CombatBehavior.CHASE,
        "Should chase when no line of sight")

func test_decide_combat_behavior_chase_when_too_far():
    # Arrange
    var has_los = true
    var distance = 100.0  # > max_range (80)
    var health_pct = 100.0
    var energy = 100.0

    # Act
    var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

    # Assert
    assert_eq(behavior, DroneCombatBrain.CombatBehavior.CHASE,
        "Should chase when beyond max range")

func test_decide_combat_behavior_strafe_in_optimal_range():
    # Arrange
    var has_los = true
    var distance = 60.0  # At optimal range
    var health_pct = 100.0
    var energy = 100.0

    # Act
    var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

    # Assert
    assert_eq(behavior, DroneCombatBrain.CombatBehavior.STRAFE,
        "Should strafe when in optimal range")

func test_decide_combat_behavior_retreat_fire_when_too_close():
    # Arrange
    var has_los = true
    var distance = 30.0  # < min_range (40)
    var health_pct = 100.0
    var energy = 100.0

    # Act
    var behavior = brain.decide_combat_behavior(has_los, distance, health_pct, energy)

    # Assert
    assert_eq(behavior, DroneCombatBrain.CombatBehavior.RETREAT_FIRE,
        "Should retreat while firing when too close")

func test_calculate_combat_movement_chase_moves_toward_target():
    # Arrange
    var behavior = DroneCombatBrain.CombatBehavior.CHASE
    var to_target = Vector3(10, 0, 5)
    var forward = Vector3(0, 0, -1)
    var strafe_dir = 1.0

    # Act
    var movement = brain.calculate_combat_movement(behavior, to_target, forward, strafe_dir)

    # Assert
    assert_gt(movement.length(), 0.0, "Should produce movement")
    var expected_dir = Vector2(10, 5).normalized()
    assert_almost_eq(movement.x, expected_dir.x, 0.01, "Movement X should point toward target")
    assert_almost_eq(movement.y, expected_dir.y, 0.01, "Movement Y should point toward target")

func test_calculate_combat_movement_strafe_moves_perpendicular():
    # Arrange
    var behavior = DroneCombatBrain.CombatBehavior.STRAFE
    var to_target = Vector3(10, 0, 0)  # Target to the right
    var forward = Vector3(0, 0, -1)
    var strafe_dir = 1.0  # Circle clockwise

    # Act
    var movement = brain.calculate_combat_movement(behavior, to_target, forward, strafe_dir)

    # Assert
    assert_gt(movement.length(), 0.0, "Should produce movement")
    # Perpendicular to (10, 0) is (0, 10) or (0, -10)
    assert_almost_eq(movement.x, 0.0, 0.01, "Should move perpendicular to target direction")

func test_should_fire_weapons_false_when_no_los():
    # Arrange
    var has_los = false
    var is_aimed = true
    var energy = 100.0
    var behavior = DroneCombatBrain.CombatBehavior.STRAFE

    # Act
    var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

    # Assert
    assert_false(should_fire, "Should not fire without line of sight")

func test_should_fire_weapons_false_when_low_energy():
    # Arrange
    var has_los = true
    var is_aimed = true
    var energy = 10.0  # Below min_firing_energy (20)
    var behavior = DroneCombatBrain.CombatBehavior.STRAFE

    # Act
    var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

    # Assert
    assert_false(should_fire, "Should not fire with insufficient energy")

func test_should_fire_weapons_true_when_all_conditions_met():
    # Arrange
    var has_los = true
    var is_aimed = true
    var energy = 100.0
    var behavior = DroneCombatBrain.CombatBehavior.STRAFE

    # Act
    var should_fire = brain.should_fire_weapons(has_los, is_aimed, energy, behavior)

    # Assert
    assert_true(should_fire, "Should fire when all conditions met")

func test_calculate_aim_point_predicts_target_movement():
    # Arrange
    var target_pos = Vector3(0, 0, 0)
    var target_vel = Vector3(10, 0, 0)  # Moving right at 10 m/s
    var projectile_speed = 100.0
    var distance = 100.0

    # Act
    var aim_point = brain.calculate_aim_point(target_pos, target_vel, projectile_speed, distance)

    # Assert
    var time_to_impact = distance / projectile_speed  # 1.0 second
    var expected_pos = target_pos + (target_vel * time_to_impact)
    assert_almost_eq(aim_point.x, expected_pos.x, 0.01, "Should predict target position")
    assert_almost_eq(aim_point.y, expected_pos.y, 0.01)
    assert_almost_eq(aim_point.z, expected_pos.z, 0.01)

func test_should_retreat_true_when_health_low():
    # Arrange
    var health_pct = 10.0
    var distance_to_safety = 100.0

    # Act
    var should_retreat = brain.should_retreat(health_pct, distance_to_safety)

    # Assert
    assert_true(should_retreat, "Should retreat when health is low")

func test_is_safe_true_when_health_recovered():
    # Arrange
    var health_pct = 50.0  # Above threshold * 2
    var distance_to_threat = 100.0

    # Act
    var is_safe = brain.is_safe(health_pct, distance_to_threat)

    # Assert
    assert_true(is_safe, "Should be safe when health recovered")

func test_is_safe_true_when_far_from_threat():
    # Arrange
    var health_pct = 20.0  # Still low
    var distance_to_threat = 400.0  # Beyond retreat_safe_distance

    # Act
    var is_safe = brain.is_safe(health_pct, distance_to_threat)

    # Assert
    assert_true(is_safe, "Should be safe when far from threat")
```

### Mock Implementations for Testing

```gdscript
# tests/mocks/mock_physics_query.gd
class_name MockPhysicsQuery extends IPhysicsQuery
## Mock physics query for testing - no Godot dependencies

var raycast_results: Dictionary = {}  # Key: "from->to", Value: result dict
var terrain_heights: Dictionary = {}  # Key: "x,z", Value: height

func set_raycast_result(from: Vector3, to: Vector3, result: Dictionary) -> void:
    var key = str(from) + "->" + str(to)
    raycast_results[key] = result

func set_terrain_height(x: float, z: float, height: float) -> void:
    var key = "%d,%d" % [int(x), int(z)]
    terrain_heights[key] = height

func raycast(from: Vector3, to: Vector3, exclude: Array = []) -> Dictionary:
    var key = str(from) + "->" + str(to)
    if raycast_results.has(key):
        return raycast_results[key]
    return {}  # No hit

func sphere_cast(position: Vector3, radius: float, exclude: Array = []) -> Array:
    return []

func get_terrain_height(x: float, z: float) -> float:
    var key = "%d,%d" % [int(x), int(z)]
    if terrain_heights.has(key):
        return terrain_heights[key]
    return 0.0
```

```gdscript
# tests/mocks/mock_drone.gd
class_name MockDrone extends IDrone
## Mock drone for testing - no Godot dependencies

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var forward: Vector3 = Vector3.FORWARD
var health_percentage: float = 100.0
var energy: float = 100.0
var max_speed: float = 60.0

func get_position() -> Vector3:
    return position

func get_velocity() -> Vector3:
    return velocity

func get_forward() -> Vector3:
    return forward

func get_health_percentage() -> float:
    return health_percentage

func get_energy() -> float:
    return energy

func get_max_speed() -> float:
    return max_speed
```

---

## Phase 7: Integration Tests

```gdscript
# tests/integration/test_drone_combat_integration.gd
extends GutTest
## Integration tests for drone combat system

var controller: DroneAIController
var mock_drone: MockDrone
var mock_physics: MockPhysicsQuery
var mock_target: MockTargetable
var command_queue: CommandQueue

func before_each():
    # Setup mocks
    mock_drone = MockDrone.new()
    mock_physics = MockPhysicsQuery.new()
    mock_target = MockTargetable.new()
    command_queue = CommandQueue.new()

    # Create controller
    controller = DroneAIController.new(mock_drone, mock_physics, command_queue)

func test_combat_generates_move_and_fire_commands():
    # Arrange
    mock_drone.position = Vector3(0, 0, 0)
    mock_drone.health_percentage = 100.0
    mock_drone.energy = 100.0

    mock_target.position = Vector3(60, 0, 0)  # At optimal range
    mock_target.velocity = Vector3.ZERO
    mock_target.valid = true

    # Setup LOS = true
    mock_physics.set_raycast_result(
        mock_drone.position,
        mock_target.position,
        {}  # No hit = clear LOS
    )

    controller.set_target(mock_target)

    # Act
    controller.update(0.016)  # One frame

    # Assert
    var history = command_queue.get_execution_history()
    assert_gt(history.size(), 0, "Should have executed commands")

    # Should have move command
    var has_move = false
    var has_fire = false
    for cmd_dict in history:
        if cmd_dict["type"] == "MOVE":
            has_move = true
        if cmd_dict["type"] == "FIRE_WEAPON":
            has_fire = true

    assert_true(has_move, "Should generate move command")
    assert_true(has_fire, "Should generate fire command when aimed")

func test_combat_no_fire_when_low_energy():
    # Arrange
    mock_drone.position = Vector3(0, 0, 0)
    mock_drone.health_percentage = 100.0
    mock_drone.energy = 10.0  # Low energy

    mock_target.position = Vector3(60, 0, 0)
    mock_target.valid = true

    mock_physics.set_raycast_result(mock_drone.position, mock_target.position, {})

    controller.set_target(mock_target)

    # Act
    controller.update(0.016)

    # Assert
    var history = command_queue.get_execution_history()
    for cmd_dict in history:
        assert_ne(cmd_dict["type"], "FIRE_WEAPON", "Should not fire with low energy")
```

---

## Testing Requirements

### Every AI Function Must Have:

1. **Unit Test** - Tests the pure logic in isolation with mocks
2. **Integration Test** - Tests the function working with other systems
3. **Edge Case Tests** - Boundary conditions, error cases
4. **Performance Test** - Verify O(1) or O(log n) complexity where required

### Test Coverage Requirements:

- **Minimum 95% line coverage** for AI brain classes
- **Minimum 85% line coverage** for adapter classes
- **100% coverage** of public API methods
- **All edge cases** must have explicit tests

### No Code Accepted Without Tests

All pull requests must include:
1. Unit tests for all new functions
2. Integration tests for new features
3. All tests passing
4. Coverage report showing requirements met

---

## Migration Strategy

### Step 1: Create Infrastructure (Week 1)
1. Create interface layer
2. Create mock implementations
3. Setup GUT test framework
4. Write first passing test

### Step 2: Migrate Combat AI (Week 2)
1. Extract DroneCombatBrain (pure logic)
2. Write comprehensive unit tests
3. Create GodotCombatAdapter
4. Write integration tests
5. Switch old code to use new system

### Step 3: Migrate Pathfinding AI (Week 3)
1. Extract DronePathfindingBrain
2. Write unit tests
3. Create adapter
4. Integration tests

### Step 4: Performance Systems (Week 4)
1. Implement spatial partitioning
2. Implement LOD system
3. Add performance tests
4. Benchmark improvements

### Step 5: Squad AI (Week 5-6)
1. Apply same pattern to squad AI
2. Queue-based command system
3. All tests passing

---

## Success Criteria

- [ ] 100% of AI functions have unit tests
- [ ] 100% of AI features have integration tests
- [ ] All tests pass on every commit
- [ ] 95%+ test coverage
- [ ] No Godot dependencies in AI brain classes
- [ ] Can run 100 drones at 60fps
- [ ] Can replay AI commands for debugging
- [ ] Clear separation of concerns

---

## Benefits of This Architecture

1. **Testable** - Pure logic classes with no Godot dependencies
2. **Debuggable** - Command queue can be recorded and replayed
3. **Performant** - Spatial partitioning and LOD built in
4. **Maintainable** - Clear interfaces and single responsibility
5. **Extensible** - Easy to add new behaviors without breaking existing code
6. **Verifiable** - 100% test coverage proves correctness
