class_name GameCard
extends Button

## One game on the picker's shelf, drawn as the cartridge the title screen
## seats in its console: a dark shell with ribbed grips and a gold edge
## connector, wearing a label in the game's own colours.
##
## The label carries the game's logo, its title and what it can be played as.
## Its window shows the game's own footage while this is the cartridge the
## player holds: the poster at once, then the tutorial clip. Everything else is
## drawn, so a new game needs no picker art beyond the [GameTheme] and tutorial
## media its manifest already declares.
##
## A dumb view on purpose. It is a class_name script that headless tests
## import, so it touches no autoload instance. The screen decides which
## cartridge is current, whether clips may run and where each one stands;
## a press is reported through [signal BaseButton.pressed] like any button.

## Proportions of the title screen's cartridge, in its model units.
const MODEL_WIDTH := 3.28
const MODEL_SHELL := 2.65
const MODEL_HEIGHT := 2.885
## Height of the whole cartridge, connector included, per unit of width.
const HEIGHT_RATIO := MODEL_HEIGHT / MODEL_WIDTH
## Height of the shell alone, per unit of width.
const SHELL_RATIO := MODEL_SHELL / MODEL_WIDTH
## How far the edge connector reaches below the shell, per unit of width.
const CONNECTOR_RATIO := (MODEL_HEIGHT - MODEL_SHELL) / MODEL_WIDTH

## Seconds a cartridge must stay current before its clip starts, so browsing
## quickly past a game never begins decoding its video.
const PREVIEW_DELAY := 0.3
const SCREEN_FADE := 0.22

## Shell parts, in model units.
const LABEL := Rect2(0.39, 0.165, 2.5, 2.24)
const RECESS := Rect2(0.32, 0.095, 2.64, 2.38)
const CONNECTOR := Rect2(0.515, 2.6, 2.25, 0.285)
const GRIP_CENTRES := [0.18, 3.1]
const SCREWS := [Vector2(0.18, 2.445), Vector2(3.1, 2.445)]
const CONTACTS := 14
## Within the label: the window the footage shows through, and the sticker
## band that carries the title and the mode chips.
const WINDOW := Rect2(0.1, 0.1, 2.3, 2.3 * 9.0 / 16.0)
const BAND := Rect2(0.1, 1.47, 2.3, 0.67)

const SHELL_TOP := Color("3a424b")
const SHELL_BOTTOM := Color("20252b")
const EDGE := Color("12161b")
const GRIP := Color("191e24")
const RIB := Color("2f363e")
const RECESS_COLOR := Color("0a0e13")
const METAL := Color("7d8a94")
const GOLD_TOP := Color("d9b574")
const GOLD_BOTTOM := Color("ad8951")
const SCREEN_COLOR := Color("04070a")
const STICKER := Color(0.02, 0.03, 0.04, 0.8)
const TITLE_INK := Color("f2f7f9")
const CHIP_INK := Color("0b1216")

const _BUTTON_STYLES: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed",
	&"normal_mirrored", &"hover_mirrored", &"pressed_mirrored",
	&"disabled_mirrored", &"hover_pressed_mirrored",
]

## Outline traced around the cartridge while it has focus.
var ring_color := Color.WHITE:
	set(value):
		ring_color = value
		queue_redraw()
## Width of that outline, in pixels.
var ring_width := 3.0:
	set(value):
		ring_width = maxf(value, 1.0)
		if is_node_ready():
			_ring = _ring_outline()
		queue_redraw()
## 0 standing in the rack, 1 lifted out of it; deepens the drop shadow.
var lift := 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if absf(value - lift) < 0.002 and value > 0.0 and value < 1.0:
			return
		lift = value
		queue_redraw()

