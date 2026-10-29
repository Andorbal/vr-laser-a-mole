// Endless neon grid floor with anti-aliased lines that fade out before they alias.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 base_color : source_color = vec3(0.03, 0.012, 0.07);
uniform vec3 line_color : source_color = vec3(1.0, 0.17, 0.78);
uniform vec3 major_color : source_color = vec3(0.0, 0.9, 1.0);
uniform float cell = 2.0;
uniform float line_width = 0.013;
uniform float energy = 2.0;
uniform float dome_radius = 5.4;
uniform float platform_radius = 1.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_lines(vec2 uv, float width, float halo_falloff) {
	vec2 w = fwidth(uv);
	vec2 a = abs(fract(uv - 0.5) - 0.5);
	vec2 l = 1.0 - smoothstep(vec2(width) - w, vec2(width) + w, a);
	// Soft neon halo around each line.
	l += exp(-a * halo_falloff) * 0.3;
	// Lines thinner than a pixel shimmer, so fade them as they get dense.
	vec2 fade = 1.0 - smoothstep(vec2(0.12), vec2(0.5), w);
	l *= fade;
	return max(l.x, l.y);
}

void fragment() {
	vec2 p = world_pos.xz;
	float r = length(p);
	float minor = grid_lines(p / cell, line_width, 30.0);
	float major = grid_lines(p / (cell * 6.0), line_width / 6.0, 180.0);
	float near = exp(-max(r - dome_radius, 0.0) * 0.04);
	vec3 col = base_color;
	col += line_color * minor * energy * (0.3 + 0.7 * near);
	col += major_color * major * energy * 0.8;
	// Glowing ring where the dome meets the floor.
	col += major_color * exp(-abs(r - dome_radius) * 6.0) * 0.8;
	col += line_color * exp(-abs(r - dome_radius - 0.6) * 9.0) * 0.5;
	// Soft light pool around the platform.
	col += vec3(0.3, 0.08, 0.5) * exp(-max(r - platform_radius, 0.0) * 0.6) * 0.45;
	ALBEDO = col;
}
