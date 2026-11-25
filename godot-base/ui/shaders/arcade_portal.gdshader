shader_type canvas_item;
render_mode unshaded;

uniform sampler2D scene_color : hint_screen_texture, filter_linear, repeat_disable;
uniform bool uncovering = false;
uniform float frozen_coverage = -1.0;

float cell_hash(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	float opacity = COLOR.a;
	if (opacity <= 0.0) {
		COLOR = vec4(0.0);
	} else if (opacity >= 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float cover = frozen_coverage >= 0.0 ? frozen_coverage : opacity;
		// In short-side units; the rim must clear the corners at any aspect.
		float ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		vec2 aspect = vec2(ratio, 1.0) / min(1.0, ratio);
		vec2 point = (UV - 0.5) * aspect;
		float radius = length(point);
		float angle = atan(point.y, point.x + 0.00001);
		float turn = uncovering ? 2.0 - cover : cover;

		// Swallow the title from its centre, then open a window into the plaza.
		float sweep = uncovering ? 1.0 - cover : cover;
		float rim = mix(-0.12, length(aspect * 0.5) + 0.20, pow(sweep, 1.35));
		float curls = 0.031 * sin(5.0 * angle - turn * 7.0 - radius * 9.0)
			+ 0.015 * sin(9.0 * angle - turn * 9.0 + radius * 14.0);
		float edge = radius + curls * smoothstep(0.02, 0.15, radius) - rim;
		float mouth = smoothstep(-0.10, 0.085, edge);
		float veil = uncovering ? mouth : 1.0 - mouth;
		float wake = 1.0 - smoothstep(0.025, 0.19, abs(edge));
		float energy = smoothstep(0.0, 0.18, cover) * (1.0 - smoothstep(0.80, 1.0, cover));

		float gravity = energy * exp(-radius * 1.7);
		float bend = gravity * (uncovering ? 0.32 : 1.10);
		mat2 spin = mat2(vec2(cos(bend), sin(bend)), vec2(-sin(bend), cos(bend)));
		vec2 bent = spin * point * (1.0 + gravity * (uncovering ? 0.14 : 0.76));
		vec3 view = textureLod(scene_color, SCREEN_UV + (bent - point) / aspect, 0.0).rgb;
		view *= 1.0 - 0.42 * energy;

		// Layer a broad, softly broken spiral over a narrow illuminated lip.
		float coil = 4.0 * angle - 18.0 * radius - turn * 10.0;
		float twist = sin(3.0 * angle + 13.0 * radius - turn * 5.0);
		float mist = pow(0.5 + 0.5 * sin(coil + twist * 0.85), 2.5);
		float threads = pow(0.5 + 0.5 * sin(coil * 2.0 + twist), 7.0);
		float core = smoothstep(0.015, 0.14, radius);
		vec3 fog = vec3(0.018, 0.045, 0.065)
			+ vec3(0.07, 0.33, 0.29) * mist * core * (0.32 + 0.68 * wake);
		vec3 result = mix(view, fog, veil);
		float lip = 1.0 - smoothstep(0.006, 0.047, abs(edge));
		result += vec3(0.15, 0.61, 0.49) * energy * core
			* (lip * (0.32 + threads * 0.68) + wake * mist * 0.32);

		// Polar cells carry flecks inward along the spiral, without emitter nodes.
		vec2 grid = vec2((angle / TAU + turn * 0.40 + radius * 0.28) * 44.0,
			radius * 24.0 + turn * 8.0);
		vec2 cell = floor(grid);
		cell.x = mod(cell.x, 44.0);
		float seed = cell_hash(cell);
		vec2 fleck = (fract(grid) - vec2(0.27 + 0.46 * seed, 0.5)) * vec2(1.5, 0.85);
		float sparks = step(0.78, seed) * (1.0 - smoothstep(0.06, 0.20, length(fleck)));
		result += vec3(0.98, 0.60, 0.22) * sparks * energy * core * (0.25 + 0.75 * wake);

		// A live accessibility change fades this exact frame rather than moving its rim.
		float alpha = 1.0;
		if (frozen_coverage >= 0.0) {
			if (opacity >= cover) {
				result *= (1.0 - opacity) / max(1.0 - cover, 0.0001);
			} else {
				alpha = opacity / max(cover, 0.0001);
			}
		}
		result *= 1.0 - smoothstep(0.89, 1.0, cover);
		COLOR = vec4(result, alpha);
	}
}
