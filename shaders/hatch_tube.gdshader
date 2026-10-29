// The tube behind each hatch: dark ribbed metal with a light glowing deep inside.
// The tube is a CylinderMesh of height 1.3 whose +Y end is the deep end.
// Instance COLOR: rgb = glow color. INSTANCE_CUSTOM.r = glow intensity.
shader_type spatial;
render_mode shadows_disabled, cull_disabled;

varying float depth01;
varying vec4 custom;

void vertex() {
	depth01 = clamp(VERTEX.y / 1.3 + 0.5, 0.0, 1.0);
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	float rings = smoothstep(0.38, 0.5, abs(fract(depth01 * 9.0) - 0.5));
	ALBEDO = vec3(0.06, 0.06, 0.09) * (1.0 - rings * 0.5);
	METALLIC = 0.7;
	ROUGHNESS = 0.4;
	float glow = pow(depth01, 3.0) * (0.25 + custom.r * 2.5);
	EMISSION = COLOR.rgb * (glow + rings * 0.2 * custom.r * depth01);
}
