shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Greyscale Texture Coloring Shader
// Takes greyscale textures and multiplies them by a custom color
// Perfect for recoloring models with greyscale base textures

// Albedo and Color Properties
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float color_intensity : hint_range(0.0, 2.0) = 1.0;

// PBR Properties
uniform float metallic : hint_range(0.0, 1.0) = 0.6;
uniform float roughness : hint_range(0.0, 1.0) = 0.4;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Ambient Occlusion
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 1.0;

// Normal Mapping
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool use_normal_map = false;

// Emission (for lights, engines, status indicators)
uniform bool emission_enabled = false;
uniform vec4 emission_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 1.0;
uniform sampler2D emission_texture : source_color, filter_linear_mipmap, repeat_enable;

// Rim Lighting (for atmospheric effect)
uniform bool rim_enabled = true;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.3;

void fragment() {
	// Sample greyscale texture
	vec4 albedo_tex = texture(albedo_texture, UV);

	// Multiply greyscale by tint color to create colored version
	// The greyscale value modulates the brightness of the tint color
	vec3 colored_albedo = albedo_tex.rgb * tint_color.rgb * color_intensity;

	ALBEDO = colored_albedo;
	// Ensure fully opaque for proper shadow casting (unless explicitly using transparency)
	ALPHA = 1.0;

	// PBR properties
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;

	// Ambient Occlusion
	float ao = texture(ao_texture, UV).r;
	AO = ao;
	AO_LIGHT_AFFECT = ao_light_affect;

	// Normal mapping (if enabled)
	if (use_normal_map) {
		vec3 normal_tex = texture(normal_texture, UV).rgb;
		normal_tex = normal_tex * 2.0 - 1.0;
		normal_tex.xy *= normal_strength;
		NORMAL_MAP = normal_tex;
	}

	// Emission
	if (emission_enabled) {
		vec3 emission_tex = texture(emission_texture, UV).rgb;
		EMISSION = emission_color.rgb * emission_tex * emission_energy;
	}

	// Rim lighting for nice edge highlights
	if (rim_enabled) {
		float rim = 1.0 - max(dot(normalize(VIEW), normalize(NORMAL)), 0.0);
		rim = pow(rim, 4.0); // Higher power for sharper edges
		// Apply as emission so it doesn't interfere with shadow calculations
		EMISSION += tint_color.rgb * rim * rim_strength * 0.1;
	}
}
