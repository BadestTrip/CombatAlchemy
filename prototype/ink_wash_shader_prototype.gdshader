shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float reveal_progress : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_growth_time : hint_range(0.5, 3.0) = 2.1;

uniform vec4 ink_color : source_color = vec4(0.035, 0.028, 0.022, 1.0);

uniform float drop_scale : hint_range(0.5, 2.0) = 1.0;
uniform float puddle_scale : hint_range(0.5, 2.5) = 2.2;
uniform float edge_noise_strength : hint_range(0.0, 0.90) = 0.90;
uniform float ink_rim_strength : hint_range(0.0, 1.0) = 0.0;

uniform float drop_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float splash_alpha : hint_range(0.0, 1.0) = 0.75;

const int DROP_COUNT = 24;
const float GRID_COLUMNS = 6.0;
const float GRID_ROWS = 4.0;


float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453123);
}


float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	vec2 u = f * f * (3.0 - 2.0 * f);

	return mix(a, b, u.x)
		+ (c - a) * u.y * (1.0 - u.x)
		+ (d - b) * u.x * u.y;
}


float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;

	for (int i = 0; i < 5; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}

	return value;
}


float ease_out_cubic(float x) {
	return 1.0 - pow(1.0 - x, 3.0);
}


float ease_in_quad(float x) {
	return x * x;
}


float ellipse_mask(vec2 uv, vec2 center, float radius_x, float radius_y, float aspect) {
	vec2 p = uv - center;
	p.x *= aspect;

	float d = length(vec2(p.x / radius_x, p.y / radius_y));
	return 1.0 - smoothstep(0.82, 1.0, d);
}


float circle_mask(vec2 uv, vec2 center, float radius, float aspect) {
	vec2 p = uv - center;
	p.x *= aspect;

	return 1.0 - smoothstep(radius * 0.75, radius, length(p));
}


