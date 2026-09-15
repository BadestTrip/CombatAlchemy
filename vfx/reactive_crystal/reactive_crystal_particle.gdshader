shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 crystal_color : source_color = vec4(1.0, 0.18, 0.31, 1.0);
uniform float glow_strength : hint_range(0.0, 1.5, 0.05) = 1.0;
uniform float core_size : hint_range(0.0, 1.0, 0.05) = 0.28;

void fragment() {
	float shape = texture(TEXTURE, UV).a;
	float center_distance = max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0;
	float core = 1.0 - step(core_size, center_distance);
	float inner = 1.0 - step(0.68, center_distance);
	vec3 dark_halo = crystal_color.rgb * 0.28;
	vec3 body = mix(dark_halo, crystal_color.rgb, inner);
	vec3 final_color = mix(body, vec3(1.0), core * 0.92);
	float outer_alpha = mix(0.24, 0.46, clamp(glow_strength, 0.0, 1.5) / 1.5);
	float alpha = shape * mix(outer_alpha, 1.0, max(inner, core));
	COLOR = vec4(final_color, alpha * COLOR.a);
}
