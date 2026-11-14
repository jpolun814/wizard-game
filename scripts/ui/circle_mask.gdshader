shader_type canvas_item;

// Shows only the round part of a window: a view that is square is seen through a circle.
void fragment() {
	vec4 seen = texture(TEXTURE, UV);
	float edge = length(UV - vec2(0.5));
	COLOR = vec4(seen.rgb, seen.a * step(edge, 0.5));
}
