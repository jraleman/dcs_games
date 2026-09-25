extends MenuScreen

## Picks a game.
##
## The title screen's single Play button lands here in any build with more than
## one game to offer. Every game stands in a long console rack as the cartridge
## the title screen seats: dressed in its own colours and logo, with a label
## window that shows its footage while it is the cartridge in the player's
## hands. Browsing slides the rack along; Play seats the cartridge in the slot
## before the usual setup route, just as the title screen seats its own.
##
## Every cartridge is built from a [GameManifest], so a new game appears here by
## declaring itself and nothing else — no scene edit, and no list to keep in
## step with the catalog.
##
## A build with only one game available never reaches this screen: the title
## screen starts that game directly, the same way it already skips mode select
## for a game that cannot be played by two people.

const Shelf := preload("res://ui/components/cartridge_shelf.gd")
const REDUCED_MOTION_KEY := "accessibility/reduced_motion"

## The cartridges beside the one in hand stand smaller, further along the rack.
const SIDE_SCALE := 0.72
## Room above the lifted cartridge for its bob and focus ring, per card width.
const HEADROOM := 0.05
## How far the lifted cartridge's connector clears the deck, per card width.
const HOVER_GAP := 0.03
## Air between the lifted cartridge and its neighbours, per card width.
const NEIGHBOUR_GAP := 0.08
## Centre-to-centre spacing of the cartridges beyond them, per side width.
const SIDE_PITCH := 1.08
## A standing cartridge sits just below the near edge of the slot.
const REST_SINK := 0.012
## How far a chosen cartridge travels into the slot, per card width.
const SEAT_DEPTH := 0.42
## The lifted cartridge rises and falls this far, per card width.
const BOB := 0.012
const BOB_SPEED := 1.6
## Standing cartridges are dimmed so the one in hand leads; hover lifts one.
const SIDE_BRIGHTNESS := 0.58
const HOVER_BRIGHTNESS := 0.82
## Easing rates for the carousel and the accent blend, per second.
const SCROLL_RATE := 12.0
const ACCENT_RATE := 6.0
## How much of the backdrop's glow takes on the current game's accent.
const GLOW_MIX := 0.6
## A cartridge fades over this distance before a closed end of the rack.
const END_FADE := 0.2
## The lifted cartridge's width as a share of the room it has.
const LANDSCAPE_SHARE := 0.34
const PORTRAIT_SHARE := 0.58
const SIDE_SHARE := 0.31
## The details column's share of the width once it moves beside the rack, and
## how much larger that must make the cartridges before it is worth doing.
const SIDE_COLUMN_SHARE := 0.3
const SIDE_ADVANTAGE := 1.2
const MIN_CARD_WIDTH := 200.0
## Physical pixels a press must travel before it becomes a drag.
const DRAG_THRESHOLD := 10.0
## How far a drag may pull past either end, in cartridges.
const DRAG_OVERSHOOT := 0.35
## Seconds of momentum a released drag carries on for, unless the pointer was
## held still for longer than [constant FLING_HOLD_MSEC] before letting go.
const FLING_TIME := 0.18
const FLING_HOLD_MSEC := 90
## A wheel notch browses one game; a spinning wheel is not a way to skip nine.
const WHEEL_COOLDOWN_MSEC := 120
const INSERT_TIME := 0.52
const REDUCED_FADE := 0.16

@export_file("*.tscn") var play_scene := "res://scenes/menus/mode_select.tscn"
@export_file("*.tscn") var instructions_scene := "res://scenes/menus/instructions.tscn"

## The cartridge this screen clones per game. Exported rather than preloaded so
## the look of an entry can be replaced without touching this script.
@export var card_scene: PackedScene

@onready var _background: ColorRect = %Background
@onready var _margins: MarginContainer = %Margins
@onready var _layout: VBoxContainer = %Layout
@onready var _header_pad: MarginContainer = %HeaderPad
@onready var _header: HBoxContainer = %Header
@onready var _title_box: VBoxContainer = %TitleBox
@onready var _title: Label = %Title
@onready var _rule: ColorRect = %Rule
@onready var _back_button: Button = %BackButton
@onready var _empty: Label = %Empty
@onready var _scroll_box: ScrollContainer = %Scroll
@onready var _body: BoxContainer = %Body
@onready var _stage: Control = %Stage
@onready var _shelf_back: Shelf = %ShelfBack
@onready var _track: Control = %Track
@onready var _shelf_front: Shelf = %ShelfFront
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _details_pad: MarginContainer = %DetailsPad
@onready var _details: BoxContainer = %Details
@onready var _info: VBoxContainer = %Info
@onready var _game_title: Label = %GameTitle
@onready var _game_rule: ColorRect = %GameRule
@onready var _game_tagline: Label = %GameTagline
@onready var _game_modes: Label = %GameModes
@onready var _game_status: Label = %GameStatus
@onready var _play_button: Button = %PlayButton
@onready var _footer_pad: MarginContainer = %FooterPad
@onready var _footer_left: Label = %FooterLeft
@onready var _footer_right: Label = %FooterRight
@onready var _focus_accent: ColorRect = %FocusAccent

