class_name SessionShareCard
extends Control

## Fixed-aspect score card rendered by ShareManager in a SubViewport.
## Games can reuse this scene as-is or pass their own scene with the same
## configure(Dictionary) contract.

@onready var _game_title: Label = %GameTitle
@onready var _studio: Label = %Studio
@onready var _mode: Label = %Mode
@onready var _result: Label = %Result
@onready var _subtitle: Label = %Subtitle
@onready var _score_caption: Label = %ScoreCaption
@onready var _score: Label = %Score
@onready var _accuracy: Label = %Accuracy
@onready var _hits: Label = %Hits
@onready var _combo: Label = %Combo
@onready var _achievement_badge: Label = %AchievementBadge
@onready var _achievement_title: Label = %AchievementTitle
@onready var _achievement_copy: Label = %AchievementCopy
@onready var _footer: Label = %Footer

var _accent := GameInfo.SKY
var _secondary := Color("4da3ff")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func configure(data: Dictionary) -> void:
	_accent = data.get("accent_color", GameInfo.SKY)
	_secondary = data.get("secondary_color", Color("4da3ff"))
	_game_title.text = str(data.get("game_title", GameInfo.TITLE)).to_upper()
	_studio.text = str(data.get("studio", GameInfo.STUDIO)).to_upper()
	_mode.text = str(data.get("mode", "GAME SESSION")).to_upper()
	_result.text = str(data.get("result", "ROUND COMPLETE"))
	_subtitle.text = str(data.get("subtitle", "Thanks for playing."))
	_score_caption.text = str(data.get("score_caption", "FINAL SCORE")).to_upper()
	_score.text = str(data.get("score", "0"))
	_accuracy.text = str(data.get("accuracy", "0%"))
	_hits.text = str(data.get("hits", "0"))
	_combo.text = str(data.get("combo", "x0"))
	_footer.text = str(
		data.get("footer", "%s  |  %s" % [GameInfo.TAGLINE, GameInfo.WEBSITE])
	)
	_mode.add_theme_color_override("font_color", _accent.lightened(0.2))
	_score_caption.add_theme_color_override("font_color", _accent.lightened(0.2))
	_score.add_theme_color_override("font_color", _accent)

	var titles := _achievement_titles(data.get("achievements", []))
	var achievement_count := int(data.get("achievement_count", titles.size()))
	var achievements_are_new := bool(data.get("achievements_are_new", true))
	if titles.is_empty():
		_achievement_badge.text = "PLAY"
		_achievement_title.text = "KEEP THE RUN GOING"
		_achievement_copy.text = "Every round is another shot at a new achievement."
	else:
		_achievement_badge.text = str(data.get("achievement_badge", "NEW"))
		if achievements_are_new:
			_achievement_title.text = (
				"NEW ACHIEVEMENT" if titles.size() == 1 else "NEW ACHIEVEMENTS"
			)
		else:
			_achievement_title.text = (
				"ACHIEVEMENT" if titles.size() == 1 else "ACHIEVEMENTS"
			)
		_achievement_copy.text = "  |  ".join(titles)
	if achievement_count > titles.size():
		_achievement_title.text += "  (%d TOTAL)" % achievement_count

	_result.add_theme_font_size_override("font_size", 62 if _result.text.length() < 20 else 48)
	queue_redraw()


func _achievement_titles(raw: Variant) -> PackedStringArray:
	var titles := PackedStringArray()
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for item: Variant in raw:
			var title := str(item).strip_edges()
			if not title.is_empty():
				titles.append(title)
	return titles


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0e1519"))
	draw_circle(Vector2(size.x * 0.84, size.y * 0.12), size.y * 0.38, _alpha(_accent, 0.08))
	draw_circle(Vector2(size.x * 0.14, size.y * 0.92), size.y * 0.31, _alpha(_secondary, 0.07))

	for index in range(10):
		var center := Vector2(
			size.x * (0.05 + fmod(float(index) * 0.173, 0.9)),
			size.y * (0.11 + fmod(float(index) * 0.237, 0.78))
		)
		var radius := 18.0 + float(index % 3) * 9.0
		draw_polyline(
			_triangle(center, radius, float(index) * 0.7),
			_alpha(_accent if index % 2 == 0 else _secondary, 0.09),
			2.0,
			true
		)

	draw_line(
		Vector2(64.0, size.y - 70.0),
		Vector2(size.x - 64.0, size.y - 70.0),
		_alpha(_accent, 0.24),
		2.0,
		true
	)


func _triangle(center: Vector2, radius: float, rotation: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(3):
		points.append(center + Vector2.UP.rotated(rotation + TAU * float(index) / 3.0) * radius)
	points.append(points[0])
	return points


func _alpha(color: Color, value: float) -> Color:
	var result := color
	result.a = value
	return result
