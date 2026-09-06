class_name SessionShareCard
extends Control

## Fixed-aspect promotional result card rendered by ShareManager.

@onready var _game_title: Label = %GameTitle
@onready var _studio: Label = %Studio
@onready var _mode: Label = %Mode
@onready var _result: Label = %Result
@onready var _challenge: Label = %Challenge
@onready var _score_caption: Label = %ScoreCaption
@onready var _score: Label = %Score
@onready var _accuracy: Label = %Accuracy
@onready var _hits: Label = %Hits
@onready var _combo: Label = %Combo
@onready var _achievement_panel: PanelContainer = %AchievementPanel
@onready var _achievement_badge: Label = %AchievementBadge
@onready var _achievement_title: Label = %AchievementTitle
@onready var _achievement_copy: Label = %AchievementCopy
@onready var _info_panel: PanelContainer = %InfoPanel
@onready var _info_game: Label = %InfoGame
@onready var _qr_code: TextureRect = %QRCode
@onready var _info_copy: Label = %InfoCopy
@onready var _website: Label = %Website
@onready var _cta: Label = %Cta
@onready var _action_art: Control = %ActionArt
@onready var _stat_panels: Array[PanelContainer] = [
	%AccuracyPanel,
	%HitsPanel,
	%ComboPanel,
]

var _game_id := ""
## Which game's art scene is currently standing in the card's art frame. Empty
## means the built-in [ShareCardArt].
var _installed_art_path := ""
var _accent := StudioInfo.SKY
var _secondary := Color("4da3ff")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(data: Dictionary) -> void:
	var fallback := GameCatalog.current()
	_game_id = str(data.get("game_id", fallback.id if fallback else ""))
	_accent = data.get("accent_color", StudioInfo.SKY)
	_secondary = data.get("secondary_color", Color("4da3ff"))

	var manifest := GameCatalog.get_manifest(_game_id)
	var default_title := manifest.title if manifest else StudioInfo.TITLE
	var game_title := str(
		data.get("game_title", default_title)
	).strip_edges()
	var score := str(data.get("score", "0"))
	_game_title.text = game_title.to_upper()
	_studio.text = str(data.get("studio", StudioInfo.STUDIO)).to_upper()
	_mode.text = str(data.get("mode", "GAME SESSION")).to_upper()
	_result.text = str(data.get("result", "ROUND COMPLETE")).to_upper()
	_challenge.text = str(
		data.get("challenge", _challenge_text(data, score))
	).to_upper()
	_score_caption.text = str(data.get("score_caption", "FINAL SCORE")).to_upper()
	_score.text = score
	_accuracy.text = str(data.get("accuracy", "0%"))
	_hits.text = str(data.get("hits", "0"))
	_combo.text = str(data.get("combo", "x0"))

	_info_game.text = game_title.to_upper()
	_info_copy.text = str(
		data.get(
			"qr_copy",
			"Open this run's stats, then jump in and set your own score."
		)
	)
	_website.text = _website_label(str(data.get("website", StudioInfo.WEBSITE)))
	_cta.text = str(data.get("cta", "PLAY  •  SHARE  •  BEAT IT")).to_upper()

	var qr_texture: Variant = data.get("qr_texture")
	_qr_code.texture = qr_texture if qr_texture is Texture2D else null

	_configure_achievements(data)
	_apply_color_theme()
	_install_game_art(manifest)
	_action_art.call("configure", _with_art_style(data, manifest))

	_game_title.add_theme_font_size_override(
		"font_size",
		31 if game_title.length() <= 18 else 25
	)
	_result.add_theme_font_size_override(
		"font_size",
		48 if _result.text.length() <= 19 else 38
	)
	_score.add_theme_font_size_override(
		"font_size",
		82 if score.length() <= 8 else 66
	)
	queue_redraw()


