// Distant wireframe mountains. Vertex COLOR holds barycentric coordinates
// (one channel per triangle corner) so edges can be drawn crisply at any distance.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 fill_top : source_color = vec3(0.16, 0.04, 0.26);
uniform vec3 fill_bottom : source_color = vec3(0.025, 0.008, 0.06);
uniform vec3 haze_color : source_color = vec3(0.55, 0.08, 0.42);
uniform vec3 edge_color : source_color = vec3(0.0, 0.85, 1.0);
uniform vec3 peak_color : source_color = vec3(1.0, 0.2, 0.8);
uniform float edge_energy = 1.8;

varying float height01;

void vertex() {
	height01 = UV.y;
}

void fragment() {
	vec3 b = COLOR.rgb;
	vec3 fw = max(fwidth(b), vec3(0.0001));
	vec3 e = smoothstep(vec3(0.0), fw * 1.3, b);
	float edge = 1.0 - min(min(e.x, e.y), e.z);
	vec3 col = mix(fill_bottom, fill_top, height01);
	col = mix(haze_color * 0.5, col, smoothstep(0.0, 0.35, height01));
	vec3 line = mix(edge_color, peak_color, smoothstep(0.45, 1.0, height01));
	col += line * edge * edge_energy * (0.2 + 0.8 * height01);
	ALBEDO = col;
}
