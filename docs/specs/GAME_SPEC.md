# DroneWorld - Game Specification

## Core Concept

**Genre:** Open World Exploration with Combat, Logistics, and Scanning

**Elevator Pitch:** Pilot various hover drone types across a planetary environment, freely exploring, engaging in combat, transporting cargo, and scanning the world. Switch between drone types to adapt to different challenges in a sandbox experience.

**Vehicle Types:** ALL vehicles are hover drones - they use thrust to maintain altitude, not aerodynamic lift or ground wheels. The mothership is a stationary ground structure, not a vehicle.

## Design Pillars

1. **Freedom of Exploration** - No forced objectives, player-driven discovery
2. **Meaningful Choice** - Different drones for different situations, flexible roles
3. **Emergent Gameplay** - Systems interact to create unique scenarios
4. **Progression Through Discovery** - Unlock content by exploring the world

## Player Experience

### Core Loop
```
Explore World
    ↓
Discover Points of Interest
    ↓
Engage with Environment
    ↓
Earn Resources/Unlock Content
    ↓
Upgrade Drones or Unlock New Types
    ↓
Explore Further
```

### Moment-to-Moment Gameplay
- Pilot a single drone with atmospheric flight physics
- Switch between available drone types at mothership
- Encounter combat, cargo, and scanning opportunities organically
- Make decisions about which drone to use for each situation

## Setting & Environment

**Location:** Planetary surface with atmosphere
**Physics:** Gravity-based flight with atmospheric drag
**Terrain:** Varied biomes, structures, and points of interest

**Environmental Features:**
- Mountains and valleys
- Structures (abandoned facilities, outposts)
- Weather effects (wind, storms)
- Day/night cycle
- Hazardous areas

## Drone Types

All drones can perform most functions but with different efficiency/capabilities.

### 1. Cargo Drone (CargoDroneType1)
**Primary Strength:** Transport capacity
- High cargo capacity
- Moderate speed and maneuverability
- Light defensive weapons
- Durable hull

**Use Cases:**
- Transporting discovered items
- Moving resources between locations
- Can fight if necessary but not optimal

### 2. Explorer Drone (ExplorerDroneType1)
**Primary Strength:** Scanning and detection
- Advanced sensor suite
- High speed and agility
- Minimal weapons
- Long operational range

**Use Cases:**
- Discovering points of interest
- Scanning terrain and objects
- Quick reconnaissance
- Avoiding combat through speed

### 3. Fighter Drone Type 1 (FighterDroneType1)
**Primary Strength:** Combat effectiveness
- Heavy armament
- Agile combat maneuvers
- Medium speed
- Strong shields

**Use Cases:**
- Engaging hostile forces
- Clearing dangerous areas
- Escort missions
- Area defense

### 4. Fighter Drone Type 2 (FighterDroneType2)
**Primary Strength:** Speed and hit-and-run
- Lighter, faster than Type 1
- Moderate weapons
- High maneuverability
- Lower armor, higher speed

**Use Cases:**
- Fast combat strikes
- Evasive combat
- Quick response to threats
- Interceptor role

### 5. Mothership (MotherShip)
**Role:** Stationary ground base and command center
- NOT a vehicle - it's a ground structure
- Drone switching station
- Upgrade facility
- Storage hub
- Safe haven
- Can be relocated to landing zones, but not piloted

## Core Systems

### 1. Hover Flight System
**Hover Mechanics (NOT aerodynamic flight):**
- All drones are hover vehicles using thrust, not lift
- WASD for horizontal movement
- Space/Shift for vertical movement
- Mouse for look/aim
- Inertia and momentum
- Wind effects on movement
- Gravity affects all drones
- Can hover stationary in place
- No stalling - not aerodynamic vehicles

**Parameters per Drone:**
- Max speed
- Acceleration
- Turn rate
- Mass (affects momentum)

### 2. Combat System
**Weapons:**
- ALL drones have TWO weapons: Laser and Energy Burst
- NO kinetic weapons (no bullets, missiles, cannons)
- ONLY energy-based weapons
- Fixed loadout per drone (no customization)

**Combat Mechanics:**
- Free aim targeting (no lock-on system)
- Shield/armor system
- Single damage type (energy)
- Energy management (weapons drain energy)

**Enemies:**
- Hostile drones (same weapon types)
- Automated defense systems
- Environmental hazards