## Swaps the artwork to whatever the game being rendered declares.
##
## [member GameManifest.share_art_scene_path] has been in the manifest since
## this card was written and nothing ever read it, so a game that wanted
## artwork of its own had no way in except a third hardcoded style inside
## [ShareCardArt] — which is the framework drawing a game's content, exactly
## what the manifest exists to prevent. The declared scene replaces
## `%ActionArt` in the same frame and is handed the same dictionary, so it is a
## drop-in for the built-in art rather than a second art pathway.
##
## The swap is reversible because a card can be reconfigured for another game,
## and a Desk-Can-Saw result must not be posted over another game's corridor.
##
## Anything that fails — a missing file, a scene that is not a `Control`, or
## one with no `configure()` — leaves the installed art alone. A card is worth
## rendering with generic art; it is not worth failing to render at all.
func _install_game_art(manifest: GameManifest) -> void:
	var wanted := manifest.share_art_scene_path if manifest != null else ""
	if wanted == _installed_art_path:
		return
	var replacement: Control = _game_art(wanted) if not wanted.is_empty() else ShareCardArt.new()
	if replacement == null:
		return
	replacement.name = _action_art.name
	replacement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replacement.size_flags_horizontal = _action_art.size_flags_horizontal
	replacement.size_flags_vertical = _action_art.size_flags_vertical

	var frame := _action_art.get_parent()
	var slot := _action_art.get_index()
	frame.remove_child(_action_art)
	_action_art.queue_free()
	frame.add_child(replacement)
	frame.move_child(replacement, slot)
	# `%ActionArt` has to keep resolving: the card's own scene, and the tests,
	# reach the artwork by unique name. A node added at runtime has no owner,
	# and without one the unique-name flag registers against nothing.
	replacement.owner = self
	replacement.unique_name_in_owner = true
	_action_art = replacement
	_installed_art_path = wanted


## Instantiates a game's declared art scene, or null if it cannot stand in for
## the built-in artwork.
func _game_art(path: String) -> Control:
	var scene: PackedScene = load(path) if ResourceLoader.exists(path) else null
	var art: Node = scene.instantiate() if scene != null else null
	if art is Control and art.has_method("configure"):
		return art
	if art != null:
		art.queue_free()
	push_warning(
		"Share art scene '%s' must be a Control with configure(); using built-in art."
		% path
	)
	return null


## The payload's `game_id` decides the artwork, so a caller reusing a payload
## for another game cannot leave a stale `share_art_style` behind.
func _with_art_style(data: Dictionary, manifest: GameManifest) -> Dictionary:
	if manifest == null:
		return data
	var art_data := data.duplicate()
	art_data["share_art_style"] = manifest.share_art_style
	return art_data


func _configure_achievements(data: Dictionary) -> void:
	var titles := _achievement_titles(data.get("achievements", []))
	var achievement_count := int(data.get("achievement_count", titles.size()))
	var achievements_are_new := bool(data.get("achievements_are_new", true))
	if titles.is_empty():
		_achievement_badge.text = "GO"
		_achievement_title.text = "YOUR NEXT RUN STARTS HERE"
		_achievement_copy.text = "Scan the card, study the score, and take another shot."
		return

	_achievement_badge.text = str(data.get("achievement_badge", "NEW"))
	_achievement_title.text = (
		"NEW ACHIEVEMENT"
		if achievements_are_new and titles.size() == 1
		else "NEW ACHIEVEMENTS"
		if achievements_are_new
		else "ACHIEVEMENT"
		if titles.size() == 1
		else "ACHIEVEMENTS"
	)
	_achievement_copy.text = "  •  ".join(titles)
	if achievement_count > titles.size():
		_achievement_title.text += "  (%d TOTAL)" % achievement_count


