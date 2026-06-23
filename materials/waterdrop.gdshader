shader_type spatial;

render_mode depth_draw_always, cull_back, blend_mix;


// ----------------------------------------------------
// SCREEN INPUTS (Godot 4.7 correct)
// ----------------------------------------------------
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform sampler2D DEPTH_TEXTURE   : hint_depth_texture, filter_linear;


// ----------------------------------------------------
// MATERIAL LOOK
// ----------------------------------------------------
uniform vec3 color_shallow : source_color = vec3(0.02, 0.18, 0.25);
uniform vec3 color_deep    : source_color = vec3(0.05, 0.35, 0.45);

uniform float transparency : hint_range(0.0, 1.0) = 0.15;
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;


// ----------------------------------------------------
// REFRACTION
// ----------------------------------------------------
uniform float ior : hint_range(1.0, 2.0) = 1.333;
uniform float refraction_strength : hint_range(0.0, 1.0) = 0.25;


// ----------------------------------------------------
// DROPLET SURFACE DETAIL
// ----------------------------------------------------
uniform sampler2D droplet_noise;

uniform float noise_scale = 8.0;
uniform float noise_strength = 0.2;
uniform float noise_speed = 0.1;


// ----------------------------------------------------
// INTERNAL WATER LOOK
// ----------------------------------------------------
uniform float absorption = 1.2;
uniform float edge_darkening = 0.6;


// ----------------------------------------------------
// WORLD DATA
// ----------------------------------------------------
varying vec3 world_pos;


// ----------------------------------------------------
// FRESNEL
// ----------------------------------------------------
float fresnel_func(vec3 view_dir, vec3 normal)
{
	return pow(1.0 - clamp(dot(view_dir, normal), 0.0, 1.0), 5.0);
}


// ----------------------------------------------------
// DROPLET NORMAL DISTORTION
// ----------------------------------------------------
vec3 droplet_normal(vec3 normal, vec3 world_position)
{
	vec3 p = world_position * noise_scale;

	p.xy += TIME * noise_speed;

	float h  = texture(droplet_noise, p.xy).r;
	float hx = texture(droplet_noise, p.xy + vec2(0.01, 0.0)).r;
	float hy = texture(droplet_noise, p.xy + vec2(0.0, 0.01)).r;

	vec3 n = normalize(vec3(
		h - hx,
		noise_strength,
		h - hy
	));

	return normalize(mix(normal, n, noise_strength));
}


// ----------------------------------------------------
// SCREEN REFRACTION
// ----------------------------------------------------
vec3 screen_refract(vec3 normal, vec3 view_dir, vec2 uv)
{
	vec3 refr_dir = refract(-view_dir, normal, 1.0 / ior);

	vec2 offset = refr_dir.xy * refraction_strength;

	return texture(SCREEN_TEXTURE, uv + offset).rgb;
}


// ----------------------------------------------------
// WORLD POSITION
// ----------------------------------------------------
void vertex()
{
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


// ----------------------------------------------------
// FRAGMENT
// ----------------------------------------------------
void fragment()
{
	// camera direction (Godot 4 safe)
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);

	// base sphere normal
	vec3 normal = normalize(NORMAL);

	// droplet distortion
	normal = droplet_normal(normal, world_pos);

	// fresnel term
	float f = fresnel_func(view_dir, normal);

	// screen colors
	vec3 screen_col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 refracted  = screen_refract(normal, view_dir, SCREEN_UV);

	// depth-based tinting (restores "liquid feel")
	float depth_factor = clamp(length(view_dir) * 0.05, 0.0, 1.0);
	vec3 water_tint = mix(color_shallow, color_deep, depth_factor);

	// core blending (water behavior)
	vec3 color = mix(screen_col, refracted, 0.65);

	// tint absorption
	float thickness = 1.0 - abs(dot(view_dir, normal));
	color = mix(color, water_tint, thickness * absorption * 0.4);

	// fresnel edge boost (gives droplet silhouette)
	color = mix(color, screen_col, f * 0.4);

	// edge darkening (critical for sphere readability)
	color *= mix(1.0, edge_darkening, f);

	// output
	ALBEDO = color;

	ALPHA = 1.0 - transparency;

	ROUGHNESS = roughness;
	METALLIC = metallic;

	NORMAL = normal;
}