var _game_id := ""
var _title := ""
var _tagline := ""
var _summary := ""
var _status := ""
var _slot := ""
var _badges := PackedStringArray()
var _accent := Color("afddea")
var _plaque_color := Color("141d23")
var _plaque_texture: Texture2D
var _plaque_region := Rect2()
var _logo: Texture2D
var _logo_color := Color.WHITE
var _clip: VideoStream
var _current := false
var _reduced_motion := false
var _closed := false
var _screen_alpha := 0.0
var _screen_tween: Tween
var _video_tween: Tween
var _unit := 1.0
var _title_font: FontVariation
var _chip_font: FontVariation
var _shadow := StyleBoxFlat.new()
var _badge_style: StyleBoxFlat
var _shell := PackedVector2Array()
var _shell_colors := PackedColorArray()
var _outline := PackedVector2Array()
var _connector := PackedVector2Array()
var _recess := PackedVector2Array()
var _grips: Array[PackedVector2Array] = []
var _ring := PackedVector2Array()

@onready var _label: Control = %Label
@onready var _screen: Control = %Screen
@onready var _poster: TextureRect = %Poster
@onready var _video: VideoStreamPlayer = %Video
@onready var _placeholder: Label = %Placeholder
@onready var _badge: Label = %Badge
@onready var _band: Control = %Band
@onready var _gloss: Control = %Gloss
@onready var _preview_delay: Timer = %PreviewDelay


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var empty := StyleBoxEmpty.new()
	for style in _BUTTON_STYLES:
		add_theme_stylebox_override(style, empty)
	# A plaque texture is tiled across the label the way the title screen's
	# box mesh repeats it.
	_label.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_label.draw.connect(_draw_label)
	_screen.draw.connect(_draw_screen)
	_band.draw.connect(_draw_band)
	_gloss.draw.connect(_draw_gloss)
	_preview_delay.timeout.connect(_start_clip)
	_badge_style = (_badge.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
	_badge.add_theme_stylebox_override("normal", _badge_style)
	_shadow.bg_color = Color(0, 0, 0, 0)
	var base := get_theme_default_font()
	_title_font = FontVariation.new()
	_title_font.base_font = base
	_title_font.variation_embolden = 0.55
	_chip_font = FontVariation.new()
	_chip_font.base_font = base
	_chip_font.variation_embolden = 0.4
	_set_screen_alpha(0.0)
	_layout()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT:
			queue_redraw()


## Reads everything the label shows from the game's manifest. Call it once the
## card is in the tree. [param status] is an extra line, such as newly unlocked
## modes; [param multiplayer_available] is false where the platform has no
## second seat, so the mode chips never promise one.
func configure(
	manifest: GameManifest, status := "", multiplayer_available := true
) -> void:
	_game_id = manifest.id
	_title = manifest.title
	_tagline = manifest.tagline
	_status = status
	var modes := describe_modes(manifest, multiplayer_available)
	_badges = modes["badges"]
	_summary = modes["summary"]
	var presentation := (
		manifest.theme if manifest.theme != null else GameTheme.studio_default()
	)
	_accent = presentation.accent
	ring_color = _accent
	_plaque_color = presentation.plaque_color
	_logo = presentation.logo_texture()
	if _logo == null:
		_logo = GameTheme.studio_default().logo_texture()
	_logo_color = presentation.logo_color
	_plaque_texture = null
	var material := presentation.plaque_material as BaseMaterial3D
	if material != null and material.albedo_texture != null:
		# The title screen's box mesh fits a third of its UV width and half its
		# height on the front face, then repeats the texture by uv1_scale.
		_plaque_texture = material.albedo_texture
		var repeat := material.uv1_scale
		var texture_size := _plaque_texture.get_size()
		_plaque_region = Rect2(
			Vector2.ZERO,
			Vector2(texture_size.x * repeat.x / 3.0, texture_size.y * repeat.y / 2.0)
		)
	_poster.texture = _load(manifest.tutorial_poster_path) as Texture2D
	_clip = _load(manifest.tutorial_video_path) as VideoStream
	_placeholder.visible = _clip == null and _poster.texture == null
	_update_accessibility()
	_sync_preview(true)
	_redraw_all()


## Where this cartridge stands in the rack, for screen readers.
func set_slot(index: int, count: int) -> void:
	_slot = "Cartridge %d of %d." % [index + 1, count]
	_update_accessibility()


## The current cartridge is the one lifted out of the rack. Only it opens its
## window, and only it may play its clip.
func set_current(current: bool, immediate := false) -> void:
	if current == _current and not immediate:
		return
	_current = current
	_fade_screen(1.0 if current else 0.0, immediate)
	_sync_preview(immediate)
	queue_redraw()


## With reduced motion the window holds the poster and the clip never starts.
func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if enabled:
		_fade_screen(1.0 if _current else 0.0, true)
	_sync_preview(true)


## The player has chosen. The clip freezes on its frame while the cartridge
## seats, every other cartridge stops, and nothing responds to input again.
func close() -> void:
	_closed = true
	disabled = true
	_sync_preview(true)
	queue_redraw()


func is_current() -> bool:
	return _current


func is_closed() -> bool:
	return _closed


## True while the clip is actually running. A paused clip still reports
## [method VideoStreamPlayer.is_playing], so that alone would not do.
func is_previewing() -> bool:
	return _video.is_playing() and not _video.paused


func has_preview_clip() -> bool:
	return _clip != null


func has_poster() -> bool:
	return _poster.texture != null


func preview_player() -> VideoStreamPlayer:
	return _video


func poster() -> Texture2D:
	return _poster.texture


func game_id() -> String:
	return _game_id


func game_title() -> String:
	return _title


func game_tagline() -> String:
	return _tagline


## The mode chips as one sentence, such as "1–2 players · Vs CPU".
func mode_summary() -> String:
	return _summary


func badges() -> PackedStringArray:
	return _badges


func status_line() -> String:
	return _status


func accent() -> Color:
	return _accent


## The control that takes focus for this game; the cartridge itself.
func focus_target() -> Control:
	return self


# --- Preview ------------------------------------------------------------------

func _wants_clip() -> bool:
	return _clip != null and _current and not _closed and not _reduced_motion


func _sync_preview(immediate := false) -> void:
	if not is_inside_tree():
		return
	var wanted := _wants_clip()
	if wanted:
		if _video.is_playing():
			_video.paused = false
		elif immediate:
			_preview_delay.stop()
			_start_clip()
		elif _preview_delay.is_stopped():
			_preview_delay.start(PREVIEW_DELAY)
	else:
		_preview_delay.stop()
		if _closed and _current and _video.is_playing():
			_video.paused = true
		else:
			_stop_clip()
	_badge.visible = _clip != null and _current and not _closed
	_badge.text = "PREVIEW" if wanted else "PREVIEW PAUSED"


func _start_clip() -> void:
	if not _wants_clip() or _video.is_playing():
		return
	# The stream is only attached while it plays, so a rack of nine games keeps
	# one decoder open rather than nine.
	_video.stream = _clip
	_video.paused = false
	_video.play()
	# Fading the clip in over the poster hides the frame the decoder needs to
	# produce its first picture.
	_video.modulate.a = 0.0
	_video.show()
	if _video_tween != null:
		_video_tween.kill()
	_video_tween = create_tween()
	_video_tween.tween_interval(0.05)
	_video_tween.tween_property(_video, "modulate:a", 1.0, 0.2)


func _stop_clip() -> void:
	if _video_tween != null:
		_video_tween.kill()
		_video_tween = null
	if _video.is_playing():
		_video.stop()
	_video.paused = false
	_video.hide()
	if _video.stream != null:
		_video.stream = null


func _fade_screen(target: float, immediate: bool) -> void:
	if _screen_tween != null:
		_screen_tween.kill()
		_screen_tween = null
	if immediate or _reduced_motion or not is_inside_tree() \
			or is_equal_approx(target, _screen_alpha):
		_set_screen_alpha(target)
		return
	_screen_tween = create_tween()
	_screen_tween.tween_method(
		_set_screen_alpha, _screen_alpha, target,
		SCREEN_FADE * absf(target - _screen_alpha)
	)


func _set_screen_alpha(value: float) -> void:
	_screen_alpha = value
	_screen.modulate.a = value
	_screen.visible = value > 0.001
	_gloss.queue_redraw()


func _update_accessibility() -> void:
	accessibility_name = _title
	var parts := PackedStringArray()
	for part in [_tagline, _summary, _status, _slot]:
		var sentence := String(part).strip_edges()
		if sentence.is_empty():
			continue
		if not (sentence.right(1) in [".", "!", "?"]):
			sentence += "."
		parts.append(sentence)
	accessibility_description = " ".join(parts)


static func _load(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)


# --- Layout -------------------------------------------------------------------

func _layout() -> void:
	if not is_node_ready() or size.x <= 0.0:
		return
	var u := size.x / MODEL_WIDTH
	_unit = u
	var label := _model_rect(LABEL)
	for part: Control in [_label, _gloss]:
		part.position = label.position
		part.size = label.size
	_screen.position = label.position + WINDOW.position * u
	_screen.size = WINDOW.size * u
	_band.position = label.position + BAND.position * u
	_band.size = BAND.size * u
	_title_font.spacing_glyph = roundi(0.012 * u)
	_chip_font.spacing_glyph = roundi(0.006 * u)
	_placeholder.add_theme_font_size_override("font_size", maxi(8, roundi(0.1 * u)))
	_badge.add_theme_font_size_override("font_size", maxi(8, roundi(0.07 * u)))
	_badge_style.content_margin_left = 0.05 * u
	_badge_style.content_margin_right = 0.05 * u
	_badge_style.content_margin_top = 0.012 * u
	_badge_style.content_margin_bottom = 0.012 * u
	_badge_style.set_corner_radius_all(roundi(0.025 * u))
	_badge.reset_size()
	_badge.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, roundi(0.05 * u)
	)
	_build_shapes()
	_redraw_all()