func _apply_color_theme() -> void:
	_mode.add_theme_color_override("font_color", _accent.lightened(0.26))
	_score_caption.add_theme_color_override(
		"font_color",
		_accent.lightened(0.22)
	)
	_score.add_theme_color_override("font_color", _accent.lightened(0.08))
	_challenge.add_theme_color_override(
		"font_color",
		_secondary.lightened(0.24)
	)
	_cta.add_theme_color_override("font_color", StudioInfo.INK)

	for panel in _stat_panels:
		_tint_panel(
			panel,
			_alpha(_accent, 0.28),
			_alpha(_accent.darkened(0.55), 0.34)
		)
	_tint_panel(
		_achievement_panel,
		_alpha(Color("ffd36a"), 0.52),
		Color(0.16, 0.12, 0.035, 0.88)
	)
	_tint_panel(
		_info_panel,
		_alpha(_accent, 0.72),
		Color(0.025, 0.075, 0.105, 0.96)
	)
	var cta_panel := %CtaPanel as PanelContainer
	_tint_panel(cta_panel, _accent.lightened(0.24), _accent)


func _tint_panel(
	panel: PanelContainer,
	border_color: Color,
	background_color: Color
) -> void:
	var source := panel.get_theme_stylebox("panel")
	if not source is StyleBoxFlat:
		return
	var style := source.duplicate() as StyleBoxFlat
	style.border_color = border_color
	style.bg_color = background_color
	panel.add_theme_stylebox_override("panel", style)


func _challenge_text(data: Dictionary, score: String) -> String:
	var score_values: Variant = data.get("score_values", [])
	if (
		(score_values is Array and score_values.size() > 1)
		or score.contains(" - ")
	):
		return "WHO TAKES THE NEXT ROUND?"
	return "CAN YOU BEAT %s?" % score


func _website_label(raw: String) -> String:
	return (
		raw.strip_edges()
		.trim_prefix("https://")
		.trim_prefix("http://")
		.trim_suffix("/")
	)


func _achievement_titles(raw: Variant) -> PackedStringArray:
	var titles := PackedStringArray()
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for item: Variant in raw:
			var title := str(item).strip_edges()
			if not title.is_empty():
				titles.append(title)
	return titles


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var top_color := Color("12202a")
	var bottom_color := Color("081015")
	var stripe_height := size.y / 12.0
	for stripe_index in range(12):
		var ratio := float(stripe_index) / 11.0
		draw_rect(
			Rect2(
				Vector2(0.0, stripe_height * float(stripe_index)),
				Vector2(size.x, stripe_height + 1.0)
			),
			top_color.lerp(bottom_color, ratio)
		)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(size.x * 0.42, 0.0),
			Vector2(size.x * 0.71, 0.0),
			Vector2(size.x * 0.49, size.y),
			Vector2(size.x * 0.2, size.y),
		]),
		_alpha(_accent, 0.055)
	)
	draw_circle(
		Vector2(size.x * 0.78, size.y * 0.06),
		size.y * 0.34,
		_alpha(_accent, 0.075)
	)
	draw_circle(
		Vector2(size.x * 0.08, size.y * 0.96),
		size.y * 0.28,
		_alpha(_secondary, 0.06)
	)

	for line_index in range(8):
		var start := Vector2(
			size.x * (0.36 + float(line_index) * 0.045),
			size.y * (0.04 + float(line_index % 3) * 0.075)
		)
		draw_line(
			start,
			start + Vector2(150.0, -35.0),
			_alpha(_accent if line_index % 2 == 0 else _secondary, 0.09),
			3.0,
			true
		)

	for dot_index in range(18):
		var position := Vector2(
			size.x * (0.035 + fmod(float(dot_index) * 0.137, 0.9)),
			size.y * (0.08 + fmod(float(dot_index) * 0.219, 0.84))
		)
		draw_circle(
			position,
			2.0 + float(dot_index % 3),
			_alpha(_accent if dot_index % 2 == 0 else _secondary, 0.18)
		)

	draw_line(
		Vector2(42.0, 24.0),
		Vector2(size.x - 42.0, 24.0),
		_alpha(_accent, 0.42),
		2.0,
		true
	)


func _alpha(color: Color, value: float) -> Color:
	var result := color
	result.a = value
	return result
