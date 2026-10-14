# Autonomous Expanse - World Specification

## World Overview

**Setting:** Procedurally generated planetary surface with breathable atmosphere

**Biome:** Varied terrain with procedural FBM (Fractal Brownian Motion) generation including plains, rolling hills, and mountains

**Time Period:** Far future with autonomous drone factions competing for resources

**Atmosphere:** Earth-like, supports drone physics with gravity

**Size:** 2000m x 2000m playable area (configurable via `world_size_override`)

**Vehicle Types:** All combat units are hover drones (thrust-based). Motherships are stationary ground structures serving as faction bases.

---

## Environmental Properties

### Atmospheric Physics

```
Gravity: 9.8 m/s² (Earth standard)
Air Density: Standard (affects drag)
```

### Visibility & Render Distance

- Standard Godot 4 rendering with default settings
- Terrain rendered at full detail within view frustum

---

## World Generation System

### Generation Pipeline

The world is procedurally generated through a 4-phase system managed by `WorldGenerator`:

#### Phase 1: Terrain Generation
**File:** `src/world/terrain_generator.gd`

**Algorithm:**
- Procedural FBM (Fractal Brownian Motion) noise
- Domain warping for natural-looking terrain variation
- Power redistribution for height diversity

**Terrain Types:**
- **Plains:** 0-20m elevation (most common)
- **Rolling Hills:** 20-100m elevation
- **Mountains:** 100-300m elevation (rare)

**Technical Details:**
- Mesh-based terrain with collision shapes
- Raycasting used for height queries
- Terrain generated before entity placement

#### Phase 2: Mothership Placement
**File:** `src/world/world_generator.gd`

**Placement Rules:**
- Minimum spacing: 400m between motherships
- Raycasts to find flat terrain suitable for placement
- Each faction receives N motherships (default: 3)
- Motherships placed on terrain surface (not floating)

**Faction Distribution:**
- 1-3 factions supported (configurable in `sandbox_world.gd`)
- Each faction has unique ID, name, and color
- Factions:
  - Faction 0: "Alpha Swarm" (RED)
  - Faction 1: "Beta Collective" (BLUE)
  - Faction 2: "Gamma Hive" (GREEN)

#### Phase 3: POI (Point of Interest) Placement
**File:** `src/world/poi_spawner.gd`

**Resource Types:**
- Iron nodes
- Copper nodes

**Placement Rules:**
- Noise-based distribution algorithm
- Minimum spacing: 200m between resource nodes
- Default count: 18 total resources
- Raycasting ensures placement on terrain surface

**Resource Properties (per node):**
- Starting amount: 500 units
- Harvest rate: 10 units/second
- HP: 200 (destructible)
- Respawn time: 60 seconds after depletion

#### Phase 4: FactionManager Registration
- All motherships registered with FactionManager
- All POIs registered globally
- Initial squad spawning triggered

---

## World Structure

### Scene Hierarchy

**Main Scene:** `scenes/main.tscn`

```
SandboxWorld (Node3D)
├── WorldGenerator (Node3D)
│   ├── Terrain (MeshInstance3D + CollisionShape3D)
│   ├── Motherships/ (Container)
│   │   ├── Mothership_0_0 (FactionMothership)
│   │   ├── Mothership_0_1 (FactionMothership)
│   │   └── ... (3 per faction)
│   └── POIs/ (Container)
│       ├── ResourceNode_0 (IronNode/CopperNode)
│       └── ... (18 total)
├── FreeCamera (Camera3D) - Debug free-flying camera
├── Player (PlayerDrone) - Player-controlled fighter
├── PlayerCamera (Camera3D) - Third-person follow camera
└── DebugUI (CanvasLayer) - Statistics overlay
```

### Configuration

**File:** `src/sandbox/sandbox_world.gd`

**Editable Parameters:**
```gdscript
@export var n_factions: int = 1  # Range: 1-3
@export var n_motherships_per_faction: int = 3
@export var n_squads_per_mothership: int = 3
@export var world_size_override: Vector2 = Vector2(2000, 2000)
```

---

## Mothership Structures

### Mothership Components

**Scene:** `scenes/buildings/faction_mothership.tscn`

**Structure:**
```
Mothership (Node3D)
├── Label3D - "Mothership [Name] [Faction]"
├── Visual (StaticBody3D)
│   └── GLBModel (MeshInstance3D) - 100x scale
└── AssemblyZones (Node3D)
    ├── AssemblyZone1 (Position: +60m, 0m, zone_id=1)
    ├── AssemblyZone2 (Position: -30m, +52m, zone_id=2, rotation: 120°)
    └── AssemblyZone3 (Position: -30m, -52m, zone_id=3, rotation: 240°)
```

