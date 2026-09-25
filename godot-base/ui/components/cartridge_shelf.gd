extends Control

## The console the game picker's cartridges stand in: a long, game-neutral
## cousin of the receiver on the title screen, with one slot for the whole
## collection and a row of LEDs on its face, one per game, each lit in that
## game's accent.
##
## It is drawn in two layers so a cartridge can stand *in* the slot without a
## clipping mask. [constant Layer.BACK] paints what is behind the cartridges:
## the spotlight, the deck behind the slot and the slot itself.
## [constant Layer.FRONT] paints what is in front of them: the deck lip, the
## face and its pager. The screen sandwiches its cartridges between the two.
##
## Every measure is a multiple of the full-size cartridge width, so the rack
## scales with the cartridges on any screen. Either end can be left open, so the
## rack runs on past the edge of the screen instead of stopping at its power
## switch and vents. The screen owns the state and calls
## [method CanvasItem.queue_redraw] after changing it. Nothing here reads a
## manager, so a headless test can load it.

enum Layer { BACK, FRONT }

## Rows, measured down from the far edge of the deck.
const SLOT_TOP := 0.02
const SLOT_BOTTOM := 0.045
const DECK_DEPTH := 0.07
const FACE := 0.15
const LOWER := 0.03
const FOOT := 0.016
const SHADOW := 0.045

## The slot stops short of both ends, where the power switch and vents live.
const SLOT_INSET := 0.15
## The deck's far edge is slightly narrower than its near one: just enough
## perspective for the strip to read as a surface rather than a stripe.
const TAPER := 0.014
const END_RADIUS := 0.035

# The title-screen console's materials, as they read under its key light.
const DECK_FAR := Color("2b333b")
const DECK_NEAR := Color("39434d")
const LIP_LIGHT := Color(0.62, 0.7, 0.77, 0.32)
const SLOT_WALL := Color("111820")
const SLOT_FLOOR := Color("04070a")
const FACE_TOP := Color("252b32")
const FACE_BOTTOM := Color("1a1f25")
const SEAM := Color("0b0f14")
const LOWER_TOP := Color("181c22")
const LOWER_BOTTOM := Color("101317")
const FOOT_COLOR := Color("090e14")
const PORT := Color("0a0e13")
const PORT_INSET := Color("56636d")
const VENT := Color("0c1015")
const SOCKET := Color("070a0e")
const SOCKET_EDGE := Color(1, 1, 1, 0.07)
const LED_OFF := Color("253b46")
const METAL := Color("75838d")
const SWITCH := Color("15191f")

@export var layer := Layer.BACK

## Width of a full-size cartridge, in pixels. Every other measure follows it.
var card_width := 300.0
## Y of the far edge of the deck, in this control's space.
var deck_y := 0.0
## Fractional index of the cartridge in the middle; the pager slides with it.
var scroll := 0.0
## One accent per game, in rack order.
var slot_accents := PackedColorArray()
## Accent of the cartridge being shown, blended while the player browses.
var accent := Color.WHITE
## How far the middle cartridge has been lifted out of the slot, 0 to 1.
var lift := 0.0
## Rises as a cartridge seats, like the power light on the title screen.
var power := 0.0
## Horizontal centre of the lifted cartridge.
var focus_x := 0.0
## An open end carries on past this control's edge rather than closing there.
var open_left := false
var open_right := false

var _glow: ImageTexture


## Everything the rack draws below the far edge of its deck, in card widths.
static func depth() -> float:
	return DECK_DEPTH + FACE + LOWER + FOOT + SHADOW


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow = _make_glow()


func _draw() -> void:
	if card_width <= 0.0 or size.x <= 0.0:
		return
	if layer == Layer.BACK:
		_draw_back()
	else:
		_draw_front()


