extends Node

## Persistent achievement registry with a global, queued toast overlay.
## Definitions live in GameInfo so another game can replace the list without
## changing this manager.

signal unlocked(id: String, achievement: Dictionary)

const SAVE_PATH := "user://achievements.cfg"
const TOAST_LAYER := 120
const TOAST_SCENE: PackedScene = preload("res://ui/components/achievement_toast.tscn")

var _definitions: Dictionary = {}
var _unlocked: Dictionary = {}
var _toast_queue: Array[Dictionary] = []
var _toast_layer: CanvasLayer
var _toast_host: Control
var _current_toast: AchievementToast


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	register_achievements(GameInfo.ACHIEVEMENTS)
	_load_unlocked()
	_build_toast_overlay()


func register_achievements(definitions: Dictionary) -> void:
	for raw_id: Variant in definitions:
		var id := str(raw_id)
		var raw_definition: Variant = definitions[raw_id]
		if typeof(raw_definition) != TYPE_DICTIONARY:
			push_warning("Achievement '%s' must be a Dictionary." % id)
			continue
		var definition: Dictionary = raw_definition
		if str(definition.get("title", "")).is_empty():
			push_warning("Achievement '%s' needs a title." % id)
			continue
		var normalized := definition.duplicate(true)
		normalized["id"] = id
		_definitions[id] = normalized


func unlock(id: String) -> bool:
	if not _definitions.has(id):
		push_warning("Unknown achievement '%s'." % id)
		return false
	if _unlocked.has(id):
		return false

	_unlocked[id] = Time.get_datetime_string_from_system()
	_save_unlocked()
	var achievement := get_achievement(id)
	unlocked.emit(id, achievement)
	_toast_queue.append(achievement)
	_show_next_toast.call_deferred()
	return true


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func get_achievement(id: String) -> Dictionary:
	if not _definitions.has(id):
		return {}
	var definition: Dictionary = _definitions[id]
	var result := definition.duplicate(true)
	result["unlocked"] = _unlocked.has(id)
	result["unlocked_at"] = str(_unlocked.get(id, ""))
	return result


func get_unlocked_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_id: Variant in _definitions:
		var id := str(raw_id)
		if _unlocked.has(id):
			result.append(get_achievement(id))
	return result


func unlocked_count() -> int:
	return _unlocked.size()


func _build_toast_overlay() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = TOAST_LAYER
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_layer)

	_toast_host = Control.new()
	_toast_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_layer.add_child(_toast_host)
	get_viewport().size_changed.connect(_position_current_toast)


func _show_next_toast() -> void:
	if is_instance_valid(_current_toast) or _toast_queue.is_empty():
		return

	var achievement: Dictionary = _toast_queue.pop_front()
	_current_toast = TOAST_SCENE.instantiate() as AchievementToast
	if _current_toast == null:
		push_error("Achievement toast scene has an invalid root.")
		return
	_toast_host.add_child(_current_toast)
	_current_toast.dismissed.connect(_on_toast_dismissed)
	_position_current_toast()
	_current_toast.present(achievement)


func _position_current_toast() -> void:
	if not is_instance_valid(_current_toast):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := clampf(minf(viewport_size.x, viewport_size.y) * 0.035, 24.0, 48.0)
	var width := clampf(viewport_size.x - margin * 2.0, 320.0, 540.0)
	_current_toast.anchor_left = 1.0
	_current_toast.anchor_top = 0.0
	_current_toast.anchor_right = 1.0
	_current_toast.anchor_bottom = 0.0
	_current_toast.offset_left = -margin - width
	_current_toast.offset_top = margin
	_current_toast.offset_right = -margin
	_current_toast.offset_bottom = margin + 148.0


func _on_toast_dismissed() -> void:
	if is_instance_valid(_current_toast):
		_current_toast.queue_free()
	_current_toast = null
	_show_next_toast.call_deferred()


func _load_unlocked() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for raw_id: Variant in _definitions:
		var id := str(raw_id)
		if config.has_section_key("unlocked", id):
			_unlocked[id] = str(config.get_value("unlocked", id))


func _save_unlocked() -> void:
	var config := ConfigFile.new()
	for raw_id: Variant in _unlocked:
		var id := str(raw_id)
		config.set_value("unlocked", id, _unlocked[raw_id])
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save achievements to %s (error %d)." % [SAVE_PATH, err])
