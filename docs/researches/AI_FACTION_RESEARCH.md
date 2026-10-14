# DroneWorld Faction System Design

Based on Kenshi AI faction research (2026-02-28)

## Overview

DroneWorld features 3 autonomous drone factions competing for resources. This document outlines the simplified faction system adapted from Kenshi's design patterns.

## Game Design Specs

### Factions

- **3 drone factions** in total
- Each faction has **3 motherships** (act like cities/home bases)
- Factions compete for resources and territory

### Squads

- Squad size: **1-5 drones** per squad
- No healing mechanics between drones
- Squads are autonomous units with specific goals

### Core Behaviors

1. **Resource Gathering**: Visit and attend Points of Interest (POIs)
2. **Travel**: Navigate between friendly faction motherships
3. **Combat**: Engage enemy factions when encountered

## 1. Simplified AI Goals System

### Core Drone Goals (Simplified from Kenshi's 300+)

We need only **6 core goals** for drone squads:

1. **COMBAT** - Engage enemy drones
2. **FLEE** - Retreat from overwhelming force
3. **GATHER_RESOURCE** - Attend a Point of Interest to collect resources
4. **TRAVEL_TO_MOTHERSHIP** - Navigate to a friendly mothership
5. **PATROL** - Move between POIs and motherships
6. **IDLE** - Wait at mothership or POI

### Priority System (Kenshi-inspired)

Goals use a simple weighting system:

- **Priority 0** (URGENT): Combat response, flee from danger
- **Priority 1** (HIGH): Travel to mothership when damaged/low resources
- **Priority 2** (MEDIUM): Gather resources at POI
- **Priority 3** (LOW): Patrol, idle behaviors

### Goal Assignment

