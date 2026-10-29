// Glowing ring around each hatch (drawn with a MultiMesh).
// Instance COLOR: rgb = linear color, a = energy.
// INSTANCE_CUSTOM: r = telegraph progress (segments light up in turn),
// g = white flash, b = taunt flicker.
shader_type spatial;
render_mode shadows_disabled;

varying vec4 custom;
varying float ring_angle;

void vertex() {
	custom = INSTANCE_CUSTOM;
	ring_angle = atan(VERTEX.z, VERTEX.x);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float energy = COLOR.a * 4.0;
	float turn = ring_angle / 6.2831853 + 0.5;
	float seg = fract(turn * 12.0);
	float seg_mask = smoothstep(0.08, 0.18, seg) * (1.0 - smoothstep(0.82, 0.92, seg));
	float idx = floor(turn * 12.0) / 12.0;
	float lit = step(idx, custom.r - 0.0001) * step(0.0001, custom.r);
	float flicker = 1.0 + custom.b * sin(TIME * 40.0) * 0.5;
	vec3 emis = c * energy * (0.45 + 0.55 * seg_mask) * flicker;
	emis += c * lit * seg_mask * 7.0;
	emis = mix(emis, vec3(5.0), clamp(custom.g, 0.0, 1.0));
	ALBEDO = vec3(0.04);
	METALLIC = 0.6;
	ROUGHNESS = 0.3;
	EMISSION = emis;
}
