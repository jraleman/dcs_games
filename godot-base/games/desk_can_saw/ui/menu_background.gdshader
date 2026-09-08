shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.168627, 0.160784, 0.137255, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.070588, 0.058824, 0.047059, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.811765, 0.4, 1.0);
uniform vec2 aspect = vec2(1.0);
uniform float speed : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec2 p = UV * aspect;
	vec3 color = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, UV.y));
	float wood_area = smoothstep(0.34, 0.52, UV.y);
	float right_side = smoothstep(0.3, 0.85, UV.x);

	vec2 holes = fract(p * 32.0) - 0.5;
	float peg = 1.0 - smoothstep(0.055, 0.115, length(holes));
	color *= 1.0 - peg * (1.0 - wood_area) * 0.30;

	// Grain is static; only the soft task lamp breathes, and speed zero freezes it.
	float grain = sin(p.y * 180.0 + sin(p.x * 8.0 + p.y * 5.0) * 2.0
		+ sin(p.x * 19.0) * 0.4);
	float plank = fract(p.y * 9.0);
	float seam = 1.0 - smoothstep(0.012, 0.038, min(plank, 1.0 - plank));
	color *= mix(vec3(1.0), vec3(1.28, 1.03, 0.80), wood_area);
	color += vec3(0.055, 0.032, 0.014) * (0.5 + grain * 0.5)
		* wood_area * (0.5 + right_side * 0.5);
	color *= 1.0 - seam * wood_area * 0.35;

	float stripe = step(0.5, fract((p.x + p.y) * 14.0));
	color += glow_color.rgb * stripe * smoothstep(0.965, 0.985, UV.x) * 0.065;
	float lamp = exp(-length((UV - vec2(0.76, 0.14)) * aspect) * 3.0);
	color += glow_color.rgb * lamp * (0.97 + sin(TIME * speed) * 0.03) * 0.10;
	vec2 centered = (UV - 0.5) * aspect;
	color *= clamp(1.0 - dot(centered, centered) * 0.16, 0.4, 1.0);
	COLOR = vec4(color, 1.0);
}
