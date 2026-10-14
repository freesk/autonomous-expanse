# Camera System Specification

## Overview
This document defines the camera system for DroneWorld, focusing on a third-person follow camera with full manual control, adaptive smoothing, and intelligent obstruction prevention.

> **Note:** This spec integrates with the aiming system defined in PLAYER_AIM_SPEC.md. Mouse controls the aiming reticle (aiming takes priority), and the drone smoothly rotates to follow where you're aiming. The camera then follows the drone normally with all the adaptive smoothing features. See SPEC_CONFLICTS_RESOLUTION.md for details.

## Camera Type

### Third-Person Follow Camera
- Camera follows behind and slightly above the drone
- Player has full manual control over rotation, tilt, and zoom
- Default distance: 5-10 meters (close follow for immersive experience)
- Camera maintains relative position to drone while allowing free look

## Camera Controls

### Rotation (Horizontal)
- **Input**: Drone automatically rotates to follow the aim reticle direction (mouse controls reticle via aiming system)
- **Range**: 360° continuous rotation
- **Speed**: Fast hybrid follow (1-2 seconds for full 180° turn)
- **Behavior**: Drone smoothly rotates toward where the player is aiming. Camera follows behind the drone automatically with adaptive smoothing.

### Tilt/Pitch (Vertical)
- **Input**: Right Stick Y-axis only (no mouse vertical control)
- **Range**: -80° to +80° (prevent gimbal lock at poles)
- **Speed**: Configurable sensitivity (default: medium)
- **Behavior**: Gamepad only for vertical camera angle

### Zoom
- **Input**: Mouse scroll wheel or D-Pad Up/Down
- **Range**: 5m (min) to 30m (max)
- **Steps**: Smooth continuous zoom (not discrete steps)
- **Behavior**: Maintains current rotation and tilt while adjusting distance

### Reset to Default
- **Input**: Dedicated key (e.g., 'C' or Right Stick click)
- **Behavior**: Smoothly return to default position
- **Default Position**:
  - Distance: 7 meters
  - Angle: Behind drone, slightly elevated (15° above horizontal)
  - Rotation: Aligned with drone forward direction

## Camera Movement Behavior

### Adaptive Smoothing
The camera uses context-aware smoothing to balance responsiveness and cinematic feel:

#### Cruise Mode (Low Speed, No Combat)
- **Position Smoothing**: High (smooth follow)
- **Rotation Smoothing**: Medium (cinematic feel)
- **Characteristics**: Floaty, cinematic camera movement

#### Combat Mode (High Speed or Combat Detected)
- **Position Smoothing**: Low (responsive follow)
- **Rotation Smoothing**: Low (instant response)
- **Characteristics**: Tight, responsive control for precise aiming

#### Transition
- Mode detection based on:
  - Drone speed threshold
  - Weapon fire detection
  - Taking damage
  - Enemy proximity
- Smooth interpolation between modes (0.5s transition time)

### Smoothing Implementation
```gdscript
# Position smoothing (lerp factor)
cruise_smoothing = 0.1  # Higher = smoother (10% per frame)
combat_smoothing = 0.3  # Lower = more responsive (30% per frame)

# Rotation smoothing (lerp factor)
cruise_rotation_smoothing = 0.15
combat_rotation_smoothing = 0.4

# Current smoothing interpolated based on combat state
current_smoothing = lerp(cruise_smoothing, combat_smoothing, combat_intensity)
```

## Collision and Obstruction Handling

### Obstruction Prevention
The camera actively prevents positioning that would result in obstructed views:

#### Ray Casting System
1. Cast ray from drone to desired camera position
2. If obstruction detected:
   - Find closest valid position along the ray
   - Move camera to just before obstruction point
   - Minimum distance: 2 meters from drone
3. When obstruction clears, smoothly return to desired position

#### Implementation Details
```gdscript
# Godot RayCast3D configuration
var camera_ray = RayCast3D.new()
camera_ray.collision_mask = collision_layer_world  # Only check world geometry
camera_ray.exclude = [drone_body]  # Ignore the drone itself

# Adjust camera position based on ray result
if camera_ray.is_colliding():
    var collision_point = camera_ray.get_collision_point()
    var safe_distance = drone.position.distance_to(collision_point) - 0.5
    camera_distance = clamp(safe_distance, min_distance, desired_distance)
```

### Collision Layers
- Check against: Terrain, buildings, large obstacles
- Ignore: Other drones, projectiles, small debris, effects

