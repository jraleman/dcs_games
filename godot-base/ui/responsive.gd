class_name Responsive
extends RefCounted

## Small helpers for layouts that have to survive phones, 16:9 monitors and
## ultrawides. The project stretches a 1920x1080 base with aspect "expand", so
## the viewport is never smaller than the base on one axis but can be much
## longer on the other — these helpers work off the live viewport size instead
## of hardcoded pixels.

## Aspect ratio above which a screen is treated as ultrawide.
const WIDE_ASPECT := 2.0


static func is_portrait(viewport: Vector2) -> bool:
	return viewport.y > viewport.x


static func is_ultrawide(viewport: Vector2) -> bool:
	return viewport.y > 0.0 and viewport.x / viewport.y >= WIDE_ASPECT


## Sets a MarginContainer's four margins to a share of the viewport, clamped.
static func apply_margins(
	container: MarginContainer,
	viewport: Vector2,
	ratio := Vector2(0.07, 0.05),
	min_margin := Vector2(28, 20),
	max_margin := Vector2(240, 120)
) -> void:
	if container == null:
		return
	var mx := int(clampf(viewport.x * ratio.x, min_margin.x, max_margin.x))
	var my := int(clampf(viewport.y * ratio.y, min_margin.y, max_margin.y))
	set_margins(container, mx, my, mx, my)


## Pads all four sides by a share of the *shorter* axis, so square-ish content
## (a logo, a dialog) keeps the same presence in portrait and landscape.
static func apply_uniform_margins(
	container: MarginContainer,
	viewport: Vector2,
	ratio := 0.14,
	min_margin := 32.0,
	max_margin := 320.0
) -> void:
	if container == null:
		return
	var pad := int(clampf(minf(viewport.x, viewport.y) * ratio, min_margin, max_margin))
	set_margins(container, pad, pad, pad, pad)


static func set_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)


## Caps how wide a column of content is allowed to get on large screens.
static func content_width(viewport: Vector2, preferred := 0.42, minimum := 420.0, maximum := 760.0) -> float:
	return clampf(viewport.x * preferred, minimum, maximum)