var _cards: Array[GameCard] = []
## Index of the cartridge in hand.
var _current := 0
## Fractional index at the middle of the rack; eases towards [member _current].
var _scroll := 0.0
var _time := 0.0
## 0 lifted, 1 seated; briefly negative as the cartridge is lifted to go in.
var _seat := 0.0
var _power := 0.0
var _card_width := 0.0
var _deck_y := 0.0
var _unit := 1.0
var _side_margin := 0.0
var _side_mode := false
var _reserve_status := false
var _reduced_motion := false
var _launching := false
var _launch_routed := false
var _launch_tween: Tween
var _sounds_ready := false
var _silent_focus := false
var _hovered: GameCard
var _studio_accent := Color.WHITE
var _accent_shown := Color.WHITE
var _accent_applied := Color.TRANSPARENT
var _drag_armed := false
var _dragging := false
var _drag_origin := Vector2.ZERO
var _drag_scroll := 0.0
var _drag_last_x := 0.0
var _drag_last_msec := 0
var _drag_velocity := 0.0
var _suppress_press := false
var _last_wheel_msec := -WHEEL_COOLDOWN_MSEC
var _navigation_styles: Dictionary[StringName, StyleBox] = {}
var _scaled_styles: Dictionary[StringName, StyleBox] = {}


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	_studio_accent = GameCatalog.theme().accent
	_accent_shown = _studio_accent
	margins = _margins
	_footer_left.text = StudioInfo.copyright_line()
	_footer_right.text = "v%s" % StudioInfo.version()
	for button: Button in [_back_button, _play_button]:
		button.expand_icon = true
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.focus_entered.connect(_on_navigation_focused.bind(button))
		button.focus_exited.connect(_on_navigation_focus_exited.bind(button))
	for arrow: Button in [_prev_button, _next_button]:
		# Browsing already ticks, and an arrow never takes focus to announce.
		arrow.set_meta("ui_sounds", true)
		arrow.expand_icon = true
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_prev_button.tooltip_text = "Previous game"
	_next_button.tooltip_text = "Next game"
	_prev_button.accessibility_name = _prev_button.tooltip_text
	_next_button.accessibility_name = _next_button.tooltip_text
	_play_button.gui_input.connect(_on_browse_input)
	_stage.resized.connect(_on_stage_resized)
	_build_cards()
	_select_index(maxi(_index_of(GameCatalog.current_id()), 0), true)
	Settings.changed.connect(_on_setting_changed)
	AchievementManager.progression_changed.connect(_on_progression_changed)
	set_process(not _reduced_motion)
	super()
	# Queued after MenuScreen's own deferred focus, so opening stays silent.
	_enable_sounds.call_deferred()


func _process(delta: float) -> void:
	if not _launching:
		_time += delta
	if not _dragging:
		var target := float(_current)
		_scroll = lerpf(_scroll, target, 1.0 - exp(-SCROLL_RATE * delta))
		if absf(_scroll - target) < 0.0005:
			_scroll = target
	var accent := _current_accent()
	_accent_shown = _accent_shown.lerp(accent, 1.0 - exp(-ACCENT_RATE * delta))
	if _color_distance(_accent_shown, accent) < 0.002:
		_accent_shown = accent
	_apply_accent()
	_update_stage()


# --- Layout -------------------------------------------------------------------

