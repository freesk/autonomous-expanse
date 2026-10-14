shader_type spatial;
render_mode blend_mix, cull_back;

// Stealth cloak shader with shimmer and distortion effects
// Makes drones semi-transparent with optical camouflage appearance

uniform vec4 cloak_tint : source_color = vec4(0.3, 0.4, 0.5, 0.2);
uniform float cloak_strength : hint_range(0.0, 1.0) = 0.8;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;

// Refraction/Distortion
uniform bool distortion_enabled = true;
uniform float distortion_strength : hint_range(0.0, 0.2) = 0.05;
uniform float distortion_scale : hint_range(1.0, 20.0) = 5.0;
uniform float distortion_speed : hint_range(0.0, 5.0) = 1.0;

// Shimmer effect
uniform bool shimmer_enabled = true;
uniform float shimmer_speed : hint_range(0.0, 10.0) = 2.0;
uniform float shimmer_scale : hint_range(1.0, 50.0) = 10.0;
uniform float shimmer_intensity : hint_range(0.0, 1.0) = 0.3;

// Edge detection for shimmer
uniform float edge_threshold : hint_range(0.0, 1.0) = 0.3;
uniform vec4 edge_color : source_color = vec4(0.4, 0.6, 0.8, 0.5);

// Movement detection (increases visibility when moving)
uniform float movement_visibility : hint_range(0.0, 1.0) = 0.0;

// Detection pulse effect
uniform bool scan_pulse_active = false;
uniform float scan_pulse_time : hint_range(0.0, 1.0) = 0.0;
uniform vec4 scan_pulse_color : source_color = vec4(1.0, 0.3, 0.3, 1.0);

// Noise function for shimmer
float noise(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);

	float a = noise(i);
	float b = noise(i + vec2(1.0, 0.0));
	float c = noise(i + vec2(0.0, 1.0));
	float d = noise(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

varying vec3 world_position;
varying vec3 world_normal;
varying vec2 screen_uv;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	// Add subtle vertex displacement for shimmer effect
	if (shimmer_enabled) {
		float shimmer_offset = smooth_noise(vec2(TIME * shimmer_speed + UV.x * shimmer_scale, UV.y * shimmer_scale));
		VERTEX += NORMAL * shimmer_offset * 0.01 * cloak_strength;
	}
}

void fragment() {
	// Base texture
	vec4 albedo_tex = texture(albedo_texture, UV);
	vec3 base_color = albedo_tex.rgb * cloak_tint.rgb;

	// Calculate fresnel for edge detection
	vec3 view_dir = normalize(VIEW);
	float fresnel = 1.0 - abs(dot(view_dir, NORMAL));
	fresnel = pow(fresnel, 2.0);

	// Shimmer effect
	float shimmer = 0.0;
	if (shimmer_enabled) {
		vec2 shimmer_uv = UV * shimmer_scale + vec2(TIME * shimmer_speed * 0.1);
		shimmer = smooth_noise(shimmer_uv);
		shimmer = sin(shimmer * 6.28318 + TIME * shimmer_speed) * 0.5 + 0.5;
		shimmer *= shimmer_intensity;
	}

	// Edge highlight
	float edge = step(edge_threshold, fresnel);
	vec3 edge_contribution = edge_color.rgb * edge * fresnel;

	// Scan pulse effect
	float scan_effect = 0.0;
	if (scan_pulse_active && scan_pulse_time < 1.0) {
		float pulse = sin(scan_pulse_time * 3.14159);
		scan_effect = pulse * (1.0 - scan_pulse_time);
	}

	// Movement makes cloak less effective
	float visibility = cloak_strength * (1.0 - movement_visibility * 0.5);

	// Combine effects
	vec3 final_color = base_color;
	final_color += edge_contribution * visibility;
	final_color += shimmer * visibility;
	final_color = mix(final_color, scan_pulse_color.rgb, scan_effect * 0.5);

	// Calculate final alpha
	float base_alpha = cloak_tint.a * (1.0 - visibility);
	base_alpha += fresnel * 0.2;
	base_alpha += shimmer * 0.1;
	base_alpha += movement_visibility * 0.3;
	base_alpha += scan_effect * 0.4;

	ALBEDO = final_color;
	ALPHA = clamp(base_alpha, 0.0, 0.9);
	METALLIC = 0.3;
	ROUGHNESS = 0.5;

	// Refraction for distortion effect
	if (distortion_enabled) {
		vec2 distortion_uv = UV * distortion_scale + vec2(TIME * distortion_speed * 0.1);
		float distortion_noise = smooth_noise(distortion_uv);
		NORMAL_MAP = vec3(
			(distortion_noise - 0.5) * distortion_strength,
			(smooth_noise(distortion_uv + vec2(0.5)) - 0.5) * distortion_strength,
			1.0
		);
	}
}
