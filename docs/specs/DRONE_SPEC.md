# DroneWorld - Drone Specifications

## Vehicle Type: HOVER ONLY

**ALL vehicles in this game are HOVER drones:**
- They use thrust to maintain altitude, NOT aerodynamic lift
- They are NOT traditional aircraft (no wings, no stalling)
- They are NOT ground vehicles (no wheels, no ground contact required)
- The mothership is a stationary GROUND STRUCTURE, not a vehicle

## Flight Physics Model

**Type:** Semi-Realistic Hover Physics
- Momentum and inertia affect movement
- Atmospheric drag slows drones
- Gravity pulls drones down (counteracted by hover thrust)
- Mass affects acceleration and turning
- Wind can push drones off course
- Can hover perfectly still in place
- Still accessible and fun to control

**Universal Flight Controls:**
- **W/S** - Forward/Backward thrust
- **A/D** - Strafe left/right
- **Space** - Vertical thrust up
- **Shift** - Vertical thrust down (or lower thrust)
- **Mouse** - Look/aim direction
- **Shift (hold)** - Boost (when available)

---

## Drone Type Specifications

### 1. Explorer Drone (ExplorerDroneType1)

**Role:** Reconnaissance, Discovery, Speed

**Model:** `assets/drones/ExplorerDroneType1.glb`

#### Stats
```
Health: 80
Shields: 60
Max Speed: 45 m/s
Acceleration: 12 m/s²
Turn Rate: 180°/s
Mass: Light (800 kg)
Cargo Capacity: 2 units
Boost Duration: 3 seconds
Boost Cooldown: 8 seconds
Boost Speed Multiplier: 1.8x
```

#### Weapon Loadout
- **Primary Weapon:** Laser (continuous beam, instant hit)
- **Secondary Weapon:** Energy Burst (projectile-based, burst fire)
- NO weapon customization - fixed loadout
- Stats vary by drone type

#### Behavior Characteristics
- Fast and agile
- Best for avoiding combat
- Excellent vertical mobility
- Low combat capability
- Quick boost recharge
- Ideal for scouting ahead

#### Audio
- High-pitched engine whine
- Quick thruster bursts
- Light weapon sounds

---

### 2. Cargo Drone (CargoDroneType1)

**Role:** Transport, Logistics, Durability

**Model:** `assets/drones/CargoDroneType1.glb`

#### Stats
```
Health: 150
Shields: 80
Max Speed: 28 m/s
Acceleration: 6 m/s²
Turn Rate: 90°/s
Mass: Heavy (2000 kg)
Cargo Capacity: 12 units
Boost Duration: 2 seconds
Boost Cooldown: 12 seconds
Boost Speed Multiplier: 1.4x
```

#### Weapon Loadout
- **Primary Weapon:** Laser (continuous beam, instant hit)
- **Secondary Weapon:** Energy Burst (projectile-based, burst fire)
- NO weapon customization - fixed loadout
- Defensive focus through durability, not weapons

#### Cargo System
- **Pickup Range:** 8m radius
- **Pickup Method:** Auto-collect when close, press E to collect
- **Cargo Display:** Shows capacity as ratio (7/12)
- **Cargo Types:**
  - Standard Resources (1 unit each)
  - Large Components (2-3 units)
  - Artifacts (1 unit, high value)
- **Drop Cargo:** Press G to drop individual item, Hold G to drop all
- **Speed Penalty:** -10% speed per 50% cargo capacity filled

#### Behavior Characteristics
- Slow but steady
- Tank-like durability
- Poor maneuverability when loaded
- Defensive combat focus
- Requires escort in dangerous areas
- Stable in rough weather

#### Audio
- Deep, heavy engine rumble
- Hydraulic cargo mechanisms
- Shield deployment bass tone
- Slow, powerful weapon fire

---

### 3. Fighter Drone Type 1 (FighterDroneType1)

**Role:** Heavy Combat, Area Control, Assault

**Model:** `assets/drones/FighterDroneType1.glb`

