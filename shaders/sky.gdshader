// Synthwave night sky: gradient, nebula band, stars, a ringed planet and a
// striped sunset sun. No TIME, so Godot only bakes the radiance map once.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.012, 0.01, 0.05);
uniform vec3 mid_color : source_color = vec3(0.07, 0.025, 0.2);
uniform vec3 horizon_color : source_color = vec3(0.55, 0.08, 0.42);
uniform vec3 below_color : source_color = vec3(0.02, 0.008, 0.05);
uniform vec3 sun_dir = vec3(0.0, 0.12, -1.0);
uniform vec3 sun_top : source_color = vec3(1.0, 0.86, 0.32);
uniform vec3 sun_bottom : source_color = vec3(1.0, 0.16, 0.56);
uniform float sun_size = 0.22;
uniform vec3 planet_dir = vec3(-0.62, 0.42, 0.66);
uniform float planet_radius = 0.1;
uniform float star_density = 140.0;
uniform float nebula_strength = 0.65;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	float x00 = mix(n000, n100, f.x);
	float x10 = mix(n010, n110, f.x);
	float x01 = mix(n001, n101, f.x);
	float x11 = mix(n011, n111, f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 5.1);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;

	// Base gradient.
	vec3 col;
	if (h > 0.0) {
		float t = pow(h, 0.45);
		col = mix(horizon_color, mid_color, smoothstep(0.0, 0.4, t));
		col = mix(col, zenith_color, smoothstep(0.35, 1.0, t));
	} else {
		col = mix(horizon_color * 0.6, below_color, smoothstep(0.0, 0.06, -h));
	}

	vec3 sd = normalize(sun_dir);
	float sun_dot = dot(d, sd);

	// Horizon haze, strongest toward the sun.
	float haze = exp(-abs(h) * 12.0) * (0.35 + 0.65 * pow(max(sun_dot, 0.0), 3.0));
	col += horizon_color * haze * 0.9;

	// Nebula band across the sky.
	if (h > -0.05) {
		float n = fbm(d * 2.6 + vec3(1.7, 0.3, 2.9));
		float n2 = fbm(d * 5.5 + vec3(5.1, 2.2, 0.4));
		float band_dist = dot(d, normalize(vec3(0.35, 0.55, 0.75)));
		float band = exp(-band_dist * band_dist * 5.0);
		float neb = smoothstep(0.38, 0.8, n) * band;
		vec3 neb_col = mix(vec3(0.42, 0.06, 0.62), vec3(0.02, 0.38, 0.62), smoothstep(0.3, 0.7, n2));
		col += neb_col * neb * nebula_strength * smoothstep(-0.05, 0.3, h);
		col += vec3(0.5, 0.25, 0.8) * pow(max(n2 - 0.55, 0.0), 2.0) * band * 2.0 * smoothstep(0.0, 0.3, h);
	}

	// Stars.
	vec3 sp = d * star_density;
	vec3 cell = floor(sp);
	vec3 f = fract(sp) - 0.5;
	float rnd = hash13(cell);
	if (rnd > 0.9) {
		vec3 off = (hash33(cell) - 0.5) * 0.5;
		float dist = length(f - off);
		float bright = (rnd - 0.9) / 0.1;
		float star = 1.0 - smoothstep(0.0, 0.16 + 0.14 * bright, dist);
		vec3 star_col = mix(vec3(0.7, 0.82, 1.0), vec3(1.0, 0.72, 0.92), hash13(cell + 7.0));
		col += star_col * star * (0.5 + 3.0 * bright * bright) * smoothstep(0.0, 0.12, h);
	}

	// Ringed planet.
	vec3 pd = normalize(planet_dir);
	float pdot = dot(d, pd);
	if (pdot > 0.94) {
		vec3 px_axis = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
		vec3 py_axis = cross(px_axis, pd);
		vec2 q = vec2(dot(d, px_axis), dot(d, py_axis)) / planet_radius;
		float ca = cos(0.42);
		float sa = sin(0.42);
		vec2 rq = vec2(ca * q.x - sa * q.y, sa * q.x + ca * q.y);
		float r2 = dot(q, q);
		float ring_r = length(vec2(rq.x, rq.y / 0.24));
		float ring = smoothstep(1.3, 1.38, ring_r) * (1.0 - smoothstep(2.12, 2.25, ring_r));
		ring *= 0.55 + 0.45 * sin(ring_r * 38.0);
		vec3 ring_col = vec3(0.95, 0.62, 1.0) * ring * 0.75;
		if (r2 < 1.0) {
			float z = sqrt(1.0 - r2);
			vec3 n = vec3(q, z);
			float lit = clamp(dot(n, normalize(vec3(0.75, 0.25, 0.6))), 0.0, 1.0);
			float bands = sin(rq.y * 9.0 + sin(rq.x * 3.0) * 0.8) * 0.5 + 0.5;
			vec3 pcol = mix(vec3(0.12, 0.3, 0.7), vec3(0.62, 0.28, 0.82), bands) * (0.06 + 0.9 * lit);
			pcol += vec3(0.35, 0.55, 1.0) * pow(1.0 - z, 3.0) * 0.7;
			col = pcol;
			if (rq.y < 0.0) {
				col = mix(col, ring_col * 1.4, clamp(ring * 0.85, 0.0, 1.0));
			}
		} else {
			col += ring_col;
			col += vec3(0.3, 0.45, 1.0) * exp(-(sqrt(r2) - 1.0) * 7.0) * 0.3;
		}
	}

	// Synthwave sun with horizontal stripes cut into its lower half.
	float ang = acos(clamp(sun_dot, -1.0, 1.0));
	if (ang < sun_size * 1.02) {
		vec3 up_axis = normalize(vec3(0.0, 1.0, 0.0) - sd * sd.y);
		float v = dot(d - sd * sun_dot, up_axis) / sin(sun_size);
		float disc = 1.0 - smoothstep(sun_size * 0.99, sun_size * 1.01, ang);
		float stripes = 1.0;
		float gap = clamp((0.25 - v) * 0.42, 0.0, 0.6);
		if (gap > 0.0) {
			float s = fract(v * 7.0);
			stripes = smoothstep(gap - 0.035, gap + 0.035, s);
		}
		vec3 sun_col = mix(sun_bottom, sun_top, smoothstep(-0.85, 0.75, v));
		col = mix(col, sun_col * 2.4, disc * stripes);
	}
	col += mix(sun_bottom, sun_top, 0.4) * 0.45 * exp(-max(ang - sun_size, 0.0) * 9.0);

	COLOR = col;
}
