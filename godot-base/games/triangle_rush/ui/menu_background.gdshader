shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_color : source_color = vec4(0.090196, 0.121569, 0.219608, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.031373, 0.05098, 0.105882, 1.0);
uniform vec4 glow_color : source_color = vec4(0.4, 0.937255, 0.835294, 1.0);
uniform vec2 aspect = vec2(1.0);
uniform float speed : hint_range(0.0, 1.0) = 0.18;

float triangle_outline(vec2 p, float radius) {
	float edge = max(abs(p.x) * 0.8660254 - p.y * 0.5, p.y) - radius * 0.5;
	return 1.0 - smoothstep(0.003, 0.009, abs(edge));
}

void fragment() {
	vec2 p = (UV - 0.5) * aspect;
	vec3 color = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, UV.y));
	float time = TIME * speed;

	// Geometry stays mostly behind the plaque, not the menu's reading column.
	float right_side = smoothstep(0.28, 0.85, UV.x);
	vec2 grid = p * 7.0;
	float horizontal = abs(fract(grid.y) - 0.5);
	float rising = abs(fract(dot(grid, vec2(0.8660254, 0.5))) - 0.5);
	float falling = abs(fract(dot(grid, vec2(-0.8660254, 0.5))) - 0.5);
	float lines = 1.0 - smoothstep(0.006, 0.035, min(horizontal, min(rising, falling)));
	color += glow_color.rgb * lines * right_side * 0.028;

	vec2 target = (UV - vec2(0.76, 0.47)) * aspect;
	target.y += sin(time) * 0.018;
	float rings = triangle_outline(target, 0.38) + triangle_outline(target, 0.60);
	color += glow_color.rgb * rings * right_side * 0.045;
	float glow = exp(-length(target) * 3.0);
	color += glow_color.rgb * glow * 0.075;
	color *= clamp(1.0 - dot(p, p) * 0.16, 0.4, 1.0);
	COLOR = vec4(color, 1.0);
}