#### Stats
```
Health: 120
Shields: 100
Max Speed: 38 m/s
Acceleration: 9 m/s²
Turn Rate: 140°/s
Mass: Medium (1200 kg)
Cargo Capacity: 3 units
Boost Duration: 2.5 seconds
Boost Cooldown: 10 seconds
Boost Speed Multiplier: 1.6x
```

#### Weapon Loadout
- **Primary Weapon:** Laser (continuous beam, instant hit, HIGH damage)
- **Secondary Weapon:** Energy Burst (projectile-based, burst fire, HIGH damage)
- NO weapon customization - fixed loadout
- Higher damage output than other drones

#### Combat Systems
- **Target Lock:** Hold right-click on enemy to lock missiles
- **Lock Time:** 1.5 seconds
- **Max Locks:** 3 simultaneous targets
- **Weapon Groups:** Can fire primary + secondary together

#### Behavior Characteristics
- Balanced combat platform
- Good staying power in fights
- Moderate speed for repositioning
- Strong frontal assault
- Can take and deal significant damage
- Stable weapon platform

#### Audio
- Mid-range engine roar
- Heavy weapon impacts
- Shield recharge hum
- Missile lock beeping
- Explosion sounds

---

### 4. Fighter Drone Type 2 (FighterDroneType2)

**Role:** Fast Attack, Hit-and-Run, Interceptor

**Model:** `assets/drones/FighterDroneType2.glb`

#### Stats
```
Health: 90
Shields: 70
Max Speed: 50 m/s
Acceleration: 14 m/s²
Turn Rate: 200°/s
Mass: Light (900 kg)
Cargo Capacity: 2 units
Boost Duration: 4 seconds
Boost Cooldown: 8 seconds
Boost Speed Multiplier: 2.0x
```

#### Weapon Loadout
- **Primary Weapon:** Laser (continuous beam, instant hit, FAST fire rate)
- **Secondary Weapon:** Energy Burst (projectile-based, RAPID burst fire)
- NO weapon customization - fixed loadout
- Faster fire rate than other drones

#### Combat Systems
- **Lead Indicator:** Shows where to aim for moving targets
- **Overheat Management:** Weapons overheat with sustained fire
- **Evasion Bonus:** +15% dodge chance from enemy auto-aim

#### Behavior Characteristics
- Glass cannon - high damage, low survivability
- Excellent for quick strikes
- Best vertical mobility of fighters
- Poor sustained combat
- Requires hit-and-run tactics
- Excels at chasing/fleeing

#### Audio
- High-pitched screaming engine
- Rapid-fire weapon sounds
- Dash burst sound effect
- Lightweight impact sounds

---

### 5. Mothership (MotherShip)

**Role:** Stationary Ground Structure, Command Center, Safe Haven

**Model:** `assets/drones/MotherShip.glb`

**IMPORTANT:** The mothership is NOT a vehicle. It is a stationary ground structure that serves as a base.

#### Stats
```
Health: 500
Shields: 300
Max Speed: N/A (not pilotable - stationary structure)
Acceleration: N/A
Turn Rate: N/A
Mass: N/A (ground structure)
Cargo Capacity: 100 units (storage)
```

#### Functionality

**Drone Bay:**
- Switch between owned drones
- View drone status (health, loadout)
- Repair damaged drones automatically (over time)

**Armory:**
- Equip weapons to drone hardpoints
- View weapon stats and ammo
- Unlock new weapons with resources

**Upgrade Terminal:**
- Spend resources on drone upgrades
- View upgrade trees
- Compare stat changes

**Storage:**
- Central cargo repository
- Transfer items between drones and storage
- Organize inventory

**Map & Journal:**
- View discovered locations
- Set waypoints
- Read discovered lore/data logs

**Relocation:**
- Can be moved to discovered landing zones
- Must clear area of hostiles first
- 5-minute deployment time

#### Defense Systems
- **Auto-Turrets:** Defend against nearby hostiles
- **Shield Generator:** Protects landing zone
- **Repair Field:** Slowly repairs drones within 50m

