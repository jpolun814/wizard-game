shader_type canvas_item;

// The wizard's sprite. Cuts the body off at a line while it is stuck in the ground (keep), and colours the part of it
// below the surface of the water or lava it stands in, so it looks as if that part is really under it.

uniform float keep = 2.0;                       // the part of the picture, from the top, that is shown: 1.0 is all of it
uniform float water_y = 1000000.0;              // the height of the liquid's surface in the world
uniform vec4 water_tint : source_color = vec4(1.0);
uniform float obsidian = 0.0;                   // 0 to 1: how far the body has turned to black glass
uniform float aura = 0.0;                       // 0 to 1: how strongly a blood veil tints the body red

// The wizard's colours (see WizardLook): two groups of the picture's colours, each picked out by its hue (centre and half-width, in turns of the
// colour wheel, and the least colour a pixel must have to count), are turned to a new hue and made more or less colourful. Skin, wood and
// outlines are in neither group, so they stay as they were. A hue of -1 leaves a group as it is.
uniform vec4 robe_group = vec4(-1.0, 0.0, 0.0, 0.0);   // hue, half-width, least colour, and how much brighter and livelier a dark figure's group is made when it is recoloured (0: not at all)
uniform vec4 trim_group = vec4(-1.0, 0.0, 0.0, 0.0);
uniform vec4 shade = vec4(-1.0, 0.0, 0.0, 0.0);        // for a figure whose cloak is black: the hue, colour and brightness its black becomes (hue -1: stays black)
uniform vec2 caps = vec2(1.0);                          // the brightest a pixel of the robe group and of the trim group can be and still count (skin and hair are brighter than cloth)
uniform vec4 robe_goal = vec4(-1.0, 1.0, 0.0, 0.0);    // the hue it becomes (-1: unchanged), and how much colour it keeps
uniform vec4 trim_goal = vec4(-1.0, 1.0, 0.0, 0.0);

varying float world_y;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec4 k = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + k.xyz) * 6.0 - k.www);
	return c.z * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), c.y);
}

// How much of a pixel belongs to a group of hues: 1 inside it, falling to 0 over a little way past its edge.
float in_group(vec3 hsv, vec4 group, float cap) {
	float apart = abs(hsv.x - group.x);
	apart = min(apart, 1.0 - apart);
	float hue_part = 1.0 - smoothstep(group.y, group.y + 0.025, apart);
	return hue_part * smoothstep(group.z * 0.7, group.z, hsv.y) * step(0.1, hsv.z) * (1.0 - smoothstep(cap, cap + 0.06, hsv.z));
}

vec3 recolour(vec3 rgb, vec3 hsv, vec4 group, vec4 goal, float cap) {
	if (goal.x < 0.0 && goal.y >= 1.0) {
		return rgb;
	}
	float part = in_group(hsv, group, cap);
	if (part <= 0.0) {
		return rgb;
	}
	vec3 moved = hsv;
	if (goal.x >= 0.0) {
		moved.x = fract(hsv.x + goal.x - group.x);
	}
	moved.y = clamp(hsv.y * goal.y, 0.0, 1.0);
	if (goal.x >= 0.0 && group.w > 1.0) {
		moved.z = clamp(hsv.z * group.w, 0.0, 1.0);
		moved.y = clamp(moved.y * (1.0 + (group.w - 1.0) * 0.6), 0.0, 1.0);
	}
	return mix(rgb, hsv_to_rgb(moved), part);
}

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	if (UV.y > keep) {
		discard;
	}
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (robe_goal.x >= 0.0 || robe_goal.y < 1.0 || trim_goal.x >= 0.0 || trim_goal.y < 1.0) {
		vec3 hsv = rgb_to_hsv(c.rgb);
		c.rgb = recolour(c.rgb, hsv, robe_group, robe_goal, caps.x);
		c.rgb = recolour(c.rgb, hsv, trim_group, trim_goal, caps.y);
	}
	if (shade.x >= 0.0) {
		float top = max(c.r, max(c.g, c.b));
		float dark = 1.0 - smoothstep(0.03, 0.12, top);
		c.rgb = mix(c.rgb, hsv_to_rgb(vec3(shade.x, shade.y, shade.z)), dark);
	}
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
