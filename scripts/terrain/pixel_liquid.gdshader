shader_type canvas_item;

// Turns the smooth shading of a pool into dithered bands, drawn in 2 by 2 world pixel blocks like the pixel art around it.
uniform float levels = 7.0;
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

void fragment() {
	vec2 block = floor(world / 2.0);
	vec3 c = COLOR.rgb * levels + bayer(block);
	COLOR.rgb = floor(c + 0.5) / levels;
}