**Script:** `src/buildings/mothership.gd`

**Properties:**
- `faction_id`: Integer identifying owning faction
- `faction_name`: Display name ("Alpha Swarm", etc.)
- `faction_color`: Color for visual tinting
- `mothership_id`: Unique ID within faction
- `resource_storage`: Current stored resources (max: 10,000)

**Methods:**
- `initialize(id, faction, color, name, faction_name)` - Setup identity
- `spawn_squad()` - Create new squad via FactionManager
- `receive_resources(amount)` - Accept deliveries from squads
- `get_spawn_position()` - Returns random assembly zone spawn point
- `is_in_landing_zone(position)` - Checks 20m proximity to zones

**Visual Features:**
- Faction-colored glow material on mesh
- Dynamic tinting preserves base textures
- Three evenly-spaced assembly zones (120° apart)

---

## Assembly Zones

### Zone Purpose

Assembly zones are circular areas around motherships where squads:
1. **Spawn** when created (15m above zone)
2. **Deliver** resources after mining
3. **Land** after completing missions

### Zone Structure

**Scene:** `scenes/buildings/assembly_zone.tscn`

**Components:**
```
AssemblyZone (Node3D)
├── ZoneArea (Area3D) - Sphere collision (15m radius)
├── NeonTube (MeshInstance3D) - Visual ring marker
└── Label3D - "Zone 1/2/3"
```

**Script:** `src/buildings/assembly_zone.gd`

**Configuration:**
```gdscript
@export var zone_id: int = 1
@export var zone_radius: float = 15.0
@export var entry_delay: float = 3.0  # Seconds before triggering entry
@export var neon_color: Color = Color.WHITE
@export var tube_radius: float = 15.0
@export var tube_height: float = 1.0
```

**Signals:**
- `player_entered(zone)` - Player drone entered radius
- `player_exited(zone)` - Player drone left radius
- `entry_timer_started(zone)` - 3-second countdown began
- `entry_timer_cancelled(zone)` - Player left before timer finished
- `mothership_entry_triggered(zone)` - Timer completed, enter mothership

**Player Interaction:**
- 3-second delay before triggering mothership entry
- Visual feedback via neon ring color matching faction
- Label shows zone number for identification

**Squad Behavior:**
- Squads spawn 15m above zone center
- Squads navigate to zone when delivering resources
- Zone proximity triggers resource delivery (handled by squad AI)

---

## Navigation System

### World Boundaries

**Type:** Hard boundaries (terrain ends at world size)

**Implementation:**
- World size: 2000m x 2000m (default)
- Terrain ends at edges

### Terrain Navigation

**Height Queries:**
- `WorldManager.get_terrain_height(position: Vector2) -> float`
- Raycasting from above down to terrain
- Used by squad navigation for altitude calculations

**Pathfinding:**
- No A* or navigation mesh
- Direct waypoint-to-waypoint movement
- Squads generate waypoints every 50m
- Cruising altitude: 3m above terrain (avoids ground obstacles)

---

## Resource System

### Resource Nodes

**Scene:** `scenes/props/resource_node.tscn`
**Script:** `scenes/props/resource_node.gd`

**Resource Types:**
```gdscript
enum ResourceType {
    IRON,
    COPPER
}
```

**Node Properties:**
- Starting amount: 500 units
- Harvest rate: 10 units/second (configurable)
- Max HP: 200
- Respawn time: 60 seconds after depletion
- Visual: Glowing ore vein appearance

**States:**
- **Active:** Can be harvested
- **Depleted:** Empty, respawn timer running
- **Destroyed:** HP reached 0 (same as depleted)

**Interactions:**
- Squads harvest automatically when in GATHER_RESOURCE state
- Multiple squads can harvest same node simultaneously
- Node visuals update based on remaining resources

### Resource Flow

1. **Discovery:** Squads use FactionManager to find unclaimed POIs
2. **Claiming:** Squad claims POI (prevents other faction squads from targeting)
3. **Navigation:** Squad flies to POI location
4. **Harvesting:** Squad positions around node, mines at 10 units/sec
5. **Cargo Full:** Squad interrupts mining when cargo reaches 100 units
6. **Delivery:** Squad navigates to mothership assembly zone
7. **Unload:** Resources transferred to mothership storage
8. **Repeat:** Squad finds next unclaimed POI

**Faction Tracking:**
- FactionManager tracks total resources collected per faction
- Displayed in DebugUI overlay

---

## Squad System

### Squad Composition

**Default Spawning (per squad):**
- 1x Explorer drone
- 1x Cargo drone
- 1x Fighter Type 1 drone
- 1x Fighter Type 2 drone

