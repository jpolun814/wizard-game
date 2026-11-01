shader_type canvas_item;

// The wizard's sprite. Cuts the body off at a line while it is stuck in the ground (keep), and colours the part of it
// below the surface of the water or lava it stands in, so it looks as if that part is really under it.

uniform float keep = 2.0;                       // the part of the picture, from the top, that is shown: 1.0 is all of it
uniform float water_y = 1000000.0;              // the height of the liquid's surface in the world
uniform vec4 water_tint : source_color = vec4(1.0);
uniform float obsidian = 0.0;                   // 0 to 1: how far the body has turned to black glass
uniform float aura = 0.0;                       // 0 to 1: how strongly a blood veil tints the body red

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	if (UV.y > keep) {
		discard;
	}
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (world_y > water_y) {
		c.rgb *= water_tint.rgb;
	}
	if (obsidian > 0.0) {
		// Obsidian: nearly black, with a hard bright sheen that runs across it and a pinprick of light where the picture was bright.
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec3 glass = vec3(0.012, 0.01, 0.022) + lum * vec3(0.05, 0.045, 0.09);
		float p = fract(UV.x * 1.4 + UV.y * 0.9 - TIME * 0.55);
		float sheen = smoothstep(0.07, 0.0, abs(p - 0.5) - 0.02);
		float edge = smoothstep(0.55, 0.9, lum);
		glass += vec3(0.75, 0.8, 1.0) * (sheen * (0.35 + lum) + edge * 0.35);
		c.rgb = mix(c.rgb, glass, obsidian);
	}
	if (aura > 0.0) {
		float beat = 0.75 + 0.25 * sin(TIME * 5.0);
		vec3 red = c.rgb * vec3(1.6, 0.35, 0.4) + vec3(0.18, 0.0, 0.02);
		c.rgb = mix(c.rgb, red, aura * 0.8 * beat);
	}
	COLOR = c;
}