func _on_layout_changed(area: Vector2) -> void:
	var portrait := Responsive.is_portrait(area)
	var preference := float(Settings.get_value("ui/scale", 1.0))
	var unit := maxf(1.0, area.x * preference / maxf(get_window().size.x, 1.0) / 1.5)
	_unit = unit
	# The rack runs to the edges of the screen, so the side margins MenuScreen
	# gives the whole screen move onto the rows that stay inside them.
	var side := float(int(clampf(area.x * margin_ratio.x, margin_min.x, margin_max.x)))
	_side_margin = side
	_margins.add_theme_constant_override("margin_left", 0)
	_margins.add_theme_constant_override("margin_right", 0)
	for pad: MarginContainer in [_header_pad, _footer_pad]:
		pad.add_theme_constant_override("margin_left", roundi(side))
		pad.add_theme_constant_override("margin_right", roundi(side))

	# Whole pixels, as the containers apply them, so the fit below is exact.
	var gap := float(roundi(24.0 * unit))
	var rows := float(roundi(18.0 * unit))
	var spacing := float(roundi(8.0 * unit))
	var title_gap := float(roundi(12.0 * unit))
	_layout.add_theme_constant_override("separation", roundi(rows))
	_header.add_theme_constant_override("separation", roundi(gap))
	_title_box.add_theme_constant_override("separation", roundi(title_gap))
	_title.add_theme_font_size_override("font_size", roundi((42.0 if portrait else 56.0) * unit))
	_rule.custom_minimum_size = (Vector2(92.0, 3.0) * unit).round()
	_back_button.custom_minimum_size = Vector2(0.0, 66.0 * unit)
	for button: Button in [_back_button, _play_button]:
		button.add_theme_font_size_override("font_size", roundi(24.0 * unit))
		button.add_theme_constant_override("icon_max_width", roundi(18.0 * unit))
	_game_title.add_theme_font_size_override(
		"font_size", roundi((34.0 if portrait else 40.0) * unit)
	)
	_game_rule.custom_minimum_size = (Vector2(64.0, 3.0) * unit).round()
	_game_tagline.add_theme_font_size_override("font_size", roundi(22.0 * unit))
	for label: Label in [_game_modes, _game_status]:
		label.add_theme_font_size_override("font_size", roundi(18.0 * unit))
	for label: Label in [_footer_left, _footer_right]:
		label.add_theme_font_size_override("font_size", roundi(16.0 * unit))
	_info.add_theme_constant_override("separation", roundi(spacing))
	_body.add_theme_constant_override("separation", roundi(gap))
	# Two lines are kept for every tagline and a line for a status if any game
	# has one, so browsing never makes the details jump.
	_game_tagline.custom_minimum_size.y = ceilf(
		_line_height(_game_tagline) * 2.0 + _game_tagline.get_theme_constant("line_spacing")
	)
	_game_status.visible = _reserve_status
	_game_status.custom_minimum_size.y = ceilf(_line_height(_game_status))
	var align := HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_LEFT
	for label: Label in [_game_title, _game_tagline, _game_modes, _game_status]:
		label.horizontal_alignment = align
	_game_rule.size_flags_horizontal = (
		Control.SIZE_SHRINK_CENTER if portrait else Control.SIZE_SHRINK_BEGIN
	)
	_scale_navigation_styles(unit)

	# Measured from the fonts rather than the containers, whose cached minimum
	# sizes only catch up with the overrides above at the end of the frame.
	var top := float(_margins.get_theme_constant("margin_top"))
	var bottom := float(_margins.get_theme_constant("margin_bottom"))
	var inner := Vector2(area.x - 2.0 * side, area.y - top - bottom)
	var header := maxf(
		_line_height(_title) + title_gap + _rule.custom_minimum_size.y, 66.0 * unit
	)
	var footer := maxf(_line_height(_footer_left), _line_height(_footer_right))
	# Two pixels of slack for the fonts' fractional line heights.
	var room := floorf(inner.y - header - footer - 2.0 * rows - 2.0)
	var info := _info_height(spacing)
	var play := 72.0 * unit
	var ratio := stage_ratio()
	var details := info + gap + play if portrait else maxf(info, play)
	var stacked := minf(
		inner.x * (PORTRAIT_SHARE if portrait else LANDSCAPE_SHARE),
		(room - details - gap) / ratio
	)
	var column := clampf(inner.x * SIDE_COLUMN_SHARE, 280.0 * unit, 520.0 * unit)
	var beside_width := area.x - side - column - gap
	var beside := minf(beside_width * SIDE_SHARE, room / ratio)
	_side_mode = not portrait and not _cards.is_empty() and beside > stacked * SIDE_ADVANTAGE
	var width := maxf(beside if _side_mode else stacked, MIN_CARD_WIDTH * unit)
	_card_width = width
	_deck_y = (HEADROOM + GameCard.HEIGHT_RATIO + HOVER_GAP - Shelf.SLOT_TOP) * width
	var stage_height := ceilf(_deck_y + Shelf.depth() * width)

	_body.vertical = not _side_mode
	if _side_mode:
		# Like the title screen: words on the left, hardware on the right.
		_body.move_child(_details_pad, 0)
		_details_pad.add_theme_constant_override("margin_left", roundi(side))
		_details_pad.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_details.vertical = true
		_details.custom_minimum_size.x = column
		_details.add_theme_constant_override("separation", roundi(gap))
		_play_button.custom_minimum_size = Vector2(0.0, play)
		_play_button.size_flags_horizontal = Control.SIZE_FILL
		_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stage.custom_minimum_size = Vector2(maxf(beside_width, width), stage_height)
	else:
		_body.move_child(_details_pad, -1)
		_details_pad.add_theme_constant_override("margin_left", 0)
		_details_pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_details.vertical = portrait
		if portrait:
			_details.custom_minimum_size.x = minf(inner.x, 900.0 * unit)
			_details.add_theme_constant_override("separation", roundi(gap))
			_play_button.custom_minimum_size = Vector2(0.0, play)
			_play_button.size_flags_horizontal = Control.SIZE_FILL
		else:
			_details.custom_minimum_size.x = minf(maxf(width * 2.1, 700.0 * unit), inner.x)
			_details.add_theme_constant_override("separation", roundi(32.0 * unit))
			_play_button.custom_minimum_size = Vector2(360.0 * unit, play)
			_play_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_stage.custom_minimum_size = Vector2(area.x, stage_height)
	_track.offset_bottom = _deck_y + Shelf.DECK_DEPTH * width
	_shelf_back.open_left = not _side_mode
	_shelf_front.open_left = not _side_mode
	_shelf_back.open_right = true
	_shelf_front.open_right = true
	_size_cards()
	_style_arrows(unit)
	_place_arrows()
	_update_stage()
	_sync_focus_accent.call_deferred()


