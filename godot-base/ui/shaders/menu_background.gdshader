shader_type canvas_item;

// Resolution-independent menu backdrop: vertical gradient, two slowly
// drifting glows, a vignette and a touch of grain to stop the gradient
// from banding. Everything is driven by UV, so it looks identical on a
// phone and on an ultrawide monitor.

uniform vec4 top_color : source_color = vec4(0.086, 0.129, 0.157, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.035, 0.055, 0.067, 1.0);
uniform vec4 glow_color : source_color = vec4(0.686, 0.867, 0.918, 1.0);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.20;
uniform float vignette : hint_range(0.0, 2.0) = 0.85;
uniform float speed : hint_range(0.0, 1.0) = 0.06;
uniform float grain : hint_range(0.0, 0.1) = 0.012;
// Set from ui/components/background.gd so the glows stay circular.
uniform vec2 aspect = vec2(1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, uv.y));

	vec2 p = (uv - vec2(0.5)) * aspect;
	float t = TIME * speed;

	vec2 c1 = vec2(sin(t * 1.3) * 0.26, cos(t) * 0.18 - 0.12);
	col += glow_color.rgb * glow_strength * exp(-length(p - c1) * 3.0);

	vec2 c2 = vec2(cos(t * 0.7) * -0.30, sin(t * 1.1) * 0.22 + 0.18);
	col += glow_color.rgb * glow_strength * 0.55 * exp(-length(p - c2) * 4.2);

	col *= clamp(1.0 - vignette * dot(p, p) * 0.6, 0.0, 1.0);

	float n = fract(sin(dot(uv * vec2(1024.0, 768.0), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain;

	COLOR = vec4(col, 1.0);
}
