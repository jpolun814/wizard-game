shader_type canvas_item;

// The wizard's sprite. Cuts the body off at a line while it is stuck in the ground (keep), and colours the part of it
// below the surface of the water or lava it stands in, so it looks as if that part is really under it.

uniform float keep = 2.0;                       // the part of the picture, from the top, that is shown: 1.0 is all of it
uniform float water_y = 1000000.0;              // the height of the liquid's surface in the world
uniform vec4 water_tint : source_color = vec4(1.0);

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
	COLOR = c;
}