## Stage height per unit of cartridge width: headroom, the lifted cartridge,
## and the rack beneath it.
static func stage_ratio() -> float:
	return HEADROOM + GameCard.HEIGHT_RATIO + HOVER_GAP - Shelf.SLOT_TOP + Shelf.depth()


func _info_height(spacing: float) -> float:
	var height := _line_height(_game_title) + spacing + _game_rule.custom_minimum_size.y
	height += spacing + _game_tagline.custom_minimum_size.y
	height += spacing + _line_height(_game_modes)
	if _game_status.visible:
		height += spacing + _game_status.custom_minimum_size.y
	return height


func _line_height(label: Label) -> float:
	var font := label.get_theme_font("font")
	if font == null:
		return 0.0
	return font.get_height(label.get_theme_font_size("font_size"))


func _size_cards() -> void:
	if _card_width <= 0.0:
		return
	var card_size := Vector2(_card_width, _card_width * GameCard.HEIGHT_RATIO)
	for card in _cards:
		card.size = card_size
		card.pivot_offset = Vector2(card_size.x * 0.5, card_size.y)
		card.ring_width = maxf(2.0, 3.0 * _unit)


func _on_stage_resized() -> void:
	_place_arrows()
	_update_stage()


## The arrows line up with the header's edges where the rack runs off screen,
## and sit on the rack's own end where it stops beside the details.
func _place_arrows() -> void:
	var arrow := 72.0 * _unit
	var y := (HEADROOM + GameCard.SHELL_RATIO * 0.5) * _card_width - arrow * 0.5
	for button: Button in [_prev_button, _next_button]:
		button.size = Vector2(arrow, arrow)
	_prev_button.position = Vector2(0.0 if _side_mode else _side_margin, y)
	_next_button.position = Vector2(_stage.size.x - _side_margin - arrow, y)


# --- Cartridges ---------------------------------------------------------------

## Builds one cartridge per available game, in catalog (menu) order.
##
## [method GameCatalog.available] is asked again on every rebuild rather than
## cached, because unlocking a game while this screen is open must add it.
func _build_cards() -> void:
	for card in _cards:
		_track.remove_child(card)
		card.queue_free()
	_cards.clear()
	_hovered = null

	var games := GameCatalog.available()
	_empty.visible = games.is_empty()
	_scroll_box.visible = not games.is_empty()
	_play_button.disabled = games.is_empty()
	first_focus = _back_button
	if card_scene == null:
		push_error("GameSelect: no card scene assigned.")
		return

	var multiplayer_available := GameSession.multiplayer_available()
	var accents := PackedColorArray()
	_reserve_status = false
	for manifest in games:
		var node := card_scene.instantiate()
		var card := node as GameCard
		if card == null:
			node.free()
			push_error("GameSelect: the card scene is not a GameCard.")
			break
		# The screen voices the rack itself: a tick per game browsed, rather
		# than the stock sounds for a button taking focus.
		card.set_meta("ui_sounds", true)
		_track.add_child(card)
		card.configure(manifest, _status_line(manifest), multiplayer_available)
		card.set_slot(_cards.size(), games.size())
		card.set_reduced_motion(_reduced_motion)
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(_on_card_pressed.bind(card))
		card.gui_input.connect(_on_browse_input)
		card.focus_entered.connect(_on_card_focused)
		card.mouse_entered.connect(_on_card_hovered.bind(card))
		card.mouse_exited.connect(_on_card_unhovered.bind(card))
		_cards.append(card)
		accents.append(card.accent())
		if not card.status_line().is_empty():
			_reserve_status = true
	_shelf_back.slot_accents = accents
	_shelf_front.slot_accents = accents
	_size_cards()


