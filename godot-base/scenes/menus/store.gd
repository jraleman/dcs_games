extends MenuScreen

## Spends the points a game's rounds pay out on that game's cosmetics.
##
## Everything on these shelves comes from a [GameManifest] by way of [Store], so
## a new game — or a new hat — appears here without this screen changing. The
## screen owns the money question and the card owns the picture: a card asks to
## buy or wear, and this is where the price is checked.
##
## Which game it is selling for follows the same rule as the Settings screen's
## Controls and Game tabs. A standalone build adopts the only game it ships; a
## collection is told by the pause menu which game is running, because a
## collection's main menu has not chosen a game yet.

## Game whose store this screen sells. Empty resolves in [method
## _resolve_game_context]; assign it before `add_child()`, since `_ready()` is
## what builds the shelves.
var game_context_id := ""

## Widest a card is allowed to grow before the grid stops adding size and starts
## adding air, so an ultrawide gets a centred grid rather than billboard cards.
const MAX_CARD_WIDTH := 320.0
const MAX_COLUMNS := 4
const CARD_SEPARATION := 20.0
const HEADING_FONT_SIZE := 26
const HEADING_COLOR := Color(0.686275, 0.866667, 0.917647, 1.0)

@onready var _margins: MarginContainer = %Margins
@onready var _title: Label = %Title
@onready var _balance: Label = %Balance
@onready var _intro: Label = %Intro
@onready var _empty: Label = %Empty
@onready var _sections: VBoxContainer = %Sections
@onready var _back_button: Button = %BackButton

var _cards: Array[StoreItemCard] = []
var _grids: Array[GridContainer] = []
var _reduced_motion := false


func _ready() -> void:
	margins = _margins
	first_focus = _back_button
	_reduced_motion = Settings.reduced_motion_enabled()
	_resolve_game_context()
	_build_shelves()
	_refresh_balance()
	Settings.changed.connect(_on_setting_changed)
	Store.points_changed.connect(_on_points_changed)
	Store.purchased.connect(_on_store_changed)
	Store.equipped_changed.connect(_on_equipped_changed)
	super()


## Adopts the only game in a standalone build, so its store is reachable from
## the main menu rather than only from a paused round — the same rule, and the
## same reasoning, as `settings_menu.gd`.
func _resolve_game_context() -> void:
	if not game_context_id.is_empty():
		return
	if GameCatalog.is_single_game_build():
		game_context_id = GameCatalog.current_id()


func _on_layout_changed(size: Vector2) -> void:
	# `MenuScreen.refresh_layout` applies the margin overrides immediately
	# before this hook, so they describe the box the grid is actually inside.
	var horizontal := float(
		_margins.get_theme_constant("margin_left")
		+ _margins.get_theme_constant("margin_right")
	)
	var usable := maxf(size.x - horizontal, StoreItemCard.MIN_WIDTH)
	var fits := int(
		(usable + CARD_SEPARATION) / (StoreItemCard.MIN_WIDTH + CARD_SEPARATION)
	)
	var columns := clampi(fits, 1, mini(MAX_COLUMNS, maxi(_cards.size(), 1)))
	var width := minf(usable, columns * MAX_CARD_WIDTH + (columns - 1) * CARD_SEPARATION)
	for grid in _grids:
		grid.columns = columns
		grid.custom_minimum_size.x = width
	_sections.custom_minimum_size.x = width
	# The header stacks on a phone, where a title, a balance and Back will not
	# share a line without one of them losing its words.
	var portrait := Responsive.is_portrait(size)
	_balance.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if portrait else HORIZONTAL_ALIGNMENT_RIGHT
	)
	_title.add_theme_font_size_override(
		"font_size", int(clampf(minf(size.x, size.y) * 0.055, 32.0, 56.0))
	)


## Builds one grid per heading, in declaration order, so a game groups its
## shelves by writing a `heading` on its items and nothing else.
func _build_shelves() -> void:
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	_cards.clear()
	_grids.clear()

	var manifest := GameCatalog.get_manifest(game_context_id)
	_title.text = "%s Store" % manifest.title if manifest else "Store"
	var items := Store.items(game_context_id)
	_empty.visible = items.is_empty()
	_intro.visible = not items.is_empty()
	if items.is_empty():
		first_focus = _back_button
		return
	_intro.text = _intro_copy(manifest)

	var grid: GridContainer = null
	var heading := ""
	for item in items:
		var next_heading := str(item.get("heading", ""))
		if grid == null or next_heading != heading:
			heading = next_heading
			grid = _add_shelf(heading)
		var card := StoreItemCard.new()
		card.name = "Card_%s" % str(item.get("id", _cards.size()))
		grid.add_child(card)
		card.configure(
			item,
			Store.slots_for_item(game_context_id, str(item.get("id", ""))),
			Store.format_points(game_context_id, int(item.get("price", 0)))
		)
		card.set_preview_running(not _reduced_motion)
		card.buy_requested.connect(_on_buy_requested)
		card.equip_requested.connect(_on_equip_requested)
		card.unequip_requested.connect(_on_unequip_requested)
		_cards.append(card)

	first_focus = _first_focusable_control()
	refresh_layout()


