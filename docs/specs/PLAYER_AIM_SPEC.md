# Player Aiming Feature Specification

## Objective
Implement a mouse-controlled aiming system for the hover drone with free-aim reticle, hybrid drone rotation, and dual weapon support (hitscan + AOE).

> **Note:** This spec integrates with the camera system defined in CAMERA_SPEC.md. Mouse controls the aiming reticle (aiming takes priority), and the drone smoothly rotates to follow where you're aiming. The camera then follows the drone normally with all the adaptive smoothing features. See SPEC_CONFLICTS_RESOLUTION.md for details.

## Requirements Gathered

### Aiming System
- **Type:** Mouse-controlled reticle with circular constraint around screen center
- **Constraint:** Limited radius from center (Ace Combat style) - prevents extreme off-axis aiming
- **Prediction:** Yes - calculate lead targeting for moving targets based on drone velocity

### Drone Rotation
- **Mode:** Hybrid - drone smoothly follows aim direction (replaces direct mouse rotation from hover_physics.gd)
- **Speed:** Fast (1-2 seconds to fully rotate 180°)
- **Behavior:** Weapons can fire before drone fully faces target, but drone continuously rotates toward reticle. Camera follows the drone with adaptive smoothing (see CAMERA_SPEC.md)

### Weapons System
- **Primary (Left Mouse):** Hitscan/instant bullets
- **Secondary (Right Mouse):** Area effect weapons
- **Both support:** Lead targeting prediction for moving targets

### Visual Feedback
- **Crosshair:** Dynamic expanding reticle
  - Expands during movement/firing (accuracy decrease)
  - Contracts when stationary (accuracy increase)
  - Changes color/appearance on target

## Scope

### Included
1. Mouse-controlled reticle UI with circular constraint
2. Reticle position tracking and screen-to-world ray projection
3. Hybrid drone rotation system (replaces current mouse rotation in hover_physics.gd:158-163)
4. Lead targeting calculation accounting for drone velocity
5. Dual weapon firing inputs (left/right mouse)
6. Dynamic crosshair that responds to movement/firing state
7. Basic weapon framework for hitscan and AOE projectiles

### Excluded (Future Enhancements)
- Actual weapon damage/projectile implementation (just framework/firing events)
- Target highlighting system
- Hit markers and damage feedback
- Laser sight/tracer beams
- Multiple weapon types beyond basic hitscan/AOE

## Implementation Approach

### Components to Create

#### 1. AimingSystem.gd
Script for HoverPhysics that manages:
- Mouse reticle position (circular constraint)
- Screen-to-world raycast from reticle
- Lead targeting calculation
- Weapon firing events

#### 2. ReticleUI.gd
Control node for visual crosshair:
- Dynamic size based on movement/accuracy
- Position follows mouse within circular bounds
- Color changes on target acquisition

#### 3. WeaponManager.gd
Manages weapon states:
- Primary weapon (hitscan) on left mouse
- Secondary weapon (AOE) on right mouse
- Energy consumption integration
- Fire rate limiting

### Modifications Required
- **hover_physics.gd:158-163** - Remove `_input()` mouse rotation handler (conflicts with reticle control)
- **hover_physics.gd** - Add aiming system integration and hybrid rotation logic
- Add new child nodes to player drone scene for UI/weapons
- **Note:** Camera system (CAMERA_SPEC.md) remains unchanged - it follows the drone as the drone rotates toward aim

### Integration Points
- Uses existing `current_energy` and `consume_energy()` from HoverPhysics
- Works with existing camera system (CAMERA_SPEC.md) - camera follows drone, drone follows reticle
- Respects physics-based movement
- Hybrid rotation triggers camera's combat mode for reduced smoothing (responsive aiming feel)

## Technical Details

### Circular Constraint Math
- Reticle position = center + (mouse_offset clamped to radius)
- Radius suggestion: ~30% of screen size from center

### Hybrid Rotation
- Calculate angle between drone forward and aim direction
- Apply torque proportional to angle difference
- Rotation speed: complete 180° turn in ~1-2 seconds
- Use existing `turn_torque` property, increase magnitude

### Lead Targeting
- Project reticle ray into 3D world
- For moving targets: calculate intercept point
- Account for drone's own velocity vector
- Formula: `aim_point = target_pos + (target_vel - drone_vel) * time_to_hit`

### Dynamic Crosshair
- Base size when stationary
- Expand factor based on `linear_velocity.length()`
- Additional expansion during firing (cooldown timer)
- Smooth interpolation for size changes

## Acceptance Criteria

- ✓ Mouse moves reticle on screen constrained to circular area
- ✓ Drone smoothly rotates toward reticle direction over 1-2 seconds
- ✓ Drone can fire before fully rotated (weapons follow reticle, not drone facing)
- ✓ Left mouse button fires primary weapon (hitscan)
- ✓ Right mouse button fires secondary weapon (AOE)
- ✓ Crosshair expands when moving fast, contracts when still
- ✓ Aiming system calculates correct world position from screen reticle
- ✓ Lead targeting predicts intersection for moving targets
- ✓ No conflicts with existing movement controls (WASD, boost, etc.)

## Notes

This specification was assembled using requirements gathering for:
- Mouse-controlled aiming with circular constraint
- Hybrid drone rotation (smooth follow)
- Dual weapon system (hitscan + AOE)
- Dynamic expanding crosshair UI
- Lead targeting prediction
