extends ScrollContainer

## Keeps shared round dialogs readable and scrollable without changing their
## scene paths. Games that already arrange their own results keep that layout.

@export var content: Control

var _queued := false
var _prepared := false
var _panels: Array[PanelContainer] = []
var _rows: Array[BoxContainer] = []
var _font_sizes: Dictionary[Control, int] = {}
var _styles: Dictionary[PanelContainer, StyleBox] = {}


func _ready() -> void:
	if content == null:
		push_error("Round overlay requires a content control.")
		return
	get_viewport().size_changed.connect(_queue_layout)
	visibility_changed.connect(_queue_layout)
	child_order_changed.connect(_queue_layout)
	child_entered_tree.connect(_on_overlay_child_entered)
	var settings := get_tree().root.get_node("Settings")
	settings.changed.connect(_on_setting_changed)
	_queue_layout()


func _on_overlay_child_entered(child: Node) -> void:
	# Game-owned overlays used to have a plain Control parent. Keep their
	# explicit geometry out of the shared scroll's container sorting.
	if child is Control and child != content and not child is ScrollBar:
		(child as Control).set_as_top_level(true)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "ui/scale":
		_queue_layout()


func _queue_layout() -> void:
	if _queued or not is_inside_tree():
		return
	_queued = true
	_layout.call_deferred()


func _prepare() -> void:
	_prepared = true
	content.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if content is PanelContainer:
		_panels.append(content as PanelContainer)
		content.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
		content.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	else:
		for child in content.get_children():
			if child is PanelContainer:
				_panels.append(child as PanelContainer)
	for panel in _panels:
		panel.visibility_changed.connect(_queue_layout)
		for path in [
			"Layout/ScoreShowdown", "Layout/Report", "Layout/Report/Players",
			"Layout/Overview", "Layout/Actions/UtilityActions",
		]:
			var row := panel.get_node_or_null(path) as BoxContainer
			if row == null:
				continue
			var flexible := BoxContainer.new()
			flexible.name = row.name
			flexible.alignment = row.alignment
			flexible.size_flags_horizontal = row.size_flags_horizontal
			flexible.add_theme_constant_override("separation", 8)
			row.replace_by(flexible)
			row.free()
			_rows.append(flexible)
		_remember(panel)


func _remember(node: Control) -> void:
	node.custom_minimum_size.x = 0.0
	if node is Label:
		var original := node.get_theme_font_size("font_size")
		_font_sizes[node] = 32 if original >= 40 else 22 if original >= 27 else 14
		(node as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if node.get_parent() is GridContainer:
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif node is Button:
		_font_sizes[node] = 17
		(node as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif node is PanelContainer:
		var panel := node as PanelContainer
		_styles[panel] = panel.get_theme_stylebox("panel").duplicate() as StyleBox
	for child in node.get_children():
		if child is Control:
			_remember(child as Control)


func _layout() -> void:
	_queued = false
	if not is_inside_tree() or content == null:
		return
	if content.get_parent() != self or not content.visible:
		# A game-owned scroll is positioned by that game, not this container.
		vertical_scroll_mode = SCROLL_MODE_DISABLED
		for child in get_children():
			_on_overlay_child_entered(child)
		return
	if not _prepared:
		_prepare()
	var screen := get_viewport_rect().size
	var settings := get_tree().root.get_node("Settings")
	var unit := screen.x / maxf(get_window().size.x, 1.0) \
		* float(settings.call("get_value", "ui/scale", 1.0))
	var width := screen.x - 32.0 * unit
	for control: Control in _font_sizes.keys():
		if not is_instance_valid(control):
			_font_sizes.erase(control)
			continue
		control.add_theme_font_size_override("font_size", roundi(_font_sizes[control] * unit))
		if control is Button:
			control.custom_minimum_size.y = 44.0 * unit
			control.add_theme_constant_override("icon_max_width", roundi(18.0 * unit))
	for panel: PanelContainer in _styles.keys():
		if not is_instance_valid(panel):
			_styles.erase(panel)
			continue
		var style := _styles[panel].duplicate() as StyleBox
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side,
				minf(_styles[panel].get_content_margin(side), 20.0) * unit)
		panel.add_theme_stylebox_override("panel", style)
	for panel in _panels:
		var preferred := float(panel.get_meta("overlay_width", 560.0)) * unit
		panel.custom_minimum_size.x = minf(width, preferred)
		panel.size.x = panel.custom_minimum_size.x
		var actions := panel.get_node_or_null("Layout/Actions") as Control
		if actions != null:
			actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row in _rows:
		row.vertical = row.name != "Overview" \
			and screen.x / unit < (780.0 if row.name == "Report" else 520.0)
		row.add_theme_constant_override("separation", roundi(8.0 * unit))
		for child in row.get_children():
			if child is Control:
				(child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if content is CenterContainer:
		content.custom_minimum_size.y = screen.y
	else:
		content.size.y = content.get_combined_minimum_size().y
	var dim := get_node_or_null("Dim") as Control
	if dim != null:
		dim.size = screen
