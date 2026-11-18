shader_type canvas_item;
render_mode blend_add;

// Hides the part of a picture that is still behind a plane, so a shot comes out of the gem of a staff instead of showing its back half over the wizard.
// `gem` is a point in the world and `way` the direction the shot goes: whatever lies behind the line through the gem, square to the way, is not drawn.
uniform vec2 gem = vec2(0.0);
uniform vec2 way = vec2(1.0, 0.0);

varying vec2 spot;

void vertex() {
	spot = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (dot(spot - gem, way) < 0.0) {
		discard;
	}
}