func _build_shapes() -> void:
	var u := _unit
	var shell := Rect2(0.0, 0.0, size.x, SHELL_RATIO * size.x)
	_shell = rounded_polygon(shell, Vector4(0.11, 0.11, 0.07, 0.07) * u)
	_shell_colors = vertical_gradient(_shell, 0.0, shell.size.y, SHELL_TOP, SHELL_BOTTOM)
	_outline = _shell.duplicate()
	if not _outline.is_empty():
		_outline.append(_outline[0])
	_connector = rounded_polygon(_model_rect(CONNECTOR), Vector4(0, 0, 0.06, 0.06) * u)
	_recess = rounded_polygon(_model_rect(RECESS), Vector4.ONE * 0.04 * u)
	_grips.clear()
	for centre: float in GRIP_CENTRES:
		_grips.append(rounded_polygon(
			_model_rect(Rect2(centre - 0.14, 0.07, 0.28, 2.51)), Vector4.ONE * 0.05 * u
		))
	_shadow.set_corner_radius_all(roundi(0.1 * u))
	_ring = _ring_outline()


## The silhouette of shell and connector together, pushed out by a small gap,
## so focus reads as a line around the whole cartridge.
func _ring_outline() -> PackedVector2Array:
	if _shell.size() < 3 or _connector.size() < 3:
		return PackedVector2Array()
	var outer := PackedVector2Array()
	for polygon: PackedVector2Array in Geometry2D.merge_polygons(_shell, _connector):
		if polygon.size() > outer.size():
			outer = polygon
	var gap := ring_width * 0.5 + maxf(2.0, 0.035 * _unit)
	var grown := PackedVector2Array()
	for polygon: PackedVector2Array in Geometry2D.offset_polygon(
		outer, gap, Geometry2D.JOIN_ROUND
	):
		if polygon.size() > grown.size():
			grown = polygon
	if not grown.is_empty():
		grown.append(grown[0])
	return grown


