extends MenuScreen

## Picks a game.
##
## The main menu offers a single Play button, and this is where it lands in any
## build with more than one game to offer. Every card is built from a
## [GameManifest], so a new game appears here by declaring itself and nothing
## else — no scene edit, and no list to keep in step with the catalog.
##
## A build with only one game available never reaches this screen: `main_menu.gd`
## starts that game directly, the same way it already skips mode select for a
## game that cannot be played by two people.

@export_file("*.tscn") var play_scene := "res://scenes/menus/mode_select.tscn"
@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"

## The card this screen clones per game. Exported rather than preloaded so the
## look of an entry can be replaced without touching this script.
@export var card_scene: PackedScene

## Widest a single card is allowed to grow. Past this the picture stops gaining
## anything and a row starts pushing the grid off a short screen, so an
## ultrawide gets a centred grid with air around it instead of huge cards.
const MAX_CARD_WIDTH := 460.0
const MAX_COLUMNS := 3
const CARD_SEPARATION := 24.0

## How many clips may run at once before the screen stops previewing everything.
## Each card decodes its own video, so a catalog that outgrows this previews only
## the card the player is on and leaves the rest on their poster frames. Today's
## three games sit under the cap, so the whole grid moves.
const MAX_LIVE_PREVIEWS := 4

@onready var _margins: MarginContainer = %Margins
@onready var _title: Label = %Title
@onready var _intro: Label = %Intro
@onready var _grid: GridContainer = %Grid
@onready var _empty: Label = %Empty

var _cards: Array[GameCard] = []
var _reduced_motion := false
var _launching := false


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	margins = _margins
	_title.text = "Choose a Game"
	_build_cards()
	Settings.changed.connect(_on_setting_changed)
	AchievementManager.progression_changed.connect(_on_progression_changed)
	super()


func _on_layout_changed(size: Vector2) -> void:
	# `MenuScreen.refresh_layout` sets these overrides immediately before this
	# hook runs, so they describe the margins the grid is actually inside.
	var horizontal := float(
		_margins.get_theme_constant("margin_left")
		+ _margins.get_theme_constant("margin_right")
	)
	var usable := maxf(size.x - horizontal, GameCard.MIN_WIDTH)

	var fits := int((usable + CARD_SEPARATION) / (GameCard.MIN_WIDTH + CARD_SEPARATION))
	var columns := clampi(fits, 1, mini(MAX_COLUMNS, maxi(_cards.size(), 1)))
	_grid.columns = columns
	_grid.custom_minimum_size.x = minf(
		usable, columns * MAX_CARD_WIDTH + (columns - 1) * CARD_SEPARATION
	)
	_intro.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER if columns > 1 else HORIZONTAL_ALIGNMENT_LEFT
	)


## Builds one card per available game, in catalog (menu) order.
##
## [method GameCatalog.available] is asked again on every rebuild rather than
## cached, because unlocking a game while this screen is open must add its card.
func _build_cards() -> void:
	for card in _cards:
		_grid.remove_child(card)
		card.queue_free()
	_cards.clear()

	var games := GameCatalog.available()
	_empty.visible = games.is_empty()
	_intro.visible = not games.is_empty()
	_intro.text = "Every preview below is a real round. Pick one to play."

	if card_scene == null:
		push_error("GameSelect: no card scene assigned.")
		return

	for manifest in games:
		var card := card_scene.instantiate() as GameCard
		if card == null:
			push_error("GameSelect: the card scene is not a GameCard.")
			return
		_grid.add_child(card)
		card.configure(manifest, _status_line(manifest))
		card.set_reduced_motion(_reduced_motion)
		card.set_always_preview(games.size() <= MAX_LIVE_PREVIEWS)
		card.chosen.connect(_on_game_chosen)
		_cards.append(card)

	first_focus = _cards[0].focus_target() if not _cards.is_empty() else null


## What the player may do with a game, in words. An unlock rule that gates modes
## rather than the whole game is the only thing worth saying here, so a game with
## no rule gets no line instead of a redundant "unlocked" badge on every card.
func _status_line(manifest: GameManifest) -> String:
	var modes := AchievementManager.game_unlocked_modes(manifest.id)
	if modes.is_empty():
		return ""
	return "Available: %s." % " + ".join(modes)


func _on_game_chosen(game_id: String) -> void:
	if _launching or not GameCatalog.select(game_id):
		return
	_launching = true
	for card in _cards:
		card.close()
	Router.start_selected_game(play_scene, instructions_scene)


func _on_progression_changed(_key: String, _value: bool) -> void:
	if _launching:
		return
	_build_cards()
	refresh_layout()
	_focus_first.call_deferred()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key != "accessibility/reduced_motion":
		return
	_reduced_motion = bool(value)
	for card in _cards:
		card.set_reduced_motion(_reduced_motion)


func _on_back_pressed() -> void:
	go_back()
