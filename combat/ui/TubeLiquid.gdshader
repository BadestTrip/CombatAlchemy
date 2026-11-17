shader_type canvas_item;
render_mode unshaded;
uniform float band_top = 0.0;
uniform float band_bottom = 1.0;
uniform float surface_step = 0.0;
uniform float bottom_step = 0.0;
void fragment() {
	vec4 ink = texture(TEXTURE, UV) * COLOR;
	float row = floor(UV.y * 32.0);
	float top = band_top * 32.0 + surface_step;
	if (row < top || row >= band_bottom * 32.0 + bottom_step) { ink.a = 0.0; }
	COLOR = ink;
}