## What the player may do with a game, in words. An unlock rule that gates modes
## rather than the whole game is the only thing worth saying here, so a game with
## no rule gets no line instead of a redundant "unlocked" badge on every card.
func _status_line(manifest: GameManifest) -> String:
	var modes := AchievementManager.game_unlocked_modes(manifest.id)
	if modes.is_empty():
		return ""
	return "Available: %s." % " + ".join(modes)


## Makes [param index] the cartridge in hand. Focus roves: only that cartridge
## can take it, so Tab and the arrow keys never wade through the whole rack.
func _select_index(index: int, immediate := false) -> void:
	if _cards.is_empty():
		return
	index = clampi(index, 0, _cards.size() - 1)
	var previous := _current_card()
	var had_focus := previous != null and previous.has_focus()
	_current = index
	var card := _cards[index]
	for other_index in _cards.size():
		_cards[other_index].set_current(other_index == index, immediate)
	# Drawn last, so its shadow falls across its neighbours.
	_track.move_child(card, -1)
	card.focus_mode = Control.FOCUS_ALL
	_wire_focus(card)
	if had_focus and previous != card:
		_grab_silently(card)
	for other in _cards:
		if other != card:
			other.focus_mode = Control.FOCUS_NONE
	first_focus = card
	_show_details(card)
	_prev_button.disabled = index == 0
	_next_button.disabled = index == _cards.size() - 1
	if (immediate or _reduced_motion) and not _dragging:
		_scroll = float(index)
		_accent_shown = card.accent()
		_apply_accent()
	_update_stage()


func _wire_focus(card: GameCard) -> void:
	card.focus_neighbor_top = card.get_path_to(_back_button)
	card.focus_neighbor_bottom = card.get_path_to(_play_button)
	card.focus_neighbor_left = NodePath(".")
	card.focus_neighbor_right = NodePath(".")
	card.focus_previous = card.get_path_to(_back_button)
	card.focus_next = card.get_path_to(_play_button)
	_play_button.focus_neighbor_top = _play_button.get_path_to(card)
	_play_button.focus_previous = _play_button.get_path_to(card)
	_back_button.focus_neighbor_bottom = _back_button.get_path_to(card)
	_back_button.focus_next = _back_button.get_path_to(card)


## Moves along the rack by [param step] games. Returns whether it moved.
func _browse(step: int) -> bool:
	if _launching or _closing or _cards.is_empty():
		return false
	var target := clampi(_current + step, 0, _cards.size() - 1)
	if target == _current:
		return false
	_select_index(target)
	_tick()
	return true


func _show_details(card: GameCard) -> void:
	_game_title.text = card.game_title()
	_game_tagline.text = card.game_tagline()
	_game_modes.text = card.mode_summary()
	_game_status.text = card.status_line()
	_game_status.visible = _reserve_status or not _game_status.text.is_empty()
	_play_button.tooltip_text = "Play %s." % card.game_title()
	var description := _play_button.tooltip_text
	if not card.game_tagline().is_empty():
		description += " " + card.game_tagline()
	_play_button.accessibility_description = description


func _current_card() -> GameCard:
	if _current < 0 or _current >= _cards.size():
		return null
	return _cards[_current]


func _current_accent() -> Color:
	var card := _current_card()
	return card.accent() if card != null else _studio_accent


func _index_of(game_id: String) -> int:
	for index in _cards.size():
		if _cards[index].game_id() == game_id:
			return index
	return -1


