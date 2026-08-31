extends ColorRect

## Feeds the current aspect ratio to menu_background.gdshader so the glows
## stay round instead of stretching on wide or tall screens.

const REDUCED_MOTION_SETTING := "accessibility/reduced_motion"

var _motion_speed := 0.0


func _ready() -> void:
	resized.connect(_update_aspect)
	if material != null:
		material = material.duplicate()
	_update_aspect()
	var mat := material as ShaderMaterial
	if mat != null:
		_motion_speed = float(mat.get_shader_parameter("speed"))
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		_set_reduced_motion(bool(settings.call("reduced_motion_enabled")))
		settings.connect("changed", _on_setting_changed)


func _update_aspect() -> void:
	var mat := material as ShaderMaterial
	if mat == null or size.y <= 0.0:
		return
	var ratio := size.x / size.y
	# Scale the shorter axis up so one shader unit is square either way.
	var aspect := Vector2(ratio, 1.0) if ratio >= 1.0 else Vector2(1.0, 1.0 / ratio)
	mat.set_shader_parameter("aspect", aspect)


func _set_reduced_motion(enabled: bool) -> void:
	var mat := material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("speed", 0.0 if enabled else _motion_speed)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == REDUCED_MOTION_SETTING:
		_set_reduced_motion(bool(value))
