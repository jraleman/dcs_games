class_name GameTheme
extends Resource

## A game's own look: the logo on the main-menu plaque and the handful of
## colours the shared screens tint themselves with.
##
## Declared on [GameManifest], like every other thing a game owns, so putting a
## game's identity on screen never means editing a framework screen. A screen
## asks [method GameCatalog.theme] what to wear and gets this back — the game's
## when the build ships one game, the studio's otherwise.
##
## Deliberately small. These are the values that read at a glance across a
## whole screen; per-widget restyling belongs in `ui/theme/dcs_theme.tres`,
## which is shared by every build.

## Logo shown on the rotating plaque. A single-colour silhouette works best:
## it is tinted with [member logo_color], so it suits any theme. A texture with
## its own colours should leave that tint white.
@export_file("*.png", "*.svg", "*.webp") var logo_texture_path := ""

## Multiplied over the logo. White leaves a full-colour logo alone.
@export var logo_color := Color.WHITE

## Albedo of the slab the logo sits on.
@export var plaque_color := Color("141d23")

## The highlight: menu background glow, focus bar, and the fill light on the
## plaque. This is the colour a player would name if asked about the game.
@export var accent := Color("afddea")

## Key light on the plaque. Usually a paler relative of [member accent], since
## it is standing in for the lamp lighting the logo rather than the brand.
@export var light := Color("c9ebf4")

## Menu background gradient, top to bottom.
@export var background_top := Color("162128")
@export var background_bottom := Color("090e11")


## The studio's own look, and the exact values the shared scenes are authored
## with — so a collection build, or a game that declares no theme, looks
## precisely as it did before themes existed.
static func studio_default() -> GameTheme:
	var theme := GameTheme.new()
	theme.logo_texture_path = "res://assets/images/dcs_logo.png"
	theme.logo_color = Color.WHITE
	theme.plaque_color = Color("141d23")
	theme.accent = StudioInfo.SKY
	theme.light = Color("c9ebf4")
	theme.background_top = StudioInfo.DEEP
	theme.background_bottom = Color("090e11")
	return theme


## The logo, or null when the theme declares none or the file is missing.
## Callers keep whatever their scene was authored with in that case, so a bad
## path costs a warning rather than an empty plaque.
func logo_texture() -> Texture2D:
	var path := logo_texture_path.strip_edges()
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("GameTheme: logo '%s' does not exist." % path)
		return null
	return load(path) as Texture2D


## The shared UI theme, recoloured so wherever `dcs_theme.tres` reaches for a
## studio accent it reaches for this theme's instead — button focus rings,
## sliders, tab underlines, separators.
##
## Only those two colours are substituted, alpha intact, so the framework's
## spacing, fonts, corner radii and every neutral shade stay exactly as
## authored. A theme that keeps the studio accents gets [param base] back
## untouched, which is why a collection build pays nothing for this.
func restyle(base: Theme) -> Theme:
	if base == null:
		return null
	var studio := studio_default()
	if _same_rgb(accent, studio.accent) and _same_rgb(light, studio.light):
		return base

	var result := base.duplicate() as Theme
	for type_name in result.get_color_type_list():
		for color_name in result.get_color_list(type_name):
			result.set_color(
				color_name, type_name, _swap(result.get_color(color_name, type_name), studio)
			)
	for type_name in result.get_stylebox_type_list():
		for box_name in result.get_stylebox_list(type_name):
			var box := result.get_stylebox(box_name, type_name)
			if box != null:
				result.set_stylebox(box_name, type_name, _restyled_box(box, studio))
	return result


## Styleboxes are duplicated rather than edited: the originals belong to the
## project theme, which every other build in this process still uses.
func _restyled_box(box: StyleBox, studio: GameTheme) -> StyleBox:
	var flat := box.duplicate() as StyleBoxFlat
	if flat == null:
		return box
	flat.bg_color = _swap(flat.bg_color, studio)
	flat.border_color = _swap(flat.border_color, studio)
	flat.shadow_color = _swap(flat.shadow_color, studio)
	return flat


func _swap(color: Color, studio: GameTheme) -> Color:
	var result: Color
	if _same_rgb(color, studio.accent):
		result = accent
	elif _same_rgb(color, studio.light):
		result = light
	else:
		return color
	result.a = color.a
	return result


## Compared channel by channel at 8-bit precision, because these colours are
## written as rounded decimals in `.tres` files rather than as exact floats.
func _same_rgb(a: Color, b: Color) -> bool:
	const TOLERANCE := 0.004
	return (
		absf(a.r - b.r) < TOLERANCE
		and absf(a.g - b.g) < TOLERANCE
		and absf(a.b - b.b) < TOLERANCE
	)


## Repaints a scene that bakes a studio accent into per-node theme overrides,
## scene-local styleboxes or a [ColorRect] — the places a [Theme] cannot reach,
## and where the HUD and the credits roll keep most of their colour.
##
## Only the studio accents are substituted. Everything else is left alone,
## which is what keeps the player-one and player-two colours out of a game's
## hands: telling two players apart is an accessibility contract, not styling.
func restyle_tree(root: Node) -> void:
	if root == null:
		return
	var studio := studio_default()
	if _same_rgb(accent, studio.accent) and _same_rgb(light, studio.light):
		return
	_restyle_node(root, studio)


func _restyle_node(node: Node, studio: GameTheme) -> void:
	var rect := node as ColorRect
	if rect != null:
		rect.color = _swap(rect.color, studio)

	var control := node as Control
	if control != null:
		for property in control.get_property_list():
			var path := String(property.get("name", ""))
			var key := path.substr(path.rfind("/") + 1)
			if path.begins_with("theme_override_colors/"):
				if control.has_theme_color_override(key):
					control.add_theme_color_override(
						key, _swap(control.get_theme_color(key), studio)
					)
			elif path.begins_with("theme_override_styles/"):
				if control.has_theme_stylebox_override(key):
					control.add_theme_stylebox_override(
						key, _restyled_box(control.get_theme_stylebox(key), studio)
					)

	for child in node.get_children():
		_restyle_node(child, studio)