func _model_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position * _unit, rect.size * _unit)


func _redraw_all() -> void:
	queue_redraw()
	for part: Control in [_label, _screen, _band, _gloss]:
		part.queue_redraw()


# --- Drawing ------------------------------------------------------------------

## The shell. The label, its window, sticker and gloss are child controls,
## so they draw over all of this.
func _draw() -> void:
	if _shell.size() < 3:
		return
	var u := _unit
	_shadow.shadow_color = Color(0, 0, 0, 0.2 + 0.28 * lift)
	_shadow.shadow_size = maxi(1, roundi((0.05 + 0.12 * lift) * u))
	_shadow.shadow_offset = Vector2(0.0, (0.03 + 0.1 * lift) * u)
	draw_style_box(_shadow, Rect2(0.0, 0.0, size.x, SHELL_RATIO * size.x))

	draw_polygon(_connector, PackedColorArray([EDGE]))
	for index in CONTACTS:
		var contact := _model_rect(Rect2(0.6175 + index * 0.15, 2.65, 0.095, 0.21))
		_draw_gradient_rect(contact, GOLD_TOP, GOLD_BOTTOM)

	draw_polygon(_shell, _shell_colors)
	var hairline := maxf(1.0, 0.012 * u)
	draw_rect(Rect2(0.12 * u, 0.0, size.x - 0.24 * u, hairline), Color(1, 1, 1, 0.14))
	for grip in _grips:
		draw_polygon(grip, PackedColorArray([GRIP]))
	for centre: float in GRIP_CENTRES:
		for index in 8:
			var rib := _model_rect(Rect2(centre - 0.12, 0.359 + index * 0.24, 0.24, 0.032))
			draw_rect(rib, RIB)
			draw_rect(Rect2(rib.position.x, rib.end.y, rib.size.x, hairline), EDGE)
	draw_polygon(_recess, PackedColorArray([RECESS_COLOR]))
	for screw: Vector2 in SCREWS:
		var at := screw * u
		draw_circle(at, 0.045 * u, METAL, true, -1.0, true)
		var slot := Vector2(0.022, -0.022) * u
		draw_line(at - slot, at + slot, EDGE, hairline, true)
	# The embossed arrow that says which way the cartridge goes in.
	draw_colored_polygon(PackedVector2Array([
		Vector2(1.56, 2.47) * u, Vector2(1.72, 2.47) * u, Vector2(1.64, 2.575) * u,
	]), RIB)
	draw_polyline(_outline, EDGE, maxf(1.0, 0.014 * u), true)

	if has_focus() and not _closed and _ring.size() > 3:
		draw_polyline(_ring, ring_color, ring_width, true)