func _draw_back() -> void:
	var w := card_width
	if lift > 0.001:
		# A pool of the game's own colour behind the cartridge in the player's
		# hands; the backdrop glow carries the same hue, much fainter. It stays
		# inside the stage, because the scroll box above it clips.
		var reach := Vector2(w * 0.98, minf(w * 0.54, deck_y - w * 0.4))
		var centre := Vector2(focus_x, deck_y - w * 0.4)
		draw_texture_rect(
			_glow, Rect2(centre - reach, reach * 2.0), false, Color(accent, 0.22 * lift)
		)

	var surface := _deck_polygon(deck_y, deck_y + SLOT_BOTTOM * w)
	draw_polygon(surface, _deck_colors(surface))

	var slot_left := -w if open_left else SLOT_INSET * w
	var slot_right := size.x + w if open_right else size.x - SLOT_INSET * w
	var slot := Rect2(
		slot_left, deck_y + SLOT_TOP * w,
		slot_right - slot_left, (SLOT_BOTTOM - SLOT_TOP) * w
	)
	if slot.size.x > slot.size.y:
		var groove := GameCard.rounded_polygon(slot, Vector4.ONE * slot.size.y * 0.5)
		draw_polygon(
			groove,
			GameCard.vertical_gradient(
				groove, slot.position.y, slot.end.y, SLOT_WALL, SLOT_FLOOR
			)
		)
	if power > 0.001:
		var light := Rect2(
			focus_x - w * 0.62, slot.position.y - w * 0.03,
			w * 1.24, slot.size.y + w * 0.06
		)
		draw_texture_rect(_glow, light, false, Color(accent, 0.6 * power))
	if lift > 0.001:
		var shadow := Rect2(focus_x - w * 0.58, deck_y - w * 0.006, w * 1.16, w * 0.062)
		draw_texture_rect(_glow, shadow, false, Color(0, 0, 0, 0.55 * lift))


func _draw_front() -> void:
	var w := card_width
	var lip := deck_y + DECK_DEPTH * w
	var face_bottom := lip + FACE * w
	var lower_bottom := face_bottom + LOWER * w
	var left := -w if open_left else 0.0
	var right := size.x + w if open_right else size.x

	draw_texture_rect(
		_glow,
		Rect2(left - w * 0.06, lower_bottom - w * 0.03, right - left + w * 0.12,
			(FOOT + SHADOW + 0.05) * w),
		false, Color(0, 0, 0, 0.62)
	)
	var foot := _span(lower_bottom - 1.0, FOOT * w + 1.0, w * 0.07)
	if foot.size.x > 0.0:
		draw_polygon(
			GameCard.rounded_polygon(foot, _bottom_corners(w * 0.008)),
			PackedColorArray([FOOT_COLOR])
		)
	var lower := _span(face_bottom - 1.0, LOWER * w + 1.0, w * 0.012)
	var lower_points := GameCard.rounded_polygon(lower, _bottom_corners(END_RADIUS * w))
	draw_polygon(
		lower_points,
		GameCard.vertical_gradient(
			lower_points, lower.position.y, lower.end.y, LOWER_TOP, LOWER_BOTTOM
		)
	)

	var face := _span(lip, FACE * w, 0.0)
	var face_points := GameCard.rounded_polygon(face, _bottom_corners(END_RADIUS * w * 0.6))
	draw_polygon(
		face_points,
		GameCard.vertical_gradient(face_points, face.position.y, face.end.y, FACE_TOP, FACE_BOTTOM)
	)
	var hairline := maxf(1.0, w * 0.004)
	draw_rect(_span(face_bottom - hairline, hairline, w * 0.012), SEAM)

	var strip := _deck_polygon(deck_y + SLOT_BOTTOM * w, lip)
	draw_polygon(strip, _deck_colors(strip))
	draw_rect(_span(lip - hairline, hairline, 0.0), LIP_LIGHT)

	if not open_left:
		_draw_switch()
	_draw_face_details(face.get_center().y)
	_draw_pager(Vector2(size.x * 0.5, face.get_center().y))


## A row of the rack from [param top], [param height] tall, stopping
## [param inset] short of each closed end and running on past each open one.
func _span(top: float, height: float, inset: float) -> Rect2:
	var left := -card_width if open_left else inset
	var right := size.x + card_width if open_right else size.x - inset
	return Rect2(left, top, right - left, height)


## Rounds only the corners at a closed end; an open end has none on screen.
func _bottom_corners(radius: float) -> Vector4:
	return Vector4(0.0, 0.0, 0.0 if open_right else radius, 0.0 if open_left else radius)


## The deck between two rows, narrowing slightly towards its far edge.
func _deck_polygon(top: float, bottom: float) -> PackedVector2Array:
	var w := card_width
	var far := DECK_DEPTH * w
	var top_inset := TAPER * w * (1.0 - clampf((top - deck_y) / far, 0.0, 1.0))
	var bottom_inset := TAPER * w * (1.0 - clampf((bottom - deck_y) / far, 0.0, 1.0))
	var left := -w if open_left else 0.0
	var right := size.x + w if open_right else size.x
	return PackedVector2Array([
		Vector2(left if open_left else top_inset, top),
		Vector2(right if open_right else right - top_inset, top),
		Vector2(right if open_right else right - bottom_inset, bottom),
		Vector2(left if open_left else bottom_inset, bottom),
	])


