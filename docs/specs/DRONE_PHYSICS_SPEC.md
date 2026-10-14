# DroneWorld - Drone Physics Specification

## Vehicle Type: HOVER VEHICLES ONLY

**CRITICAL DESIGN DECISION:**
- ALL playable vehicles are HOVER drones
- NO ground vehicles (no wheels, tanks, cars, etc.)
- NO traditional flying vehicles (no planes, helicopters with aerodynamic lift)
- ONLY hover technology using thrust-based flight
- The mothership is a stationary GROUND STRUCTURE, not a vehicle

## Core Physics Model

**Physics Engine:** Godot 4 3D Physics (CharacterBody3D)
**Coordinate System:** Y-up (Y = vertical, XZ = horizontal plane)
**Gravity:** 9.8 m/s² downward
**Physics Tick Rate:** 60 Hz (physics_process)

---

## Hover Drone Mechanics

All drones are **hover drones** - they use thrust to maintain altitude, not aerodynamic lift.

### Hover System

**Anti-Gravity Thrust:**
- Drones actively counteract gravity with downward thrusters
- Automatic hover stabilization when no input
- Can hover perfectly still (not like planes)
- Vertical movement is direct thrust, not pitch-based

**Altitude Control:**
- **Space (hold):** Apply upward thrust (climb)
- **Shift (hold):** Reduce/reverse thrust (descend)
- **No input:** Maintain current altitude (auto-stabilize)

**No Stall Mechanics:**
- Drones cannot stall (not aerodynamic)
- Can fly at any speed including 0
- Can move in any direction at any time

---

## Movement Physics

### Thrust Model

Each drone has directional thrusters for movement:

**Thrust Forces:**
- **Forward/Back (W/S):** Main engines
- **Strafe (A/D):** Side thrusters
- **Vertical (Space/Shift):** Lift thrusters
- **All thrust directions independent**

**Thrust Application:**
```gdscript
# Pseudocode
var input_dir = Vector3(strafe, vertical, forward)
var thrust_force = input_dir.normalized() * acceleration * mass * delta
velocity += thrust_force
```

### Velocity & Momentum

**Acceleration Model:**
- Linear acceleration when thrust applied
- Reaches max speed over time
- Different acceleration per axis per drone

**Deceleration (Drag):**
- Atmospheric drag opposes velocity
- Drag increases with speed (quadratic: drag = k * velocity²)
- Brings drone to stop when no thrust applied
- Drag coefficient per drone type

**Momentum:**
- Heavier drones have more momentum
- Takes longer to change direction
- Cargo drone most affected when loaded

### Drag Coefficients (per drone)

```
Explorer Drone:     0.15 (low drag, quick stop)
Fighter Type 2:     0.18 (low drag, agile)
Fighter Type 1:     0.22 (medium drag)
Cargo Drone (empty): 0.28 (high drag)
Cargo Drone (full):  0.35 (very high drag)
```

**Effect:**
- Low drag = slides more, longer to stop
- High drag = stops quickly, less sliding

---

## Rotation & Turning

### Rotation Model

**Mouse Look:**
- Mouse controls camera/look direction
- Drone rotates to face look direction
- Rotation speed limited by turn rate

**Turn Rate:**
- Degrees per second (from DRONE_SPEC.md)
- Affected by current velocity
- Faster movement = slower turn rate

**Turn Rate Modifiers:**
```
Base turn rate: drone_turn_rate

If boosting:
  turn_rate *= 0.6  (40% slower turns)

If moving at max speed:
  turn_rate *= 0.8  (20% slower turns)

If hovering (velocity < 2 m/s):
  turn_rate *= 1.2  (20% faster turns)
```

### Roll & Banking (Optional Visual)

**Auto-Bank:**
- Drone rolls slightly when turning
- Visual effect only, doesn't affect physics
- Roll angle based on turn input

```
max_roll_angle = 30 degrees
roll = turn_input * max_roll_angle
```

