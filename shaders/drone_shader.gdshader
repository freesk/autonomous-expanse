shader_type spatial;

// Basic PBR shader for drones with custom properties
// Supports metallic/roughness workflow with additional features

// Albedo and Base Properties
uniform vec4 albedo_color : source_color = vec4(0.7, 0.7, 0.8, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float metallic : hint_range(0.0, 1.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.3;

// Normal Mapping
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;

// Emission (for lights, engines, status indicators)
uniform bool emission_enabled = false;
uniform vec4 emission_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 1.0;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_enable;

// Rim Lighting (for atmospheric effect)
uniform bool rim_enabled = true;
uniform vec4 rim_color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.3;
uniform float rim_tint : hint_range(0.0, 1.0) = 0.5;

// Damage/Health Visualization
uniform bool damage_effect_enabled = false;
uniform float damage_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 damage_color : source_color = vec4(0.8, 0.2, 0.1, 1.0);

// Faction/Team Color
uniform bool team_color_enabled = false;
uniform vec4 team_color : source_color = vec4(0.2, 0.8, 0.3, 1.0);
uniform float team_color_influence : hint_range(0.0, 1.0) = 0.3;

// Animation (for energy effects, etc.)
uniform float time_scale : hint_range(0.0, 10.0) = 1.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Base albedo
	vec4 albedo_tex = texture(albedo_texture, UV);
	vec3 base_albedo = albedo_color.rgb * albedo_tex.rgb;

	// Apply team color if enabled
	if (team_color_enabled) {
		base_albedo = mix(base_albedo, team_color.rgb, team_color_influence);
	}

	// Apply damage effect
	if (damage_effect_enabled && damage_amount > 0.0) {
		float damage_mask = smoothstep(0.3, 0.7, sin(world_position.x * 10.0) * 0.5 + 0.5);
		damage_mask *= damage_amount;
		base_albedo = mix(base_albedo, damage_color.rgb, damage_mask * 0.5);
	}

	ALBEDO = base_albedo;

	// Metallic and roughness
	METALLIC = metallic;
	ROUGHNESS = roughness;

	// Normal mapping
	vec3 normal_tex = texture(normal_texture, UV).rgb;
	normal_tex = normal_tex * 2.0 - 1.0;
	normal_tex.xy *= normal_strength;
	NORMAL_MAP = normal_tex;

	// Emission
	if (emission_enabled) {
		vec3 emission_tex = texture(emission_texture, UV).rgb;
		float animated_emission = sin(TIME * time_scale) * 0.2 + 0.8;
		EMISSION = emission_color.rgb * emission_tex * emission_energy * animated_emission;
	}

	// Rim lighting
	if (rim_enabled) {
		vec3 view_dir = normalize(VIEW);
		float rim = 1.0 - max(dot(view_dir, NORMAL), 0.0);
		rim = pow(rim, 3.0);
		vec3 rim_contribution = rim_color.rgb * rim * rim_strength;
		EMISSION += rim_contribution * rim_tint;
	}
}
