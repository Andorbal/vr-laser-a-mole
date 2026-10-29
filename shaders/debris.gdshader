// Glowing shards for explosions; CPUParticles3D feeds the particle color via COLOR.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform float energy = 2.5;

void fragment() {
	ALBEDO = COLOR.rgb * energy;
}
