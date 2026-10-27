shader_type canvas_item;

// A one-pixel glowing outline round whatever the sprite draws, in the colour given.
uniform vec4 outline_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float strength = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float near = max(max(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	if (c.a > 0.0) {
		COLOR = c;
	} else {
		COLOR = vec4(outline_color.rgb, near * strength);
	}
}
