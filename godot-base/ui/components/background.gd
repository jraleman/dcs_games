extends ColorRect

## Feeds the current aspect ratio to menu_background.gdshader so the glows
## stay round instead of stretching on wide or tall screens.


func _ready() -> void:
	resized.connect(_update_aspect)
	_update_aspect()


func _update_aspect() -> void:
	var mat := material as ShaderMaterial
	if mat == null or size.y <= 0.0:
		return
	var ratio := size.x / size.y
	# Scale the shorter axis up so one shader unit is square either way.
	var aspect := Vector2(ratio, 1.0) if ratio >= 1.0 else Vector2(1.0, 1.0 / ratio)
	mat.set_shader_parameter("aspect", aspect)
