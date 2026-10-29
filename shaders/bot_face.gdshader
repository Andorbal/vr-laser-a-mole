// A bot's glossy screen-face with animated glowing eyes.
// The mesh is a sphere of radius `face_radius`; model-space XY are face coordinates.
// face: 0 idle, 1 happy/taunt, 2 dizzy, 3 scared, 4 angry, 5 stars, 6 hearts, 7 surprised.
shader_type spatial;
render_mode shadows_disabled;

uniform float face_radius = 0.2;
uniform float eye_scale = 1.25;
uniform float eye_spacing = 0.45;
uniform float energy = 3.2;
instance uniform vec4 eye_color : source_color = vec4(0.0, 0.9, 1.0, 1.0);
instance uniform float face = 0.0;
instance uniform float blink = 0.0;
instance uniform vec2 look = vec2(0.0, 0.0);
instance uniform float flash = 0.0;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float sd_star5(vec2 p, float r, float rf) {
	vec2 k1 = vec2(0.809016994375, -0.587785252292);
	vec2 k2 = vec2(-0.809016994375, -0.587785252292);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float sd_heart(vec2 p) {
	p.x = abs(p.x);
	if (p.y + p.x > 1.0) {
		vec2 a = p - vec2(0.25, 0.75);
		return sqrt(dot(a, a)) - 0.35355339;
	}
	vec2 b = p - vec2(0.0, 1.0);
	vec2 c = p - 0.5 * max(p.x + p.y, 0.0);
	return sqrt(min(dot(b, b), dot(c, c))) * sign(p.x - p.y);
}

float eye_shape(vec2 q, float side, int fid, float blink_amount) {
	if (fid == 1) {
		vec2 a = q + vec2(0.0, 0.06);
		float d = abs(length(a) - 0.15) - 0.045;
		if (a.y < 0.0) {
			d = length(vec2(abs(a.x) - 0.15, a.y)) - 0.045;
		}
		return d;
	}
	if (fid == 2) {
		float s = min(sd_segment(q, vec2(-0.12, -0.12), vec2(0.12, 0.12)), sd_segment(q, vec2(-0.12, 0.12), vec2(0.12, -0.12)));
		return s - 0.045;
	}
	if (fid == 3) {
		float ring = abs(length(q) - 0.16) - 0.035;
		float pupil = length(q) - 0.055;
		return min(ring, pupil);
	}
	if (fid == 4) {
		vec2 bq = vec2(q.x, q.y / max(1.0 - blink_amount * 0.9, 0.1));
		float body = sd_round_box(bq, vec2(0.13, 0.15), 0.08);
		vec2 n = normalize(vec2(-side * 0.65, 1.0));
		return max(body, dot(q, n) - 0.01);
	}
	if (fid == 5) {
		return sd_star5(q, 0.19, 0.45);
	}
	if (fid == 6) {
		return sd_heart((q + vec2(0.0, 0.16)) / 0.32) * 0.32;
	}
	if (fid == 7) {
		return length(q) - 0.17;
	}
	vec2 iq = vec2(q.x, q.y / max(1.0 - blink_amount * 0.92, 0.08));
	return sd_round_box(iq, vec2(0.11, 0.17), 0.1);
}

void fragment() {
	vec2 p = lp.xy / face_radius;
	int fid = int(face + 0.5);
	vec2 look_ofs = look * vec2(0.12, 0.08);
	float d = 1000.0;
	for (int i = 0; i < 2; i++) {
		float side = float(i) * 2.0 - 1.0;
		vec2 center = vec2(side * eye_spacing, 0.06) + look_ofs;
		d = min(d, eye_shape((p - center) / eye_scale, side, fid, blink) * eye_scale);
	}
	float fw = max(fwidth(d), 0.001);
	float shape = 1.0 - smoothstep(-fw, fw, d);
	float halo = exp(-max(d, 0.0) * 20.0) * 0.5;
	float scan = 0.8 + 0.2 * sin(p.y * 60.0 + TIME * 7.0);
	vec3 emis = eye_color.rgb * (shape * scan + halo) * energy * eye_color.a;
	emis += vec3(1.0) * clamp(flash, 0.0, 1.0) * 3.0;
	ALBEDO = vec3(0.008, 0.01, 0.018);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = emis;
}