## Stands every cartridge where the carousel puts it, and tells the rack what
## is lifted out of it.
func _update_stage() -> void:
	if _cards.is_empty() or _card_width <= 0.0:
		return
	var w := _card_width
	var stage_width := _stage.size.x
	var centre := stage_width * 0.5
	var near := w * (0.5 + NEIGHBOUR_GAP + SIDE_SCALE * 0.5)
	var pitch := w * SIDE_SCALE * SIDE_PITCH
	var bob := 0.0 if _reduced_motion else sin(_time * BOB_SPEED) * BOB * w
	var seat := clampf(_seat, 0.0, 1.0)
	var end_inset := Shelf.END_RADIUS * w
	var fade := END_FADE * w
	var lifted_most := 0.0
	var focus_x := centre
	for index in _cards.size():
		var card := _cards[index]
		var offset := float(index) - _scroll
		var distance := absf(offset)
		var t := smoothstep(0.0, 1.0, minf(distance, 1.0))
		var card_scale := lerpf(1.0, SIDE_SCALE, t)
		var lift := 1.0 - t
		var x := centre + signf(offset) * (
			near * minf(distance, 1.0) + maxf(distance - 1.0, 0.0) * pitch
		)
		# Where the connector's tip is: hidden below the slot's near edge while
		# standing, just clear of the deck while lifted.
		var rest := _deck_y + (
			Shelf.SLOT_BOTTOM + REST_SINK + GameCard.CONNECTOR_RATIO * card_scale
		) * w
		var tip := lerpf(rest, _deck_y + (Shelf.SLOT_TOP - HOVER_GAP) * w + bob, lift)
		if index == _current and _seat != 0.0:
			tip = lerpf(tip, rest + SEAT_DEPTH * w, _seat)
			lift *= 1.0 - seat
		card.scale = Vector2.ONE * card_scale
		card.position = Vector2(x, tip) - card.pivot_offset

		var half := w * card_scale * 0.5
		var alpha := 1.0
		if offset < 0.0 and not _shelf_front.open_left:
			alpha = smoothstep(0.0, fade, x - half - end_inset)
		elif offset > 0.0 and not _shelf_front.open_right:
			alpha = smoothstep(0.0, fade, stage_width - end_inset - (x + half))
		var on_stage := x + half > 0.0 and x - half < stage_width
		card.visible = index == _current or (on_stage and alpha > 0.01)

		var brightness := lerpf(1.0, SIDE_BRIGHTNESS, t)
		if card == _hovered and not _launching:
			brightness = maxf(brightness, HOVER_BRIGHTNESS)
		if _launching and index != _current:
			brightness *= 1.0 - 0.35 * seat
		card.modulate = Color(brightness, brightness, brightness, alpha)
		card.lift = lift
		if lift > lifted_most:
			lifted_most = lift
			focus_x = x
	for shelf: Shelf in [_shelf_back, _shelf_front]:
		shelf.card_width = w
		shelf.deck_y = _deck_y
		shelf.scroll = _scroll
		shelf.accent = _accent_shown
		shelf.lift = lifted_most
		shelf.focus_x = focus_x
		shelf.power = _power
		shelf.queue_redraw()


func _apply_accent() -> void:
	if _accent_applied == _accent_shown:
		return
	_accent_applied = _accent_shown
	var backdrop := _background.material as ShaderMaterial
	if backdrop != null:
		backdrop.set_shader_parameter("glow_color", _studio_accent.lerp(_accent_shown, GLOW_MIX))
	_game_rule.color = _accent_shown
	# Lightened, so a game with a deep accent still reads against the backdrop.
	_game_modes.add_theme_color_override("font_color", _accent_shown.lerp(Color.WHITE, 0.35))
	_focus_accent.color = _accent_shown


static func _color_distance(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a)))


# --- Input --------------------------------------------------------------------

## Left and right browse from the cartridge in hand and from Play alike, so a
## pad player can compare games without leaving the button that starts one.
func _on_browse_input(event: InputEvent) -> void:
	if _launching or _closing or _cards.is_empty():
		return
	if event.is_action_pressed("ui_left", true):
		_browse(-1)
	elif event.is_action_pressed("ui_right", true):
		_browse(1)
	elif event.is_action_pressed("ui_home"):
		_browse(-_current)
	elif event.is_action_pressed("ui_end"):
		_browse(_cards.size() - 1 - _current)
	else:
		return
	accept_event()


## The pointer drags the rack and spins it with the wheel. Read here rather than
## from each cartridge, because a drag starts on one cartridge and ends on
## another, and the first must not treat its release as a press.
func _input(event: InputEvent) -> void:
	if _launching or _closing or _cards.size() < 2 or Router.is_transitioning():
		return
	var button := event as InputEventMouseButton
	if button != null:
		_on_pointer_button(button)
	elif event is InputEventMouseMotion and _drag_armed:
		_on_pointer_motion()


func _on_pointer_button(event: InputEventMouseButton) -> void:
	var pointer := get_global_mouse_position()
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT, \
				MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			if not event.pressed or not _stage_contains(pointer):
				return
			get_viewport().set_input_as_handled()
			var now := Time.get_ticks_msec()
			if now - _last_wheel_msec < WHEEL_COOLDOWN_MSEC:
				return
			_last_wheel_msec = now
			var back := event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]
			_browse(-1 if back else 1)
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_suppress_press = false
				_drag_armed = _track.get_global_rect().has_point(pointer) \
					and _scroll_box.get_global_rect().has_point(pointer)
				_drag_origin = pointer
				_drag_scroll = _scroll
				_drag_last_x = pointer.x
				_drag_last_msec = Time.get_ticks_msec()
				_drag_velocity = 0.0
			else:
				if _dragging:
					_end_drag()
				elif _suppress_press:
					_release_press.call_deferred()
				_drag_armed = false


