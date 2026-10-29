// Faint hexagonal force field enclosing the dome. Missed shots splash
// ripples across it (up to four at once).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, shadows_disabled, fog_disabled;

#include "res://shaders/common.gdshaderinc"

uniform vec3 color : source_color = vec3(0.3, 0.45, 1.0);
uniform vec3 impact_color : source_color = vec3(1.0, 0.35, 0.9);
uniform float line_alpha = 0.05;
uniform float hex_count = 42.0;
uniform float boost = 0.0;
uniform float now = 0.0;
uniform vec4 impacts[4];

varying vec3 local_dir;

void vertex() {
	local_dir = VERTEX;
}

void fragment() {
	vec3 d = normalize(local_dir);
	float lon = atan(d.x, -d.z);
	float lat = asin(clamp(d.y, -1.0, 1.0));
	vec2 uv = vec2(lon, lat) * (hex_count / 6.2831853);
	vec4 h = hex_coords(uv);
	float edge = hex_edge(h.xy);
	float fw = fwidth(edge);
	float line = 1.0 - smoothstep(0.0, 0.02 + fw * 1.5, edge);
	float pole_fade = 1.0 - smoothstep(0.55, 0.8, abs(d.y));
	float sparkle = step(0.93, hash21(h.zw)) * (0.5 + 0.5 * sin(TIME * 2.0 + hash21(h.zw + 3.1) * 40.0));
	vec3 col = color * line * pole_fade * (line_alpha * (1.0 + boost * 3.0) + sparkle * 0.05);
	col += color * exp(-abs(d.y + 0.2) * 9.0) * 0.04;

	for (int i = 0; i < 4; i++) {
		vec4 imp = impacts[i];
		float age = now - imp.w;
		if (age >= 0.0 && age < 1.4 && dot(imp.xyz, imp.xyz) > 0.0001) {
			float dist = acos(clamp(dot(d, normalize(imp.xyz)), -1.0, 1.0));
			float x = (dist - age * 0.7) * 16.0;
			float ring = exp(-x * x);
			float fade = 1.0 - age / 1.4;
			float core = exp(-dist * 28.0) * exp(-age * 7.0);
			col += impact_color * (ring * (line * 2.5 + 0.15) * fade + core * 1.6);
		}
	}
	ALBEDO = col;
}
