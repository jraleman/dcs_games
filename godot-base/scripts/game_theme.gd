class_name GameTheme
extends Resource

## A game's own presentation: branding, with optional menu skin and sounds.
##
## Declared on [GameManifest], like every other thing a game owns, so putting a
## game's identity on screen never means editing a framework screen. A screen
## asks [method GameCatalog.theme] what to wear and gets this back — the game's
## when the build ships one game, the studio's otherwise.
## Shared cards can opt into the result game's theme regardless of build mode.
##
## Unset presentation resources preserve the shared studio UI. Game-specific
## artwork, materials and sound generation stay in the game's own folder.

enum MenuMotion { SPRING, FIRM }

## Partial overrides, merged over the shared theme without changing its layout.
@export var ui_theme: Theme
@export var ui_sounds: GameUISoundBank

## Uses the shared backdrop's top_color, bottom_color, glow_color, aspect and
## speed uniforms. Setting speed to zero must freeze all decorative motion.
@export var background_material: ShaderMaterial
@export var plaque_material: Material
@export var menu_motion := MenuMotion.SPRING

## Opt into this game's branding on shared result cards, including in collections.
## Backdrop materials use the menu uniform contract, frozen at speed zero.
@export var style_share_card := false

## Logo shown on the menu cartridge. A single-colour silhouette works best:
## it is tinted with [member logo_color], so it suits any theme. A texture with
## its own colours should leave that tint white.
@export_file("*.png", "*.svg", "*.webp") var logo_texture_path := ""

## Multiplied over the logo. White leaves a full-colour logo alone.
@export var logo_color := Color.WHITE

## Albedo of the cartridge label. The plaque_* names remain stable for games.
@export var plaque_color := Color("141d23")

## The highlight: menu background glow, focus bar, and the fill light on the
## cartridge. This is the colour a player would name if asked about the game.
@export var accent := Color("afddea")

## Key light on the cartridge. Usually a paler relative of [member accent], since
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
## path costs a warning rather than an empty cartridge label.
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
## Accent substitution keeps alpha intact; an optional game-owned skin is
## merged last. Without either change the original theme is returned untouched.
func restyle(base: Theme) -> Theme:
	if base == null:
		return null
	var studio := studio_default()
	if (
		ui_theme == null
		and _same_rgb(accent, studio.accent)
		and _same_rgb(light, studio.light)
	):
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
	if ui_theme != null:
		result.merge_with(ui_theme.duplicate(true) as Theme)
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


## Explicit UI roles can override a baked colour without recolouring unrelated
## labels that happen to use the same colour, such as player identifiers.
func widget_color(key: StringName, role: StringName, fallback: Color) -> Color:
	if ui_theme != null and not role.is_empty() and ui_theme.has_color(key, role):
		return ui_theme.get_color(key, role)
	return fallback


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
## Only studio accents are substituted by default, preserving player and note
## colours. Menus can opt into widget skinning as well; gameplay does not.
func restyle_tree(root: Node, skin_widgets := false) -> void:
	if root == null:
		return
	var studio := studio_default()
	if (
		not (skin_widgets and ui_theme != null)
		and _same_rgb(accent, studio.accent)
		and _same_rgb(light, studio.light)
	):
		return
	_restyle_node(root, studio, skin_widgets)


func _restyle_node(node: Node, studio: GameTheme, skin_widgets: bool) -> void:
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
					var color := _swap(control.get_theme_color(key), studio)
					if skin_widgets:
						color = widget_color(key, control.theme_type_variation, color)
					control.add_theme_color_override(
						key, color
					)
			elif path.begins_with("theme_override_styles/"):
				if control.has_theme_stylebox_override(key):
					var box := control.get_theme_stylebox(key)
					control.add_theme_stylebox_override(
						key,
						_widget_box(control, key, box, studio)
						if skin_widgets else _restyled_box(box, studio)
					)

	for child in node.get_children():
		_restyle_node(child, studio, skin_widgets)


## Menu-local panels keep their authored padding. Gameplay only receives the
## accent pass, so semantic player/note panels are never replaced by a UI skin.
func _widget_box(
	control: Control, key: String, authored: StyleBox, studio: GameTheme
) -> StyleBox:
	if authored is StyleBoxEmpty:
		return authored
	var draw_center := true
	if authored is StyleBoxFlat:
		if is_zero_approx(authored.bg_color.a):
			return _restyled_box(authored, studio)
		draw_center = authored.draw_center
	elif authored is StyleBoxTexture:
		draw_center = authored.draw_center
	if ui_theme != null:
		var types := [control.theme_type_variation, StringName(control.get_class())]
		for type_name: StringName in types:
			if not type_name.is_empty() and ui_theme.has_stylebox(key, type_name):
				var box := ui_theme.get_stylebox(key, type_name).duplicate() as StyleBox
				# Border-only overlays must not become opaque over videos or artwork.
				if box is StyleBoxFlat or box is StyleBoxTexture:
					box.draw_center = draw_center
				for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
					box.set_content_margin(side, authored.get_content_margin(side))
				return box
	return _restyled_box(authored, studio)
