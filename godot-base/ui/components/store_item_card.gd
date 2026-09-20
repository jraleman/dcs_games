class_name StoreItemCard
extends PanelContainer

## One cosmetic for sale, drawn from a [Store] item description.
##
## Deliberately a dumb view, for the same reason [GameCard] is: it is a
## `class_name` script that a headless test may import, so it touches no autoload
## instance. It also decides nothing about money — the screen hands it an item
## that already knows whether it is owned, worn, affordable or locked, and the
## card asks to buy or wear by signal rather than doing either itself.

## The player wants this item; the screen checks the price.
signal buy_requested(item_id: String)
## The player wants this item worn in [param slot_id].
signal equip_requested(item_id: String, slot_id: String)
## The player wants [param slot_id] emptied.
signal unequip_requested(slot_id: String)

## Narrowest a card may get before the grid drops to fewer columns.
const MIN_WIDTH := 268.0
const PREVIEW_HEIGHT := 176.0

const PLATE_COLOR := Color(0.0392157, 0.0705882, 0.0941176, 1.0)
const MUTED_COLOR := Color(0.576471, 0.65098, 0.690196, 1.0)
const PRICE_COLOR := Color(1.0, 0.831373, 0.360784, 1.0)
const OWNED_COLOR := Color(0.686275, 0.866667, 0.917647, 1.0)
const LOCKED_COLOR := Color(0.729412, 0.529412, 0.529412, 1.0)

var _item_id := ""
var _preview: MarginContainer
var _plate: ColorRect
var _badge: Label
var _title: Label
var _description: Label
var _status: Label
var _actions: VBoxContainer
var _buy_button: Button
var _slot_buttons: Array[Button] = []
var _preview_instance: Control
var _ui_scale := 1.0


func _init() -> void:
	custom_minimum_size = Vector2(MIN_WIDTH, 0.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _card_style())

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)

	_preview = MarginContainer.new()
	_preview.name = "Preview"
	_preview.custom_minimum_size = Vector2(0.0, PREVIEW_HEIGHT)
	_preview.clip_contents = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(_preview)

	_plate = ColorRect.new()
	_plate.name = "Plate"
	_plate.color = PLATE_COLOR
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(_plate)

	_badge = Label.new()
	_badge.name = "Badge"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 34)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(_badge)

	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.94902, 0.968627, 0.976471, 1.0))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_title)

	_description = Label.new()
	_description.name = "Description"
	_description.add_theme_font_size_override("font_size", 18)
	_description.add_theme_color_override("font_color", MUTED_COLOR)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_description)

	_status = Label.new()
	_status.name = "Status"
	_status.add_theme_font_size_override("font_size", 20)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)

	_actions = VBoxContainer.new()
	_actions.name = "Actions"
	_actions.add_theme_constant_override("separation", 6)
	layout.add_child(_actions)


## Draws [param item] — a [method Store.describe] result — with one action per
## slot in [param slots]. [param price_text] arrives already formatted, so the
## card never has to know what the money is called.
func configure(
	item: Dictionary, slots: Array[Dictionary], price_text: String
) -> void:
	_item_id = str(item.get("id", ""))
	_title.text = str(item.get("title", _item_id))
	_description.text = str(item.get("description", ""))
	_description.visible = not _description.text.is_empty()

	var owned := bool(item.get("owned", false))
	var locked := bool(item.get("locked", false))
	var equipped_slots: PackedStringArray = item.get("equipped_slots", PackedStringArray())
	_apply_preview(item)
	_apply_status(item, slots, price_text, owned, locked, equipped_slots)
	_apply_actions(item, slots, price_text, owned, locked, equipped_slots)
	add_theme_stylebox_override(
		"panel", _card_style(not equipped_slots.is_empty(), item.get("color", PLATE_COLOR))
	)
	tooltip_text = "%s. %s" % [_title.text, _status.text]
	accessibility_description = tooltip_text


## The item this card is showing.
func item_id() -> String:
	return _item_id


## The control a screen should focus to land on this card, or null when nothing
## on it can be pressed — an item that is locked, or too expensive for now.
func focus_target() -> Control:
	if _buy_button != null and _buy_button.visible and not _buy_button.disabled:
		return _buy_button
	for button in _slot_buttons:
		if button.visible and not button.disabled:
			return button
	return null


## Stops any moving preview, so a screen can park the whole grid for reduced
## motion or while it is closing.
func set_preview_running(running: bool) -> void:
	if _preview_instance != null and _preview_instance.has_method("set_preview_running"):
		_preview_instance.call("set_preview_running", running)


## Scale actual type and spacing, not a rasterized Control, when a phone
## stretches a large project canvas. New purchase/equip buttons retain the scale.
func set_ui_scale(value: float) -> void:
	var next := maxf(1.0, value)
	if is_equal_approx(_ui_scale, next):
		return
	_ui_scale = next
	custom_minimum_size.x = MIN_WIDTH * _ui_scale
	_preview.custom_minimum_size.y = PREVIEW_HEIGHT * _ui_scale
	_badge.add_theme_font_size_override("font_size", roundi(34 * _ui_scale))
	_title.add_theme_font_size_override("font_size", roundi(26 * _ui_scale))
	_description.add_theme_font_size_override("font_size", roundi(18 * _ui_scale))
	_status.add_theme_font_size_override("font_size", roundi(20 * _ui_scale))
	(get_node("Layout") as VBoxContainer).add_theme_constant_override(
		"separation", roundi(10 * _ui_scale)
	)
	_actions.add_theme_constant_override("separation", roundi(6 * _ui_scale))
	var style := get_theme_stylebox("panel") as StyleBoxFlat
	_scale_style(style)
	if _buy_button != null:
		_scale_button(_buy_button)
	for button in _slot_buttons:
		_scale_button(button)