**Not Required for MVP** (adds feel, not necessary for function)

---

## Energy System

### Unified Energy Pool

**CRITICAL DESIGN:** All drones have a single unified energy pool that powers ALL energy-consuming actions:
- **Boost (Shift):** High-speed movement
- **Jump (Space):** Vertical burst
- **Flying Up (Hold Space):** Continuous upward thrust
- **Weapon Fire:** All weapon systems

**Energy Capacity:**
```
Energy Pool (per drone):
  Explorer:       100 energy units
  Fighter Type 2: 120 energy units
  Fighter Type 1: 100 energy units
  Cargo Drone:    80 energy units
```

**Energy Consumption Rates:**
```
Boost (per second):
  Explorer:       33.3 energy/s (3 seconds at full)
  Fighter Type 2: 30.0 energy/s (4 seconds at full)
  Fighter Type 1: 40.0 energy/s (2.5 seconds at full)
  Cargo Drone:    50.0 energy/s (2 seconds at full)

Jump (instant):
  All drones:     20 energy units

Flying Up (per second):
  All drones:     15 energy/s (continuous drain while held)

Weapon Fire:
  Laser (per second):        15-25 energy/s (continuous drain while firing)
  Energy Burst (per burst):  10-20 energy (varies by drone)
```

**Energy Recharge:**
```
Recharge Rate (per second):
  Explorer:       20 energy/s (5 seconds to full)
  Fighter Type 2: 20 energy/s (6 seconds to full)
  Fighter Type 1: 15 energy/s (6.7 seconds to full)
  Cargo Drone:    10 energy/s (8 seconds to full)

Recharge Delay:
  After any energy consumption: 1 second delay before recharge starts
```

