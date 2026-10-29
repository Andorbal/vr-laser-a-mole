// Head-locked chevrons pointing at bots outside the view. Drawn on top of
// everything. The chevron points along the quad's +X axis.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 2.2;
instance uniform vec4 arrow_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
instance uniform float urgency = 0.0;

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d1 = min(sd_segment(p, vec2(-0.15, -0.6), vec2(0.45, 0.0)), sd_segment(p, vec2(-0.15, 0.6), vec2(0.45, 0.0)));
	float d2 = min(sd_segment(p, vec2(-0.65, -0.45), vec2(-0.2, 0.0)), sd_segment(p, vec2(-0.65, 0.45), vec2(-0.2, 0.0)));
	float w = 0.12;
	float s1 = 1.0 - smoothstep(w - 0.05, w + 0.05, d1);
	float s2 = (1.0 - smoothstep(w * 0.8 - 0.05, w * 0.8 + 0.05, d2)) * 0.5;
	float glow = exp(-min(d1, d2) * 5.0) * 0.3 * (1.0 - smoothstep(0.7, 1.0, length(p)));
	float pulse = 0.75 + 0.25 * sin(TIME * (5.0 + urgency * 16.0));
	ALBEDO = arrow_color.rgb * (max(s1, s2) + glow) * energy * pulse * arrow_color.a;
}
