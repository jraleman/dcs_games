class_name PlayerAvatar
extends Control

## Stand-in for the per-player portrait art that has not been produced yet.
##
## The placeholder is drawn rather than shipped as an image so the card reserves
## the exact box a finished portrait will occupy, and so no throwaway art files
## have to be maintained. Assign [member portrait] once real art exists and this
## script renders it in the same box — no screen has to change to adopt it.
##
## Nothing here touches an autoload, so the component stays usable from headless
## test scripts that compile before autoloads are available.

## Side length the portrait box asks its container for. Portraits are square, so
## the same value serves both the drawn placeholder and a finished render.
const AVATAR_SIZE := 76.0

## Backing plate colour. Deliberately near-black so the tint reads as the
## player's colour rather than competing with the card behind it.
const PLATE_COLOR := Color(0.0392157, 0.0705882, 0.0941176, 1.0)

## Real portrait art. While this is null the procedural placeholder is drawn.
@export var portrait: Texture2D:
	set(value):
		portrait = value
		queue_redraw()

## Short player tag such as "P1", "P2" or "CPU". It is drawn onto the
## placeholder so a card never identifies its player by colour alone.
@export var tag := "P1":
	set(value):
		tag = value
		queue_redraw()

## Player colour, matching the P1/P2 colours the gameplay HUD already uses.
@export var tint := Color("4da3ff"):
	set(value):
		tint = value
		queue_redraw()


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Points the placeholder at one player. [param description] is what assistive
## technology reads out, since the drawing itself carries no text of its own.
func configure(
	new_tag: String,
	new_tint: Color,
	description: String,
	new_portrait: Texture2D = null
) -> void:
	tag = new_tag
	tint = new_tint
	portrait = new_portrait
	tooltip_text = description
	accessibility_description = description


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var unit := minf(box.size.x, box.size.y)
	if unit <= 0.0:
		return

	var plate := StyleBoxFlat.new()
	plate.bg_color = PLATE_COLOR
	plate.border_color = Color(tint.r, tint.g, tint.b, 0.85)
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(int(unit * 0.22))
	draw_style_box(plate, box)

	if portrait != null:
		draw_texture_rect(portrait, box.grow(-4.0), false)
		return
	_draw_placeholder(box, unit)


## A neutral bust silhouette plus the player tag. Generic on purpose: the
## framework must not imply what any particular game's characters look like.
func _draw_placeholder(box: Rect2, unit: float) -> void:
	var silhouette := Color(tint.r, tint.g, tint.b, 0.55)
	draw_circle(
		Vector2(box.position.x + box.size.x * 0.5, box.position.y + unit * 0.30),
		unit * 0.15,
		silhouette
	)

	var shoulders := StyleBoxFlat.new()
	shoulders.bg_color = silhouette
	shoulders.set_corner_radius_all(int(unit * 0.14))
	draw_style_box(shoulders, Rect2(
		box.position.x + box.size.x * 0.5 - unit * 0.26,
		box.position.y + unit * 0.46,
		unit * 0.52,
		unit * 0.22
	))

	var pill_rect := Rect2(
		box.position.x + box.size.x * 0.5 - unit * 0.28,
		box.position.y + unit * 0.70,
		unit * 0.56,
		unit * 0.20
	)
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(tint.r, tint.g, tint.b, 0.9)
	pill.set_corner_radius_all(int(pill_rect.size.y * 0.5))
	draw_style_box(pill, pill_rect)

	var font := get_theme_default_font()
	if font == null:
		return
	var font_size := maxi(int(unit * 0.16), 8)
	draw_string(
		font,
		Vector2(
			pill_rect.position.x,
			pill_rect.position.y + pill_rect.size.y * 0.5 + font_size * 0.36
		),
		tag,
		HORIZONTAL_ALIGNMENT_CENTER,
		pill_rect.size.x,
		font_size,
		PLATE_COLOR
	)