void fragment() {
	vec2 uv = UV;

	// The TextureRect texture is the captured previous-scene screenshot.
	vec4 snapshot_color = texture(TEXTURE, uv);

	// Keeps puddles round on widescreen.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	float t = clamp(reveal_progress, 0.0, 1.0);

	float reveal_mask = 0.0;
	float rim_mask = 0.0;
	float falling_drop_mask = 0.0;
	float splash_mask = 0.0;

	for (int i = 0; i < DROP_COUNT; i++) {
		float fi = float(i);

		float col = mod(fi, GRID_COLUMNS);
		float row = floor(fi / GRID_COLUMNS);

		float seed_a = fi * 13.17;
		float seed_b = fi * 27.41;
		float seed_c = fi * 41.93;

		// Grid placement with slight random offset.
		// This makes sure puddles eventually cover the whole screen.
		float base_x = (col + 0.5) / GRID_COLUMNS;
		float base_y = (row + 0.5) / GRID_ROWS;

		float jitter_x = (hash11(seed_a) - 0.5) * 0.09;
		float jitter_y = (hash11(seed_b) - 0.5) * 0.08;

		float drop_x = clamp(base_x + jitter_x, 0.04, 0.96);
		float land_y = clamp(base_y + jitter_y, 0.10, 0.94);

		float delay = mix(0.0, 0.36, hash11(seed_c));
		float fall_duration = mix(0.22, 0.40, hash11(seed_a + 5.0));

		float grow_duration = mix(
			puddle_growth_time * 0.8,
			puddle_growth_time * 1.2,
			hash11(seed_b + 8.0)
		);

		float fall_t = clamp((t - delay) / fall_duration, 0.0, 1.0);
		float has_started = smoothstep(0.0, 0.03, t - delay);

		// Original softer landing fade from your preferred shader.
		float is_falling = has_started * (1.0 - smoothstep(0.90, 1.0, fall_t));

		float eased_fall = ease_in_quad(fall_t);

		float drop_y = mix(-0.16, land_y, eased_fall);
		vec2 drop_center = vec2(drop_x, drop_y);

		float drop_radius = mix(0.018, 0.034, hash11(seed_c + 2.0)) * drop_scale;

		float drop_head = ellipse_mask(
			uv,
			drop_center,
			drop_radius * 0.72,
			drop_radius * 1.12,
			aspect
		);

		float drop_tail = ellipse_mask(
			uv,
			drop_center + vec2(0.0, -drop_radius * 0.85),
			drop_radius * 0.38,
			drop_radius * 0.85,
			aspect
		);

		falling_drop_mask = max(
			falling_drop_mask,
			max(drop_head, drop_tail) * is_falling
		);

		// Puddle begins after landing.
		float landed_time = t - delay - fall_duration;
		float puddle_t = clamp(landed_time / grow_duration, 0.0, 1.0);
		float eased_puddle = ease_out_cubic(puddle_t);

		vec2 land_pos = vec2(drop_x, land_y);

		// Large puddles reveal the full new scene naturally.
		float max_radius = mix(0.34, 0.52, hash11(seed_b + 4.0)) * puddle_scale;
		float radius = max_radius * eased_puddle;

		vec2 p = uv - land_pos;
		p.x *= aspect;

		float d = length(p);

		float organic_noise = fbm(uv * 19.0 + vec2(seed_a, seed_b));
		float noisy_d = d + (organic_noise - 0.5) * radius * edge_noise_strength;

		float puddle = 1.0 - smoothstep(radius * 0.72, radius, noisy_d);
		puddle *= smoothstep(0.0, 0.05, puddle_t);

		reveal_mask = max(reveal_mask, puddle);

		// Optional ink rim around the screenshot cutout.
		float rim_outer = 1.0 - smoothstep(radius * 0.90, radius * 1.05, noisy_d);
		float rim_inner = 1.0 - smoothstep(radius * 0.58, radius * 0.82, noisy_d);
		float rim = clamp(rim_outer - rim_inner, 0.0, 1.0);
		rim *= smoothstep(0.02, 0.18, puddle_t);

		rim_mask = max(rim_mask, rim);

		// Landing splashes.
		float splash_t = smoothstep(0.02, 0.20, puddle_t);

		vec2 splash_pos_a = land_pos + vec2(
			(hash11(seed_a + 77.0) - 0.5) * 0.16,
			(hash11(seed_b + 81.0) - 0.5) * 0.10
		);

		vec2 splash_pos_b = land_pos + vec2(
			(hash11(seed_a + 12.0) - 0.5) * 0.12,
			(hash11(seed_b + 19.0) - 0.5) * 0.08
		);

		float splash_radius_a = mix(0.008, 0.022, hash11(seed_c + 33.0)) * drop_scale;
		float splash_radius_b = mix(0.005, 0.016, hash11(seed_c + 44.0)) * drop_scale;

		float splash_a = circle_mask(uv, splash_pos_a, splash_radius_a, aspect) * splash_t;
		float splash_b = circle_mask(uv, splash_pos_b, splash_radius_b, aspect) * splash_t;

		splash_mask = max(splash_mask, max(splash_a, splash_b));
	}

	reveal_mask = max(reveal_mask, splash_mask);

	// Screenshot becomes transparent inside puddles.
	// This reveals the new scene underneath.
	float snapshot_alpha = snapshot_color.a * (1.0 - reveal_mask);

	// Ink visuals fade near the end, but the reveal itself is still caused by puddles.
	float ink_visual_fade = 1.0 - smoothstep(0.94, 1.0, t);

	float ink_visual_alpha = 0.0;
	ink_visual_alpha = max(ink_visual_alpha, falling_drop_mask * drop_alpha);
	ink_visual_alpha = max(ink_visual_alpha, rim_mask * ink_rim_strength * ink_visual_fade);
	ink_visual_alpha = max(ink_visual_alpha, splash_mask * splash_alpha * ink_visual_fade);

	float final_alpha = max(snapshot_alpha, ink_visual_alpha);
	float ink_weight = clamp(ink_visual_alpha / max(final_alpha, 0.001), 0.0, 1.0);

	vec3 final_color = mix(snapshot_color.rgb, ink_color.rgb, ink_weight);

	COLOR = vec4(final_color, final_alpha);
}