shader_type canvas_item;
render_mode unshaded;

uniform float band_top = 0.0;
uniform float band_bottom = 1.0;
uniform float surface_step = 0.0;
uniform float bottom_step = 0.0;
uniform float visual_time = 0.0;
uniform float bubble_speed = 12.0;
uniform float bubble_power = 0.0;

void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	vec2 pixel = floor(UV * vec2(16.0, 32.0));
	float top = band_top * 32.0 + surface_step;
	float bottom = band_bottom * 32.0 + bottom_step;
	if (pixel.y < top || pixel.y >= bottom) {
		ink.a = 0.0;
	}
	// Native-pixel bubbles share the liquid's mask and band clipping.
	float travel = floor(visual_time * bubble_speed * mix(0.25, 1.0, bubble_power));
	float lane = mod(pixel.x, 3.0);
	float phase = mod(pixel.y + travel + pixel.x * 7.0, 13.0);
	if (bubble_power > 0.0 && lane == 0.0 && phase == 0.0) {
		ink.rgb = mix(ink.rgb, vec3(0.94), 0.55);
	}
	COLOR = ink;
}
