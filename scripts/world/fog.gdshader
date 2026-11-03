shader_type canvas_item;
// Drifting zone fog, quantized to the art-pixel grid with ordered dithering.
// The local player clears a pocket around them; lamps and teammates thin it.

uniform vec2 focus = vec2(0.0);
uniform float clear_radius = 230.0;
uniform float density = 0.55;
uniform float ceiling = 0.82;
uniform vec4 fog_color : source_color = vec4(0.56, 0.7, 0.68, 1.0);
uniform vec3 lights[24];
uniform int light_count = 0;
uniform float art_pixel = 3.0;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void fragment() {
	vec2 cell = floor(world / art_pixel);
	vec2 w = cell * art_pixel;
	// Rotated octaves hide the value-noise lattice that would otherwise read as boxes.
	vec2 a = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * w;
	vec2 b = mat2(vec2(0.28, 0.96), vec2(-0.96, 0.28)) * w;
	float drift = noise(a * 0.0035 + vec2(TIME * 0.045, TIME * 0.018)) * 0.5
		+ noise(b * 0.008 - vec2(TIME * 0.07, -TIME * 0.025)) * 0.32
		+ noise(w * 0.019 + vec2(TIME * 0.02, TIME * 0.06)) * 0.18;
	float pocket = smoothstep(clear_radius * 0.3, clear_radius, distance(w, focus));
	float lit = 1.0;
	for (int i = 0; i < 24; i++) {
		if (i >= light_count) {
			break;
		}
		float d = distance(w, lights[i].xy);
		lit = min(lit, mix(0.35, 1.0, smoothstep(lights[i].z * 0.25, lights[i].z, d)));
	}
	float amount = density * pocket * lit * (0.45 + drift * 0.85);
	float stepped = floor(amount * 5.0 + bayer4(cell)) / 5.0;
	COLOR = vec4(fog_color.rgb, clamp(stepped, 0.0, ceiling));
}
