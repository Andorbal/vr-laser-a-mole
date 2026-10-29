// Laser beam on a cylinder: white-hot core fading into a colored glow toward
// the silhouette. Looks right from any angle and in both eyes.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform float energy = 3.0;
uniform float core_power = 8.0;
uniform float glow_power = 1.6;
instance uniform vec4 beam_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);

void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float core = pow(facing, core_power);
	float glow = pow(facing, glow_power);
	ALBEDO = (beam_color.rgb * glow + vec3(core * 0.9)) * energy * beam_color.a;
}
