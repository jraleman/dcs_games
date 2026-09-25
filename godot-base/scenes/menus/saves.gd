extends MenuScreen

## The save manager: back up, restore or delete each game's progress on this
## device.
##
## Which games it lists is [method GameSaves.managed_games]'s answer, so a
## collection shows every game with something saved and a standalone build only
## its own; the screen never asks which kind of build it is in. Every change
## goes through [GameSaves]. The screen owns the wording, and asks before
## anything is deleted or overwritten — a backup is the only action that cannot
## lose progress, so it is the only one that does not ask.

## Widest the list grows before it starts adding air instead, so an ultrawide
## gets a readable column rather than a sentence per line of screen.
const MAX_CONTENT_WIDTH := 880.0
## Narrowest column, in layout units, that keeps a backup's buttons beside its
## date; below it they move underneath.
const ROW_STACK_WIDTH := 640.0
const MAX_DIALOG_WIDTH := 620.0
const TITLE_COLOR := Color(0.94902, 0.968627, 0.976471, 1.0)
const DETAIL_COLOR := Color(0.686275, 0.752941, 0.788235, 1.0)
const DONE_COLOR := Color(0.686275, 0.866667, 0.917647, 1.0)
const PROBLEM_COLOR := Color(0.94902, 0.678431, 0.584314, 1.0)
## A canvas stretched onto a small screen gets two thirds of its shrink back
## through `_ui_scale`, so 72 layout units never come out under 48 physical
## pixels — clear of the 44px touch-target floor.
const BUTTON_HEIGHT := 72.0
const BUTTON_FONT_SIZE := 24
## Font sizes of the generated card labels, in layout units, by node name.
const CARD_FONT_SIZES := {
	"Title": 30, "Details": 22, "BackupsHeading": 18, "Date": 22, "Problem": 20,
}

@onready var _margins: MarginContainer = %Margins
@onready var _header: BoxContainer = %Header
@onready var _header_actions: HBoxContainer = %HeaderActions
@onready var _title: Label = %Title
@onready var _intro: Label = %Intro
@onready var _status: Label = %Status
@onready var _empty: Label = %Empty
@onready var _scroll: ScrollContainer = %Scroll
@onready var _cards: VBoxContainer = %Cards
@onready var _folder_button: Button = %FolderButton
@onready var _back_button: Button = %BackButton
@onready var _confirm: Control = %Confirm
@onready var _confirm_panel: PanelContainer = %ConfirmPanel
@onready var _confirm_title: Label = %ConfirmTitle
@onready var _confirm_message: Label = %ConfirmMessage
@onready var _confirm_actions: BoxContainer = %ConfirmActions
@onready var _cancel_button: Button = %CancelButton
@onready var _confirm_button: Button = %ConfirmButton

var _games: Array[GameManifest] = []
var _pending := Callable()
## Where focus was when a question was asked: `{ card, path }`, relative to
## the card, so it can be found again in the rebuilt list.
var _asked_from: Dictionary = {}
var _ui_scale := 1.0
var _panel_style: StyleBox
var _dialog_style: StyleBox


func _ready() -> void:
	margins = _margins
	# Web and mobile builds have no file manager to show the folder in.
	_folder_button.visible = not (OS.has_feature("web") or OS.has_feature("mobile"))
	_folder_button.tooltip_text = "Show %s in your file manager." % _save_folder()
	_folder_button.accessibility_description = _folder_button.tooltip_text
	_status.accessibility_live = AccessibilityServer.LIVE_POLITE
	_intro.text = _intro_copy()
	_trap_dialog_focus()
	_build_cards()
	first_focus = _first_focusable_control()
	super()


## A question takes Back and Escape for itself: backing out of it must never
## also leave the screen underneath.
func go_back() -> void:
	if _confirm.visible:
		AudioManager.play_back()
		_close_confirm(true)
		return
	super()


func _intro_copy() -> String:
	var games := GameCatalog.available()
	if games.size() == 1:
		return (
			"Back up, restore or delete your %s progress on this device. "
			% games[0].title
			+ "Options and key bindings are not affected."
		)
	return (
		"Back up, restore or delete each game's progress on this device. "
		+ "Options and key bindings are not affected."
	)


