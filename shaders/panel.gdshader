// Holographic UI panel: rounded rectangle with a neon border and scanlines.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform float corner = 0.04;
uniform float border = 0.007;
uniform float fill_alpha = 0.6;
instance uniform vec4 panel_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
instance uniform vec2 panel_size = vec2(1.0, 0.5);
instance uniform float highlight = 0.0;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * panel_size;
	float d = sd_round_box(p, panel_size * 0.5, corner);
	float fw = max(fwidth(d), 0.0001);
	float inside = 1.0 - smoothstep(-fw, fw, d);
	float bord = 1.0 - smoothstep(border, border + fw * 1.5, abs(d + border));
	float scan = 0.85 + 0.15 * sin(p.y * 500.0 - TIME * 3.0);
	float grad = 1.0 - UV.y;
	vec3 fill = mix(vec3(0.015, 0.008, 0.05), panel_color.rgb * 0.2, 0.3 + 0.4 * grad) * scan;
	fill += panel_color.rgb * highlight * 0.3;
	float hl = clamp(highlight, 0.0, 1.0);
	vec3 col = mix(fill, panel_color.rgb * (1.8 + hl * 2.0), bord);
	ALBEDO = col;
	ALPHA = inside * mix(fill_alpha + hl * 0.2, 1.0, bord) * panel_color.a;
}