#### Behavior Characteristics
- NOT a vehicle - it's a ground structure
- Cannot be piloted or moved during gameplay
- Safe zone for player
- Strategic positioning matters (choose landing zone carefully)
- Central hub for all activities

#### Audio
- Deep ambient hum
- Mechanical sounds (doors, lifts)
- Computer interface beeps
- Peaceful music when inside

---

## Universal Systems

### Damage Model
**Damage Types:**
- **Energy** - ONLY damage type (lasers and energy bursts)
- NO kinetic damage
- NO explosive damage
- NO EMP damage

**Armor vs Shields:**
- Shields regenerate (10 seconds after last hit)
- Armor does not regenerate (requires repair)
- Different drones have different ratios
- Energy damage affects both shields and armor equally

### Weather Effects on Drones
**Wind:**
- Pushes lighter drones more
- Affects projectile trajectory
- Cargo drone most stable

**Rain/Fog:**
- Obscures vision
- Makes lock-on harder

**Storms:**
- Strong winds, lightning hazards
- Energy weapons less effective
- Risk/reward for exploration

### Upgrade Categories (Per Drone)

**Performance:**
- Speed +10/20/30%
- Acceleration +15/30/45%
- Turn rate +10/20/30%

**Durability:**
- Max health +20/40/60
- Max shields +20/40/60
- Shield recharge rate +25/50%

**Weapons:**
- Damage +15/30/50%
- Fire rate +10/20/30%
- Energy efficiency +15/30/50% (reduces energy cost)

**Utility:**
- Cargo capacity +2/4/8 units (Cargo drone)
- Ability cooldown -20/30/40%

**Cost:** Resources found in the world

---

## Enemy Drones (AI-Controlled)

**IMPORTANT DESIGN RULE:** Enemy/NPC drones use the **exact same models and base stats** as player drones. The only differences are:
1. **Visual appearance** - Hostile color schemes (red/black vs player colors)
2. **AI behavior** - Automated combat tactics vs player control
3. **Weapons** - Same weapon types, but AI-controlled firing patterns

**This means:** If a player is flying an Explorer and fights an enemy Scout (also Explorer model), they have identical speed, health, and maneuverability. The difference is in piloting skill and tactics.

### Enemy Type → Player Drone Mapping

| Enemy Name | Player Drone | Model | Base Stats |
|------------|--------------|-------|-----------|
| **Scout Drone** | Explorer | `ExplorerDroneType1.glb` | **Identical to player Explorer** |
| **Enforcer Drone** | Fighter Type 1 | `FighterDroneType1.glb` | **Identical to player Fighter Type 1** |
| **Heavy Drone** | Cargo | `CargoDroneType1.glb` | **Identical to player Cargo** |
| **Interceptor** | Fighter Type 2 | `FighterDroneType2.glb` | **Identical to player Fighter Type 2** |

---

### Scout Drone = Enemy Explorer (ExplorerDroneType1)

**Uses Player Explorer Stats:**
```
Health: 80 (same as player)
Shields: 60 (same as player)
Max Speed: 45 m/s (same as player)
Acceleration: 12 m/s² (same as player)
Turn Rate: 180°/s (same as player)
Mass: 800 kg (same as player)
```

**AI-Specific Behavior:**
- Patrol Speed: ~20 m/s (AI throttles down during patrol)
- Combat Speed: ~35-45 m/s (AI uses full speed in combat)
- Aggressive chase tactics
- Retreats at 40% health
- Detection: 200m range, 180° FOV
- Loot: 1 energy unit

**Visual Difference:** Red/black hostile colors (vs player blue/white)

---

### Enforcer Drone = Enemy Fighter Type 1 (FighterDroneType1)

**Uses Player Fighter Type 1 Stats:**
```
Health: 120 (same as player)
Shields: 100 (same as player)
Max Speed: 38 m/s (same as player)
Acceleration: 9 m/s² (same as player)
Turn Rate: 140°/s (same as player)
Mass: 1200 kg (same as player)
```