func _save_folder() -> String:
	return ProjectSettings.globalize_path("user://")


# --------------------------------------------------------------------------
# Cards
# --------------------------------------------------------------------------


func _build_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_games = GameSaves.managed_games()
	_empty.visible = _games.is_empty()
	_scroll.visible = not _games.is_empty()
	for manifest in _games:
		var card := _build_card(manifest)
		_cards.add_child(card)
		# Cards rebuilt after an action missed the screen's one skinning pass.
		GameCatalog.theme().restyle_tree(card, true)


func _build_card(manifest: GameManifest) -> PanelContainer:
	var summary := GameSaves.summary(manifest)
	var has_save := bool(summary["has_save"])
	var card := PanelContainer.new()
	card.name = "Card_%s" % manifest.id
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	card.add_child(layout)

	var title := _label("Title", manifest.title, TITLE_COLOR)
	title.theme_type_variation = &"MenuHeading"
	layout.add_child(title)

	var lines := _summary_lines(summary)
	if not has_save:
		lines = PackedStringArray(["No saved progress right now."])
	var details := _label("Details", "\n".join(lines), DETAIL_COLOR)
	var notes := PackedStringArray()
	for entry: Dictionary in summary["files"]:
		if not str(entry["description"]).is_empty():
			notes.append("%s: %s" % [entry["title"], entry["description"]])
	if not notes.is_empty():
		details.tooltip_text = "\n".join(notes)
		details.accessibility_description = details.tooltip_text
		details.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_child(details)

	if has_save:
		var actions := BoxContainer.new()
		actions.name = "Actions"
		layout.add_child(actions)
		var back_up := _button(
			"BackUpButton", "Back up",
			"Save a copy of this %s progress that you can restore later." % manifest.title
		)
		back_up.pressed.connect(_on_back_up_pressed.bind(manifest.id))
		actions.add_child(back_up)
		var delete := _button(
			"DeleteSaveButton", "Delete save",
			"Delete the %s progress on this device. Backups are kept." % manifest.title
		)
		delete.pressed.connect(_on_delete_save_pressed.bind(manifest.id))
		actions.add_child(delete)

	var backups := GameSaves.backups(manifest.id)
	if not backups.is_empty():
		var heading := _label("BackupsHeading", "BACKUPS", GameCatalog.theme().accent)
		heading.theme_type_variation = &"MenuSectionHeading"
		layout.add_child(heading)
		var list := VBoxContainer.new()
		list.name = "Backups"
		layout.add_child(list)
		for backup in backups:
			list.add_child(_build_backup_row(manifest, backup))
	return card


func _build_backup_row(manifest: GameManifest, backup: Dictionary) -> BoxContainer:
	var path := str(backup["path"])
	var date := GameSaves.backup_date_text(backup)
	var row := BoxContainer.new()
	row.name = "Backup_%s" % path.get_file().get_basename().validate_node_name()
	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	info.add_child(_label("Date", date, TITLE_COLOR))
	var problem := str(backup.get("problem", ""))
	if not problem.is_empty():
		info.add_child(_label("Problem", problem, PROBLEM_COLOR))

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	row.add_child(buttons)
	var restore := _button(
		"RestoreButton", "Restore",
		problem if not problem.is_empty()
		else "Put the %s progress back to how it was on %s." % [manifest.title, date]
	)
	restore.accessibility_name = "Restore backup from %s" % date
	restore.disabled = not bool(backup.get("restorable", false))
	restore.pressed.connect(_on_restore_pressed.bind(manifest.id, path, date))
	buttons.add_child(restore)
	var delete := _button(
		"DeleteBackupButton", "Delete", "Delete this backup. Your current save is kept."
	)
	delete.accessibility_name = "Delete backup from %s" % date
	delete.pressed.connect(_on_delete_backup_pressed.bind(manifest.id, path, date))
	buttons.add_child(delete)
	return row


