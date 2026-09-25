class_name SetupStage
extends Control

## The lit plinth the setup screen stands a character preview on.
##
## A preview scene belongs to its game and only promises to be a [Control] that
## draws its subject inside its own rect. The stage supplies the floor, the
## turntable and the coloured ring around it, and places whichever preview is on
## show so its subject stands on the top face at any size the screen allows.
## Everything is drawn rather than shipped as art so the ring can wear any
## game's accent, or a seat's colour, without a texture per combination.
##
## Nothing here touches an autoload, so headless tests can import the script.

## Where the plinth settles in spare height: 0 hugs the top edge, 1 the bottom.
## Slightly low, so a tall subject never crowds the heading beside it.
const VERTICAL_BIAS := 0.7
## Plinth proportions, as fractions of its horizontal radius.
const DEPTH_RATIO := 0.19
const THICKNESS_RATIO := 0.14
## The preview rect, in plinth radii and in the landscape aspect a
## three-quarter vehicle or character portrait fills. It is as wide as the
## plinth, so a subject framed with a modest margin stands about two-thirds as
## wide as the turntable, and it never outgrows the stage, so a tightly framed
## subject cannot spill out.
const PREVIEW_WIDTH_RATIO := 2.0
const PREVIEW_ASPECT := 1.7
## How far the preview's bottom edge hangs below the plinth centre, in radii,
## so a subject framed with a little floor margin stands just in front of the
## middle of the top face.
const PREVIEW_DROP := 0.2
## How far the plinth and the brightest of its floor shadow reach below the
## plinth centre, in radii.
const BASE_REACH := 0.45
const SEGMENTS := 96

var _previews: Array[Control] = []
var _featured: Control
var _ring_color := Color("afddea")
var _surface_color := Color("162128")
var _caption: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = Label.new()
	_caption.name = "Caption"
	_caption.theme_type_variation = &"SetupChipLabel"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.visible = false
	add_child(_caption)
	resized.connect(_arrange)
	_caption.minimum_size_changed.connect(_arrange)


## Adds a game's preview. Only the one [method show_preview] picks is visible;
## the rest stay in the tree so they can keep their subjects up to date.
func add_preview(preview: Control) -> void:
	# The stage places each preview itself, so anchors must not stretch it too.
	preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	preview.visible = false
	add_child(preview)
	move_child(_caption, -1)
	_previews.append(preview)
	if _featured == null:
		show_preview(preview)
	else:
		_arrange()


func has_previews() -> bool:
	return not _previews.is_empty()


func show_preview(preview: Control) -> void:
	_featured = preview
	for candidate in _previews:
		candidate.visible = candidate == preview
	_arrange()


func featured_preview() -> Control:
	return _featured


func set_ring_color(color: Color) -> void:
	if color.is_equal_approx(_ring_color):
		return
	_ring_color = color
	queue_redraw()


func set_surface_color(color: Color) -> void:
	if color.is_equal_approx(_surface_color):
		return
	_surface_color = color
	queue_redraw()


## Names what is on show. Multiplayer passes the seat, so the ring colour is
## never the only thing saying whose choice this is.
func set_caption(text: String) -> void:
	if _caption == null:
		return
	_caption.text = text
	_caption.visible = not text.is_empty()
	_caption.accessibility_name = text
	_arrange()


## Plinth centre and horizontal radius for the current size, as (x, y, radius).
## The radius is solved from the whole group, preview rect above the centre
## and plinth below it, so the group always fits the stage.
func _geometry() -> Vector3:
	var caption_height := 0.0
	if _caption != null and _caption.visible:
		caption_height = _caption.get_combined_minimum_size().y
	var room := Vector2(size.x, maxf(size.y - caption_height, 0.0))
	var above := PREVIEW_WIDTH_RATIO / PREVIEW_ASPECT - PREVIEW_DROP
	var group := above + BASE_REACH
	var radius := maxf(minf(room.x * 0.47, room.y / group), 0.0)
	var top := maxf(room.y - radius * group, 0.0) * VERTICAL_BIAS
	return Vector3(room.x * 0.5, top + radius * above, radius)