**AI-Specific Behavior:**
- Patrol Speed: ~15 m/s (AI throttles down during patrol)
- Combat Speed: ~30-38 m/s (AI uses full speed in combat)
- Balanced combat tactics (chase + strafe mix)
- Retreats at 25% health
- Detection: 150m range, 120° FOV
- Loot: 2 energy units

**Visual Difference:** Dark red/black hostile colors (vs player red/gray)

---

### Heavy Drone = Enemy Cargo (CargoDroneType1)

**Uses Player Cargo Stats:**
```
Health: 150 (same as player)
Shields: 80 (same as player)
Max Speed: 28 m/s (same as player)
Acceleration: 6 m/s² (same as player)
Turn Rate: 90°/s (same as player)
Mass: 2000 kg (same as player)
```

**AI-Specific Behavior:**
- Patrol Speed: ~10 m/s (AI throttles down during patrol)
- Combat Speed: ~20-28 m/s (AI uses full speed in combat)
- Defensive positioning, area denial
- Rarely retreats (only at 15% health)
- Detection: 100m range, 90° FOV
- Loot: 3 energy units

**Visual Difference:** Dark gray/black hostile colors (vs player orange/yellow)

---

### Interceptor = Enemy Fighter Type 2 (FighterDroneType2)

**Uses Player Fighter Type 2 Stats:**
```
Health: 90 (same as player)
Shields: 70 (same as player)
Max Speed: 50 m/s (same as player)
Acceleration: 14 m/s² (same as player)
Turn Rate: 200°/s (same as player)
Mass: 900 kg (same as player)
```

**AI-Specific Behavior:**
- Patrol Speed: ~20 m/s (AI throttles down during patrol)
- Combat Speed: ~40-50 m/s (AI uses full speed in combat)
- Aggressive pursuit tactics
- Can call reinforcements
- Retreats at 30% health
- Detection: 300m range, 360° radar
- Loot: Speed upgrade components

**Visual Difference:** Crimson/black hostile colors (vs player black/red)

---

### AI Behavior Systems

**Aggression Levels:**
- **Patrol:** Fly set routes, engage if player attacks
- **Alert:** Lock onto target, prepare weapons (1 second warning)
- **Combat:** Active engagement with chase/strafe/evade tactics
- **Retreat:** Flee when health below threshold

**Combat Tactics:**
- **Chase:** Direct aggressive pursuit (Scouts, Interceptors)
- **Strafe:** Circle while firing (Enforcers)
- **Defensive:** Hold position, area denial (Heavy Drones)
- **Evasive:** Barrel rolls, random maneuvers (Light drones when damaged)

**Detection:**
- Visual range based on enemy type
- Field of View (FOV) checks
- Line of sight required
- Alert spreading (nearby enemies warned)
- Environmental modifiers (fog reduces range 25%, night 15%)

**Formation Types:**
- **Single:** Solo patrol
- **Pair:** Two drones (one aggressor, one support)
- **Squad:** 3-4 drones with coordinated attacks
- **Defense:** Stationary defensive positions

---

## Visual Identity (Per Drone)

**Explorer:** Sleek, minimal, aerodynamic, blue/white accents
**Cargo:** Bulky, industrial, visible cargo containers, orange/yellow
**Fighter Type 1:** Angular, armored, weapon hardpoints visible, red/gray
**Fighter Type 2:** Streamlined, aggressive, sharp edges, black/red
**Mothership:** Massive, modular, command tower, silver/blue

**VFX for all:**
- Engine trails (color-coded per drone type)
- Shield hit effects
- Damage sparks and smoke
- Boost afterburner glow
- Weapon muzzle flashes

---

**Version:** 1.1
**Last Updated:** 2026-02-28
**Status:** Complete Specification

**Changelog:**
- v1.1 (2026-02-28): Added Enemy Drone specifications with model mappings
- v1.0 (2026-02-27): Initial specification
