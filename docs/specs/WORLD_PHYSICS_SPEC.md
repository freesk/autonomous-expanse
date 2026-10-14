# World Physics Specification

## Physics Engine: JoltPhysics

**CRITICAL:** This project uses **Jolt Physics** (built into Godot 4.4+), not default Godot Physics.

**Rationale:** Superior performance and stability for complex dynamic scenes with many interactable objects.

**Configuration:**
```
Project Settings → Physics → 3D → Physics Engine = "Jolt Physics"
```

**Reference:** See `REAL_PHYSICS_RESEARCH.md` for technical implementation details.

---

## Core Physics Principles

### Everything is Interactable
- **ALL objects in the world use real physics simulation**
- Gravity affects everything (unless explicitly anchored)
- Forces propagate realistically through the environment
- No fake kinematic approximations

### Consistent Physics Everywhere
- **NO zone modifiers** (no low-gravity zones, no physics-change areas)
- **NO environmental variations** (no wind, no atmospheric effects)
- **NO water/buoyancy** (not in MVP)
- **NO environmental hazards** (no damage zones)
- Uniform gravity: Godot default (9.8 m/s²)

---

## World Objects

### 1. Terrain/Ground
**Type:** `StaticBody3D`
- Collision mesh only
- Never moves or deforms
- Provides collision surface for hover raycasts
- No destructibility

### 2. Buildings & Structures
**Type:** `RigidBody3D` (destructible with advanced physics)
- Can be damaged and destroyed
- Break apart into physics debris when destroyed
- Pieces fall realistically with gravity
- Requires health/damage system
- Can be pushed/moved by explosions

**Implementation:**
- Buildings start as static or kinematic until damaged
- Upon destruction, spawn RigidBody3D debris chunks
- Use Jolt Physics for efficient multi-body simulation

### 3. Natural Obstacles (Rocks, Trees, etc.)
**Type:** `RigidBody3D` (interactable)
- Can be pushed by drones or explosions
- Have mass and inertia
- Collide realistically
- Can be destroyed in advanced scenarios

---

## Dynamic Objects

### 1. Cargo/Packages
**Status:** NOT in MVP
- No pickup/carry system
- No cargo physics objects
- May be added post-MVP

### 2. Weapon Projectiles

**Energy Burst Projectiles (from DRONE_WEAPON_SPEC.md):**
**Type:** `Area3D` (not RigidBody3D)
- Fast-moving energy bolts (500 units/sec)
- **NOT affected by gravity** (energy-based, not kinetic)
- Travel in straight line from fire direction
- Use Area3D for collision detection (performance)
- Pooled/recycled to reduce instantiation cost

**Laser Weapons:**
**Type:** Hitscan (RayCast3D)
- Instant hit
- No projectile physics
- Simple raycast from weapon to target

**Key Decision:** Energy projectiles are **NOT physics objects** - they're fast-moving Area3D nodes with custom motion code. This keeps them predictable and performant.

### 3. Explosions
**Type:** Radial force impulse
- Apply radial forces to nearby RigidBody3D objects
- Push drones, debris, and destructible structures
- Force magnitude decreases with distance
- Visual-only effects for non-physics objects

**Implementation:**
```gdscript
func explode(position: Vector3, force: float, radius: float):
    var space_state = get_world_3d().direct_space_state
    var nearby = get_bodies_in_sphere(position, radius)

    for body in nearby:
        if body is RigidBody3D:
            var direction = (body.global_position - position).normalized()
            var distance = body.global_position.distance_to(position)
            var falloff = 1.0 - (distance / radius)
            var impulse_force = direction * force * falloff
            body.apply_central_impulse(impulse_force)
```

---

## Drones

### Physics Body
**Type:** `RigidBody3D` (force-based physics)
- Real gravity affecting all drones
- Hover forces counter gravity (spring-damper system)
- True F=ma physics (mass affects acceleration)
- See `REAL_PHYSICS_RESEARCH.md` for complete implementation

### Mass Differentiation
**YES** - Different drone types have different masses:
- **Scout/Explorer:** 500-600 kg (light, agile)
- **Combat:** 700-800 kg (balanced)
- **Heavy:** 900-1200 kg (slow, tanky)

Mass directly affects:
- Acceleration (F=ma)
- Momentum
- Turn rate
- Hover force requirements

### Drone-to-Drone Collisions
**Bounce with physics:**
- Drones collide and push each other around realistically
- Collision impulses transfer momentum
- May cause damage on high-velocity impacts
- Prevents drones from stacking/clipping

**Configuration:**
```gdscript
# RigidBody3D settings for drones
continuous_cd = true  # Prevent tunneling at high speed
contact_monitor = true  # Detect collisions
max_contacts_reported = 4  # Track collision contacts
```

### Drone-Terrain Collisions
**Depends on impact velocity:**
- **Low speed (<5 m/s):** Bounce off, no damage
- **Medium speed (5-15 m/s):** Bounce + take minor damage
- **High speed (>15 m/s):** Take significant damage, possibly destroy
- Use collision impulse magnitude to determine severity

---

## Physics Layers & Masks

### Layer Configuration
```
Layer 1: Terrain/Static Geometry
Layer 2: Drones
Layer 3: Destructible Structures
Layer 4: Debris/Objects
Layer 5: Weapon Projectiles (Area3D)
```

### Collision Matrix
```
Terrain (1):     Collides with all
Drones (2):      Collides with 1, 2, 3, 4, 5
Structures (3):  Collides with 1, 2, 4, 5
Debris (4):      Collides with 1, 2, 3, 4
Projectiles (5): Collides with 1, 2, 3
```

**Rationale:**
- Projectiles don't collide with debris (performance)
- Drones collide with everything (realism)
- Debris doesn't collide with other debris initially (optimization, can be enabled later)

---

## Performance Optimization

### Physics Object Budget
**Target:** 6-15 active drones + 50-100 dynamic objects
- Use Jolt Physics for better multi-body performance
- Enable sleeping for debris/structures when stationary
- Never sleep drones (can_sleep = false)
- Pool projectiles (reuse Area3D nodes)

### Sleep Configuration
```gdscript
# Drones
can_sleep = false  # Always active

# Destructible structures
can_sleep = true  # Sleep when stationary

# Debris
can_sleep = true  # Sleep after 2 seconds of no movement
```

### LOD for Physics
- Simplified collision shapes for distant objects
- Disable collision for objects far from player
- Reduce physics tick rate for distant objects (if Jolt supports it)

---

## Implementation Checklist

- [ ] Enable Jolt Physics in Project Settings
- [ ] Convert drones to RigidBody3D (see REAL_PHYSICS_RESEARCH.md)
- [ ] Implement hover suspension system (spring-damper with raycasts)
- [ ] Set up physics layers and collision masks
- [ ] Implement drone-drone collision damage system
- [ ] Implement terrain collision damage based on velocity
- [ ] Create explosion radial force system
- [ ] Set up destructible building system (break into debris)
- [ ] Implement energy burst projectiles (Area3D with custom motion)
- [ ] Test performance with 15 drones + 50 dynamic objects
- [ ] Tune spring-damper hover parameters for "gentle float" feel

---

## References

- **Physics Implementation:** `REAL_PHYSICS_RESEARCH.md`
- **Weapon Systems:** `DRONE_WEAPON_SPEC.md`
- **Jolt Physics Docs:** https://docs.godotengine.org/en/latest/tutorials/physics/using_jolt_physics.html
- **Godot Physics Layers:** https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html#collision-layers-and-masks
