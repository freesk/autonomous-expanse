shader_type spatial;
render_mode blend_add, cull_back, unshaded;

// Shield effect shader with hit detection and energy visualization
// Creates a hexagonal energy shield appearance with impact ripples

uniform vec4 shield_color : source_color = vec4(0.3, 0.6, 1.0, 0.3);
uniform float shield_strength : hint_range(0.0, 1.0) = 1.0;
uniform float fresnel_power : hint_range(0.0, 10.0) = 3.0;
uniform float fresnel_intensity : hint_range(0.0, 2.0) = 1.0;

// Hexagon pattern
uniform bool hex_pattern_enabled = true;
uniform float hex_scale : hint_range(1.0, 50.0) = 10.0;
uniform float hex_brightness : hint_range(0.0, 2.0) = 0.5;

// Pulse animation
uniform bool pulse_enabled = true;
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.2;

// Hit effect
uniform bool hit_active = false;
uniform vec3 hit_position = vec3(0.0);
uniform float hit_time : hint_range(0.0, 1.0) = 0.0;
uniform float hit_radius : hint_range(0.1, 5.0) = 1.0;
uniform vec4 hit_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);

// Distortion
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.1;

varying vec3 world_position;
varying vec3 world_normal;

// Hexagon pattern function
float hexagon(vec2 uv) {
	uv = abs(uv);
	vec2 hex = vec2(1.0, 1.732);
	float d = dot(uv, normalize(hex));
	d = max(d, uv.x);
	return step(0.5, d);
}

// Multiple hit positions support
vec3 hit_positions[4];
float hit_times[4];
int active_hits = 0;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Vertex displacement for energy flow
	if (pulse_enabled) {
		float pulse = sin(TIME * pulse_speed + world_position.y * 2.0) * pulse_strength;
		VERTEX += NORMAL * pulse * 0.01;
	}
}

void fragment() {
	// Fresnel effect (edge glow)
	vec3 view_dir = normalize(VIEW);
	float fresnel = 1.0 - abs(dot(view_dir, NORMAL));
	fresnel = pow(fresnel, fresnel_power) * fresnel_intensity;

	// Base shield color with strength
	vec3 base_color = shield_color.rgb * shield_strength;
	float base_alpha = shield_color.a * shield_strength;

	// Hexagon pattern
	float hex_pattern = 1.0;
	if (hex_pattern_enabled) {
		vec2 hex_uv = UV * hex_scale;
		hex_uv.y += sin(TIME * 0.5 + UV.x * 10.0) * 0.1;
		float col = 1.0 - hexagon(fract(hex_uv) - 0.5);
		hex_pattern = mix(1.0, col, hex_brightness);
	}

	// Pulse animation
	float pulse = 1.0;
	if (pulse_enabled) {
		pulse = sin(TIME * pulse_speed + world_position.y * 2.0) * pulse_strength + (1.0 - pulse_strength);
	}

	// Calculate hit effect
	float hit_effect = 0.0;
	vec3 hit_contribution = vec3(0.0);

	if (hit_active && hit_time < 1.0) {
		float dist_to_hit = distance(world_position, hit_position);
		float ripple = sin((dist_to_hit - hit_time * 5.0) * 10.0);
		float hit_mask = 1.0 - smoothstep(0.0, hit_radius, dist_to_hit);
		hit_mask *= (1.0 - hit_time);

		hit_effect = hit_mask * max(0.0, ripple);
		hit_contribution = hit_color.rgb * hit_effect;
	}

	// Combine all effects
	vec3 final_color = base_color * hex_pattern * pulse;
	final_color += hit_contribution;
	final_color *= (1.0 + fresnel);

	float final_alpha = base_alpha * (fresnel + 0.2);
	final_alpha += hit_effect * 0.5;
	final_alpha *= shield_strength;

	// Apply energy distortion near edges
	final_color += vec3(0.1, 0.2, 0.3) * fresnel * distortion_strength;

	ALBEDO = final_color;
	ALPHA = clamp(final_alpha, 0.0, 1.0);
}
