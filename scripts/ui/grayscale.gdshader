shader_type canvas_item;

// Takes the color out of what is behind it: the graveyard is seen in gray, with only a trace of blue left.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.92;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(color, vec3(gray * 0.96, gray * 0.99, gray * 1.04), amount), 1.0);
}