## One line per part of the save, in the words the card and the delete question
## share, so the question lists exactly what the card showed.
func _summary_lines(summary: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var total := int(summary.get("achievements_total", 0))
	if total > 0:
		lines.append(
			"Achievements: %d of %d" % [int(summary.get("achievements_unlocked", 0)), total]
		)
	var store: Dictionary = summary.get("store", {})
	if not store.is_empty():
		var line := "Store: %s" % str(store.get("points_text", ""))
		var items_total := int(store.get("items_total", 0))
		if items_total > 0:
			line += " · %d of %d items bought" % [int(store.get("items_bought", 0)), items_total]
		lines.append(line)
	var titles := PackedStringArray()
	for entry: Dictionary in summary.get("files", []):
		titles.append(str(entry.get("title", "")))
	if not titles.is_empty():
		lines.append("Also saved: %s" % ", ".join(titles))
	return lines


func _label(node_name: String, text: String, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	return label


func _button(node_name: String, text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.tooltip_text = tooltip
	button.accessibility_description = tooltip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------


func _on_layout_changed(viewport: Vector2) -> void:
	# A stretched 1920-wide canvas is still wide on a phone. Size the actual
	# fonts and controls, as the other menus do; scaling a container blurs type.
	var preference := float(Settings.get_value("ui/scale", 1.0))
	_ui_scale = maxf(1.0, viewport.x * preference / maxf(get_window().size.x, 1.0) / 1.5)
	var units := _ui_scale
	var layout_size := viewport / units
	var compact := layout_size.x < 1000.0
	var layout := _header.get_parent() as VBoxContainer
	layout.add_theme_constant_override("separation", roundi(16 * units))
	_header.vertical = compact
	_header.add_theme_constant_override("separation", roundi(16 * units))
	_header_actions.add_theme_constant_override("separation", roundi(16 * units))
	_header_actions.alignment = (
		BoxContainer.ALIGNMENT_BEGIN if compact else BoxContainer.ALIGNMENT_END
	)
	var title_size := clampf(minf(layout_size.x, layout_size.y) * 0.055, 32.0, 56.0)
	_title.add_theme_font_size_override("font_size", roundi(title_size * units))
	_intro.add_theme_font_size_override("font_size", roundi((20 if compact else 24) * units))
	_status.add_theme_font_size_override("font_size", roundi(22 * units))
	_empty.add_theme_font_size_override("font_size", roundi(24 * units))
	for button: Button in [_folder_button, _back_button]:
		_scale_button(button)

	var horizontal := float(
		_margins.get_theme_constant("margin_left") + _margins.get_theme_constant("margin_right")
	)
	var width := minf(maxf(viewport.x - horizontal, 0.0), MAX_CONTENT_WIDTH * units)
	_cards.custom_minimum_size.x = width
	_cards.add_theme_constant_override("separation", roundi(22 * units))
	var stacked := width / units < ROW_STACK_WIDTH
	for card in _cards.get_children():
		_scale_card(card as PanelContainer, stacked)
	_scale_dialog(viewport.x - horizontal, stacked)


func _scale_card(card: PanelContainer, stacked: bool) -> void:
	if card == null:
		return
	if _panel_style == null:
		_panel_style = get_theme_stylebox("panel", &"PanelContainer")
	card.add_theme_stylebox_override("panel", _scaled_style(_panel_style))
	var layout := card.get_node("Layout") as VBoxContainer
	layout.add_theme_constant_override("separation", roundi(12 * _ui_scale))
	for label: Label in card.find_children("*", "Label", true, false):
		label.add_theme_font_size_override(
			"font_size", roundi(int(CARD_FONT_SIZES.get(String(label.name), 22)) * _ui_scale)
		)
	var actions := layout.get_node_or_null("Actions") as BoxContainer
	if actions != null:
		actions.vertical = stacked
		actions.add_theme_constant_override("separation", roundi(12 * _ui_scale))
	var list := layout.get_node_or_null("Backups") as VBoxContainer
	if list != null:
		list.add_theme_constant_override("separation", roundi(14 * _ui_scale))
		for row in list.get_children():
			var box := row as BoxContainer
			box.vertical = stacked
			box.add_theme_constant_override("separation", roundi(8 * _ui_scale))
			(box.get_node("Buttons") as HBoxContainer).add_theme_constant_override(
				"separation", roundi(12 * _ui_scale)
			)
	for button: Button in card.find_children("*", "Button", true, false):
		_scale_button(button)


## [param available] is the width inside the screen's margins, which the
## question keeps too, so it never touches the edge of a phone.
func _scale_dialog(available: float, stacked: bool) -> void:
	if _dialog_style == null:
		_dialog_style = _confirm_panel.get_theme_stylebox("panel")
	_confirm_panel.add_theme_stylebox_override("panel", _scaled_style(_dialog_style))
	_confirm_panel.custom_minimum_size.x = minf(
		maxf(available, 0.0), MAX_DIALOG_WIDTH * _ui_scale
	)
	(_confirm_title.get_parent() as VBoxContainer).add_theme_constant_override(
		"separation", roundi(18 * _ui_scale)
	)
	_confirm_title.add_theme_font_size_override("font_size", roundi(34 * _ui_scale))
	_confirm_message.add_theme_font_size_override("font_size", roundi(22 * _ui_scale))
	_confirm_actions.vertical = stacked
	_confirm_actions.add_theme_constant_override("separation", roundi(16 * _ui_scale))
	for button: Button in [_cancel_button, _confirm_button]:
		_scale_button(button)


func _scale_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", roundi(BUTTON_FONT_SIZE * _ui_scale))
	button.custom_minimum_size.y = BUTTON_HEIGHT * _ui_scale


## Theme padding is authored for the canvas; a phone that scales the type up
## needs the padding to follow, or the words touch the card's edge.
func _scaled_style(original: StyleBox) -> StyleBox:
	var scaled := original.duplicate() as StyleBox
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		scaled.set_content_margin(side, original.get_content_margin(side) * _ui_scale)
	return scaled


# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------


func _on_back_up_pressed(game_id: String) -> void:
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null or _closing:
		return
	var from := _focus_memory(get_viewport().gui_get_focus_owner())
	if GameSaves.back_up(manifest).is_empty():
		_show_status("The %s progress could not be backed up." % manifest.title, true)
	else:
		_show_status("Backed up the %s progress." % manifest.title)
	_rebuild(from)


func _on_delete_save_pressed(game_id: String) -> void:
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null or _closing:
		return
	var message := "This deletes the %s progress on this device." % manifest.title
	var lines := _summary_lines(GameSaves.summary(manifest))
	if not lines.is_empty():
		message += "\n• " + "\n• ".join(lines)
	message += (
		"\n\nBackups are kept. Options and key bindings are not affected. "
		+ "This cannot be undone."
	)
	_ask(
		"Delete the %s save?" % manifest.title, message, "Delete save",
		_delete_save.bind(game_id)
	)


func _on_restore_pressed(game_id: String, path: String, date: String) -> void:
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null or _closing:
		return
	_ask(
		"Restore this backup?",
		(
			"%s will go back to how it was on %s. Progress made since then will be "
			% [manifest.title, date]
			+ "lost unless you back it up first."
		),
		"Restore",
		_restore.bind(game_id, path, date)
	)


func _on_delete_backup_pressed(game_id: String, path: String, date: String) -> void:
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null or _closing:
		return
	_ask(
		"Delete this backup?",
		(
			"The %s backup from %s will be deleted. Your current save is not affected. "
			% [manifest.title, date]
			+ "This cannot be undone."
		),
		"Delete backup",
		_delete_backup.bind(game_id, path, date)
	)


func _delete_save(game_id: String) -> void:
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null:
		return
	if GameSaves.erase(manifest) != OK:
		_show_status("Some of the %s save could not be deleted." % manifest.title, true)
	elif GameSaves.has_backups(game_id):
		_show_status("Deleted the %s save. Its backups are kept." % manifest.title)
	else:
		_show_status("Deleted the %s save." % manifest.title)
	_rebuild(_asked_from)


func _restore(game_id: String, path: String, date: String) -> void:
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null:
		return
	if GameSaves.restore(manifest, path) != OK:
		_show_status("The %s backup could not be fully restored." % manifest.title, true)
	else:
		_show_status("Restored the %s progress from %s." % [manifest.title, date])
	_rebuild(_asked_from)


func _delete_backup(game_id: String, path: String, date: String) -> void:
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null:
		return
	if GameSaves.delete_backup(manifest, path) != OK:
		_show_status("The %s backup could not be deleted." % manifest.title, true)
	else:
		_show_status("Deleted the %s backup from %s." % [manifest.title, date])
	_rebuild(_asked_from)


## The words stay on screen and are announced, because a save that silently
## changed — or silently failed to — is the one thing this screen must not do.
func _show_status(text: String, failed := false) -> void:
	_status.text = text
	_status.visible = true
	_status.add_theme_color_override("font_color", PROBLEM_COLOR if failed else DONE_COLOR)
	if failed:
		AudioManager.play_game_miss()


func _on_folder_pressed() -> void:
	var err := OS.shell_show_in_file_manager(_save_folder())
	if err != OK:
		_show_status("The save folder could not be opened. It is %s." % _save_folder(), true)


func _on_back_pressed() -> void:
	go_back()


# --------------------------------------------------------------------------
# Questions
# --------------------------------------------------------------------------


func _ask(title: String, message: String, confirm_text: String, action: Callable) -> void:
	_asked_from = _focus_memory(get_viewport().gui_get_focus_owner())
	_pending = action
	_confirm_title.text = title
	_confirm_message.text = message
	_confirm_button.text = confirm_text
	_confirm_panel.accessibility_name = title
	_confirm_panel.accessibility_description = message
	_confirm.visible = true
	# The safe answer is the default one, so a second press of Enter cancels.
	_cancel_button.grab_focus()


func _close_confirm(restore_focus := false) -> void:
	_confirm.visible = false
	_pending = Callable()
	if restore_focus:
		_focus(_focus_target(_asked_from))


func _on_cancel_pressed() -> void:
	AudioManager.play_back()
	_close_confirm(true)


func _on_confirm_pressed() -> void:
	var action := _pending
	if not action.is_valid() or _closing:
		_close_confirm(true)
		return
	_close_confirm()
	action.call()


## Two buttons, each the other's every neighbour, so a keyboard or pad can never
## wander from a question into the list behind it.
func _trap_dialog_focus() -> void:
	var buttons: Array[Button] = [_cancel_button, _confirm_button]
	for index in buttons.size():
		var button := buttons[index]
		var path := button.get_path_to(buttons[1 - index])
		button.focus_neighbor_left = path
		button.focus_neighbor_right = path
		button.focus_neighbor_top = path
		button.focus_neighbor_bottom = path
		button.focus_next = path
		button.focus_previous = path


# --------------------------------------------------------------------------
# Focus
# --------------------------------------------------------------------------


## Rebuilds every card — a backup adds a row, a delete can remove a whole card —
## and puts focus back where the player was, or as near to it as still exists.
func _rebuild(from: Dictionary) -> void:
	_build_cards()
	refresh_layout()
	first_focus = _first_focusable_control()
	_focus(_focus_target(from))
	# Rebuilt buttons never saw the screen's one-time sound pass; attaching after
	# the focus move keeps that move silent.
	_attach_sounds.call_deferred()


func _focus_memory(control: Control) -> Dictionary:
	var node: Node = control
	while node != null and node != _cards:
		var parent := node.get_parent()
		if parent == _cards:
			return {"card": String(node.name), "path": node.get_path_to(control)}
		node = parent
	return {}


func _focus_target(from: Dictionary) -> Control:
	var card := _cards.get_node_or_null(NodePath(str(from.get("card", "")))) as Control
	if card != null:
		var path: NodePath = from.get("path", NodePath())
		var same := card.get_node_or_null(path) as Control
		if _focusable(same):
			return same
		for button: Button in card.find_children("*", "Button", true, false):
			if _focusable(button):
				return button
	return _first_focusable_control()


func _first_focusable_control() -> Control:
	for button: Button in _cards.find_children("*", "Button", true, false):
		if _focusable(button):
			return button
	return _back_button


func _focusable(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	var button := control as BaseButton
	return control.focus_mode != Control.FOCUS_NONE and (button == null or not button.disabled)


func _focus(control: Control) -> void:
	if control != null and control.is_inside_tree():
		control.grab_focus()
