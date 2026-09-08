class_name GameCard
extends PanelContainer

## One game on the game-select screen: its walkthrough clip running as a moving
## thumbnail, the game's name and tagline, and what the player may do with it.
##
## The card is a view and nothing more. The screen hands it a [GameManifest] and
## decides whether a preview is allowed to move; the card never asks a manager
## anything. That is deliberate: `class_name` scripts are compiled before
## autoloads exist in headless `--script` runs, so a component that reached for
## [code]Settings[/code] could not be loaded from a test.

## Emitted when the player picks this game, whether by the button or by clicking
## the thumbnail.
signal chosen(game_id: String)

## Thumbnail shape. It matches the recorded walkthrough clips, so a preview
## fills the frame instead of sitting letterboxed inside it.
const THUMBNAIL_RATIO := 16.0 / 9.0

## Narrowest a card may be drawn. The grid divides a row by this, so a small
## screen drops to fewer columns rather than shrinking previews to stamps.
const MIN_WIDTH := 300.0

## Preview audio is never wanted: several cards play at once and the clips were
## recorded silent anyway. Far below the quietest audible level rather than a
## mute flag, so nothing depends on the stream having an audio track at all.
const SILENT_DB := -80.0

@onready var _frame: AspectRatioContainer = %Frame
@onready var _stack: PanelContainer = %Stack
@onready var _video: VideoStreamPlayer = %Video
@onready var _poster: TextureRect = %Poster
@onready var _placeholder: Label = %Placeholder
@onready var _badge: Label = %Badge
@onready var _title: Label = %Title
@onready var _tagline: Label = %Tagline
@onready var _status: Label = %Status
@onready var _play_button: Button = %PlayButton

var _game_id := ""
var _has_clip := false
var _reduced_motion := false
var _always_preview := true
var _focused := false


func _ready() -> void:
	custom_minimum_size.x = MIN_WIDTH
	_frame.ratio = THUMBNAIL_RATIO
	_frame.custom_minimum_size = Vector2(MIN_WIDTH, MIN_WIDTH / THUMBNAIL_RATIO)
	_video.expand = true
	_video.loop = true
	_video.volume_db = SILENT_DB

	_play_button.pressed.connect(_on_pick)
	_play_button.focus_entered.connect(_on_focus_changed.bind(true))
	_play_button.focus_exited.connect(_on_focus_changed.bind(false))
	_stack.gui_input.connect(_on_thumbnail_input)
	_stack.mouse_entered.connect(_focus_play_button)
	_stack.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _exit_tree() -> void:
	if _video.is_playing():
		_video.stop()


## Points the card at one game. Call it after the card is in the tree, so the
## nodes it configures exist.
##
## [param status] is the availability line under the tagline, and [param
## playable] closes the card for a game whose gate is still shut.
func configure(manifest: GameManifest, status: String, playable := true) -> void:
	_game_id = manifest.id
	_title.text = manifest.title
	_tagline.text = manifest.tagline
	_status.text = status
	_status.visible = not status.is_empty()
	_play_button.disabled = not playable

	# "Play" alone is the right label under a card that already carries the
	# name, but three identical buttons are useless read aloud, so the whole
	# sentence goes where assistive technology will find it.
	var described := "Play %s. %s" % [manifest.title, manifest.tagline]
	_play_button.tooltip_text = described
	_play_button.accessibility_description = described
	_stack.tooltip_text = described
	accessibility_name = manifest.title
	accessibility_description = described

	_load_preview(manifest)


## Whether this card may run its clip at all times, or only while the player is
## on it. The screen decides, because the cost is a video decode per card.
func set_always_preview(enabled: bool) -> void:
	if _always_preview == enabled:
		return
	_always_preview = enabled
	_refresh_preview()


## A looping thumbnail is ambient motion, so Reduced motion parks every card on
## its poster frame instead.
func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		return
	_reduced_motion = enabled
	_refresh_preview()


## The control the screen should focus to put the player on this card.
func focus_target() -> Control:
	return _play_button


## Closes the card down once the screen has committed to a game: no clip, no
## button. A card that kept decoding into the transition would be paying for a
## picture nobody can see any more.
func close() -> void:
	_play_button.disabled = true
	_play_button.release_focus()
	_focused = false
	_always_preview = false
	_refresh_preview()


func game_id() -> String:
	return _game_id


## True while the clip is actually running, which is what a test can check
## without depending on how the decision was reached.
func is_previewing() -> bool:
	return _video.is_playing()


## Loads the walkthrough clip and its poster frame. Both are optional: a game
## with only a poster shows a still, and a game with neither keeps the frame and
## says the preview is missing rather than collapsing the card's shape.
func _load_preview(manifest: GameManifest) -> void:
	var poster_path := manifest.tutorial_poster_path.strip_edges()
	if not poster_path.is_empty() and ResourceLoader.exists(poster_path):
		_poster.texture = load(poster_path) as Texture2D
	_poster.visible = _poster.texture != null

	var clip_path := manifest.tutorial_video_path.strip_edges()
	if not clip_path.is_empty() and ResourceLoader.exists(clip_path):
		_video.stream = load(clip_path) as VideoStream
	_has_clip = _video.stream != null

	_placeholder.visible = not _has_clip and _poster.texture == null
	_placeholder.text = "%s\nPREVIEW COMING SOON" % manifest.title.to_upper()
	_refresh_preview()


func _refresh_preview() -> void:
	var wanted := _has_clip and not _reduced_motion and (_always_preview or _focused)
	if wanted:
		if not _video.is_playing():
			_video.play()
		_video.paused = false
	elif _video.is_playing():
		_video.stop()
	_video.visible = wanted

	# The badge is the card's only claim about what the picture is doing, so it
	# has to be honest about a still frame as well as a running clip.
	_badge.visible = _has_clip
	_badge.text = "PREVIEW" if wanted else "PREVIEW PAUSED"


func _on_focus_changed(focused: bool) -> void:
	_focused = focused
	_refresh_preview()


func _focus_play_button() -> void:
	if not _play_button.disabled:
		_play_button.grab_focus()


func _on_thumbnail_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	_stack.accept_event()
	_on_pick()


func _on_pick() -> void:
	if _play_button.disabled or _game_id.is_empty():
		return
	chosen.emit(_game_id)
