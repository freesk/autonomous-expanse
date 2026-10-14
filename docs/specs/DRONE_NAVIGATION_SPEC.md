# NAVIGATION CORE RULE

## FUNDAMENTAL PRINCIPLE

**COMMAND ONCE, WAIT FOR COMPLETION**

When commanding a drone or squad to navigate to a position:
1. Call `pathfinding.set_target(position)` **EXACTLY ONCE**
2. **NEVER** call it again in `_process()` or any loop
3. **WAIT** for the drone to reach the position autonomously
4. The drone's pathfinding AI handles all navigation internally

## WHAT THIS MEANS

### ✅ CORRECT - Command Once
```gdscript
func start_gathering(poi: Node3D) -> void:
    # Calculate positions
    var mining_pos = calculate_position()

    # Command ONCE
    var pathfinding = drone.get_node("OrchestratorAI").pathfinding_ai
    pathfinding.set_target(mining_pos)  # ONCE!

    # Never call set_target again - drone navigates autonomously
```

### ❌ WRONG - Continuous Commanding
```gdscript
func _process(delta: float) -> void:
    var mining_pos = calculate_position()

    # NEVER DO THIS - calling every frame!
    pathfinding.set_target(mining_pos)  # BAD!
```

## WHY THIS RULE EXISTS

1. **Drone Pathfinding AI is Autonomous** - It generates waypoints, avoids obstacles, and navigates on its own
2. **Prevents Command Spam** - Continuous commands cause waypoint regeneration every frame
3. **Performance** - Single command is efficient, continuous commanding wastes CPU
4. **Predictable Behavior** - Drones complete their navigation without interference

## HOW TO CHECK IF POSITION IS REACHED

### Option 1: Distance Check (Polling)
```gdscript
func _process(delta: float) -> void:
    var distance = drone.global_position.distance_to(target_position)
    if distance < threshold and not already_at_position:
        already_at_position = true
        on_position_reached()  # Do something once
```

### Option 2: Event/Callback (Better)
```gdscript
# Drone signals when it reaches destination
drone.connect("destination_reached", self, "_on_drone_arrived")
```

## APPLIES TO ALL NAVIGATION

This rule applies to:
- ✅ Squad navigation to POIs
- ✅ Squad navigation to motherships
- ✅ Mining position assignment
- ✅ Combat maneuvering
- ✅ Retreat movements
- ✅ ALL movement commands

## SQUAD-LEVEL WAYPOINTS

Squad navigation can generate multiple waypoints, but:
- Command drones to each waypoint **ONCE**
- Wait for majority of drones to reach waypoint
- Then command **ONCE** to next waypoint
- **NEVER** command continuously in a loop

## MICROMANAGEMENT vs COMMANDING

"Micromanagement" means:
- ✅ Checking drone positions (read-only monitoring)
- ✅ Updating aim targets as needed
- ✅ Enabling/disabling firing
- ❌ **NOT** calling `set_target()` every frame

Position corrections should be done through:
- Velocity adjustments via `set_ai_movement()` if absolutely necessary
- **NOT** by repeatedly calling `set_target()`