func _draw_label() -> void:
	var u := _unit
	var rect := Rect2(Vector2.ZERO, _label.size)
	if _plaque_texture != null:
		_label.draw_texture_rect_region(_plaque_texture, rect, _plaque_region, _plaque_color)
	else:
		_label.draw_rect(rect, _plaque_color)
	if _logo != null:
		var fitted := _fit(
			_logo.get_size(), Rect2(WINDOW.position * u, WINDOW.size * u).grow(-0.05 * u)
		)
		var shadow := Rect2(fitted.position + Vector2(0.015, 0.03) * u, fitted.size)
		_label.draw_texture_rect(_logo, shadow, false, Color(0, 0, 0, 0.35 * _logo_color.a))
		_label.draw_texture_rect(_logo, fitted, false, _logo_color)
	# The console's key light falls from above.
	_label.draw_polygon(
		PackedVector2Array([
			Vector2.ZERO, Vector2(rect.size.x, 0.0), rect.size, Vector2(0.0, rect.size.y),
		]),
		PackedColorArray([
			Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.07), Color(0, 0, 0, 0.22),
			Color(0, 0, 0, 0.22),
		])
	)


func _draw_screen() -> void:
	_screen.draw_rect(Rect2(Vector2.ZERO, _screen.size), SCREEN_COLOR)