## The first thing on the shelves a player can actually press, falling back to
## Back so a store full of items nobody can afford yet still opens on something.
func _first_focusable_control() -> Control:
	for card in _cards:
		var target := card.focus_target()
		if target != null:
			return target
	return _back_button


func _add_shelf(heading: String) -> GridContainer:
	var shelf := VBoxContainer.new()
	shelf.name = "Shelf%d" % (_grids.size() + 1)
	shelf.add_theme_constant_override("separation", 10)
	_sections.add_child(shelf)

	if not heading.is_empty():
		var label := Label.new()
		label.name = "Heading"
		label.text = heading
		label.add_theme_font_size_override("font_size", HEADING_FONT_SIZE)
		label.add_theme_color_override("font_color", HEADING_COLOR)
		shelf.add_child(label)

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", int(CARD_SEPARATION))
	grid.add_theme_constant_override("v_separation", int(CARD_SEPARATION))
	shelf.add_child(grid)
	_grids.append(grid)
	return grid


## Names the money and where it comes from, so a first visit explains itself
## without the framework knowing what a "Feather" is.
func _intro_copy(manifest: GameManifest) -> String:
	var plural := Store.currency_name(game_context_id)
	var fallback := (
		"Finish a round to earn %s, then spend them on how your game looks."
		% plural.to_lower()
	)
	return manifest.text("store_intro", fallback) if manifest else fallback


func _refresh_balance() -> void:
	var balance := Store.points(game_context_id)
	_balance.text = Store.format_points(game_context_id, balance)
	_balance.tooltip_text = "You have %s to spend." % _balance.text
	_balance.accessibility_description = _balance.tooltip_text


## Rebuilds every card rather than only the one that changed: a purchase moves
## the balance, which can make every other card affordable or not.
func _refresh_cards() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focused_card := _card_owning(focused)
	for card in _cards:
		var item_id := card.item_id()
		var item := Store.describe(game_context_id, item_id)
		if item.is_empty():
			continue
		card.configure(
			item,
			Store.slots_for_item(game_context_id, item_id),
			Store.format_points(game_context_id, int(item.get("price", 0)))
		)
	_attach_card_sounds.call_deferred()
	# The buttons that had focus were freed by the rebuild, so focus is handed
	# back to the same card rather than lost to the top of the screen.
	if focused_card != null:
		var target := focused_card.focus_target()
		if target != null:
			target.grab_focus.call_deferred()
			return
	if focused != null and is_instance_valid(focused) and focused.is_inside_tree():
		return
	var fallback := _first_focusable_control()
	if fallback != null:
		fallback.grab_focus.call_deferred()


## Rebuilt cards carry rebuilt buttons, which the screen's one-time sound pass
## never saw. Re-attaching is a no-op for the buttons that already have cues.
func _attach_card_sounds() -> void:
	AudioManager.attach_ui_sounds(self)


func _card_owning(control: Control) -> StoreItemCard:
	var node := control
	while node != null:
		var card := node as StoreItemCard
		if card != null:
			return card
		node = node.get_parent() as Control
	return null


func _on_buy_requested(item_id: String) -> void:
	if not Store.purchase(game_context_id, item_id):
		AudioManager.play_game_miss()
		return
	var item := Store.describe(game_context_id, item_id)
	AudioManager.play_achievement()
	AudioManager.request_caption("%s bought" % str(item.get("title", item_id)))


func _on_equip_requested(item_id: String, slot_id: String) -> void:
	if Store.equip(game_context_id, item_id, slot_id):
		AudioManager.play_click()


func _on_unequip_requested(slot_id: String) -> void:
	if Store.unequip(game_context_id, slot_id):
		AudioManager.play_back()


func _on_points_changed(game_id: String, _points: int) -> void:
	if game_id != game_context_id:
		return
	_refresh_balance()
	_refresh_cards()


func _on_store_changed(game_id: String, _item_id: String) -> void:
	if game_id == game_context_id:
		_refresh_cards()


func _on_equipped_changed(game_id: String, _slot_id: String, _item_id: String) -> void:
	if game_id == game_context_id:
		_refresh_cards()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key != Settings.REDUCED_MOTION_KEY:
		return
	_reduced_motion = bool(value)
	for card in _cards:
		card.set_preview_running(not _reduced_motion)


func _on_back_pressed() -> void:
	go_back()