**Energy Management Strategy:**
- Player must balance offense (weapons) with mobility (boost/jump/flight)
- Laser drains energy continuously while firing (can't fire indefinitely)
- Flying up drains energy continuously while held (can't fly forever)
- Cannot boost and fire lasers simultaneously without rapid energy depletion
- Rewards tactical energy management and burst usage
- Forces decision-making in combat (offense vs mobility vs altitude control)

### Boost Behavior

**Activation:**
- Hold **Shift** to boost
- Drains energy continuously
- Boost automatically stops when energy reaches 0
- Cannot boost if energy is depleted

**Speed Multiplier:**
- Max speed *= boost_multiplier (from DRONE_SPEC.md)
- Acceleration increases proportionally
- Applied to all movement axes

**Reduced Control:**
- Turn rate reduced by 40% during boost
- Harder to change direction quickly
- Momentum increases

**Visual/Audio Feedback:**
- Engine trail intensifies
- Afterburner particles
- Louder engine sound
- Screen speed lines (optional)

**HUD Display:**
- Energy bar with color fill (replaces separate boost bar)
- High energy (>60%): Green
- Medium energy (30-60%): Yellow
- Low energy (<30%): Red/Orange
- Recharging: Fill animation
- Shows energy cost preview when hovering over abilities

---

## Collision Physics

### Collision Response: **Slide + Damage**

**Low Speed Collision (< 10 m/s):**
- Slide along surface
- No damage
- Velocity redirected parallel to surface
- Friction applied (slow down while sliding)

**Medium Speed Collision (10-20 m/s):**
- Slide along surface
- Minor damage (5-10% max health)
- Bounce slightly away from surface
- Lost speed proportional to impact angle

**High Speed Collision (> 20 m/s):**
- Heavy damage (15-30% max health)
- Hard bounce away from surface
- Stun effect (0.5 seconds can't control)
- Screen shake and impact effects

### Collision Damage Formula

```gdscript
var impact_speed = velocity.length()

if impact_speed < 10.0:
    damage = 0
    collision_mode = SLIDE
elif impact_speed < 20.0:
    damage = (impact_speed - 10.0) * 2.0  # 0-20 damage
    collision_mode = SLIDE_BOUNCE
else:
    damage = 20.0 + (impact_speed - 20.0) * 3.0  # 20+ damage
    collision_mode = HARD_BOUNCE

# Apply damage
health -= damage * (1.0 - armor_rating)
```

### Surface Types

**Hard Surfaces (terrain, buildings):**
- Full collision response
- Standard damage
- Metallic impact sound

**Soft Surfaces (water, vegetation):**
- Reduced damage (50%)
- Slower slide
- Splash/rustle effects

**Destructible Surfaces:**
- Break on high-speed impact
- Reduced damage to player
- Debris particles

---

## Terrain Interaction

### Ground Proximity

**Hover Height:**
- Drones try to maintain minimum height above ground
- Auto-stabilization prevents accidental ground collision
- Can be disabled for precise low-flying

**Ground Effect (Optional):**
- Slightly increased lift near ground
- Visual: Dust/debris kicked up
- Audio: Ground turbulence sound

### Altitude Management

**No Hard Ceiling:**
- Drones can fly as high as map allows
- Performance same at all altitudes (no atmosphere thinning)
- Altitude displayed on HUD

**Altitude Recommendations:**
```
Safe altitude:        50-200m
Combat altitude:      20-100m
Low-flying:           5-20m (risky, better cover)
High-altitude:        200-500m (safe, harder to engage)
```

### Underwater Behavior

**If Drone Enters Water:**
- Heavy drag applied (drag *= 5.0)
- Speed drastically reduced
- Health drains over time (water damage)
- HUD warning
- Upward thrust to escape

---

## Mass & Cargo System

### Base Mass (from DRONE_SPEC.md)

```
Explorer:     800 kg
Fighter Type 2: 900 kg
Fighter Type 1: 1200 kg
Cargo Drone:  2000 kg
Mothership:   10000 kg
```

### Cargo Mass Effect (Cargo Drone Only)

```
cargo_mass = cargo_count * 50 kg  # 50kg per cargo unit

total_mass = base_mass + cargo_mass

Speed penalty:
  max_speed *= (1.0 - (cargo_count / max_capacity) * 0.2)
  # 20% speed reduction at full cargo

Acceleration penalty:
  acceleration *= (base_mass / total_mass)
  # Heavier = slower acceleration

Turn rate penalty:
  turn_rate *= (base_mass / total_mass)
  # Heavier = slower turning
```

**Example:**
```
Cargo Drone with 6/12 cargo (50% full):
  Mass: 2000 + (6 * 50) = 2300 kg
  Speed: 28 * (1.0 - 0.1) = 25.2 m/s
  Accel: 6 * (2000/2300) = 5.2 m/s²
  Turn: 90 * (2000/2300) = 78°/s
```

---

## Forces Summary

### Active Forces

1. **Thrust** - Player input, moves drone
2. **Gravity** - Constant downward (9.8 m/s²)
3. **Hover Stabilization** - Auto-counteracts gravity
4. **Drag** - Opposes velocity, slows drone

### Force Application Order

```gdscript
func _physics_process(delta: float) -> void:
    # 1. Apply gravity
    velocity.y -= gravity * delta

    # 2. Get input and calculate thrust
    var input = get_input_vector()
    var thrust = input * acceleration * delta

    # 3. Apply hover stabilization (if not manually descending)
    if not Input.is_action_pressed("move_down"):
        var hover_thrust = calculate_hover_thrust(delta)
        thrust.y += hover_thrust

    # 4. Apply thrust
    velocity += thrust

    # 5. Apply drag
    var drag_force = velocity * drag_coefficient * delta
    velocity -= drag_force

    # 6. Clamp to max speed (unless boosting)
    var max = max_speed * boost_multiplier
    velocity = velocity.limit_length(max)

    # 7. Move drone
    move_and_slide()

    # 8. Handle collisions
    handle_collisions()
```

---

## Special Movement Abilities

### Jump Function (All Drones)

**Activation:**
- Press **Space** key (tap, not hold)
- Available on all drone types
- Hold Space = continuous upward thrust (climb, drains energy)
- Tap Space = jump impulse (costs 20 energy)

**Energy Cost:**
- **Jump (instant):** 20 energy units
- **Flying Up (hold Space):** 15 energy/second
- Cannot jump if energy < 20
- Cannot fly up if energy is depleted

**Mechanics:**
- Instant upward velocity impulse
- Brief burst of vertical thrust
- No horizontal momentum change
- Can be used while moving in any direction

**Jump Parameters:**
```
Jump Velocity (per drone):
  Explorer:       20 m/s upward
  Fighter Type 2: 18 m/s upward
  Fighter Type 1: 15 m/s upward
  Cargo Drone:    12 m/s upward (affected by cargo)

Energy Cost:
  All drones:     20 energy units (instant)

Cargo Mass Penalty (Cargo Drone only):
  jump_velocity *= (base_mass / total_mass)
  At 50% cargo: 12 * (2000/2300) = 10.4 m/s
  At 100% cargo: 12 * (2000/2600) = 9.2 m/s
```

**Implementation:**
```gdscript
const JUMP_VELOCITY: float = 20.0  # Per drone type
const JUMP_ENERGY_COST: float = 20.0
const FLY_UP_ENERGY_RATE: float = 15.0  # Per second

func _physics_process(delta: float) -> void:
    # Handle jump input (tap, not hold)
    if Input.is_action_just_pressed("move_up") and energy >= JUMP_ENERGY_COST:
        perform_jump()

    # Handle flying up (hold)
    elif Input.is_action_pressed("move_up") and energy > 0:
        fly_up(delta)

    # ... rest of physics processing

func perform_jump() -> void:
    # Check energy
    if energy < JUMP_ENERGY_COST:
        return

    # Consume energy
    energy -= JUMP_ENERGY_COST

    # Apply instant upward velocity
    velocity.y += JUMP_VELOCITY

    # Effects
    play_jump_sound()
    spawn_jump_particles()

func fly_up(delta: float) -> void:
    # Drain energy over time
    var energy_cost = FLY_UP_ENERGY_RATE * delta
    if energy >= energy_cost:
        energy -= energy_cost
        # Apply upward thrust
        velocity.y += hover_upward_thrust * delta
    else:
        # Not enough energy, stop flying up
        energy = 0
```

**Use Cases:**
- Quick altitude gain
- Dodge ground obstacles
- Evasive maneuver in combat
- Gain height advantage quickly
- Escape from low altitude danger

**Visual/Audio Feedback:**
- Downward thruster burst effect
- Engine flare animation
- Whoosh sound
- Brief camera shake (optional)
- HUD cooldown indicator

**Limitations:**
- Cannot jump while stunned (collision stun)
- Cannot jump if underwater
- Requires 20 energy units minimum
- Cannot fly up if energy depleted
- Respects max altitude (if implemented)
- No air control during jump ascent

**Combining with Other Abilities:**
- Can jump while boosting (both drain energy simultaneously)
- Can jump while firing weapons (all share same energy pool)
- Cannot jump during dash (Fighter Type 2)
- Energy management is critical when combining abilities

---

### Combat Dash (Fighter Type 2 Only)

**Mechanics:**
- Instant velocity burst in input direction
- Ignores drag for duration
- Brief invincibility (0.5s)

```gdscript
func activate_dash():
    var dash_dir = get_input_direction()  # Current input
    velocity = dash_dir * 80.0  # Instant velocity
    is_dashing = true
    invincible = true

    await get_tree().create_timer(1.0).timeout
    is_dashing = false
    invincible = false
```

**Can Dash:**
- Forward/back/strafe/up/down
- Any direction based on current input
- Not locked to facing direction

---

## Environmental Physics

### No Wind System

**Design Decision:** No wind to keep physics predictable and simple.

**Future Consideration:**
- Could add wind in specific zones for variety
- Weather zones with push forces
- Not in MVP

### Weather Effects (Visual Only)

**Rain:**
- Particles only
- No physics impact
- Reduced visibility

**Fog:**
- Visual obscurity
- No physics impact

**Storms:**
- Dramatic visuals
- Screen shake
- No actual wind physics (for now)

---

## Physics Tuning Parameters

### Per-Drone Tuning Values

From DRONE_SPEC.md, here's how they translate to physics:

**Explorer Drone:**
```
max_speed: 45 m/s
acceleration: 12 m/s²
turn_rate: 180°/s
mass: 800 kg
drag_coefficient: 0.15
boost_multiplier: 1.8x
```

**Cargo Drone:**
```
max_speed: 28 m/s
acceleration: 6 m/s²
turn_rate: 90°/s
mass: 2000 kg
drag_coefficient: 0.28
boost_multiplier: 1.4x
cargo_mass_multiplier: 50 kg per unit
```

**Fighter Type 1:**
```
max_speed: 38 m/s
acceleration: 9 m/s²
turn_rate: 140°/s
mass: 1200 kg
drag_coefficient: 0.22
boost_multiplier: 1.6x
```

**Fighter Type 2:**
```
max_speed: 50 m/s
acceleration: 14 m/s²
turn_rate: 200°/s
mass: 900 kg
drag_coefficient: 0.18
boost_multiplier: 2.0x
dash_speed: 80 m/s (instant)
```

### Global Constants

```gdscript
const GRAVITY = 9.8
const HOVER_FORCE_MULTIPLIER = 1.1  # Slightly more than gravity
const COLLISION_DAMAGE_THRESHOLD = 10.0  # m/s
const HIGH_SPEED_COLLISION_THRESHOLD = 20.0  # m/s
const COLLISION_STUN_DURATION = 0.5  # seconds
const BOOST_TURN_PENALTY = 0.6  # 40% slower
const GROUND_PROXIMITY_THRESHOLD = 5.0  # meters
```

---

## Physics Debugging

### Debug Visualizations

**Velocity Vector:**
- Line showing current velocity direction and magnitude
- Color coded: Green (slow), Yellow (medium), Red (fast)

**Collision Shape:**
- Show collision boundaries
- Flash red on collision

**Forces Display:**
- On-screen text showing:
  - Current velocity
  - Applied thrust
  - Altitude
  - Speed
  - Turn rate

**Enable with:**
```gdscript
const DEBUG_PHYSICS = OS.is_debug_build()
```

---

## Performance Optimization

### Physics Updates

**Update Frequency:**
- Player drone: Every physics frame (60 Hz)
- Nearby AI: Every physics frame
- Distant AI: Reduced to 10-20 Hz

**Collision Checks:**
- Use simplified collision shapes (capsules, boxes)
- Disable collision for distant drones
- Layer-based collision filtering

**LOD Physics:**
```
Distance < 50m:  Full physics
Distance 50-200m: Simplified physics (no rotation, basic collision)
Distance > 200m: Kinematic (no physics, just position updates)
```

---

## Testing & Validation

### Physics Feel Checklist

- [ ] Drone responds immediately to input
- [ ] Hover feels stable, not floaty
- [ ] Turning feels responsive but not twitchy
- [ ] Collisions are clear and fair
- [ ] Boost feels powerful and risky
- [ ] Heavy drones feel heavy
- [ ] Light drones feel agile
- [ ] Cargo affects handling noticeably
- [ ] No jittering or stuttering
- [ ] 60 FPS maintained with multiple drones

### Balance Testing

- [ ] Can player stop quickly when needed?
- [ ] Can player navigate tight spaces?
- [ ] Does collision damage feel fair?
- [ ] Is boost duration appropriate?
- [ ] Do different drones feel distinct?
- [ ] Is combat maneuvering satisfying?

---

**Version:** 1.0
**Last Updated:** 2026-02-27
**Status:** Complete Specification
