shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_opaque, depth_prepass_alpha;

// Height and gradient controls
uniform float model_height = 1.0;
uniform float dissolve_start = 0.0;
uniform float dissolve_length = 1.0;
uniform float gradient_bias = 2.0;

// Noise animation
uniform sampler2D noise_texture;
uniform float noise_strength = 0.2;
uniform float noise_speed = 1.0;
uniform vec2 stretch_factor = vec2(1.0, 3.0);

// Color controls
uniform vec4 base_color : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform vec4 tip_color : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform float color_intensity = 1.0;

varying float height_normalized;

void vertex() {
	// Normalize vertex height between 0-1
	height_normalized = (VERTEX.y + model_height * 0.5) / model_height;
}

vec3 neon_color(float value) {
	// Layer colors at different intensities for flame-like appearance
	vec3 col1 = mix(base_color.rgb, tip_color.rgb, value);
	vec3 col2 = mix(base_color.rgb, tip_color.rgb, pow(value, 0.5));
	return mix(col1, col2, 0.5) * color_intensity;
}

void fragment() {
	// Animate UVs over time
	vec2 animated_uv = UV * stretch_factor;
	animated_uv.y += TIME * noise_speed;

	// Sample noise and distort gradient
	float noise = texture(noise_texture, animated_uv).r;
	// Invert so tip (y=bottom) is transparent, base (y=top) is opaque
	float dissolve_value = 1.0 - height_normalized;
	float gradient = clamp((dissolve_value - dissolve_start) / dissolve_length, 0.0, 1.0);
	gradient = pow(gradient, gradient_bias);

	// Fresnel for smooth edges (but don't let it make center invisible)
	float fresnel = 1.0 - abs(dot(VIEW, NORMAL));
	fresnel = pow(fresnel, 1.5);
	fresnel = mix(0.6, 1.0, fresnel); // Keep minimum visibility at center

	// Apply color and emission
	ALBEDO = neon_color(gradient);
	EMISSION = ALBEDO * gradient * 0.5; // Self-illumination
	ALPHA = gradient * fresnel; // Soften cone edges
}
