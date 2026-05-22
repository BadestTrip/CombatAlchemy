shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;

/*
	These positions are normalized screen UVs.
	For your current menu image:
	- fire_origin should sit around the campfire
	- sun_origin should sit around the sunset
*/
uniform vec2 fire_origin = vec2(0.32, 0.84);
uniform float fire_radius : hint_range(0.05, 0.8) = 0.28;
uniform float fire_strength : hint_range(0.0, 1.5) = 0.55;

uniform vec2 sun_origin = vec2(0.33, 0.42);
uniform float sun_radius : hint_range(0.05, 1.0) = 0.55;
uniform float sun_strength : hint_range(0.0, 1.0) = 0.28;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.38;
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_outer : hint_range(0.0, 2.0) = 1.0;

uniform float warmth : hint_range(0.0, 1.0) = 0.25;
uniform float pulse_speed : hint_range(0.0, 10.0) = 4.5;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x)
		+ (c - a) * u.y * (1.0 - u.x)
		+ (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 source = texture(screen_texture, uv);
	vec3 col = source.rgb;

	float n = noise(vec2(TIME * 3.0, uv.x * 12.0 + uv.y * 4.0));
	float flicker = 0.72 + 0.28 * sin(TIME * pulse_speed + n * 6.2831);
	flicker += noise(uv * 18.0 + vec2(TIME * 2.0, -TIME * 1.3)) * 0.18;
	flicker = clamp(flicker, 0.45, 1.2);

	float fire_dist = distance(uv, fire_origin);
	float fire_mask = max(0.0, 1.0 - fire_dist / fire_radius);
	fire_mask = pow(fire_mask, 2.6) * flicker;

	vec3 fire_color = vec3(1.0, 0.42, 0.09);
	col += fire_color * fire_mask * fire_strength;

	float sun_dist = distance(uv, sun_origin);
	float sun_mask = max(0.0, 1.0 - sun_dist / sun_radius);
	sun_mask = pow(sun_mask, 2.0);

	vec3 sun_color = vec3(1.0, 0.55, 0.24);
	col += sun_color * sun_mask * sun_strength;

	vec3 warm_grade = col * vec3(1.06, 0.97, 0.88) + vec3(0.025, 0.004, -0.012);
	col = mix(col, warm_grade, warmth);

	vec2 centered = (uv - vec2(0.5)) * vec2(1.0, 1.35);
	float vignette = smoothstep(vignette_inner, vignette_outer, length(centered));
	col *= 1.0 - vignette * vignette_strength;

	col = mix(source.rgb, col, effect_strength);

	COLOR = vec4(col, source.a);
}
