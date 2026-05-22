shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float panel_opacity : hint_range(0.0, 1.0) = 0.92;
uniform float blur_radius : hint_range(0.0, 8.0) = 3.0;

uniform vec4 panel_tint : source_color = vec4(0.16, 0.09, 0.045, 0.78);
uniform vec4 edge_color : source_color = vec4(1.0, 0.72, 0.34, 1.0);

uniform float edge_strength : hint_range(0.0, 2.0) = 0.55;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;
uniform float rounded_corners : hint_range(0.0, 0.5) = 0.13;
uniform float corner_softness : hint_range(0.001, 0.08) = 0.02;

uniform float darken_background : hint_range(0.0, 1.0) = 0.28;
uniform float shimmer_speed : hint_range(0.0, 5.0) = 0.7;

float hash(vec2 p) {
	p = fract(p * vec2(91.17, 437.53));
	p += dot(p, p + 29.31);
	return fract(p.x * p.y);
}

float rounded_rect_mask(vec2 uv, float radius, float softness) {
	vec2 p = uv * 2.0 - 1.0;
	vec2 box_size = vec2(1.0 - radius);
	vec2 q = abs(p) - box_size;
	float d = length(max(q, 0.0)) - radius;
	return 1.0 - smoothstep(0.0, softness, d);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 local_uv = UV;

	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;

	vec3 blurred = vec3(0.0);
	blurred += texture(screen_texture, uv).rgb * 0.24;
	blurred += texture(screen_texture, uv + vec2(px.x, 0.0)).rgb * 0.12;
	blurred += texture(screen_texture, uv - vec2(px.x, 0.0)).rgb * 0.12;
	blurred += texture(screen_texture, uv + vec2(0.0, px.y)).rgb * 0.12;
	blurred += texture(screen_texture, uv - vec2(0.0, px.y)).rgb * 0.12;
	blurred += texture(screen_texture, uv + vec2(px.x, px.y)).rgb * 0.07;
	blurred += texture(screen_texture, uv + vec2(-px.x, px.y)).rgb * 0.07;
	blurred += texture(screen_texture, uv + vec2(px.x, -px.y)).rgb * 0.07;
	blurred += texture(screen_texture, uv + vec2(-px.x, -px.y)).rgb * 0.07;

	blurred *= 1.0 - darken_background;

	vec3 col = mix(blurred, panel_tint.rgb, panel_tint.a);

	float mask = rounded_rect_mask(local_uv, rounded_corners, corner_softness);

	float edge_distance = min(
		min(local_uv.x, 1.0 - local_uv.x),
		min(local_uv.y, 1.0 - local_uv.y)
	);

	float edge = 1.0 - smoothstep(0.0, 0.065, edge_distance);
	edge *= mask;

	float shimmer = 0.75 + 0.25 * sin(TIME * shimmer_speed + local_uv.y * 12.0);
	col += edge_color.rgb * edge * edge_strength * shimmer;

	float grain = hash(local_uv * 900.0 + TIME * 0.15) - 0.5;
	col += grain * grain_strength;

	COLOR = vec4(col, mask * panel_opacity);
}