// Additive camera-facing radial glow. Used for muzzle flashes, impacts,
// the aiming dot and halos. Per-instance tint via instance uniform.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 2.0;
uniform float sharpness = 3.0;
uniform float core_amount = 0.6;
uniform bool billboard = true;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	if (billboard) {
		mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		mat4 scale = mat4(
				vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * facing * scale;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d2 = dot(p, p);
	float edge = 1.0 - smoothstep(0.7, 1.0, d2);
	float g = exp(-d2 * sharpness) * edge;
	float core = exp(-d2 * sharpness * 8.0);
	ALBEDO = (tint.rgb * g + vec3(core * core_amount)) * energy * tint.a;
}
