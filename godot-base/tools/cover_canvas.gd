extends Control

## Printed cover composition, rendered offline. No runtime animation or font dependency.

var design: Dictionary
var photograph: Texture2D
var _fonts: Dictionary[String, Font] = {}


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / 1024.0)
	var paper: Color = design["paper"]
	var ink: Color = design["ink"]
	var accent: Color = design["accent"]
	draw_rect(Rect2(0, 0, 1024, 1024), paper)
	_pattern(str(design["motif"]), ink, accent)
	var random := RandomNumberGenerator.new()
	random.seed = 1907
	for index in 1700:
		var at := Vector2(random.randf_range(0, 1024), random.randf_range(0, 1024))
		draw_line(at, at + Vector2(random.randf_range(1, 4), 0),
			Color(ink, 0.035), 1)
	if photograph != null:
		var rect: Rect2 = design["photo"]
		var outline := float(design.get("cutout", 0))
		if outline > 0:
			for index in 12:
				var offset := Vector2.from_angle(index * TAU / 12.0) * outline
				draw_texture_rect(photograph, Rect2(rect.position + offset, rect.size),
					false, Color(ink, 0.85))
		draw_texture_rect(photograph, rect, false)
	for line: Dictionary in design["lettering"]:
		_letter(line, ink)
	draw_set_transform(Vector2.ZERO)


func _pattern(motif: String, ink: Color, accent: Color) -> void:
	match motif:
		"speed":
			for index in 11:
				var x := -700.0 + index * 180.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(x, 1024), Vector2(x + 55, 1024),
					Vector2(x + 700, 0), Vector2(x + 645, 0),
				]), Color(accent, 0.10 if index % 3 else 0.65))
			draw_arc(Vector2(690, 650), 290, -1.6, 1.6, 90, accent, 8, true)
		"hazard":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, 370), Vector2(1024, 230),
				Vector2(1024, 960), Vector2(0, 1024),
			]), accent)
			for index in 18:
				var x := index * 86.0 - 200
				draw_line(Vector2(x, 1024), Vector2(x + 150, 924), ink, 35, true)
			_halftone(Rect2(560, 380, 430, 430), ink, 0.20)
		"rays":
			var center := Vector2(520, 620)
			for index in 18:
				var angle := index * TAU / 18.0
				draw_colored_polygon(PackedVector2Array([
					center, center + Vector2.from_angle(angle) * 1400,
					center + Vector2.from_angle(angle + 0.10) * 1400,
				]), Color(accent, 0.27))
		"checker":
			for row in 8:
				for col in 9:
					if (row + col) % 2 == 0:
						draw_colored_polygon(PackedVector2Array([
							Vector2(col * 145 - row * 30 - 100, 420 + row * 85),
							Vector2(col * 145 - row * 30 + 45, 420 + row * 85),
							Vector2(col * 145 - row * 30 + 15, 505 + row * 85),
							Vector2(col * 145 - row * 30 - 130, 505 + row * 85),
						]), Color(accent, 0.18))
			draw_line(Vector2(56, 356), Vector2(968, 356), accent, 4, true)
		"orbits":
			for radius in [180, 280, 380, 490]:
				draw_arc(Vector2(550, 650), radius, -PI, PI, 160,
					Color(accent, 0.35), 2, true)
			for index in 38:
				var angle := index * 2.39996
				var point := Vector2(540, 660) + Vector2.from_angle(angle) * (110 + index * 11)
				draw_circle(point, 3.0 if index % 4 else 7.0, accent, true, -1, true)
		"racing":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, 530), Vector2(1024, 285),
				Vector2(1024, 860), Vector2(0, 1110),
			]), accent)
			for index in 3:
				draw_line(Vector2(-80, 800 + index * 44),
					Vector2(1100, 520 + index * 44), ink, 12, true)
			for row in 2:
				for col in 12:
					if (row + col) % 2 == 0:
						draw_rect(Rect2(col * 48 + 450, row * 48 + 880, 48, 48), ink)
		"garden":
			draw_circle(Vector2(785, 520), 260, accent, true, -1, true)
			for index in 10:
				var x := index * 128.0 - 80
				draw_circle(Vector2(x, 1120), 260, Color("67a46a"), true, -1, true)
			_halftone(Rect2(25, 390, 240, 460), ink, 0.09)
		"waves":
			for row in 9:
				var points := PackedVector2Array()
				for x in range(-20, 1050, 12):
					points.append(Vector2(x, 520 + row * 65 + sin(x * 0.009 + row) * 48))
				draw_polyline(points, Color(accent, 0.24 + (row % 2) * 0.10), 20, true)
			draw_circle(Vector2(810, 420), 116, Color("f8d376"), true, -1, true)
		"terrace":
			for index in 11:
				var y := 460 + index * 58
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, y), Vector2(1024, y - 190),
					Vector2(1024, y - 171), Vector2(0, y + 19),
				]), Color(accent, 0.35))
			draw_colored_polygon(PackedVector2Array([
				Vector2(680, 0), Vector2(820, 0),
				Vector2(430, 1024), Vector2(290, 1024),
			]), Color(accent, 0.18))
		"blocks":
			for row in 8:
				for col in 10:
					var step := (col * 7 + row * 3) % 5
					if step < 2:
						draw_rect(Rect2(col * 120 - 60, row * 120 + 390, 108, 108),
							Color(accent, 0.13 + step * 0.12))
			draw_circle(Vector2(785, 500), 195, Color("ffdc8a"), true, -1, true)
		"confetti":
			draw_circle(Vector2(760, 600), 400, Color(accent, 0.3), true, -1, true)
			for index in 75:
				var x := float((index * 137 + 36) % 1024)
				var y := float((index * 233 + 400) % 1024)
				var color := accent if index % 2 else ink
				draw_line(Vector2(x, y), Vector2(x + 15, y - 26),
					Color(color, 0.40), 7, true)
		"bubbles":
			for index in 22:
				var center := Vector2((index * 271 + 40) % 1070, (index * 149 + 430) % 1100)
				var radius := float(25 + (index * 31) % 130)
				draw_circle(center, radius, Color(accent, 0.15), true, -1, true)
				draw_arc(center, radius, -2.9, -1.0, 32, Color(accent, 0.55), 3, true)
		"blueprint":
			for x in range(0, 1024, 64):
				draw_line(Vector2(x, 375), Vector2(x, 1024), Color(accent, 0.16), 1)
			for y in range(375, 1024, 64):
				draw_line(Vector2(0, y), Vector2(1024, y), Color(accent, 0.16), 1)
			draw_rect(Rect2(48, 438, 928, 438), accent, false, 3)
			draw_line(Vector2(740, 32), Vector2(970, 32), accent, 12)
		"metal":
			for index in 8:
				var x := index * 190.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 520, 1024), Vector2(x - 450, 1024),
					Vector2(x + 280, 335), Vector2(x + 210, 335),
				]), Color(accent, 0.27))
			_halftone(Rect2(0, 350, 1024, 674), accent, 0.12)
		"park":
			draw_circle(Vector2(820, 390), 130, accent, true, -1, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, 910), Vector2(1024, 715),
				Vector2(1024, 1024), Vector2(0, 1024),
			]), Color(accent, 0.50))
		_:
			push_error("Unknown cover motif: " + motif)


