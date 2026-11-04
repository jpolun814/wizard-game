shader_type canvas_item;

// Hides the rows of a flytrap's picture that lie below the ground line, so a plant that sinks into the soil is cut off by it and is not squashed.
uniform float soil_row = 51.0;  // the row the plant's foot stands on
uniform float sunk_rows = 0.0;  // how many rows it has sunk into the ground
uniform float rows = 64.0;      // the height of a frame

void fragment() {
	if (UV.y * rows > soil_row - sunk_rows + 1.0) {
		discard;
	}
}
