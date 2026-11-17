// Recolours the character's "magic" layer (weapon gem, glow, spell effects) to the spell being cast.
// The layer is drawn in key greys: 236 near-white, 190 light, 128 mid, 70 deep; 255 stays white.
// Set the four colours from the spell (e.g. material.set_shader_parameter("light", spell_color)).
shader_type canvas_item;

uniform float keep = 2.0;  // the part of the picture, from the top, that is shown (the wizard's own: cut off at the waist while stuck in the ground)
uniform vec4 near_white : source_color = vec4(0.92, 1.0, 1.0, 1.0);
uniform vec4 light : source_color = vec4(0.54, 0.92, 1.0, 1.0);
uniform vec4 mid : source_color = vec4(0.2, 0.72, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.1, 0.35, 0.69, 1.0);

void fragment() {
	if (UV.y > keep) {
		discard;
	}
	vec4 t = texture(TEXTURE, UV);
	float g = t.r;
	vec3 c = g >= 0.969 ? vec3(1.0) : g >= 0.835 ? near_white.rgb : g >= 0.624 ? light.rgb : g >= 0.388 ? mid.rgb : deep.rgb;
	COLOR = vec4(c, t.a * COLOR.a);
}