func _apply_preview(item: Dictionary) -> void:
	var color: Color = item.get("color", PLATE_COLOR)
	_plate.color = color.darkened(0.55)
	_badge.text = str(item.get("badge", ""))
	_badge.add_theme_color_override("font_color", color)
	_badge.visible = true

	if _preview_instance != null:
		_preview.remove_child(_preview_instance)
		_preview_instance.queue_free()
		_preview_instance = null

	var path := str(item.get("preview_scene_path", "")).strip_edges()
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	# A preview is artwork: it must never be the reason a store cannot open, so
	# a scene with the wrong root simply leaves the badge plate showing.
	var instance := packed.instantiate() as Control
	if instance == null:
		push_warning("StoreItemCard: '%s' is not a Control scene." % path)
		return
	instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(instance)
	_preview_instance = instance
	if instance.has_method("configure"):
		instance.call("configure", item)
	_badge.visible = false


func _apply_status(
	item: Dictionary,
	slots: Array[Dictionary],
	price_text: String,
	owned: bool,
	locked: bool,
	equipped_slots: PackedStringArray
) -> void:
	if locked:
		_status.text = str(item.get("locked_reason", "Locked."))
		_status.add_theme_color_override("font_color", LOCKED_COLOR)
		return
	if not owned:
		var price := int(item.get("price", 0))
		_status.text = "Free" if price <= 0 else price_text
		if not bool(item.get("affordable", false)):
			_status.text += "  ·  not enough yet"
		_status.add_theme_color_override(
			"font_color", PRICE_COLOR if bool(item.get("affordable", false)) else MUTED_COLOR
		)
		return
	if equipped_slots.is_empty():
		_status.text = "Owned"
		_status.add_theme_color_override("font_color", MUTED_COLOR)
		return
	_status.text = "Worn: %s" % ", ".join(_slot_titles(slots, equipped_slots))
	_status.add_theme_color_override("font_color", OWNED_COLOR)


func _apply_actions(
	item: Dictionary,
	slots: Array[Dictionary],
	price_text: String,
	owned: bool,
	locked: bool,
	equipped_slots: PackedStringArray
) -> void:
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	_slot_buttons.clear()
	_buy_button = null

	if not owned:
		_buy_button = Button.new()
		_buy_button.name = "BuyButton"
		var price := int(item.get("price", 0))
		_buy_button.text = "Take it" if price <= 0 else "Buy  ·  %s" % price_text
		_buy_button.disabled = locked or not bool(item.get("affordable", false))
		_buy_button.tooltip_text = (
			str(item.get("locked_reason", "Locked.")) if locked
			else "Buy %s." % str(item.get("title", ""))
		)
		_buy_button.accessibility_description = _buy_button.tooltip_text
		_buy_button.pressed.connect(_on_buy_pressed)
		_actions.add_child(_buy_button)
		_scale_button(_buy_button)
		return

	# A game with one wearer gets one plain Equip button; a game with several
	# labels them, so nothing here has to know how many sides a match has.
	var single := slots.size() <= 1
	for slot in slots:
		var slot_id := str(slot.get("id", ""))
		var worn := equipped_slots.has(slot_id)
		var button := Button.new()
		button.name = "Slot_%s" % slot_id
		var label := "Equip" if single else str(slot.get("title", slot_id))
		if worn:
			label = "Equipped" if single else "%s ✓" % str(slot.get("title", slot_id))
		button.text = label
		button.disabled = worn and not bool(slot.get("allows_empty", false))
		button.tooltip_text = (
			"Take %s off the %s." % [str(item.get("title", "")), str(slot.get("title", ""))]
			if worn
			else "Wear %s on the %s." % [
				str(item.get("title", "")), str(slot.get("title", ""))
			]
		)
		button.accessibility_description = button.tooltip_text
		if worn:
			button.pressed.connect(_on_unequip_pressed.bind(slot_id))
		else:
			button.pressed.connect(_on_equip_pressed.bind(slot_id))
		_actions.add_child(button)
		_scale_button(button)
		_slot_buttons.append(button)


func _slot_titles(slots: Array[Dictionary], ids: PackedStringArray) -> PackedStringArray:
	var titles := PackedStringArray()
	for slot in slots:
		if ids.has(str(slot.get("id", ""))):
			titles.append(str(slot.get("title", slot.get("id", ""))))
	return titles


func _on_buy_pressed() -> void:
	buy_requested.emit(_item_id)


func _on_equip_pressed(slot_id: String) -> void:
	equip_requested.emit(_item_id, slot_id)


func _on_unequip_pressed(slot_id: String) -> void:
	unequip_requested.emit(slot_id)


func _scale_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", roundi(28 * _ui_scale))
	button.custom_minimum_size.y = 60 * _ui_scale


func _scale_style(box: StyleBoxFlat) -> void:
	box.set_corner_radius_all(roundi(14 * _ui_scale))
	box.set_content_margin_all(16 * _ui_scale)
	box.set_border_width_all(roundi(2 * _ui_scale))


## Worn items get an accent border, so the grid answers "what am I wearing?"
## at a glance rather than only in the status line.
func _card_style(equipped := false, accent: Color = PLATE_COLOR) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0784314, 0.121569, 0.145098, 0.92)
	_scale_style(box)
	box.border_color = accent if equipped else Color(0.290196, 0.352941, 0.4, 0.55)
	return box
