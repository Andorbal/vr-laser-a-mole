// Mechanical iris door over each hatch (drawn with a MultiMesh of quads).
// INSTANCE_CUSTOM: r = open amount (0 closed, 1 open), g = seam glow.
// Instance COLOR: rgb = glow color.
shader_type spatial;
render_mode shadows_disabled, cull_disabled;

varying vec4 custom;

void vertex() {
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float open = clamp(custom.r, 0.0, 1.0);
	float hole = open * 1.05;
	if (r > 1.0 || r < hole) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float b = fract(ang / 6.2831853 * 8.0 + r * 0.9 - open * 1.6);
	float seam = 1.0 - smoothstep(0.0, 0.07, min(b, 1.0 - b));
	float lip = exp(-(r - hole) * 16.0) * step(0.01, open);
	float rim_shade = smoothstep(0.75, 1.0, r);
	vec3 base = vec3(0.13, 0.13, 0.19) * (0.75 + 0.45 * b) * (1.0 - rim_shade * 0.5);
	ALBEDO = base * (1.0 - seam * 0.75);
	METALLIC = 0.9;
	ROUGHNESS = 0.28 + 0.25 * b;
	EMISSION = COLOR.rgb * (seam * 0.8 * custom.g + lip * 3.0);
}