func _halftone(rect: Rect2, color: Color, opacity: float) -> void:
	for row in int(rect.size.y / 18):
		for col in int(rect.size.x / 18):
			var at := rect.position + Vector2(col * 18 + (row % 2) * 9, row * 18)
			draw_circle(at, 2.5, Color(color, opacity), true, -1, true)


func _letter(line: Dictionary, ink: Color) -> void:
	var font := _font(str(line.get("font", "display")))
	var text := str(line["text"])
	var font_size := int(line["size"])
	var width := float(line.get("width", 910.0))
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if measured > width:
		font_size = maxi(12, floori(font_size * width / measured))
	var at: Vector2 = line["at"]
	draw_set_transform(at * size / 1024.0, deg_to_rad(float(line.get("angle", 0))),
		size / 1024.0)
	var color: Color = line.get("color", ink)
	var alignment := int(line.get("align", HORIZONTAL_ALIGNMENT_LEFT))
	if line.get("shadow", false):
		draw_string(font, Vector2(5, 7), text, alignment, width, font_size, Color(ink, 0.8))
	var stroke := int(line.get("outline", 0))
	if stroke > 0:
		draw_string_outline(font, Vector2.ZERO, text, alignment, width,
			font_size, stroke, ink)
	draw_string(font, Vector2.ZERO, text, alignment, width, font_size, color)
	draw_set_transform(Vector2.ZERO, 0.0, size / 1024.0)


func _font(role: String) -> Font:
	if _fonts.has(role):
		return _fonts[role]
	var font := SystemFont.new()
	match role:
		"serif":
			font.font_names = PackedStringArray(["Georgia", "DejaVu Serif"])
			font.font_weight = 700
		"round":
			font.font_names = PackedStringArray(["Trebuchet MS", "DejaVu Sans"])
			font.font_weight = 800
		"mono":
			font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono"])
			font.font_weight = 600
		_:
			font.font_names = PackedStringArray(["Impact", "Noto Sans", "DejaVu Sans"])
			font.font_weight = 900
	_fonts[role] = font
	return font