func _arrange() -> void:
	if _caption == null:
		return
	var plinth := _geometry()
	var width := minf(plinth.z * PREVIEW_WIDTH_RATIO, size.x)
	var height := width / PREVIEW_ASPECT
	var bottom := plinth.y + plinth.z * PREVIEW_DROP
	for preview in _previews:
		preview.position = Vector2(plinth.x - width * 0.5, bottom - height)
		preview.size = Vector2(width, height)
	if _caption.visible:
		var caption_size := _caption.get_combined_minimum_size()
		_caption.position = Vector2(0.0, size.y - caption_size.y)
		_caption.size = Vector2(size.x, caption_size.y)
	queue_redraw()


func _draw() -> void:
	var plinth := _geometry()
	var radius := plinth.z
	if radius < 8.0:
		return
	var center := Vector2(plinth.x, plinth.y)
	var depth := radius * DEPTH_RATIO
	var thickness := radius * THICKNESS_RATIO
	var line := maxf(radius * 0.0075, 1.5)

	var floor_center := center + Vector2(0.0, thickness + depth * 0.4)
	for step in 6:
		var spread := lerpf(1.2, 1.0, step / 5.0)
		draw_colored_polygon(
			_ellipse(floor_center, radius * spread, depth * 1.4 * spread),
			Color(0.0, 0.0, 0.0, 0.08)
		)

	# The visible front of the cylinder wall, lit in the middle and falling
	# away to the sides so the disc reads as solid rather than as a flat sticker.
	var front := _arc(center, radius, depth, 0.0, PI)
	var band := PackedVector2Array()
	var shades := PackedColorArray()
	var side_light := _surface_color.lightened(0.08)
	var side_dark := _surface_color.darkened(0.5)
	for point in front:
		var edge := absf(point.x - center.x) / radius
		band.append(point)
		shades.append(side_light.lerp(side_dark, edge * edge))
	for index in range(front.size() - 1, -1, -1):
		band.append(front[index] + Vector2(0.0, thickness))
		shades.append(_surface_color.darkened(0.62))
	draw_polygon(band, shades)

	var top_edge := _surface_color.lightened(0.1)
	var top_middle := _surface_color.lightened(0.26)
	draw_colored_polygon(_ellipse(center, radius, depth), top_edge)
	for step in range(1, 6):
		var shrink := 1.0 - step / 6.0 * 0.6
		draw_colored_polygon(
			_ellipse(center + Vector2(0.0, depth * 0.1 * step / 6.0), radius * shrink, depth * shrink),
			Color(top_middle, 0.2)
		)
	draw_polyline(front, Color(1.0, 1.0, 1.0, 0.16), line, true)

	# The ring: faint across the back, bright and glowing across the front.
	var ring_x := radius * 0.955
	var ring_y := depth * 0.955
	draw_polyline(_arc(center, ring_x, ring_y, PI, TAU), Color(_ring_color, 0.35), line, true)
	var ring_front := _arc(center, ring_x, ring_y, 0.0, PI)
	draw_polyline(ring_front, Color(_ring_color, 0.1), line * 8.0, true)
	draw_polyline(ring_front, Color(_ring_color, 0.22), line * 3.6, true)
	draw_polyline(ring_front, _ring_color.lightened(0.2), line * 1.3, true)


## A closed ellipse without a repeated end point, which polygon triangulation
## rejects.
func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in SEGMENTS:
		var angle := TAU * index / SEGMENTS
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


## An open arc including both end points. Angles grow clockwise on screen, so
## 0 to PI is the half nearest the viewer.
func _arc(center: Vector2, rx: float, ry: float, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(int(SEGMENTS * absf(to - from) / TAU), 8)
	for index in count + 1:
		var angle := lerpf(from, to, float(index) / count)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points
