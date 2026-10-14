# Faction AI System - Design Specification

**Project**: Autonomous Expanse
**Version**: 2.0
**Date**: 2026-03-08
**Merged from**: FACTION_AI_SPEC.md v1.0 + SQUAD_AI_SPEC.md

## Table of Contents

1. [System Overview](#system-overview)
2. [Core Components](#core-components)
3. [AI Goal System](#ai-goal-system)
4. [Navigation & Pathfinding](#navigation--pathfinding)
5. [Squad Behavior](#squad-behavior)
6. [Combat System](#combat-system)
7. [Mining & Resource Economy](#mining--resource-economy)
8. [Component Architecture](#component-architecture)
9. [Performance & Optimization](#performance--optimization)

---

## System Overview

### Design Philosophy

The faction AI system follows these core principles:

1. **Squad-level AI only** - Individual drones have no autonomous decision-making
2. **Priority-based goals** - Higher priority goals interrupt lower priority ones
3. **Single active goal** - Each squad has ONE goal at a time
4. **Simple state machines** - Avoid deep conditional nesting
5. **Event-driven triggers** - Minimize reliance on timers

### World Configuration

- **3 Factions**: All factions are at war with each other
- **9 Motherships**: 3 per faction, distributed across the map
- **Resource Nodes**: Points of interest for gathering
- **Dynamic Squads**: Spawned from motherships, size 1-5 drones
- **Player Faction**: Player is initially neutral to all factions until provoked

---

## Core Components

### FactionManager (Singleton)

**Responsibility**: Global faction state management

**Key Data**:
- List of all factions
- All active squads across all factions
- All motherships
- All resource nodes/POIs
- Global configuration (max squads, spawn intervals, AI tick rate)

**Key Functions**:
- Initialize factions with hostile relations to each other
- Initialize all factions as neutral to player (until player attacks)
- Spawn motherships
- Get faction data by ID
- Query faction relations (hostile/neutral/allied)
- Update faction-player relations when player attacks faction

### Faction

**Responsibility**: Faction-level data and squad management

**Key Data**:
- Faction identity (ID, name, color)
- Relations dictionary (faction_id → relation value -100 to 100)
  - All other factions initialized at -100 (hostile/at war)
  - Own faction at 0 (neutral to self)
- Player relation value (-100 to 100, starts at 0 = neutral)
- Owned motherships and squads
- Combat behavior settings (retreat ratios)
- Statistics (resources collected, kills, losses)

**Key Functions**:
- Spawn squads from motherships
- Track faction assets
- Remove destroyed squads

---

## Faction Relations

### Faction-to-Faction Relations

**All Factions at War**:
- Each faction has relation value of -100 (hostile) to all other factions
- Faction A vs Faction B: -100 (hostile)
- Faction A vs Faction C: -100 (hostile)
- Faction B vs Faction C: -100 (hostile)

**Combat Behavior**:
- Squads will engage enemy faction squads on sight within detection range
- No alliances or truces between factions
- Factions compete for resources, territory, and dominance

**Self-Recognition**:
- Squads recognize their own faction (relation = 0, neutral to self)
- Squads do not attack other squads from same faction

### Faction-to-Player Relations

**Initial State**:
- All factions start with relation value 0 (neutral) to player
- Factions ignore player until provoked
- Player can observe faction warfare without interference

**Triggering Hostility**:
- Player damages any drone from a faction → that faction becomes hostile (-100)
- Relation change is permanent and faction-wide
- Other factions remain neutral unless player attacks them

**Independent Relations**:
- Each faction tracks its own relation to player separately
- Attacking Faction A does not make Faction B or C hostile
- Player can remain neutral, pick sides, or fight all factions

---

## AI Goal System

### Goal Enumeration

| Goal State           | Description                          |
| -------------------- | ------------------------------------ |
| IDLE                 | Waiting at mothership                |
| PATROL               | Moving between locations             |
| MOVE_TO_RESOURCE     | Navigating to resource node          |
| GATHER_RESOURCE      | Mining/collecting at resource node   |
| MOVE_TO_MOTHERSHIP   | Returning home                       |
| COMBAT               | Engaging enemies                     |
| RETREAT              | Fleeing from combat                  |

**Naming Convention**: States use `MOVE_TO_*` for navigation goals

### Priority Levels

| Priority | Level  | Goals                             | Description                           |
| -------- | ------ | --------------------------------- | ------------------------------------- |
| 0        | URGENT | COMBAT, RETREAT                   | Immediate survival responses          |
| 1        | HIGH   | MOVE_TO_MOTHERSHIP                | Return when damaged or full resources |
| 2        | MEDIUM | GATHER_RESOURCE, MOVE_TO_RESOURCE | Economic activity                     |
| 3        | LOW    | PATROL, IDLE                      | Default behaviors                     |

### Goal State Machine

```
     ┌─────────┐
     │  IDLE   │
     └────┬────┘
          │
          ├──[timer/random]──────────► PATROL
          │
          ├──[resource node spotted]─► MOVE_TO_RESOURCE ─► GATHER_RESOURCE
          │                                                      │
          │                                                      │
          │                                              [resources full/depleted]
          │                                                      │
          │                                                      ▼
          └──[arrive at mothership]───────────────────► MOVE_TO_MOTHERSHIP
                                                                 │
                                                      [deliver resources]
                                                                 │
          ┌────────────────────────────────────────────────────┘
          │
          ├──[enemy detected]───────────────► COMBAT
          │                                      │
          │                                [outnumbered/damaged]
          │                                      │
          └──[enemy eliminated/escaped]─────────┴─► RETREAT
                                                       │
                                                [reach safety]
                                                       │
                                                   PATROL/IDLE
```

### State Transition Rules

**Priority System**:
- New goals only activate if their priority is higher or equal to current goal priority
- Combat and Retreat always interrupt any other activity (priority 0)
- Returning home interrupts gathering but not combat (priority 1)

**Transition Logic**:
1. Check for enemies → COMBAT or RETREAT
2. Check if need to return home → MOVE_TO_MOTHERSHIP
3. Look for resource opportunities → MOVE_TO_RESOURCE → GATHER_RESOURCE
4. Default behavior → PATROL → IDLE

---

## Navigation & Pathfinding

### Waypoint-Based System

All squad navigation uses waypoint-based pathfinding:

**Waypoint Generation**:
- Generate waypoints at regular intervals (e.g., every 50m)
- Calculate direct path to destination
- Use vertical raycasting to detect terrain height
- Position waypoints above terrain with clearance (e.g., 10m)

**Waypoint Following**:
- Squad moves toward current waypoint
- Advance to next waypoint when within arrival threshold
- Path complete when all waypoints reached

**3D Obstacle Avoidance**:
- Raycast downward from high above to find terrain
- Adjust waypoint Y position to clear obstacles
- Maintain minimum clearance above ground

### Formation Positioning

**At Waypoints**:
- Drones arranged in circular formation around waypoint
- Formation radius based on squad size
- Each drone assigned specific position in circle
- Drones move independently to their formation position

**During Movement**:
- Formation updates as squad advances through waypoints
- Maintains cohesion while navigating terrain

---

## Squad Behavior

### DroneSquad

**Identity**:
- Squad ID, Faction ID
- List of drones (1-5 per squad)
- Starting squad size (for retreat calculations)

**AI State**:
- Current goal
- Goal priority
- Target references (resource node, mothership, enemy squad)

**Navigation Data**:
- Waypoint list
- Current waypoint index
- Waypoint spacing and arrival threshold
- Move speed, formation spacing

**Resources**:
- Resources carried (aggregate or via drone cargo systems)
- Max resource capacity

**Combat**:
- Detection radius
- Combat range
- Retreat speed multiplier

### AI Decision Loop

**Update Frequency**: 0.5 seconds (configurable AI tick rate)

**Decision Priority Order**:

1. **URGENT (Priority 0)**: Combat or Retreat
   - Detect enemies in range (check faction relations)
   - **Player Detection**: Only engage player if faction relation with player is hostile (< 0)
   - If outnumbered or heavily damaged → RETREAT
   - Otherwise → COMBAT
   - If retreating and safe → return to PATROL

2. **HIGH (Priority 1)**: Return Home
   - If cargo full → MOVE_TO_MOTHERSHIP
   - If squad health below threshold → MOVE_TO_MOTHERSHIP

3. **MEDIUM (Priority 2)**: Resource Gathering
   - Find nearest unclaimed resource node
   - Navigate to node → MOVE_TO_RESOURCE
   - Upon arrival → transition to GATHER_RESOURCE
   - Continue until cargo full or node depleted

4. **LOW (Priority 3)**: Patrol
   - Move between faction motherships
   - Idle at mothership when arrived

### Retreat Conditions

**Size-Based**:
- Current squad size / starting squad size < retreat ratio (e.g., 0.5 = 50%)

**Enemy Superiority**:
- Our drones / enemy drones < outnumber threshold (e.g., 1.5 means need 1.5:1 advantage)

**Retreat Destination**:
- Always retreat to nearest friendly mothership

---

## Combat System

### Enemy Detection

**Detection Range**: Configurable per squad (e.g., 50m)
**Field of View**: 360° (omnidirectional awareness)
**Detection Method**: Distance-based scanning of all squads and player

**Hostility Check**:
- Query faction relations via FactionManager
- For squads: Check faction-to-faction relation (< 0.0 = hostile)
- For player: Check faction-to-player relation (< 0.0 = hostile)
- **Player starts neutral**: Player relation = 0.0 initially (not hostile)

### Combat Behavior

**Engagement**:
- Move toward enemy squad until within combat range
- Individual drones attack enemy drones
- Drones use weapon systems (lasers, energy bursts)
- Damage applied per attack interval with cooldowns

**Target Selection**:
- Squad targets closest enemy squad
- Individual drones attack random enemy drone within target squad

**Combat Exit**:
- Enemy destroyed/escaped → return to PATROL
- Squad becomes outnumbered → RETREAT

### Player-Faction Relations

**Initial State**:
- All factions start with 0 (neutral) relation to player
- Factions ignore player during patrol and resource gathering
- Player can freely observe faction activity without aggression

**Relation Changes**:

**When Player Attacks Faction**:
- Player damages any drone from a faction → that faction's player relation becomes -100 (hostile)
- Relation change is permanent and faction-wide
- All squads from that faction will now engage player on sight

**Hostility Scope**:
- Attacking Faction A makes only Faction A hostile
- Factions B and C remain neutral to player
- Player can still attack different factions independently

**Relation Values**:
- `0`: Neutral (default) - faction ignores player
- `-100`: Hostile - faction attacks player on detection
- Future: Could support positive relations for allied gameplay

**Implementation Notes**:
- Track damage source when drones take damage
- If damage source = player → set faction.player_relation = -100
- Detection system checks player_relation before targeting player

---

## Mining & Resource Economy

### Component Architecture

**Three AI Components**:

1. **SquadOrchestratorAI**
   - High-level decision making
   - Locates resource nodes
   - Manages goal transitions

2. **SquadNavigationAI**
   - Waypoint pathfinding
   - Terrain avoidance
   - **Disabled during mining** (SquadMiningAI takes over)

3. **SquadMiningAI**
   - Micromanages drone positioning during gathering
   - Controls laser firing
   - Monitors cargo levels

### Mining Behavior

**Circular Positioning**:
- When entering GATHER_RESOURCE state, SquadMiningAI activates
- Calculate mining positions in circle around resource node
- Position count = number of drones in squad
- Mining radius (e.g., 15m from node center)
- Adjust Y position using terrain height detection

**Mining Execution**:
- Each drone moves to assigned mining position
- Drone aims at resource node center
- Drone fires laser weapon continuously
- As laser fires, drone cargo fills progressively
- Resource node depletes as drones gather

**Cargo Management**:
- Monitor average cargo fill across all squad drones
- When average ≥ 100% → interrupt mining
- Transition to MOVE_TO_MOTHERSHIP
- Return to mothership and unload cargo

**Return Trip**:
- After unloading at mothership → resume resource gathering or patrol

### Cargo System

**All Drones Have CargoSystem**:
- Max capacity defined in drone class (src/drones/), NOT scene files
- Current load tracking
- Fill percentage calculation
- Add/unload resource functions

**Squad-Level Monitoring**:
- Calculate average cargo fill across all drones
- Use average to determine when to return home

### Resource Node Configuration

**Nearly Indestructible**:
- Resource health: 9999999999 (effectively infinite)
- Focus on resource depletion, not node destruction

**Resource Regeneration**:
- Current resources / max resources
- Regeneration rate (e.g., 5 per second)
- Depleted flag when resources reach zero

**Claiming System**:
- Resource nodes can be claimed by squads
- Prevents multiple squads from same faction targeting same node
- Released when squad leaves or node depletes

---

## Component Architecture

### Drone Class

**Core Stats** (defined in `src/drones/*`, NOT scene files):
- Max health, current health
- Damage per second
- Attack cooldown/interval
- Movement speed

**Positioning**:
- Formation position (assigned by squad)
- Mining position (assigned by mining AI)

**Mining State**:
- Mining mode enabled/disabled
- Mining target reference
- Laser firing state

**Cargo**:
- CargoSystem component (attached at runtime)

**Movement Behavior**:
- If in mining mode → move to mining position
- Otherwise → move to formation position
- Physics-based movement with velocity

**Combat Functions**:
- Attack target drone
- Take damage
- Die and remove from squad

**Mining Functions**:
- Set mining mode
- Aim at target
- Fire/stop laser
- Check if at mining position

### Mothership

**Identity**:
- Mothership ID, owning faction, name
- Position in world

**Zones**:
- Defense range (safe zone for faction)
- Landing range (to deliver resources)

**Resources**:
- Resource storage, max storage
- Receive resources from squads

**Spawning**:
- Spawn cooldown timer
- Min spawn interval
- Can spawn squads when cooldown ready

### Resource Node (POI)

**Resources**:
- Resource type (e.g., "energy")
- Current resources, max resources
- Regeneration rate
- Depleted flag
- Health (set to 9999999999)

**Claiming**:
- Claimed by squad reference
- Can be claimed check
- Claim/release functions

**Gathering**:
- Has resources check
- Gather function (returns actual amount gathered)

---

## Performance & Optimization

### AI Update Rate

- Squad AI updates at configurable interval (e.g., 0.5 seconds)
- Not every frame to reduce CPU load

### Spatial Queries

- Use Area3D nodes for enemy detection instead of distance checks
- Reduces per-frame distance calculations

### Squad Pooling

- Reuse squad objects instead of creating/destroying
- Object pool pattern for spawning

### LOD System

- Disable distant squad AI updates (beyond player view range)
- Reduce update frequency for squads far from action

### AI Limits

- Max squads per faction (e.g., 10)
- Total active squads in scene
- Spawn new squads when others destroyed

---

## Implementation Notes

### Performance Considerations

1. **AI Update Rate**: Run squad AI at 0.5s intervals, not every frame
2. **Spatial Queries**: Use Area3D nodes for enemy detection
3. **Squad Pooling**: Reuse squad objects instead of creating/destroying
4. **LOD System**: Disable distant squad AI updates

### Key Constants

- `MAX_FACTIONS`: 3
- `MOTHERSHIPS_PER_FACTION`: 3
- `MIN_SQUAD_SIZE`: 1
- `MAX_SQUAD_SIZE`: 5
- `HOSTILE_RELATION`: -100.0
- `NEUTRAL_RELATION`: 0.0
- `ALLIED_RELATION`: 100.0

### Key Formulas

**Retreat Based on Size**:
```
should_retreat_size = (current_drones / starting_drones) < run_away_ratio
```

**Retreat Based on Enemy Count**:
```
should_retreat_enemy = (our_drones / enemy_drones) < (1.0 / run_away_vs_enemy)
```

**Resource Gathering Rate**:
```
gathered = min(node.resources, gather_rate * delta)
```

### Testing Checklist

- [ ] Single squad spawns and patrols between motherships
- [ ] Squad detects and navigates to resource node using waypoints
- [ ] Squad mines in circular formation around node
- [ ] Squad cargo fills as lasers fire
- [ ] Squad returns to mothership when cargo full
- [ ] Squad engages enemy squad in range
- [ ] Squad retreats when outnumbered
- [ ] Resource nodes regenerate over time
- [ ] Multiple squads from same faction don't attack each other
- [ ] All 3 factions spawn and behave independently
- [ ] Drones maintain formation during waypoint navigation
- [ ] Combat damage is applied correctly
- [ ] Waypoint pathfinding avoids terrain obstacles

### Future Enhancements

1. **Dynamic Relations**: Add actions that change faction relations
2. **Squad Abilities**: Special powers for different squad compositions
3. **Tech Progression**: Factions research improvements over time
4. **Territory Control**: Zones of influence around motherships
5. **Player Interaction**: Player faction with diplomacy options
6. **Advanced Combat**: Flanking, focus fire, tactical retreats
7. **Supply Lines**: Squads need to resupply at motherships
8. **Faction Personalities**: Aggressive, defensive, economic focus

---

**End of Specification**
