extends MenuScreen

@onready var _margins: MarginContainer = %Margins
@onready var _mode_label: Label = %ModeLabel
@onready var _card: PanelContainer = %Card
@onready var _summary: Label = %Summary
@onready var _demo_prompt: Label = %DemoPrompt
@onready var _demo_one: PanelContainer = %DemoOne
@onready var _demo_two: PanelContainer = %DemoTwo
@onready var _demo_three: PanelContainer = %DemoThree
@onready var _demo_one_label: Label = %DemoOneLabel
@onready var _demo_two_label: Label = %DemoTwoLabel
@onready var _demo_three_label: Label = %DemoThreeLabel
@onready var _rule: ColorRect = %Rule
@onready var _control_grid: GridContainer = %ControlGrid
@onready var _player_one_controls: Label = %PlayerOneControls
@onready var _opponent_card: PanelContainer = %OpponentCard
@onready var _opponent_title: Label = %OpponentTitle
@onready var _opponent_controls: Label = %OpponentControls
@onready var _actions: HBoxContainer = %Actions
@onready var _show_again: CheckButton = %ShowAgainToggle
@onready var _start_button: Button = %StartButton

var _multiplayer := false
var _demo_targets: Array[PanelContainer] = []
var _entrance_tween: Tween
var _demo_cycle_tween: Tween
var _rule_tween: Tween
var _reduced_motion := false


func _ready() -> void:
	_reduced_motion = Settings.reduced_motion_enabled()
	first_focus = _start_button
	margins = _margins
	_multiplayer = GameSession.player_two_enabled()
	_demo_targets = [_demo_one, _demo_two, _demo_three]
	_populate_instructions()
	_show_again.button_pressed = bool(Settings.get_value("game/show_instructions", true))
	_show_again.toggled.connect(_on_show_again_toggled)
	for target in _demo_targets:
		target.resized.connect(_center_pivot.bind(target))
	_play_entrance.call_deferred()
	_start_demo_loop.call_deferred()
	super()


func _on_layout_changed(size: Vector2) -> void:
	_control_grid.columns = 1 if not _multiplayer or Responsive.is_portrait(size) else 2


func _populate_instructions() -> void:
	if GameSession.is_slice_and_slash():
		_populate_slice_and_slash_instructions()
		return

	_mode_label.text = GameSession.mode_title().to_upper()
	var player_one_actions := Settings.control_actions_for_player(0)
	var demo_labels := [_demo_one_label, _demo_two_label, _demo_three_label]
	for index in range(mini(player_one_actions.size(), demo_labels.size())):
		_set_demo_binding(demo_labels[index], player_one_actions[index])
	_player_one_controls.text = _target_rush_controls(0, 1)
	if GameSession.is_single_player():
		_summary.text = (
			"Only Player 1 is active. Score as many correct hits as possible "
			+ "before the timer reaches zero."
		)
		_demo_prompt.text = "WATCH PLAYER 1'S HIGHLIGHTED TARGET"
		_opponent_card.hide()
	elif GameSession.player_two_is_cpu():
		_summary.text = (
			(
				"Race the %s CPU for the highest score. You control P1 targets; "
				% GameSession.cpu_difficulty_title().to_lower()
			)
			+ "the CPU controls P2 targets."
		)
		_demo_prompt.text = "PLAYER 1 FOLLOWS THE HIGHLIGHT"
		_opponent_title.text = "CPU OPPONENT"
		_opponent_controls.text = (
			(
				"%s · %s\n" % [
					GameSession.cpu_difficulty_title(),
					GameSession.cpu_preset_title(),
				]
			)
			+ "The CPU plays automatically.\n"
			+ "Follow Player 1's highlighted target and beat the CPU's score."
		)
	else:
		_summary.text = (
			"Both players act at the same time. Each player must follow their "
			+ "own highlighted target."
		)
		_demo_prompt.text = "EACH PLAYER FOLLOWS THEIR OWN HIGHLIGHT"
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = _target_rush_controls(1, 2)


