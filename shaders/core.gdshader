// The swirling energy core at the top of the dome.
shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

uniform vec3 color_a : source_color = vec3(0.0, 0.9, 1.0);
uniform vec3 color_b : source_color = vec3(1.0, 0.17, 0.78);
uniform float energy = 2.5;
uniform float boost = 0.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float a = atan(lp.z, lp.x);
	float swirl = sin(lp.y * 16.0 + TIME * 3.0 + sin(a * 3.0 + TIME * 1.3) * 2.0) * 0.5 + 0.5;
	vec3 c = mix(color_a, color_b, swirl);
	ALBEDO = c * energy * (0.35 + fres * 1.8 + boost * 1.5);
}
