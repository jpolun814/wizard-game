shader_type canvas_item;

// A crystal ball seen close: a round of drifting mist, drawn in blocks of one size so that it sits with the pixel art of the rest of the game. It is an
// interface piece (the stats screen's window), not a picture of the world.

uniform float cells = 72.0;  // how many blocks across the ball
uniform float pulse = 0.0;   // brightens the mist for a moment, when the page turns
uniform vec3 deep : source_color = vec3(0.055, 0.04, 0.13);
uniform vec3 wisp : source_color = vec3(0.26, 0.2, 0.5);
uniform vec3 rim_dark : source_color = vec3(0.1, 0.08, 0.2);
uniform vec3 rim_light : source_color = vec3(0.62, 0.55, 0.85);
uniform vec3 glint : source_color = vec3(0.92, 0.9, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float half_cells = cells * 0.5;
	p = (floor(p * half_cells) + 0.5) / half_cells;  // the middle of the block this point is in
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float t = TIME * 0.1;
	vec2 q = p * 2.3;
	float n = noise(q + vec2(t, -t * 0.7)) * 0.6 + noise(q * 2.2 + vec2(-t * 1.3, t)) * 0.4;
	float swirl = noise(vec2(atan(p.y, p.x) * 1.4 + t * 4.0, r * 3.2 - t * 2.5));
	float m = clamp(n * 0.75 + swirl * 0.45 - 0.15 + pulse * 0.35, 0.0, 1.0);
	m = floor(m * 4.0) / 4.0;
	vec3 col = mix(deep, wisp, m);
	// the glass: darker at the edge, a thin bright rim, and a glint high on the left
	if (r > 0.86) {
		col = mix(col, rim_dark, 0.55);
	}
	if (r > 0.95) {
		col = rim_light * (0.5 + 0.5 * step(0.0, -p.x - p.y));
	}
	vec2 g = p - vec2(-0.7, -0.58);  // a small glint on the upper left, out of the way of what is written
	if (length(g) < 0.1 && length(g - vec2(0.03, 0.03)) > 0.065) {
		col = mix(col, glint, 0.75);
	}
	COLOR = vec4(col, 1.0);
}