## Camera Parameters

### Distance Settings
```gdscript
{
    "min_distance": 5.0,      # Closest zoom (meters)
    "max_distance": 30.0,     # Farthest zoom (meters)
    "default_distance": 7.0,  # Starting distance
    "zoom_speed": 2.0,        # Units per scroll/input
}
```

### Rotation Settings
```gdscript
{
    "rotation_speed": 180.0,     # Degrees per second at default sensitivity
    "tilt_speed": 120.0,         # Degrees per second at default sensitivity
    "min_tilt": -80.0,           # Maximum downward angle
    "max_tilt": 80.0,            # Maximum upward angle
    "invert_y": false,           # Option to invert vertical axis
}
```

### Default Position
```gdscript
{
    "distance": 7.0,
    "horizontal_offset": 0.0,    # Centered behind drone
    "vertical_offset": 1.5,      # Slightly elevated
    "pitch": 15.0,               # Looking slightly down at drone
    "yaw": 0.0,                  # Aligned with drone forward
}
```

## Camera States

### Normal State
- Full player control
- Adaptive smoothing active
- All features available

### Reset Animation
- Duration: 0.5 seconds
- Smooth interpolation to default position
- Player can interrupt by moving camera

## Field of View (FOV)

### Base FOV
- **Default**: 75° (good balance for third-person)
- **Range**: 60° to 90° (adjustable in settings)

### Dynamic FOV (Optional Future Feature)
- Increase FOV at high speeds for sense of motion
- Max increase: +10° at top speed

## Technical Implementation (Godot)

### Node Structure
```
DroneCamera (Camera3D)
├── CameraArm (SpringArm3D or custom pivot)
│   └── CameraTarget (Position3D)
└── CameraRaycaster (RayCast3D)
```

### Camera Rig Setup
1. **CameraArm**: Handles distance and collision
2. **CameraTarget**: Defines desired position
3. **Camera3D**: Actual camera, smoothly follows target
4. **RayCast3D**: Detects obstructions

### Update Loop
```gdscript
func _process(delta):
    # 1. Update combat intensity
    update_combat_state()

    # 2. Process player input
    handle_rotation_input(delta)
    handle_zoom_input(delta)
    handle_reset_input()

    # 3. Check for obstructions
    check_camera_collision()

    # 4. Apply adaptive smoothing
    apply_smoothing(delta)

    # 5. Update camera transform
    update_camera_position()
```

### Performance Considerations
- Use SpringArm3D for built-in collision handling (optimization)
- Limit raycasts to 60 FPS (cache results between frames if needed)
- Use simple collision shapes for camera checks (spheres/capsules)

## Input Mapping

### Mouse + Keyboard
- **Mouse Movement**: Controls aiming reticle (drone rotates to follow, camera follows drone)
- **Mouse Scroll**: Zoom in/out
- **C Key**: Reset camera to default

### Gamepad
- **Right Stick**: Camera tilt (vertical angle)
- **D-Pad Up/Down**: Zoom in/out
- **Right Stick Click (R3)**: Reset camera to default

### Sensitivity Settings
- Independent X/Y sensitivity multipliers
- Saved in player settings/config file
- Accessible from in-game settings menu

## Edge Cases and Polish

### Rapid Drone Movement
- Camera doesn't overshoot or lag excessively
- Maintain visual connection to drone
- Increase responsiveness temporarily during sharp maneuvers

### Death/Respawn
- Camera smoothly transitions to new drone position
- Brief moment of fixed camera before resuming follow

### Low Ceiling/Tight Spaces
- Camera intelligently finds best angle
- Prevents getting stuck in geometry
- May temporarily move closer than min distance if necessary

## Future Enhancements
- Replay camera system with free-fly mode
- Photo mode with full camera freedom
- Slow-motion action cameras during critical moments
- Camera shake for impacts and weapon fire
- Picture-in-picture targeting camera
- Tactical overview mode (zoomed out strategic view)

## Testing Checklist
- [ ] Camera follows drone smoothly at all speeds
- [ ] Manual controls are responsive and intuitive
- [ ] Zoom functions correctly across full range
- [ ] Collision prevention works in tight spaces
- [ ] Adaptive smoothing transitions seamlessly
- [ ] Reset function returns to proper default
- [ ] No camera clipping through geometry
- [ ] Performance stable at 60+ FPS
- [ ] Input settings save and load correctly
- [ ] Works with both mouse/keyboard and gamepad