func _on_pointer_motion() -> void:
	var pointer := get_global_mouse_position()
	var moved := pointer - _drag_origin
	if not _dragging:
		if moved.length() < DRAG_THRESHOLD * _logical_pixels():
			return
		if absf(moved.y) > absf(moved.x):
			# An upright gesture belongs to the scroll box, not the rack. Like a
			# drag, a gesture is never a press of the cartridge it began on.
			_drag_armed = false
			_suppress_press = true
			return
		_dragging = true
		_hovered = null
	get_viewport().set_input_as_handled()
	var near := maxf(_card_width * (0.5 + NEIGHBOUR_GAP + SIDE_SCALE * 0.5), 1.0)
	_scroll = clampf(
		_drag_scroll - moved.x / near, -DRAG_OVERSHOOT, _cards.size() - 1 + DRAG_OVERSHOOT
	)
	var now := Time.get_ticks_msec()
	var elapsed := maxf(float(now - _drag_last_msec) / 1000.0, 0.001)
	_drag_velocity = lerpf(_drag_velocity, (_drag_last_x - pointer.x) / near / elapsed, 0.35)
	_drag_last_x = pointer.x
	_drag_last_msec = now
	var nearest := clampi(roundi(_scroll), 0, _cards.size() - 1)
	if nearest != _current:
		_select_index(nearest)
		_tick()
	if _reduced_motion:
		_update_stage()


func _end_drag() -> void:
	_dragging = false
	# A pointer that came to rest before letting go carries no momentum.
	if Time.get_ticks_msec() - _drag_last_msec > FLING_HOLD_MSEC:
		_drag_velocity = 0.0
	var fling := clampf(_drag_velocity * FLING_TIME, -2.0, 2.0)
	var target := clampi(roundi(_scroll + fling), 0, _cards.size() - 1)
	# The release that ends a drag must not also press the cartridge under it.
	_suppress_press = true
	_release_press.call_deferred()
	if target != _current:
		_select_index(target)
		_tick()
	if _reduced_motion:
		_scroll = float(_current)
		_update_stage()


func _release_press() -> void:
	_suppress_press = false


func _stage_contains(point: Vector2) -> bool:
	return _stage.is_visible_in_tree() and _stage.get_global_rect().has_point(point) \
		and _scroll_box.get_global_rect().has_point(point)


## Logical pixels per physical one, so a drag threshold feels the same on a
## phone as on a monitor.
func _logical_pixels() -> float:
	return get_viewport_rect().size.x / maxf(float(get_window().size.x), 1.0)


func _on_card_pressed(card: GameCard) -> void:
	if _suppress_press or _launching or _closing:
		return
	var index := _cards.find(card)
	if index < 0:
		return
	if index != _current:
		# A cartridge on the rack is brought forward first; the one in hand
		# is the one a press starts.
		var had_focus := _current_card() != null and _current_card().has_focus()
		_select_index(index)
		_tick()
		if not had_focus:
			_grab_silently(card)
		return
	AudioManager.play_click()
	_launch()


func _on_card_hovered(card: GameCard) -> void:
	if _launching or _dragging:
		return
	_hovered = card
	if card == _current_card() and not card.has_focus():
		card.grab_focus()
	if _reduced_motion:
		_update_stage()


func _on_card_unhovered(card: GameCard) -> void:
	if _hovered == card:
		_hovered = null
		if _reduced_motion:
			_update_stage()


func _on_card_focused() -> void:
	if _sounds_ready and not _silent_focus:
		AudioManager.play_focus()
	_sync_focus_accent.call_deferred()


func _on_prev_pressed() -> void:
	_browse(-1)


func _on_next_pressed() -> void:
	_browse(1)


func _on_play_pressed() -> void:
	_launch()


func _on_back_pressed() -> void:
	go_back()


func _tick() -> void:
	if _sounds_ready:
		AudioManager.play_focus()


func _grab_silently(control: Control) -> void:
	_silent_focus = true
	control.grab_focus()
	_silent_focus = false


func _enable_sounds() -> void:
	_sounds_ready = true


# --- Launch -------------------------------------------------------------------