func _populate_slice_and_slash_instructions() -> void:
	_mode_label.text = "%s · %s" % [
		GameInfo.DESK_CAN_SAW_TITLE.to_upper(),
		GameSession.mode_title().to_upper(),
	]
	_set_demo_text(_demo_one_label, "MOVE")
	_set_demo_text(_demo_two_label, "REV")
	_set_demo_text(_demo_three_label, "+1")
	_demo_prompt.text = "DRIVE THE ELECTRIC CHAIN THROUGH A CAN"
	if GameSession.is_single_player():
		_summary.text = (
			"Move Player 1's electric chainsaw over the workshop desk. Each can "
			+ "erupts in sparks and scores exactly once."
		)
		_player_one_controls.text = (
			"Mouse or arrow keys\nController 1: %s"
			% Settings.controller_movement_scheme_label()
		)
		_opponent_card.hide()
	else:
		_summary.text = (
			"Both players work the same can-covered desk. The first electric "
			+ "chainsaw to tear through a can earns its point."
		)
		_player_one_controls.text = (
			"Player 1: mouse\nController 1: %s"
			% Settings.controller_movement_scheme_label()
		)
		_opponent_title.text = "PLAYER 2"
		_opponent_controls.text = (
			"Player 2: arrow keys\nController 2: %s"
			% Settings.controller_movement_scheme_label()
		)


func _target_rush_controls(player_index: int, controller_number: int) -> String:
	var keyboard_summary := Settings.control_summary(player_index)
	var controller_summary := (
		"any mapped button (%s)" % Settings.controller_target_summary(", ")
		if Settings.one_button_target_rush_enabled()
		else Settings.controller_target_summary(", ")
	)
	var triangle_summary := "P%d triangles" % (player_index + 1)
	return "Keyboard: %s\nController %d: %s\nMouse/touch: select %s" % [
		keyboard_summary,
		controller_number,
		controller_summary,
		triangle_summary,
	]


func _set_demo_binding(label: Label, action: StringName) -> void:
	label.text = Settings.control_key_label(action)
	_size_demo_label(label)


func _set_demo_text(label: Label, text: String) -> void:
	label.text = text
	_size_demo_label(label)


func _size_demo_label(label: Label) -> void:
	label.add_theme_font_size_override(
		"font_size",
		28 if label.text.length() <= 2 else 21 if label.text.length() <= 5 else 16
	)


func _play_entrance() -> void:
	_center_pivot(_card)
	if _reduced_motion:
		_mode_label.modulate.a = 1.0
		_card.modulate.a = 1.0
		_card.scale = Vector2.ONE
		_actions.modulate.a = 1.0
		_rule.modulate.a = 1.0
		return
	_mode_label.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.965, 0.965)
	_actions.modulate.a = 0.0

	_entrance_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(_mode_label, "modulate:a", 1.0, 0.18)
	_entrance_tween.tween_property(_card, "modulate:a", 1.0, 0.26)
	_entrance_tween.parallel().tween_property(_card, "scale", Vector2.ONE, 0.38)
	_entrance_tween.tween_property(_actions, "modulate:a", 1.0, 0.2)

	_rule.modulate.a = 0.45
	_rule_tween = create_tween().set_loops()
	_rule_tween.tween_property(_rule, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	_rule_tween.tween_property(_rule, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)


func _start_demo_loop() -> void:
	for target in _demo_targets:
		_center_pivot(target)
	_highlight_demo_target(0)
	if _reduced_motion:
		return
	_demo_cycle_tween = create_tween().set_loops()
	for index in range(_demo_targets.size()):
		_demo_cycle_tween.tween_callback(_highlight_demo_target.bind(index))
		_demo_cycle_tween.tween_interval(0.72)


func _highlight_demo_target(active_index: int) -> void:
	for index in range(_demo_targets.size()):
		var target := _demo_targets[index]
		var active := index == active_index
		var target_scale := Vector2(1.14, 1.14) if active else Vector2.ONE
		var target_tint := (
			Color(1.12, 1.18, 1.22, 1.0)
			if active
			else Color(0.68, 0.74, 0.78, 1.0)
		)
		if _reduced_motion:
			target.scale = Vector2.ONE
			target.self_modulate = target_tint
			continue
		var tween := target.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(target, "scale", target_scale, 0.24)
		tween.tween_property(target, "self_modulate", target_tint, 0.2)


func _center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5


func _on_show_again_toggled(pressed: bool) -> void:
	Settings.set_value("game/show_instructions", pressed)


func _on_start_pressed() -> void:
	Router.goto(GameSession.gameplay_scene_path())


func _on_back_pressed() -> void:
	go_back()