## Both layers shade the deck as one surface, so the seam between them vanishes.
func _deck_colors(points: PackedVector2Array) -> PackedColorArray:
	return GameCard.vertical_gradient(
		points, deck_y, deck_y + DECK_DEPTH * card_width, DECK_FAR, DECK_NEAR
	)


## The title-screen console's power button, left of the slot.
func _draw_switch() -> void:
	var w := card_width
	var centre := Vector2(w * 0.075, deck_y + DECK_DEPTH * w * 0.5)
	# Seen from above at an angle, a round button is an ellipse.
	draw_set_transform(centre, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, w * 0.03, METAL, true, -1.0, true)
	draw_circle(Vector2(0.0, -w * 0.006), w * 0.022, SWITCH, true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Vents and a port at each closed end of the face.
func _draw_face_details(middle: float) -> void:
	var w := card_width
	for side: float in [-1.0, 1.0]:
		if (open_left if side < 0.0 else open_right):
			continue
		var vent_size := Vector2(w * 0.075, maxf(1.0, w * 0.007))
		var vent_x := w * 0.045 if side < 0.0 else size.x - w * 0.045 - vent_size.x
		for index in 5:
			draw_rect(
				Rect2(Vector2(vent_x, middle - w * 0.036 + index * w * 0.018), vent_size),
				VENT
			)
		var port := Rect2(0.0, middle - w * 0.018, w * 0.12, w * 0.036)
		port.position.x = w * 0.16 if side < 0.0 else size.x - w * 0.16 - port.size.x
		draw_polygon(
			GameCard.rounded_polygon(port, Vector4.ONE * w * 0.006),
			PackedColorArray([PORT])
		)
		draw_rect(
			Rect2(port.position.x + w * 0.02, middle - w * 0.005,
				port.size.x - w * 0.04, w * 0.01),
			PORT_INSET
		)

## One LED per game. The one for the cartridge being shown stretches wide and
## lights in its accent, sliding along with the carousel; it is the only light
## on the rack that flares when a cartridge seats.
func _draw_pager(centre: Vector2) -> void:
	var count := slot_accents.size()
	if count == 0:
		return
	var w := card_width
	var dot := Vector2(w * 0.022, maxf(2.0, w * 0.011))
	var wide := w * 0.075
	var gap := w * 0.022
	var span := (count - 1) * (dot.x + gap) + wide
	var room := maxf(size.x - w * 0.8, w * 0.3)
	if span > room:
		var squeeze := room / span
		dot.x *= squeeze
		wide *= squeeze
		gap *= squeeze
		span = room
	var socket := Rect2(
		centre.x - span * 0.5 - w * 0.026, centre.y - w * 0.021, span + w * 0.052, w * 0.042
	)
	draw_polygon(
		GameCard.rounded_polygon(socket, Vector4.ONE * socket.size.y * 0.5),
		PackedColorArray([SOCKET])
	)
	draw_rect(
		Rect2(socket.position.x + socket.size.y * 0.5, socket.end.y,
			socket.size.x - socket.size.y, maxf(1.0, w * 0.003)),
		SOCKET_EDGE
	)

	# The widths always sum to the same span, so the row never shuffles.
	var shown := clampf(scroll, 0.0, float(count - 1))
	var x := centre.x - span * 0.5
	for index in count:
		var near := smoothstep(0.0, 1.0, clampf(1.0 - absf(float(index) - shown), 0.0, 1.0))
		var width := lerpf(dot.x, wide, near)
		var tint := slot_accents[index]
		var led := Rect2(x, centre.y - dot.y * 0.5, width, dot.y)
		if near > 0.001:
			draw_texture_rect(
				_glow, led.grow_individual(w * 0.035, w * 0.03, w * 0.035, w * 0.03),
				false, Color(tint, (0.2 + 0.65 * power) * near)
			)
		var rest := LED_OFF.lerp(tint, 0.24)
		var lit := LED_OFF.lerp(tint, 0.66 + 0.34 * power).lerp(Color.WHITE, 0.3 * power)
		draw_polygon(
			GameCard.rounded_polygon(led, Vector4.ONE * dot.y * 0.5),
			PackedColorArray([rest.lerp(lit, near)])
		)
		x += width + gap


## A soft round falloff, generated rather than imported so the rack carries no
## asset of its own and draws on the very first frame.
func _make_glow() -> ImageTexture:
	var side := 64
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	var half := side * 0.5
	for y in side:
		for x in side:
			var distance := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var alpha := clampf(1.0 - distance, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha * (3.0 - 2.0 * alpha)))
	return ImageTexture.create_from_image(image)
