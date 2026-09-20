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
const MIN_NATIVE_SCALE := 0.75
const HEADING_FONT_SIZE := 26
const HEADING_COLOR := Color(0.686275, 0.866667, 0.917647, 1.0)

@onready var _margins: MarginContainer = %Margins
@onready var _header: BoxContainer = %Header
@onready var _header_actions: HBoxContainer = %HeaderActions
@onready var _title: Label = %Title
@onready var _balance: Label = %Balance
@onready var _intro: Label = %Intro
@onready var _empty: Label = %Empty
@onready var _sections: VBoxContainer = %Sections
@onready var _back_button: Button = %BackButton

var _cards: Array[StoreItemCard] = []
var _grids: Array[GridContainer] = []
var _reduced_motion := false
var _cards_refresh_pending := false


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
	# A stretched 1920-wide canvas is still wide on a phone. Size the actual
	# fonts and controls before choosing columns; scaling a container blurs type.
	var units := maxf(1.0, size.x * MIN_NATIVE_SCALE / maxf(1, get_window().size.x))
	var layout_size := size / units
	var margin_x := roundi(
		clampf(layout_size.x * margin_ratio.x, margin_min.x, margin_max.x) * units
	)
	var margin_y := roundi(
		clampf(layout_size.y * margin_ratio.y, margin_min.y, margin_max.y) * units
	)
	Responsive.set_margins(_margins, margin_x, margin_y, margin_x, margin_y)
	var horizontal := float(
		_margins.get_theme_constant("margin_left")
		+ _margins.get_theme_constant("margin_right")
	)
	var minimum := StoreItemCard.MIN_WIDTH * units
	for card in _cards:
		card.set_ui_scale(units)
		minimum = maxf(minimum, card.get_combined_minimum_size().x)
	var usable := maxf(size.x - horizontal, minimum)
	var separation := CARD_SEPARATION * units
	var fits := int(
		(usable + separation) / (minimum + separation)
	)
	var columns := clampi(fits, 1, mini(MAX_COLUMNS, maxi(_cards.size(), 1)))
	var width := usable if columns == 1 else minf(
		usable, columns * maxf(MAX_CARD_WIDTH * units, minimum) + (columns - 1) * separation
	)
	for grid in _grids:
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", roundi(separation))
		grid.add_theme_constant_override("v_separation", roundi(separation))
		grid.custom_minimum_size.x = width
	_sections.custom_minimum_size.x = width
	_sections.add_theme_constant_override("separation", roundi(22 * units))
	for shelf in _sections.get_children():
		(shelf as VBoxContainer).add_theme_constant_override("separation", roundi(10 * units))
		var heading := shelf.get_node_or_null("Heading") as Label
		if heading != null:
			heading.add_theme_font_size_override("font_size", roundi(HEADING_FONT_SIZE * units))
	var layout := _header.get_parent() as VBoxContainer
	layout.add_theme_constant_override("separation", roundi(16 * units))
	_header.add_theme_constant_override("separation", roundi(24 * units))
	_header_actions.add_theme_constant_override("separation", roundi(24 * units))
	# The header stacks on a phone, where a title, a balance and Back will not
	# share a line without one of them losing its words.
	var compact := layout_size.x < 1000.0
	_header.vertical = compact
	_balance.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_RIGHT
	)
	_intro.add_theme_font_size_override("font_size", roundi((20 if compact else 24) * units))
	_empty.add_theme_font_size_override("font_size", roundi(24 * units))
	_balance.add_theme_font_size_override("font_size", roundi(30 * units))
	_back_button.add_theme_font_size_override("font_size", roundi(28 * units))
	_back_button.custom_minimum_size.y = 60 * units
	var title_size := clampf(minf(layout_size.x, layout_size.y) * 0.055, 32.0, 56.0)
	_title.add_theme_font_size_override("font_size", roundi(title_size * units))


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


## A purchase emits equip, balance and ownership changes together. Rebuild once
## so its deferred focus target is not removed by a second rebuild.
func _queue_card_refresh() -> void:
	if _cards_refresh_pending:
		return
	_cards_refresh_pending = true
	_refresh_cards.call_deferred()


## Rebuilds every card rather than only the one that changed: a purchase moves
## the balance, which can make every other card affordable or not.
func _refresh_cards() -> void:
	_cards_refresh_pending = false
	if not is_inside_tree() or is_queued_for_deletion():
		return
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
		card.set_preview_running(not _reduced_motion)
	refresh_layout()
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
	_queue_card_refresh()


func _on_store_changed(game_id: String, _item_id: String) -> void:
	if game_id == game_context_id:
		_queue_card_refresh()


func _on_equipped_changed(game_id: String, _slot_id: String, _item_id: String) -> void:
	if game_id == game_context_id:
		_queue_card_refresh()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key != Settings.REDUCED_MOTION_KEY:
		return
	_reduced_motion = bool(value)
	for card in _cards:
		card.set_preview_running(not _reduced_motion)


func _on_back_pressed() -> void:
	go_back()
