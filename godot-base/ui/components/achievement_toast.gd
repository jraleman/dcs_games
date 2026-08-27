class_name AchievementToast
extends PanelContainer

signal dismissed

@export_range(1.0, 10.0, 0.1) var hold_time := 3.2

@onready var _badge: Label = %Badge
@onready var _title: Label = %Title
@onready var _description: Label = %Description

var _tween: Tween
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func present(achievement: Dictionary) -> void:
	_badge.text = str(achievement.get("badge", "NEW"))
	_title.text = str(achievement.get("title", "Achievement"))
	_description.text = str(achievement.get("description", "A new achievement was unlocked."))
	_play_animation.call_deferred()


func _play_animation() -> void:
	if _finished:
		return
	pivot_offset = size * 0.5
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	scale = Vector2.ONE * 0.84

	AudioManager.play_achievement()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.28)
	_tween.tween_interval(hold_time)
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, 0.24)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.95, 0.24)
	_tween.tween_callback(_finish)


func dismiss() -> void:
	if _finished:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	dismissed.emit()
