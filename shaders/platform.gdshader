// The hex-tiled platform the player stands on. Pulses a ripple when the
// player scores and flashes red when something bad happens.
shader_type spatial;
render_mode shadows_disabled;

#include "res://shaders/common.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.05, 0.05, 0.08);
uniform vec3 seam_color : source_color = vec3(0.58, 0.3, 1.0);
uniform vec3 pulse_color : source_color = vec3(0.0, 0.9, 1.0);
uniform float hex_scale = 5.0;
uniform float now = 0.0;
uniform float pulse_time = -100.0;
uniform float danger = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = local_pos.xz * hex_scale;
	vec4 h = hex_coords(uv);
	float edge = hex_edge(h.xy);
	float fw = fwidth(edge);
	float seam = 1.0 - smoothstep(0.015, 0.035 + fw * 1.5, edge);
	float r = length(local_pos.xz);
	float age = now - pulse_time;
	float wave = 0.0;
	if (age >= 0.0 && age < 2.0) {
		float x = (r - age * 2.5) * 5.0;
		wave = exp(-x * x) * (1.0 - age * 0.5);
	}
	float rnd = hash21(h.zw);
	float shimmer = 0.5 + 0.5 * sin(TIME * 1.1 + rnd * 6.2831);
	vec3 emis = seam_color * seam * (0.55 + 0.45 * shimmer) * 1.4;
	emis += pulse_color * wave * (seam * 3.0 + 0.35);
	emis += seam_color * 0.06 * (1.0 - smoothstep(0.0, 0.35, r));
	vec3 danger_col = vec3(1.0, 0.1, 0.15) * (seam * 2.5 + 0.25);
	emis = mix(emis, danger_col, clamp(danger, 0.0, 1.0));
	ALBEDO = base_color * (0.75 + 0.5 * rnd);
	METALLIC = 0.65;
	ROUGHNESS = 0.22 + 0.25 * rnd;
	EMISSION = emis;
}
