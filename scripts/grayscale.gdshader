shader_type canvas_item;

// Takes the colour out of what is behind it: the graveyard is seen in grey, with only a trace of blue left.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.92;

void fragment() {
	vec3 colour = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(colour, vec3(grey * 0.96, grey * 0.99, grey * 1.04), amount), 1.0);
}