## Seats the cartridge in hand, then starts it through [method Router.start_selected_game],
## the one definition of "begin the selected game" the title screen shares.
func _launch() -> void:
	if _launching or _closing or Router.is_transitioning():
		return
	var card := _current_card()
	if card == null or not GameCatalog.select(card.game_id()):
		return
	_launching = true
	_closing = true
	_drag_armed = false
	_dragging = false
	_hovered = null
	for other in _cards:
		other.close()
	for button: Button in [_back_button, _play_button, _prev_button, _next_button]:
		button.disabled = true
	_focus_accent.hide()
	if _reduced_motion:
		_play_reduced_launch()
		return
	_launch_tween = create_tween()
	# A small lift before the push down, as a hand lines a cartridge up.
	_launch_tween.tween_method(_set_seat, 0.0, -0.03, 0.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_launch_tween.tween_method(_set_seat, -0.03, 1.0, INSERT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_launch_tween.tween_interval(0.12)
	_launch_tween.tween_callback(_complete_launch)


func _set_seat(value: float) -> void:
	_seat = value
	# The rack's lights come up only as the connector meets the contacts.
	_power = smoothstep(0.82, 1.0, value)
	_update_stage()


func _play_reduced_launch() -> void:
	if _launch_tween != null and _launch_tween.is_valid():
		_launch_tween.kill()
	_power = 1.0
	_update_stage()
	_launch_tween = create_tween()
	_launch_tween.tween_property(_stage, "modulate:a", 0.0, REDUCED_FADE)
	_launch_tween.tween_callback(_complete_launch)


func _complete_launch() -> void:
	if _launch_routed:
		return
	_launch_routed = true
	Router.start_selected_game(play_scene, instructions_scene)


# --- Settings and progression -------------------------------------------------

func _on_setting_changed(key: String, value: Variant) -> void:
	if key != REDUCED_MOTION_KEY:
		return
	_reduced_motion = bool(value)
	for card in _cards:
		card.set_reduced_motion(_reduced_motion)
	set_process(not _reduced_motion)
	if _launching:
		if _reduced_motion and not _launch_routed:
			# Killing a tween does not emit finished. Replace the seating with an
			# opacity-only finish so a live accessibility change cannot trap Play.
			_play_reduced_launch()
		return
	if _reduced_motion:
		_dragging = false
		_drag_armed = false
		_scroll = float(_current)
		_accent_shown = _current_accent()
		_apply_accent()
		_update_stage()


func _on_progression_changed(_key: String, _value: bool) -> void:
	if _launching:
		return
	var card := _current_card()
	var keep := card.game_id() if card != null else GameCatalog.current_id()
	var had_focus := card != null and card.has_focus()
	_build_cards()
	_select_index(maxi(_index_of(keep), 0), true)
	refresh_layout()
	if had_focus and _current_card() != null:
		_grab_silently(_current_card())


# --- Navigation buttons -------------------------------------------------------

func _on_navigation_focused(button: Button) -> void:
	if _scaled_styles.has(&"hover"):
		button.add_theme_stylebox_override("normal", _scaled_styles[&"hover"])
	_sync_focus_accent.call_deferred()


func _on_navigation_focus_exited(button: Button) -> void:
	if _scaled_styles.has(&"normal"):
		button.add_theme_stylebox_override("normal", _scaled_styles[&"normal"])
	_sync_focus_accent.call_deferred()


## The title screen's accent bar, on whichever glass button has focus.
func _sync_focus_accent() -> void:
	_focus_accent.hide()
	if _launching:
		return
	for button: Button in [_back_button, _play_button]:
		if not button.has_focus() or not button.is_visible_in_tree():
			continue
		if _focus_accent.get_parent() != button:
			_focus_accent.reparent(button, false)
		_focus_accent.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_focus_accent.offset_right = maxf(button.size.y, button.custom_minimum_size.y) / 18.0
		_focus_accent.show()
		return


func _scale_navigation_styles(unit: float) -> void:
	if _navigation_styles.is_empty():
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			_navigation_styles[state] = _play_button.get_theme_stylebox(state)
	for state: StringName in _navigation_styles:
		var original := _navigation_styles[state]
		var scaled := original.duplicate() as StyleBox
		for side_index in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			scaled.set_content_margin(side_index, original.get_content_margin(side_index) * unit)
		_scaled_styles[state] = scaled
		for button: Button in [_back_button, _play_button]:
			button.add_theme_stylebox_override(state, scaled)
	for button: Button in [_back_button, _play_button]:
		if button.has_focus():
			button.add_theme_stylebox_override("normal", _scaled_styles[&"hover"])


## The same glass as the title screen's buttons, as round browse keys.
func _style_arrows(unit: float) -> void:
	var radius := roundi(36.0 * unit)
	for state: StringName in _scaled_styles:
		var style := _scaled_styles[state].duplicate() as StyleBox
		for side_index in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side_index, 0.0)
		var flat := style as StyleBoxFlat
		if flat != null:
			flat.set_corner_radius_all(radius)
			flat.corner_detail = 12
		for arrow: Button in [_prev_button, _next_button]:
			arrow.add_theme_stylebox_override(state, style)
	for arrow: Button in [_prev_button, _next_button]:
		arrow.add_theme_constant_override("icon_max_width", roundi(26.0 * unit))