- Goals assigned at **squad level only** (avoids Kenshi's individual/squad conflict issues)
- Each squad has ONE active goal at a time
- Goals transition based on conditions (enemy spotted, resources full, etc.)

### Goal State Transitions

```
IDLE (at mothership)
  → PATROL (timer/random)
  → GATHER_RESOURCE (POI spotted)
  → TRAVEL_TO_MOTHERSHIP (resources full OR damage threshold)
  → COMBAT (enemy detected)
  → FLEE (squad size too small vs enemy)
  → back to IDLE
```

## 2. Faction Configuration (Simplified)

### Faction Properties

Each of the 3 factions has:

```gdscript
faction_id: int                    # 0, 1, or 2
faction_name: String               # e.g., "Alpha Swarm", "Beta Collective", "Gamma Hive"
motherships: Array[Vector3]        # Positions of 3 motherships
faction_color: Color               # Visual identification

# Combat behavior
run_away_ratio: float = 0.5        # Flee when squad reduced to 50% size
run_away_vs_enemy: float = 1.5     # Flee unless outnumbering enemy 1.5:1

# Faction relations
relations: Dictionary = {
    0: 0.0,   # Own faction (neutral baseline)
    1: -100.0, # Enemy faction
    2: -100.0  # Enemy faction
}
```

### Relations System (Simplified)

**Scale**: -100 to +100

**Key Thresholds:**

- **-100 to -1**: Hostile (attack on sight)
- **0**: Neutral (own faction, no squads attack each other)
- **+1 to +100**: Allied (reserved for future diplomacy features)

**Note**: For initial implementation, all 3 factions are hostile to each other. Relations can be expanded later.

### Mothership Properties

Motherships serve as faction "cities":

```gdscript
mothership_id: int
owning_faction: int
position: Vector3
defense_range: float = 100.0       # Safe zone radius
spawn_point: bool = true           # Can spawn squads here
resource_storage: int = 0          # Resources delivered by squads
```

## 3. Lessons from Kenshi (What to Avoid)

### Kenshi's Complexity Problems

Kenshi developers warn about their AI system:

> "We created a beast of code that has its own mind with so many conditions, priorities and overlapping instances that it's frankly impossible for a human to follow"

### Design Principles for DroneWorld

**✓ DO:**

1. **Squad-level AI only** - No individual drone goals (avoids conflicts)
2. **One active goal per squad** - No concurrent timed goals
3. **Simple state transitions** - Clear conditions for goal changes
4. **Priority-based interrupts** - Combat always overrides gathering
5. **Fallback behaviors** - Always have a default IDLE state

**✗ AVOID:**

1. **NO individual + squad AI mixing** - Kenshi's biggest issue
2. **NO complex timer systems** - Use event-based triggers instead
3. **NO deep conditional nesting** - Keep decision trees shallow
4. **NO overlapping priorities** - Each priority level must be distinct

## 4. Squad AI Implementation

### Squad Structure

```gdscript
class_name DroneSquad extends Node3D

var squad_id: int
var faction_id: int
var drones: Array[Drone] = []      # 1-5 drones
var current_goal: AIGoal
var goal_priority: int
var target_position: Vector3
var target_poi: POI
var target_mothership: Mothership
var resources_carried: int = 0
var max_resources: int = 100
```

### AI Goal Enum

```gdscript
enum AIGoal {
    IDLE,
    PATROL,
    GATHER_RESOURCE,
    TRAVEL_TO_MOTHERSHIP,
    COMBAT,
    FLEE
}
```

### Decision Making (Per Frame or Interval)

```gdscript
func update_squad_ai():
    # Priority 0: URGENT - Combat/Flee
    var enemies = detect_enemies_in_range()
    if enemies.size() > 0:
        if should_flee(enemies):
            set_goal(AIGoal.FLEE, 0)
            return
        else:
            set_goal(AIGoal.COMBAT, 0)
            return

    # Priority 1: HIGH - Return home if needed
    if resources_carried >= max_resources or squad_damaged():
        set_goal(AIGoal.TRAVEL_TO_MOTHERSHIP, 1)
        return

    # Priority 2: MEDIUM - Gather resources
    var nearby_poi = find_nearest_unclaimed_poi()
    if nearby_poi != null:
        set_goal(AIGoal.GATHER_RESOURCE, 2)
        target_poi = nearby_poi
        return

    # Priority 3: LOW - Patrol or idle
    if current_goal == AIGoal.IDLE:
        set_goal(AIGoal.PATROL, 3)
```

## 5. World-Level Behaviors

### Squad Spawning

Each faction spawns squads from motherships:

```gdscript
func spawn_squad(mothership: Mothership, faction_id: int):
    var squad_size = randi_range(1, 5)  # Random 1-5 drones
    var squad = DroneSquad.new()
    squad.faction_id = faction_id

    for i in range(squad_size):
        var drone = spawn_drone(mothership.position)
        squad.drones.append(drone)

    squad.set_goal(AIGoal.PATROL, 3)
    return squad
```

### Resource Gathering at POIs

Points of Interest provide resources:

```gdscript
class_name POI extends Node3D

var resource_type: String
var current_resources: int = 100
var max_resources: int = 100
var regeneration_rate: float = 1.0  # Per second
var claimed_by_squad: DroneSquad = null

func gather(squad: DroneSquad, delta: float):
    var gather_amount = min(current_resources, squad.gather_rate * delta)
    current_resources -= gather_amount
    squad.resources_carried += gather_amount
```

### Mothership Network Travel

Squads navigate between friendly motherships:

```gdscript
func get_next_mothership_destination(current_mothership: Mothership) -> Mothership:
    var faction_motherships = get_faction_motherships(faction_id)
    # Choose random friendly mothership (not current)
    faction_motherships.erase(current_mothership)
    return faction_motherships.pick_random()
```

## 6. Architecture & Implementation Plan

### Component Hierarchy

```
FactionManager (singleton)
├── Faction (x3)
│   ├── faction_id, name, color
│   ├── relations: Dictionary
│   ├── motherships: Array[Mothership] (x3 each)
│   └── squads: Array[DroneSquad]
│
├── DroneSquad (multiple per faction)
│   ├── squad_id, faction_id
│   ├── current_goal: AIGoal
│   ├── drones: Array[Drone] (1-5)
│   ├── resources_carried
│   └── AI decision logic
│
└── Drone (individual unit)
    ├── health, position
    ├── parent_squad: DroneSquad
    └── follows squad commands (no individual AI)
```

### Separation of Concerns

- **FactionManager**: Tracks all factions, relations, global state
- **Faction**: Owns motherships and squads, handles spawning
- **DroneSquad**: **ALL AI logic here** - decides goals, navigation, combat
- **Drone**: Dumb unit that follows squad leader, renders visual, handles damage

### Critical Design Rule

**ALL AI decisions happen at SQUAD level, NEVER at individual Drone level.**

This avoids Kenshi's #1 problem: conflicting individual/squad AI.

## 7. Implementation Roadmap

### Phase 1: Basic Faction Setup

- [ ] Create FactionManager singleton
- [ ] Define 3 factions with colors and IDs
- [ ] Place 3 motherships per faction (9 total in world)
- [ ] Set up hostile relations between all factions

### Phase 2: Squad Spawning & Movement

- [ ] Spawn squads (1-5 drones) from motherships
- [ ] Implement IDLE and PATROL goals
- [ ] Basic navigation between motherships
- [ ] Squad maintains formation

### Phase 3: Resource Gathering

- [ ] Create POI nodes in world
- [ ] Implement GATHER_RESOURCE goal
- [ ] Squads collect resources at POIs
- [ ] Implement TRAVEL_TO_MOTHERSHIP with resources
- [ ] Deliver resources to mothership (scoring)

### Phase 4: Combat System

- [ ] Enemy detection in range
- [ ] Implement COMBAT goal (engage enemies)
- [ ] Basic combat mechanics (damage, death)
- [ ] Implement FLEE goal based on squad size ratios

### Phase 5: Polish & Balancing

- [ ] Debug visualization (show current goal, target)
- [ ] Tune priority values and thresholds
- [ ] Balance squad spawn rates
- [ ] Balance resource regeneration
- [ ] Test edge cases

### Debug Visualization Needed

```gdscript
func debug_draw():
    # Show current goal above squad
    draw_label(position, AIGoal.keys()[current_goal])

    # Show faction color
    draw_sphere(position, 2.0, faction.color)

    # Show target line
    if target_position:
        draw_line(position, target_position, Color.YELLOW)

    # Show detection radius
    draw_circle(position, detection_radius, Color.RED.with_alpha(0.2))
```

## 8. Quick Reference: Kenshi Concepts → DroneWorld

| Kenshi Concept         | DroneWorld Adaptation                                     |
| ---------------------- | --------------------------------------------------------- |
| 300+ AI Goals          | 6 core goals (IDLE, PATROL, GATHER, TRAVEL, COMBAT, FLEE) |
| Squad AI Packages      | Single goal per squad with priority-based transitions     |
| Healing strangers      | **Removed** - drones don't heal                           |
| Run away ratios        | Flee at 0.5 squad size OR 1.5:1 enemy ratio               |
| Relations -100 to +100 | Simplified: -100 (hostile), 0 (own faction)               |
| Cities/Towns           | Motherships (3 per faction)                               |
| Resource gathering     | POIs with regenerating resources                          |
| Faction patrols        | Squads travel mothership-to-mothership                    |
| Player faction         | Not implemented (AI factions only)                        |

## Original Research References

This design is based on research of Kenshi's faction system:

- Kenshi Wiki: AI Goals - https://kenshi.fandom.com/wiki/AI_Goals
- Kenshi Modding Wiki: FCS Faction - https://kenshi-modding.fandom.com/wiki/FCS:_Faction
- Kenshi Wiki: Guide to Faction Relations - https://kenshi.fandom.com/wiki/Guide_to_Faction_Relations
