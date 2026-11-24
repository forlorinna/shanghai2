shader_type canvas_item;
uniform vec2 midpoint = vec2(0.5);
uniform vec2 span = vec2(1.0);
uniform bool round_map = false;
void fragment() {
	if (round_map && length(UV - vec2(0.5)) > 0.497) {
		discard;
	}
	vec2 tile = midpoint + (UV - vec2(0.5)) * span;
	if (any(lessThan(tile, vec2(0.0))) || any(greaterThan(tile, vec2(1.0)))) {
		COLOR = vec4(0.027, 0.051, 0.065, 1.0);
	} else {
		COLOR = texture(TEXTURE, tile);
	}
}
