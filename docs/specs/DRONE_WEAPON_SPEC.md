# Drone Weapon System Specification

## Overview
This document outlines the weapon systems available for drones in DroneWorld, including weapon types, mechanics, balancing, and implementation details.

## WEAPON TYPES: ENERGY ONLY

**CRITICAL DESIGN DECISION:**
- ALL drones have ONLY TWO weapon types: **Laser** and **Energy Burst**
- NO kinetic weapons (no bullets, no missiles, no rockets, no projectiles)
- NO explosive weapons
- NO special weapons (mines, flares, etc.)
- ONLY energy-based weapons using the drone's energy system

## Weapon Categories

### 1. Laser Weapons
- **Continuous Beam**: Instant hit, sustained beam damage
- **Characteristics**:
  - Hitscan (instant travel time)
  - Continuous energy drain while firing
  - Precision targeting
  - No reload needed
  - Limited by energy capacity
  - No ammo system

### 2. Energy Burst Weapons
- **Energy Projectiles**: Fast-moving energy bolts
- **Characteristics**:
  - Projectile-based (fast but not instant)
  - Burst fire pattern
  - Energy cost per burst
  - Medium range effectiveness
  - No reload needed
  - Limited by energy capacity
  - No ammo system

## Weapon Properties

Each weapon has the following base properties:

```gdscript
{
    "name": String,
    "type": String,  # laser or energy_burst ONLY
    "damage": float,
    "fire_rate": float,  # shots per second (for burst) or DPS (for laser)
    "range": float,  # maximum effective range
    "energy_cost": float,  # energy consumed per shot/second
    "ammo_capacity": int,  # ALWAYS -1 (no ammo, energy-based only)
    "reload_time": float,  # ALWAYS 0 (no reload, energy regenerates)
    "projectile_speed": float,  # for energy burst only, N/A for laser
    "accuracy": float,  # 0.0 to 1.0
    "weight": float,  # affects drone performance
}
```

## Weapon Mounting System

### Hardpoints
All drones have TWO weapon slots:
- **Primary Weapon Slot**: Laser weapon
- **Secondary Weapon Slot**: Energy Burst weapon

### Weapon Slots
Each drone has a fixed loadout:
- **Primary**: Laser (instant hit, continuous beam)
- **Secondary**: Energy Burst (projectile-based, burst fire)
- NO weapon swapping or customization
- NO hardpoint system needed

## Damage System

### Damage Types
- **Energy**: ONLY damage type in the game
  - Laser: Continuous beam energy damage
  - Energy Burst: Projectile energy damage
- NO kinetic damage
- NO explosive damage
- NO EMP or special damage types

### Damage Calculation
```gdscript
final_damage = base_damage * distance_modifier * shield_armor_modifier
```

- Distance modifier: Damage falloff over distance
- Shield/Armor modifier: Energy damage is consistent against shields and armor
- No critical hit system (keep it simple)

## Weapon Balance

### Weapon Variations by Drone Type
Each drone type has slightly different weapon stats to match their role:

### Example Weapons

#### Laser Weapon (All Drones)
```yaml
type: laser
damage_per_second: 30-50 (varies by drone)
range: 400
energy_cost_per_second: 15-25
ammo_capacity: -1 (energy-based)
reload_time: 0 (continuous)
projectile_speed: N/A (instant)
accuracy: 0.95 (very precise)
weight: N/A
```

#### Energy Burst Weapon (All Drones)
```yaml
type: energy_burst
damage_per_burst: 25-40 (varies by drone)
fire_rate: 2-4 bursts per second
range: 300
energy_cost_per_burst: 10-20
ammo_capacity: -1 (energy-based)
reload_time: 0 (continuous)
projectile_speed: 500
accuracy: 0.85 (good)
weight: N/A
```

## Weapon Effects

### Visual Effects
- Muzzle flash
- Projectile trail
- Impact effects
- Hit markers

### Audio Effects
- Firing sound
- Reload sound
- Impact sound
- Warning sounds (lock-on, overheat)

## Weapon Upgrades

### Modification System
Players can upgrade weapons through the mothership:
- **Damage Boost**: +10-20% damage
- **Rate of Fire**: +10-15% fire rate (Energy Burst only)
- **Energy Efficiency**: -20% energy cost per shot
- **Targeting Computer**: +10% accuracy
- **Beam Focus**: +15% laser range
- **Burst Capacity**: +1 projectile per burst (Energy Burst only)

## Energy Management

### Energy System
Weapons use the drone's energy pool:
- Energy depletes when firing weapons
- Energy regenerates slowly when not firing
- Cannot fire when energy is depleted
- No heat system
- No overheating mechanics

```gdscript
energy_consumption = weapon_energy_cost * fire_rate
energy_regeneration = max_energy * 0.05  # 5% per second (varies by drone)
```

## NO Ammunition System

### Energy-Based Only
- NO ammo system
- NO ammo types
- NO ammo pickups
- NO reload mechanics
- ONLY energy management
- Energy regenerates automatically

## AI Weapon Behavior

### Targeting Priority
1. Threats attacking player
2. Low health targets
3. Closest targets
4. High value targets

### Fire Control
- Lead calculation for moving targets
- Range optimization
- Ammo conservation
- Heat management

## Implementation Notes

### Godot Implementation
- Use Area3D for projectile collision detection
- RayCast3D for instant-hit weapons
- AudioStreamPlayer3D for 3D positioned audio
- GPUParticles3D for visual effects

### Performance Considerations
- Pool projectiles to reduce instantiation
- Limit active projectiles per weapon type
- Use simplified collision for distant projectiles
- LOD for weapon effects based on distance

## Future Enhancements (Energy-Based Only)
- Weapon upgrade system refinements
- Advanced energy burst patterns
- Charged laser shots (hold to charge)
- Energy field abilities
- Shield penetration upgrades
- Energy efficiency improvements
