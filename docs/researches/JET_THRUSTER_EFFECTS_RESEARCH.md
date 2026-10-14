# Jet Thruster Effects Research for Godot 4

## Overview
Research on implementing realistic jet thruster/engine exhaust effects for hover drones in Godot 4.

## Two Main Approaches

### 1. Shader-Based Approach (Recommended for Performance)
**Source:** [Sci-fi Engine Thrust Shader Tutorial](https://gameidea.org/2024/08/22/sci-fi-engine-thrust-shader/)

#### Advantages:
- Better performance (GPU-based)
- Cleaner, more stylized look
- Easier to control intensity/color
- No particle system overhead

#### Implementation Steps:

**Step 1: Cone Mesh Setup**
- Use Godot's default CylinderMesh
- Set one radius to 0.0 to create cone shape
- Orient cone with tip pointing down/away from thruster
- Ensure parallel UV unwrapping for consistent effect

**Step 2: Basic Gradient Shader**
```gdshader
shader_type spatial;
render_mode blend_mix, unshaded, cull_back;

uniform float model_height = 1.0;
uniform float dissolve_start = 0.0;
uniform float dissolve_length = 1.0;
uniform float gradient_bias = 2.0;

varying float height_normalized;

void vertex() {
    // Normalize vertex height between 0-1
    height_normalized = (VERTEX.y + model_height * 0.5) / model_height;
}

void fragment() {
    // Calculate gradient from tip (transparent) to base (opaque)
    float gradient = clamp((height_normalized - dissolve_start) / dissolve_length, 0.0, 1.0);
    gradient = pow(gradient, gradient_bias); // Adjust transition sharpness

    ALPHA = gradient;
    ALBEDO = vec3(0.3, 0.6, 1.0); // Blue thrust color
}
```

**Step 3: Add Animated Noise**
```gdshader
uniform sampler2D noise_texture;
uniform float noise_strength = 0.2;
uniform float noise_speed = 1.0;
uniform vec2 stretch_factor = vec2(1.0, 3.0); // Stretch vertically

void fragment() {
    // Animate UVs over time
    vec2 animated_uv = UV * stretch_factor;
    animated_uv.y += TIME * noise_speed;

    // Sample noise and distort gradient
    float noise = texture(noise_texture, animated_uv).r;
    float gradient = clamp((height_normalized - dissolve_start + noise * noise_strength) / dissolve_length, 0.0, 1.0);
    gradient = pow(gradient, gradient_bias);

    ALPHA = gradient;
}
```

**Step 4: Enhanced Color with "Neon" Effect**
```gdshader
uniform vec4 base_color : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform vec4 tip_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float color_intensity = 2.0;

vec3 neon_color(float value) {
    // Layer colors at different intensities for flame-like appearance
    vec3 col1 = mix(base_color.rgb, tip_color.rgb, value);
    vec3 col2 = mix(base_color.rgb, tip_color.rgb, pow(value, 0.5));
    return mix(col1, col2, 0.5) * color_intensity;
}

void fragment() {
    // ... gradient calculation ...
    ALBEDO = neon_color(gradient);
    EMISSION = ALBEDO * gradient; // Self-illumination
}
```

**Step 5: Fresnel Edge Smoothing**
```gdshader
void fragment() {
    // ... previous calculations ...

    // Fresnel for smooth edges
    float fresnel = 1.0 - abs(dot(VIEW, NORMAL));
    fresnel = pow(fresnel, 2.0);

    ALPHA = gradient * fresnel; // Soften cone edges
}
```

#### Final Shader Features:
- Height-based gradient from transparent tip to opaque base
- Animated noise distortion for turbulence
- Enhanced color with layered intensity
- Fresnel effect for soft edges
- Self-illumination via EMISSION
- Unshaded rendering for consistent brightness

---

### 2. Particle-Based Approach (More Dynamic)
**Source:** [Godot 4 Official Documentation](https://docs.godotengine.org/en/stable/tutorials/3d/particles/creating_a_3d_particle_system.html)

#### Advantages:
- More dynamic, organic appearance
- Can interact with environment (collisions)
- Good for smoke/steam effects
- Supports sub-emitters for complex plumes

#### Basic Setup:

**Step 1: Create GPUParticles3D Node**
- Add as child of drone/thruster hardpoint
- Position at engine nozzle exit point

**Step 2: Configure ParticleProcessMaterial**
```gdscript
# Key Properties:
- Emission Shape: Point or Cone (for directional thrust)
- Direction: Vector3(0, -1, 0) for downward thrust
- Initial Velocity: 10-20 for fast exhaust
- Gravity: Vector3.ZERO (space) or slight downward (atmosphere)
- Damping: 1-5 to slow particles over time
- Scale: Start at 0.1, end at 0.5 (expand as exhaust disperses)
- Color Ramp: Blue/White at spawn → Transparent at death
- Lifetime: 0.3-0.8 seconds
```

**Step 3: Particle Material**
- Use additive blend mode for glow
- Apply noise texture for turbulence
- Set transparency for fade-out

**Step 4: Performance Optimization**
```gdscript
# For multiple thrusters on one drone:
amount = 50  # particles per emitter (keep low)
lifetime = 0.5  # shorter = better performance
one_shot = false  # continuous emission
explosiveness = 0.0  # smooth emission
```

---

## Implementation Recommendations for DroneWorld

### For Hover Drones (4 hover points):
**Hybrid Approach:**
1. **Main thrust visual:** Shader-based cone (best performance for 4+ thrusters)
2. **Accent effects:** Small particle system for heat distortion/smoke

**Shader Setup Per Hover Point:**
```
HoverPoint (Node3D)
└── ThrusterMesh (MeshInstance3D)
    ├── Material: thruster_shader.gdshader
    └── Scale: (0.3, 1.0, 0.3) # Thin cone
```

**Script to Control Intensity:**
```gdscript
extends MeshInstance3D

var thrust_material: ShaderMaterial
@export var max_intensity: float = 2.0

func _ready():
    thrust_material = get_surface_override_material(0)

func set_thrust_intensity(normalized_value: float):
    # Link to hover physics thrust output
    var intensity = normalized_value * max_intensity
    thrust_material.set_shader_parameter("color_intensity", intensity)
    thrust_material.set_shader_parameter("dissolve_length", 0.5 + normalized_value * 0.5)
```

---

## Common Issues & Solutions

### Issue: Particles lag behind moving drone
**Solution:** Use `CPUParticles3D` with `local_coords = false` OR set particle velocity to match drone velocity

### Issue: Thrust doesn't scale with power
**Solution:** Control shader parameters dynamically based on:
- `thrust_force` from hover_physics.gd
- `is_boosting` state
- Vertical velocity for climb indication

### Issue: Performance with multiple drones
**Solution:**
- Use shader approach (500+ thrusters = minimal cost)
- Limit particles to player drone only
- Use LOD system to disable distant thruster effects

---

## Assets Needed

### Textures:
1. **Noise Texture** (for shader distortion)
   - Seamlessly tiling Perlin/Simplex noise
   - 512x512 or 256x256
   - Grayscale

2. **Particle Texture** (if using particles)
   - Soft circular gradient
   - White center → Transparent edges
   - 64x64 or 128x128

### Materials:
- `thruster_main.gdshader` - Main engine effect
- `thruster_boost.gdshader` - Boost variant (more intense)
- `thruster_climb.gdshader` - Upward thrust (different color?)

---

## Color Schemes by Drone Type

### Explorer Drone:
- Base: Cyan/Blue (0.2, 0.6, 1.0)
- Tip: White/Pale Blue (0.8, 0.9, 1.0)

### Fighter Drones:
- Base: Orange/Red (1.0, 0.4, 0.2)
- Tip: Yellow/White (1.0, 0.9, 0.6)

### Cargo Drone:
- Base: Green/Teal (0.2, 0.8, 0.6)
- Tip: White (0.9, 1.0, 0.9)

### Boost Mode (All):
- Increase intensity by 1.5-2.0x
- Add more white to tip color
- Increase noise distortion

---

## Integration with Existing Systems

### Link to hover_physics.gd:
```gdscript
# In hover_physics.gd, add signal:
signal thrust_changed(hover_point_index: int, thrust_normalized: float)

# In apply_hover_suspension_forces():
func apply_hover_suspension_forces() -> void:
    # ... existing code ...
    for i in range(hover_raycasts.size()):
        var thrust_percent = clamp(total_acceleration / max_acceleration, 0.0, 1.0)
        emit_signal("thrust_changed", i, thrust_percent)
```

### Create ThrusterController component:
```gdscript
extends Node
class_name ThrusterController

@export var thruster_meshes: Array[MeshInstance3D] = []
var physics: HoverPhysics

func _ready():
    physics = get_parent() as HoverPhysics
    physics.thrust_changed.connect(_on_thrust_changed)

func _on_thrust_changed(point_index: int, intensity: float):
    if point_index < thruster_meshes.size():
        var mesh = thruster_meshes[point_index]
        var mat = mesh.get_surface_override_material(0) as ShaderMaterial
        if mat:
            mat.set_shader_parameter("color_intensity", intensity * 2.0)
```

---

## Next Steps

1. Create basic thruster shader with gradient + noise
2. Add thruster mesh instances to hover points in drone scenes
3. Create ThrusterController component
4. Test performance with multiple drones
5. Add boost/climb visual variations
6. Polish: color tweaking, intensity curves, sound integration

---

## References

- [Sci-fi Engine Thrust Shader Tutorial](https://gameidea.org/2024/08/22/sci-fi-engine-thrust-shader/)
- [Godot 4 GPUParticles3D Documentation](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html)
- [Creating 3D Particle Systems](https://docs.godotengine.org/en/stable/tutorials/3d/particles/creating_a_3d_particle_system.html)
- [Godot Forum: Ship Engine Exhaust](https://forum.godotengine.org/t/how-do-i-emit-a-ships-engine-exhaust-correctly/13974)
