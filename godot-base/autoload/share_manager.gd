extends Node

## Renders shareable session cards without coupling a game scene to image
## capture or platform-specific download/clipboard behavior.

signal image_generated(path: String, png: PackedByteArray)

const CARD_SIZE := Vector2i(1200, 630)
const SHARE_FOLDER := "shares"
const PREVIEW_LAYER := 126
const DEFAULT_CARD: PackedScene = preload("res://ui/components/share_card.tscn")
const PREVIEW_SCENE: PackedScene = preload("res://ui/components/share_preview.tscn")

var _busy := false
var _preview_layer: CanvasLayer
var _preview: ShareImagePreview


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = PREVIEW_LAYER
	_preview_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_preview_layer)


func is_busy() -> bool:
	return _busy


func show_preview(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		push_warning("ShareManager.show_preview() needs a successful image result.")
		return
	if is_instance_valid(_preview):
		_preview.queue_free()

	_preview = PREVIEW_SCENE.instantiate() as ShareImagePreview
	if _preview == null:
		push_error("Share preview scene has an invalid root.")
		return
	_preview_layer.add_child(_preview)
	_preview.closed.connect(_on_preview_closed.bind(_preview))
	_preview.present(result)


func open_original_image(global_path: String) -> Error:
	if OS.has_feature("web"):
		return ERR_UNAVAILABLE
	if global_path.is_empty():
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(global_path):
		return ERR_FILE_NOT_FOUND
	return OS.shell_open(global_path)


## Renders the score card and saves it: to `user://shares` (with the path copied
## to the clipboard) on desktop, or straight to a browser download on the web.
func generate_score_image(
	data: Dictionary,
	card_scene: PackedScene = null
) -> Dictionary:
	return await _render_card(data, card_scene, true)


## Renders the same card for on-screen display only. Nothing is written to
## disk, downloaded or copied to the clipboard, so a screen can show the card
## as a live summary without producing a file the player never asked for.
func preview_score_image(
	data: Dictionary,
	card_scene: PackedScene = null
) -> Dictionary:
	return await _render_card(data, card_scene, false)


func _render_card(
	data: Dictionary,
	card_scene: PackedScene,
	store: bool
) -> Dictionary:
	if _busy:
		return {
			"ok": false,
			"message": "A share image is already being generated.",
		}
	if DisplayServer.get_name() == "headless":
		return {
			"ok": false,
			"message": "Share images require a rendering display.",
		}

	var prepared_result := _prepare_card_data(data)
	if not bool(prepared_result.get("ok", false)):
		return prepared_result
	var card_data: Dictionary = prepared_result["data"]

	_busy = true
	var scene := card_scene if card_scene != null else DEFAULT_CARD
	var viewport := SubViewport.new()
	viewport.size = CARD_SIZE
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var card := scene.instantiate()
	var result: Dictionary
	if card == null or not card.has_method("configure"):
		# The card never gets parented to the viewport, so it would leak.
		if card != null:
			card.queue_free()
		result = {
			"ok": false,
			"message": "The share card must implement configure(Dictionary).",
		}
	else:
		viewport.add_child(card)
		if card is Control:
			(card as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.call("configure", card_data)

		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		await get_tree().process_frame

		var image: Image = viewport.get_texture().get_image()
		if image == null or image.is_empty():
			result = {
				"ok": false,
				"message": "The share image could not be rendered.",
			}
		else:
			result = (
				_store_and_share(
					image,
					str(card_data.get("game_title", StudioInfo.TITLE)),
					str(card_data.get("stats_url", ""))
				)
				if store
				else _preview_result(
					image,
					str(card_data.get("stats_url", ""))
				)
			)

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	await get_tree().process_frame
	_busy = false
	return result


func _prepare_card_data(data: Dictionary) -> Dictionary:
	var prepared := data.duplicate(true)
	var fallback := GameCatalog.current()
	var game_id := str(
		prepared.get("game_id", fallback.id if fallback else "")
	).strip_edges()
	var manifest := GameCatalog.get_manifest(game_id)
	if manifest == null:
		manifest = fallback

	var default_stats_url := manifest.resolved_stats_url() if manifest else ""
	var stats_url := str(
		prepared.get("stats_url", default_stats_url)
	).strip_edges()
	var validation_error := ShareQrCode.validation_error(stats_url)
	if not validation_error.is_empty():
		return {
			"ok": false,
			"message": validation_error,
		}

	var qr_texture := ShareQrCode.create_texture(stats_url)
	if qr_texture == null:
		return {
			"ok": false,
			"message": "The stats QR code could not be generated.",
		}

	prepared["game_id"] = game_id
	if manifest and not prepared.has("share_art_style"):
		prepared["share_art_style"] = manifest.share_art_style
	prepared["stats_url"] = stats_url
	prepared["website"] = str(prepared.get("website", StudioInfo.WEBSITE))
	prepared["qr_texture"] = qr_texture
	return {
		"ok": true,
		"data": prepared,
	}


## Wraps a rendered card as a display-only result: same texture, no file.
func _preview_result(image: Image, stats_url: String) -> Dictionary:
	return {
		"ok": true,
		"texture": ImageTexture.create_from_image(image),
		"stats_url": stats_url,
		"can_open_original": false,
		"stored": false,
		"message": "Scorecard ready.",
	}


func _store_and_share(
	image: Image,
	game_title: String,
	stats_url: String
) -> Dictionary:
	var png := image.save_png_to_buffer()
	if png.is_empty():
		return {
			"ok": false,
			"message": "The share image could not be encoded.",
		}

	var filename := "%s-%s.png" % [_safe_stem(game_title), _timestamp()]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(png, filename, "image/png")
		image_generated.emit(filename, png)
		return {
			"ok": true,
			"path": filename,
			"filename": filename,
			"png": png,
			"texture": ImageTexture.create_from_image(image),
			"stats_url": stats_url,
			"can_open_original": false,
			"stored": true,
			"message": "Share image downloaded.",
		}

	var directory := DirAccess.open("user://")
	if directory == null:
		return {
			"ok": false,
			"message": "The game storage folder could not be opened.",
		}
	var directory_error := directory.make_dir_recursive(SHARE_FOLDER)
	if directory_error != OK:
		return {
			"ok": false,
			"message": "The share image folder could not be created.",
		}

	var local_path := "user://%s/%s" % [SHARE_FOLDER, filename]
	var save_error := image.save_png(local_path)
	if save_error != OK:
		return {
			"ok": false,
			"message": "The share image could not be saved (error %d)." % save_error,
		}

	var global_path := ProjectSettings.globalize_path(local_path)
	DisplayServer.clipboard_set(global_path)
	image_generated.emit(local_path, png)
	return {
		"ok": true,
		"path": local_path,
		"global_path": global_path,
		"filename": filename,
		"png": png,
		"texture": ImageTexture.create_from_image(image),
		"stats_url": stats_url,
		"can_open_original": true,
		"stored": true,
		"message": "Share image saved and its path copied to the clipboard.",
	}


func _on_preview_closed(preview: ShareImagePreview) -> void:
	if _preview == preview:
		_preview = null


func _safe_stem(raw: String) -> String:
	var result := ""
	var valid := "abcdefghijklmnopqrstuvwxyz0123456789"
	for index in range(raw.length()):
		var character := raw.substr(index, 1).to_lower()
		if valid.contains(character):
			result += character
		elif character == " " or character == "-" or character == "_":
			if not result.ends_with("-"):
				result += "-"
	result = result.trim_suffix("-")
	return result if not result.is_empty() else "game-score"


func _timestamp() -> String:
	var value := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d-%02d%02d%02d" % [
		int(value.year),
		int(value.month),
		int(value.day),
		int(value.hour),
		int(value.minute),
		int(value.second),
	]
