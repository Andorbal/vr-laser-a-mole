// Dome pipes: dark metal with two neon stripes and energy pulses flowing
// up toward the core. UV.x wraps around the pipe, UV.y is meters along it,
// COLOR.r is a per-pipe random seed.
shader_type spatial;
render_mode shadows_disabled;

uniform vec3 metal_color : source_color = vec3(0.09, 0.09, 0.14);
uniform vec3 stripe_color : source_color = vec3(0.58, 0.3, 1.0);
uniform vec3 pulse_color : source_color = vec3(0.0, 0.9, 1.0);
uniform float pulse_speed = 2.2;
uniform float pulse_spacing = 3.5;
uniform float boost = 0.0;
uniform float danger = 0.0;

void fragment() {
	float around = UV.x;
	float along = UV.y;
	float seed = COLOR.r;
	float stripe = 1.0 - smoothstep(0.035, 0.07, abs(fract(around * 2.0) - 0.5));
	float s = (along - TIME * pulse_speed * (0.8 + 0.4 * seed)) / pulse_spacing + seed * 7.0;
	float pulse = pow(fract(s), 10.0);
	float rib = smoothstep(0.42, 0.5, abs(fract(along * 3.0) - 0.5));
	vec3 stripe_tint = mix(stripe_color, vec3(1.0, 0.12, 0.2), clamp(danger, 0.0, 1.0));
	vec3 emis = stripe_tint * stripe * (0.9 + 2.0 * boost);
	emis += pulse_color * pulse * (stripe * 4.0 + 0.5) * (1.0 + boost);
	ALBEDO = metal_color * (1.0 - rib * 0.5);
	METALLIC = 0.85;
	ROUGHNESS = 0.28 + rib * 0.2;
	EMISSION = emis;
}
