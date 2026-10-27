shader_type canvas_item;

// Enemy sprites. A creature keeps its own colours but takes a little of its school's colour, and gets a one-pixel
// outline in that colour, so you can tell its school at a glance without losing the art. Also flashes the sprite
// when it is hit, and turns it icy while it is frozen.

uniform vec4 school_color : source_color = vec4(1.0);
uniform float tint = 0.0;          // 0 to 1: how much of the school's colour the body takes
uniform float outline = 0.0;       // 0 to 1: how strong the school-coloured outline is
uniform float flash = 0.0;         // 0 to 1: how far the sprite is washed to flash_color
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float frozen = 0.0;        // 0 to 1: how icy it looks
uniform float water_y = 1000000.0; // the surface of the water or lava it stands in: below it, the body takes the liquid's colour
uniform vec4 water_tint : source_color = vec4(1.0);

// The sprite's modulate. In fragment(), COLOR already has the texture multiplied in, so the plain modulate is
// carried over from the vertex stage instead.
varying vec4 modulate_color;
varying float world_y;

void vertex() {
	modulate_color = COLOR;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.1 && outline > 0.0) {
		// An empty pixel next to a solid one is part of the outline.
		vec2 px = TEXTURE_PIXEL_SIZE;
		float around = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (around > 0.1) {
			c = vec4(school_color.rgb, outline);
		}
	} else {
		float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		c.rgb = mix(c.rgb, school_color.rgb * (0.35 + lum * 1.2), tint);
		float shade = dot(c.rgb, vec3(0.333));
		c.rgb = mix(c.rgb, vec3(0.62, 0.86, 1.0) * (0.55 + 0.6 * shade), frozen * 0.75);
	}
	c.rgb = mix(c.rgb, flash_color.rgb, flash * step(0.1, c.a));
	if (world_y > water_y) {
		c.rgb *= water_tint.rgb;
	}
	COLOR = c * modulate_color;
}
