shader_type spatial;
render_mode cull_disabled;
global uniform float night;
global uniform float wetness;
global uniform float water_detail;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = sin(world.x * 0.112 + world.z * 0.171 + TIME * 1.9);
	float b = cos(world.x * 0.211 - world.z * 0.389 - TIME * 2.1);
	float rain = sin((world.x + world.z) * 2.22 + TIME * 12.0) * wetness * water_detail;
	NORMAL = normalize(NORMAL + vec3(a * 0.10, b * 0.13, rain * 0.035));
	float band = pow(max(0.0, sin(world.x * 0.039 + world.z * 0.02 + a * 0.4)), 13.0);
	float glint = pow(max(0.0, a * 0.5 + b * 0.5), 4.0);
	ALBEDO = mix(vec3(0.055, 0.233, 0.278), vec3(0.012, 0.066, 0.10), night)
		+ vec3(0.09, 0.14, 0.15) * glint * water_detail;
	ROUGHNESS = 0.24 + b * 0.06;
	SPECULAR = 0.76;
	EMISSION = mix(vec3(0.04, 0.19, 0.23), (vec3(0.34, 0.10, 0.20) * pow(max(0.0, sin((world.z + 510.0) * 0.023 + a * 0.12)), 12.0) + vec3(0.46, 0.36, 0.21) * band),
		night) * (0.12 + glint * 0.42 * water_detail);
}
