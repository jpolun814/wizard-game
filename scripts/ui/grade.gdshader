shader_type canvas_item;

// One color grade over every world, so art from different packs reads as one game: the darkest shadows are pulled toward a
// shared deep violet, the colors are drawn a little toward each other, the lights are warmed a touch, and the corners of the
// screen fall away into the dark. It sits over the world and under the interface.
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec3 shadow_tint = vec3(0.07, 0.04, 0.12);
uniform vec3 light_tint = vec3(1.04, 0.99, 0.94);
uniform float saturation : hint_range(0.0, 1.5) = 0.9;
uniform float shadow_lift : hint_range(0.0, 1.0) = 0.55;
uniform float vignette : hint_range(0.0, 1.0) = 0.38;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(gray), color, saturation);
	// The blacker a pixel is, the more of the shared shadow color it takes.
	float dark = 1.0 - smoothstep(0.0, 0.28, gray);
	color = mix(color, color + shadow_tint, dark * shadow_lift);
	color *= mix(vec3(1.0), light_tint, smoothstep(0.35, 0.9, gray));
	vec2 off = SCREEN_UV - vec2(0.5);
	float edge = smoothstep(0.35, 0.95, length(off * vec2(1.0, 1.25)));
	color *= 1.0 - edge * vignette;
	COLOR = vec4(color, 1.0);
}
