extends MenuScreen

## Credits roll. The content is data: the shared sections live in
## StudioInfo.CREDITS and a game's own sections live on its GameManifest, so
## this screen never names a game. Auto-scrolling stops the moment the player
## scrolls by hand, so they can read at their own pace.
##
## A standalone build is one game's product, so that game's credits lead the
## roll. A collection cannot pick one game's credits over another's, so it
## lists the games it ships and points at them instead.

@export var scroll_speed := 48.0
@export var start_delay := 1.2
@export var loop_credits := true

@onready var _scroll: ScrollContainer = %Scroll
@onready var _list: VBoxContainer = %List

var _offset := 0.0
var _auto := true
var _delay_left := 0.0


func _ready() -> void:
	_build()
	_delay_left = start_delay
	_scroll.gui_input.connect(_on_scroll_input)
	super()


func _build() -> void:
	for child in _list.get_children():
		child.queue_free()

	_add_spacer(40)
	var manifest := _credited_game()
	if manifest != null:
		_add_game_credits(manifest)
	for section: Dictionary in StudioInfo.CREDITS:
		_add_section(section)
	if manifest == null:
		_add_collection_note()

	_add_label(StudioInfo.STUDIO, 30, StudioInfo.CREAM, 0)
	_add_label(StudioInfo.copyright_line(), 24, StudioInfo.MUTED, 0)
	_add_label(StudioInfo.WEBSITE, 24, StudioInfo.MUTED, 0)
	_add_spacer(60)


## The game these credits belong to, or null when the build ships more than one.
## Same rule the settings screen uses to adopt a game context: a build with a
## single game in the catalog is that game, whoever pinned it.
func _credited_game() -> GameManifest:
	if not GameCatalog.is_single_game_build():
		return null
	return GameCatalog.current()


## A game's own credits, under its title so it is clear which work they cover
## and which of the sections below belong to the studio.
func _add_game_credits(manifest: GameManifest) -> void:
	_add_label(manifest.title, 40, StudioInfo.CREAM, 0)
	_add_spacer(24)
	for section: Dictionary in manifest.credits:
		_add_section(section)


## Sends a collection player to the credits they actually want. The list is
## built from the catalog, so it names exactly what this build ships and can
## never fall out of date.
func _add_collection_note() -> void:
	var titles := PackedStringArray()
	for game in GameCatalog.all():
		titles.append(game.title)
	if titles.is_empty():
		return

	_add_label(StudioInfo.COLLECTION_CREDITS_HEADING, 34, StudioInfo.SKY, 0)
	_add_label(" · ".join(titles), 27, StudioInfo.CREAM, 0)
	_add_label(StudioInfo.COLLECTION_CREDITS_NOTE, 27, StudioInfo.MUTED, 0)
	_add_spacer(34)


func _add_section(section: Dictionary) -> void:
	_add_label(str(section.get("heading", "")), 34, StudioInfo.SKY, 0)
	for line: String in section.get("lines", []):
		_add_label(line, 27, StudioInfo.CREAM, 0)
	_add_spacer(34)


func _add_label(text: String, font_size: int, color: Color, top_margin: int) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if top_margin > 0:
		label.add_theme_constant_override("line_spacing", top_margin)
	_list.add_child(label)


func _add_spacer(height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(spacer)


func _process(delta: float) -> void:
	if not _auto:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return

	var bar := _scroll.get_v_scroll_bar()
	var max_scroll: float = maxf(0.0, bar.max_value - bar.page)
	if max_scroll <= 0.0:
		return

	_offset += scroll_speed * delta
	if _offset > max_scroll:
		if loop_credits:
			_offset = 0.0
			_delay_left = start_delay
		else:
			_offset = max_scroll
	_scroll.scroll_vertical = int(_offset)


## Hands control to the player as soon as they scroll, drag or swipe.
func _on_scroll_input(event: InputEvent) -> void:
	var manual := (
		event is InputEventMouseButton
		or event is InputEventScreenDrag
		or event is InputEventPanGesture
	)
	if manual:
		_auto = false


func _on_back_pressed() -> void:
	go_back()