**Total:** 4 drones per squad

**Maximum Squads:**
- 10 squads per faction (hard limit in FactionManager)
- Configurable: `n_squads_per_mothership` in SandboxWorld

### Squad AI Architecture

**File:** `src/ai/squad/squad_orchestrator_ai.gd`

**Design:**
- **Strategic Layer (Squad):** Decides WHAT to do
- **Tactical Layer (Drones):** Executes HOW to do it

**AI Components:**
- `SquadNavigationAI` - Waypoint pathfinding
- `SquadCombatAI` - Combat coordination
- `SquadMiningAI` - Resource harvesting
- `SquadFormationAI` - Circular formation (10m spacing)

### Squad State Machine

**Goals (with priorities):**

1. **ATTACK** (Priority: 0 - URGENT)
   - Trigger: Enemy detected within 200m
   - Behavior: Engage nearest enemy squad/player
   - Combat range: 100m weapon range
   - Duration: Until all enemies destroyed or out of range

2. **RETREAT** (Priority: 0 - URGENT)
   - Trigger: Squad health below threshold OR outnumbered
   - Conditions:
     - `run_away_ratio`: 0.5 (flee if lost 50% of squad)
     - `run_away_vs_enemy`: 1.5 (flee if enemies outnumber 1.5:1)
   - Behavior: Navigate to nearest friendly mothership
   - Interrupts: All other goals

3. **MOVE_TO** (Priority: 3 for resources, 1 for mothership)
   - Sub-goals:
     - `MOVE_TO.RESOURCE` - Navigate to unclaimed POI
     - `MOVE_TO.MOTHERSHIP` - Return to assembly zone
   - Behavior: Generate waypoints, fly to destination
   - Completion: All drones within formation positions

4. **GATHER_RESOURCE** (Priority: 2)
   - Trigger: Arrived at resource POI
   - Behavior: Position around node, mine at 10 units/sec
   - Interrupt: Cargo full (100 units) OR node depleted
   - Completion: Auto-transition to MOVE_TO.MOTHERSHIP

**Goal Interruption System:**
- High-priority goals save interrupted state
- After combat/retreat, resume previous goal if still valid
- Validates: POI not depleted, mothership still exists
- Invalid goals trigger new goal selection

### Squad Navigation

**File:** `src/ai/squad/squad_navigation_ai.gd`

**Waypoint Generation:**
- Waypoints placed every 50m along path
- Altitude: 3m above terrain (reduced from earlier 70m)
- Smooth altitude interpolation from start to end height
- Uses `WorldManager.get_terrain_height()` for queries

**Formation Control:**
- Circular formation around current waypoint
- 10m spacing between drones
- Each drone assigned individual formation offset
- Waypoint "reached" only when ALL drones in position

**Speed Synchronization:**
```gdscript
speed_fraction = slowest_drone_max_speed / fastest_drone_max_speed
# All drones throttled to match slowest member (0.5-1.0 range)
```

**Navigation Flow:**
1. Receive target position from orchestrator
2. Generate waypoints (every 50m)
3. Calculate formation positions around current waypoint
4. Individual drones use PathfindingAI for obstacle avoidance
5. Advance to next waypoint when all drones arrive
6. Destination reached when final waypoint achieved

---

## Faction Management

### FactionManager Autoload

**File:** `src/autoloads/faction_manager.gd`

**Purpose:** Global singleton for cross-faction coordination

**Faction Definitions:**
```gdscript
Faction 0: "Alpha Swarm"      - Color.RED
Faction 1: "Beta Collective"  - Color.BLUE
Faction 2: "Gamma Hive"       - Color.GREEN
```

**Faction Relationships:**
- All factions hostile to each other (-100 relation value)
- Neutral with self (0 relation)
- No diplomacy or dynamic relations

**Global Tracking:**
```gdscript
var all_squads: Array = []           # Every squad in world
var all_motherships: Array = []      # All faction motherships
var all_pois: Array = []             # All resource nodes
```

**Squad Spawning:**
- Max 10 squads per faction
- Spawns at random assembly zone
- Position: 15m above zone center
- Adds components:
  - `OrchestratorAI` (squad AI coordination)
  - `DroneColorizer` (faction color tinting)
  - `HealthBar3D` (combat UI)

**Faction Statistics:**
- Tracks total resources collected
- Tracks squads alive/destroyed
- Tracks motherships alive/destroyed
- Displayed in DebugUI

---

## Audio & Visuals

### Visual Features

- Procedural terrain rendering
- Mothership 3D models with faction-colored glow
- Assembly zone neon ring markers
- Resource node glowing ore visuals
- Drone faction color tinting
- 3D health bars for drones