## The sticker: an accent stripe, the title, and a chip per way to play.
func _draw_band() -> void:
	var u := _unit
	var rect := Rect2(Vector2.ZERO, _band.size)
	var radius := 0.04 * u
	_band.draw_polygon(rounded_polygon(rect, Vector4.ONE * radius), PackedColorArray([STICKER]))
	_band.draw_rect(Rect2(radius, 0.0, rect.size.x - radius * 2.0, 0.028 * u), _accent)

	var room := rect.size.x - 0.16 * u
	var title := _title.to_upper()
	var title_size := maxi(1, roundi(0.2 * u))
	var title_width := _title_font.get_string_size(
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size
	).x
	if title_width > room:
		title_size = maxi(1, floori(title_size * room / title_width))
	_band.draw_string(
		_title_font,
		Vector2(0.08 * u, _baseline(_title_font, title_size, 0.215 * u)),
		title, HORIZONTAL_ALIGNMENT_CENTER, room, title_size, TITLE_INK
	)

	if _badges.is_empty():
		return
	var chip_size := maxi(1, roundi(0.085 * u))
	var pad := Vector2(0.06, 0.02) * u
	var gap := 0.04 * u
	var widths := _chip_widths(chip_size, pad.x)
	var total := gap * (widths.size() - 1)
	for width in widths:
		total += width
	if total > room:
		chip_size = maxi(1, floori(chip_size * room / total))
		widths = _chip_widths(chip_size, pad.x)
		total = gap * (widths.size() - 1)
		for width in widths:
			total += width
	var height := _chip_font.get_height(chip_size) + pad.y * 2.0
	var x := (rect.size.x - total) * 0.5
	var y := 0.515 * u - height * 0.5
	var stroke := maxf(1.0, 0.01 * u)
	for index in _badges.size():
		var chip := Rect2(x, y, widths[index], height)
		var points := rounded_polygon(chip, Vector4.ONE * height * 0.5)
		var ink := CHIP_INK
		# The first chip is the player count: filled, because it is the one
		# fact every game has. The rest are outlined.
		if index == 0:
			_band.draw_polygon(points, PackedColorArray([_accent]))
		else:
			points.append(points[0])
			_band.draw_polyline(points, _accent, stroke, true)
			ink = _accent
		_band.draw_string(
			_chip_font, Vector2(chip.position.x + pad.x, _baseline(
				_chip_font, chip_size, chip.get_center().y
			)),
			_badges[index], HORIZONTAL_ALIGNMENT_LEFT, -1, chip_size, ink
		)
		x += widths[index] + gap


func _chip_widths(font_size: int, pad: float) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	for badge in _badges:
		widths.append(
			_chip_font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			+ pad * 2.0
		)
	return widths


## Varnish over the whole label: a sheen, a bezel round the window while it is
## open, and a dark edge where the label meets the recess.
func _draw_gloss() -> void:
	var u := _unit
	var area := _gloss.size
	_gloss.draw_polygon(
		PackedVector2Array([
			Vector2(-0.1 * area.x, 0.0), Vector2(0.62 * area.x, 0.0),
			Vector2(0.26 * area.x, area.y), Vector2(-0.1 * area.x, area.y),
		]),
		PackedColorArray([
			Color(1, 1, 1, 0.075), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0),
			Color(1, 1, 1, 0.02),
		])
	)
	if _screen_alpha > 0.001:
		var window := Rect2(WINDOW.position * u, WINDOW.size * u)
		var bezel := 0.022 * u
		_gloss.draw_rect(
			window.grow(bezel * 0.5), Color(0, 0, 0, 0.7 * _screen_alpha), false, bezel
		)
		_gloss.draw_rect(
			window.grow(-0.004 * u), Color(1, 1, 1, 0.1 * _screen_alpha), false,
			maxf(1.0, 0.006 * u)
		)
	_gloss.draw_rect(
		Rect2(Vector2.ZERO, area), Color(0, 0, 0, 0.5), false, maxf(1.0, 0.024 * u)
	)