### 3. Cargo System
**Mechanics:**
- Pickup items from world
- Limited cargo capacity per drone
- Transport to destinations
- Drop/deliver cargo

**Cargo Types:**
- Resources (for upgrades)
- Artifacts (for unlocks)
- Mission items (emergent objectives)

### 4. Exploration & Scanning
**Discovery Mechanics:**
- Points of interest marked when detected
- Scanning reveals information
- Map system tracks discoveries
- Environmental storytelling

**Scannable Objects:**
- Resources
- Structures
- Wrecks
- Anomalies
- Wildlife/entities

### 5. Progression System

**Drone Unlocks:**
- Start with Explorer Drone
- Find/earn other drone types through exploration
- Unlock sequence: Explorer → Cargo → Fighter Type 2 → Fighter Type 1 → Mothership upgrades

**Upgrades (Per Drone):**
- Speed enhancement
- Weapon upgrades
- Cargo capacity (for cargo drone)
- Shield/armor improvements

**Map Expansion:**
- Start in safe starting zone
- Unlock new regions by:
  - Finding access points
  - Clearing obstacles
  - Discovering keys/codes

### 6. Mothership System
**Functions:**
- Drone switching point
- Upgrade terminal
- Storage for cargo
- Fast travel point (optional)
- Mission log/journal

**Placement:**
- Can relocate mothership to discovered landing zones
- Strategic positioning for exploration

## World Design

### Zones
1. **Starting Zone** - Safe area, tutorial elements
2. **Resource Zones** - Rich in materials, light hazards
3. **Combat Zones** - Hostile presence, combat challenges
4. **Mystery Zones** - Anomalies, secrets, high-value discoveries
5. **Extreme Zones** - Environmental hazards, endgame content

### Points of Interest
- Abandoned facilities
- Resource deposits
- Wreckage sites
- Ancient structures
- Hostile bases
- Trading posts (if NPCs exist)

## Player Objectives (Emergent)

Since it's sandbox, objectives emerge from gameplay:

**Possible Activities:**
- Clear hostile drones from an area
- Collect rare resources
- Map entire regions
- Find all artifacts
- Upgrade all drones fully
- Discover all POIs
- Survive in extreme zones
- Time trials (speed runs between locations)

## UI/UX Requirements

### HUD Elements
- Drone health/shields
- Speed indicator
- Altitude indicator
- Compass/direction
- Current cargo (if any)
- Weapon status
- Mini-map

### Menus
- Main menu
- Pause menu
- Drone switch interface (at mothership)
- Upgrade menu
- Map/journal
- Settings

## Technical Requirements

### Performance Targets
- 60 FPS on mid-range hardware
- Smooth flight physics
- LOD for distant terrain
- Draw distance appropriate for atmospheric visibility

### Camera System
- Third-person follow camera
- Smooth movement
- Adjustable distance
- Combat-oriented (not too close)

### Save System
- Auto-save at mothership
- Save drone positions
- Save discovered locations
- Save inventory/upgrades

## Audio Design

### Music
- Ambient exploration theme
- Dynamic combat music
- Calm mothership music

### SFX
- Drone engine sounds (different per type)
- Weapon firing
- Impact/explosion sounds
- Scanning beeps
- Pickup sounds
- UI sounds
- Ambient environment

## Scope & Priorities

### MVP (Minimum Viable Product)
- ✅ One playable drone (Explorer)
- ✅ Basic flight controls
- ✅ Small test map
- ✅ Simple scanning mechanic
- ✅ Basic combat (one weapon)
- ✅ Simple upgrade system
- ✅ Mothership as drone switch point

### Phase 2
- All 5 drones functional
- Full combat system
- Cargo mechanics
- Larger map with multiple zones
- Progression system
- Enemy AI

### Phase 3
- Polish and juice
- Full audio implementation
- VFX for all actions
- Complete upgrade tree
- Balanced drone stats
- Optimized performance

### Future/Optional
- Multiplayer co-op
- Procedural world generation
- Story campaign mode
- Building/crafting system
- NPC interactions

## Success Metrics

**Core Experience Goals:**
- Player feels free to explore
- Drone switching feels meaningful
- Each drone type has clear use cases
- Combat is satisfying
- Discovery is rewarding
- Progression feels earned

---

**Version:** 1.0
**Last Updated:** 2026-02-27
**Status:** Initial Specification