### UI Elements

- Debug statistics overlay
- Faction resource tracking
- Squad/mothership counts
- Player health/shields

---

## World Interactivity

### Destructible Elements

- Resource nodes (200 HP)
- Drones (variable HP)
- Motherships (if combat implemented)

### Physics

- Drone collision with terrain
- Projectile collision detection
- Basic rigid body physics for drones

---

## Performance & Optimization

### Current Implementation

- Godot 4 default rendering pipeline
- Frustum culling (automatic)
- Standard mesh rendering

**Note:** Performance is acceptable for current scope (2000x2000m world).

---

## Key File Reference

### Scenes
- Main world: `scenes/main.tscn`
- Faction mothership: `scenes/buildings/faction_mothership.tscn`
- Assembly zone: `scenes/buildings/assembly_zone.tscn`
- Resource node: `scenes/props/resource_node.tscn`

### World Generation Scripts
- World controller: `src/sandbox/sandbox_world.gd`
- World generator: `src/world/world_generator.gd`
- Terrain generator: `src/world/terrain_generator.gd`
- POI spawner: `src/world/poi_spawner.gd`

### Building Scripts
- Mothership: `src/buildings/mothership.gd`
- Assembly zone: `src/buildings/assembly_zone.gd`
- Resource node: `scenes/props/resource_node.gd`

### Squad AI Scripts
- Orchestrator: `src/ai/squad/squad_orchestrator_ai.gd`
- Navigation: `src/ai/squad/squad_navigation_ai.gd`
- Formation: `src/ai/squad/squad_formation_ai.gd`
- Combat: `src/ai/squad/squad_combat_ai.gd`
- Mining: `src/ai/squad/squad_mining_ai.gd`

### Autoloads
- Faction manager: `src/autoloads/faction_manager.gd`
- World manager: `src/autoloads/world_manager.gd`

---

## System Flow Summary

### Initialization Flow

1. **SandboxWorld._ready()** triggers world generation
2. **WorldGenerator.generate_world()** executes 4-phase pipeline:
   - Phase 1: Generate terrain mesh and collision
   - Phase 2: Place faction motherships (400m spacing)
   - Phase 3: Distribute resource POIs (200m spacing)
   - Phase 4: Register all entities with FactionManager
3. **Initial squads spawn** from mothership assembly zones
4. **Squads initialize** with 4 drones in circular formation
5. **AI begins execution** - squads seek resources autonomously

### Squad Gameplay Loop

**Normal Operation:**
1. Squad spawns at mothership assembly zone (15m altitude)
2. Find nearest unclaimed resource POI via FactionManager
3. Navigate to POI using waypoint pathfinding (3m cruise altitude)
4. Arrive at POI, transition to GATHER_RESOURCE state
5. Position drones in formation around node
6. Mine resources at 10 units/sec until cargo full (100 units)
7. Auto-transition to MOVE_TO.MOTHERSHIP
8. Navigate to nearest friendly mothership
9. Enter assembly zone, deliver resources
10. Repeat from step 2

**Combat Interruption:**
1. Enemy detected within 200m detection radius
2. Save current goal state (mining/traveling)
3. Transition to ATTACK goal (priority 0)
4. Engage enemy drones with 100m weapon range
5. Individual drones target nearest enemy
6. Combat ends when:
   - All enemies destroyed, OR
   - Enemies flee out of range, OR
   - Squad retreats (outnumbered/damaged)
7. Resume previous goal if still valid

**Retreat Behavior:**
1. Triggered by faction-specific thresholds:
   - Lost 50% of squad members, OR
   - Outnumbered 1.5:1 by enemies
2. Immediately flee to nearest friendly mothership
3. Navigate to assembly zone at max speed
4. Land and "dock" (stop moving)
5. Eventually resume gathering operations

---

## Success Metrics

**Core Functionality:**
- World generates reliably with seed system
- Factions spawn and operate autonomously
- Squads navigate terrain without getting stuck
- Resource economy functions (gather → deliver → repeat)
- Combat interrupts and resumes correctly
- Multiple factions compete without interference

**Performance:**
- Stable framerate with 3 factions (9 motherships, ~27 squads)
- Terrain collision works reliably
- No significant memory leaks during long sessions

**Gameplay Feel:**
- Player can observe faction wars naturally emerging
- Factions behave intelligently (gather, fight, retreat)
- World feels alive despite minimal content
- Player can join faction conflicts meaningfully

---

**Version:** 2.0 (Updated to match implementation)
**Last Updated:** 2026-03-08
**Status:** Reflects actual codebase implementation