func _draw_gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y),
		]),
		PackedColorArray([top, top, bottom, bottom])
	)


## The baseline that centres a line of [param font] on [param centre_y].
static func _baseline(font: Font, font_size: int, centre_y: float) -> float:
	return centre_y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5


# --- Shared helpers -------------------------------------------------------------

## What a game can be played as, from the manifest alone: the chips on its
## label and the sentence the picker reads out. [param multiplayer_available]
## is the platform's answer, so a phone never advertises a second seat.
static func describe_modes(
	manifest: GameManifest, multiplayer_available := true
) -> Dictionary:
	var badges := PackedStringArray()
	var words := PackedStringArray()
	var multi := multiplayer_available and manifest.supports_multiplayer
	var solo := not multi or manifest.supports_single_player
	var most := maxi(manifest.max_local_players, 2) if multi else 1
	if solo and most > 1:
		badges.append("1–%dP" % most)
		words.append("1–%d players" % most)
	elif most > 1:
		badges.append("%dP" % most)
		words.append("%d players" % most)
	else:
		badges.append("1P")
		words.append("1 player")
	# Direct-movement games keep their two-human setup, so they seat no CPU.
	if multi and manifest.supports_cpu_opponent \
			and manifest.control_style != GameManifest.CONTROL_STYLE_DIRECT_MOVEMENT:
		badges.append("VS CPU")
		words.append("Vs CPU")
	if multi and manifest.local_multiplayer_turns:
		badges.append("TURNS")
		words.append("Takes turns")
	return {"badges": badges, "summary": " · ".join(words)}


## A rectangle with its corners rounded by [param radii] (top-left, top-right,
## bottom-right, bottom-left), wound clockwise on screen. Duplicate points are
## dropped, because they make [method CanvasItem.draw_polygon] fail to
## triangulate.
static func rounded_polygon(
	rect: Rect2, radii: Vector4, detail := 6
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var limit := minf(rect.size.x, rect.size.y) * 0.5
	var corners := [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var inward := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for corner in 4:
		var radius := clampf(radii[corner], 0.0, limit)
		var centre: Vector2 = corners[corner] + inward[corner] * radius
		var start := PI + corner * PI * 0.5
		var steps := detail if radius > 0.5 else 0
		for step in steps + 1:
			var angle := start + PI * 0.5 * float(step) / maxi(steps, 1)
			var point := centre + Vector2(cos(angle), sin(angle)) * radius
			if points.is_empty() or points[-1].distance_squared_to(point) > 0.0001:
				points.append(point)
	if points.size() > 1 and points[0].distance_squared_to(points[-1]) <= 0.0001:
		points.remove_at(points.size() - 1)
	return points


## Per-vertex colours for a two-stop vertical gradient. Exact for
## [method CanvasItem.draw_polygon], which interpolates colour linearly.
static func vertical_gradient(
	points: PackedVector2Array, top: float, bottom: float,
	top_color: Color, bottom_color: Color
) -> PackedColorArray:
	var colors := PackedColorArray()
	colors.resize(points.size())
	var span := maxf(bottom - top, 0.0001)
	for index in points.size():
		colors[index] = top_color.lerp(
			bottom_color, clampf((points[index].y - top) / span, 0.0, 1.0)
		)
	return colors


static func _fit(content: Vector2, box: Rect2) -> Rect2:
	if content.x <= 0.0 or content.y <= 0.0:
		return box
	var fitted := content * minf(box.size.x / content.x, box.size.y / content.y)
	return Rect2(box.position + (box.size - fitted) * 0.5, fitted)
