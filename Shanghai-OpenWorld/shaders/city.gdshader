shader_type spatial;
render_mode cull_disabled;
global uniform float night;
global uniform float wetness;
uniform int surface_type = 0;
varying vec3 world;
varying vec3 normal_world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float noise = hash(floor(world.xz * 4.0));
	ALBEDO = base * (0.977 + noise * 0.035);
	ROUGHNESS = 0.87;
	if (surface_type == 0 && abs(normal_world.y) < 0.4) {
		float u = mix(world.x, world.z, step(abs(normal_world.x), abs(normal_world.z)));
		vec2 grid = vec2(u / 2.65, world.y / 3.3);
		vec2 f = fract(grid);
		float distance_to_camera = distance(world, CAMERA_POSITION_WORLD);
		float edge = max(fwidth(grid.x), fwidth(grid.y)) * 0.9 + 0.008;
		float windows = smoothstep(0.14, 0.14 + edge, f.x) * (1.0 - smoothstep(0.82 - edge, 0.82, f.x));
		windows *= smoothstep(0.22, 0.22 + edge, f.y) * (1.0 - smoothstep(0.80 - edge, 0.80, f.y));
		windows *= 1.0 - smoothstep(195.0, 460.0, distance_to_camera);
		float hue = hash(floor(grid) + floor(world.xz / 25.0));
		vec3 glass = mix(vec3(0.051, 0.090, 0.128), vec3(0.202, 0.309, 0.388), hue);
		ALBEDO = mix(ALBEDO, glass, windows);
		ROUGHNESS = mix(0.76, 0.32, windows);
		EMISSION = vec3(1.0, 0.55, 0.21) * windows * night * step(0.65, hue) * 0.48;
	}
	if (surface_type == 1) {
		float puddle = smoothstep(0.42, 0.76, sin(world.x * 0.31) * cos(world.z * 0.23));
		ALBEDO *= 1.0 - wetness * (0.27 + puddle * 0.22);
		ROUGHNESS = mix(0.89, 0.29 - 0.19 * puddle, wetness);
	}
	if (surface_type == 3) {
		EMISSION = base * night * 3.1;
	}
}
