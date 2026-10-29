// Shared helpers for the game's shaders.

const vec2 HEX_S = vec2(1.0, 1.7320508);

// Returns the position inside the nearest hexagon (xy) and that hexagon's id (zw).
vec4 hex_coords(vec2 uv) {
	vec4 hc = floor(vec4(uv, uv - vec2(0.5, 1.0)) / HEX_S.xyxy) + 0.5;
	vec4 h = vec4(uv - hc.xy * HEX_S, uv - (hc.zw + 0.5) * HEX_S);
	if (dot(h.xy, h.xy) < dot(h.zw, h.zw)) {
		return vec4(h.xy, hc.xy);
	}
	return vec4(h.zw, hc.zw + vec2(0.5, 1.0));
}

// Distance from a point inside a hexagon (from hex_coords) to its edge; 0 on the edge.
float hex_edge(vec2 p) {
	p = abs(p);
	return 0.5 - max(dot(p, HEX_S * 0.5), p.x);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
