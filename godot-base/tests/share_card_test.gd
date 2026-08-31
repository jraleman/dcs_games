extends SceneTree

var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configured_urls()
	_test_url_validation()
	_test_qr_image()
	_test_slice_counts()
	await _test_prepared_share_data()
	await _test_share_card()
	await _finish()


func _test_configured_urls() -> void:
	_expect(
		GameInfo.stats_url_for(GameInfo.TARGET_RUSH_ID)
		== "https://deskcansaw.com/stats/tr",
		"Target Rush must expose its configured stats route."
	)
	_expect(
		GameInfo.stats_url_for(GameInfo.SLICE_AND_SLASH_ID)
		== "https://deskcansaw.com/stats/dcs",
		"Desk-Can-Saw must expose its configured stats route."
	)
	_expect(
		GameInfo.website_label() == "deskcansaw.com",
		"The share card must have a readable website label."
	)


func _test_url_validation() -> void:
	_expect(
		ShareQrCode.validation_error(
			"https://deskcansaw.com/stats/test-run"
		).is_empty(),
		"HTTPS stats URLs must be accepted."
	)
	_expect(
		not ShareQrCode.validation_error("").is_empty(),
		"Empty stats URLs must be rejected."
	)
	_expect(
		not ShareQrCode.validation_error("deskcansaw.com/stats").is_empty(),
		"Stats URLs without an HTTP scheme must be rejected."
	)
	_expect(
		not ShareQrCode.validation_error("https://").is_empty(),
		"Stats URLs without a host must be rejected."
	)
	_expect(
		not ShareQrCode.validation_error(
			"https://deskcansaw.com/\tstats"
		).is_empty(),
		"Stats URLs containing control characters must be rejected."
	)
	_expect(
		not ShareQrCode.validation_error(
			"https://deskcansaw.com/" + "a".repeat(ShareQrCode.MAX_URL_BYTES)
		).is_empty(),
		"Overlong stats URLs must be rejected before QR generation."
	)


func _test_qr_image() -> void:
	var image := ShareQrCode.create_image(
		"https://deskcansaw.com/stats/test-run"
	)
	_expect(image != null, "A valid stats URL must generate a QR image.")
	if image == null:
		return

	_expect(
		image.get_size() == Vector2i(
			ShareQrCode.DEFAULT_IMAGE_SIZE,
			ShareQrCode.DEFAULT_IMAGE_SIZE
		),
		"The QR image must use the designed share-card dimensions."
	)

	var dark_count := 0
	var minimum_dark := Vector2i(image.get_width(), image.get_height())
	var maximum_dark := Vector2i.ZERO
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			if image.get_pixel(x, y).is_equal_approx(ShareQrCode.DARK_COLOR):
				dark_count += 1
				minimum_dark.x = mini(minimum_dark.x, x)
				minimum_dark.y = mini(minimum_dark.y, y)
				maximum_dark.x = maxi(maximum_dark.x, x)
				maximum_dark.y = maxi(maximum_dark.y, y)

	_expect(dark_count > 500, "The generated QR image must contain dark modules.")
	_expect(
		minimum_dark.x >= 16
		and minimum_dark.y >= 16
		and maximum_dark.x <= image.get_width() - 17
		and maximum_dark.y <= image.get_height() - 17,
		"The QR image must preserve a scan-safe quiet zone."
	)


func _test_slice_counts() -> void:
	var game_script := load("res://scenes/game/slice_and_slash.gd") as Script
	var game: Node = game_script.new()
	game.set("points_per_can", 5)
	game.set("_scores", [10, 5])
	_expect(
		int(game.call("_player_slice_count", 0)) == 2,
		"Desk-Can-Saw must convert points back into Player 1 slice counts."
	)
	_expect(
		int(game.call("_total_slice_count")) == 3,
		"Desk-Can-Saw must report total sliced cans instead of total points."
	)
	game.free()


func _test_prepared_share_data() -> void:
	var manager := get_root().get_node_or_null("ShareManager")
	_expect(manager != null, "ShareManager must be available as an autoload.")
	if manager == null:
		return

	var result: Dictionary = manager.call(
		"_prepare_card_data",
		_base_payload()
	)
	_expect(
		bool(result.get("ok", false)),
		"ShareManager must prepare valid card data."
	)
	if bool(result.get("ok", false)):
		var data: Dictionary = result["data"]
		_expect(
			data.get("qr_texture") is Texture2D,
			"Prepared card data must include a QR texture."
		)
		_expect(
			str(data.get("stats_url")) == GameInfo.stats_url_for(
				GameInfo.TARGET_RUSH_ID
			),
			"Prepared card data must retain the QR destination."
		)

	var invalid := _base_payload()
	invalid["stats_url"] = "not-a-url"
	var invalid_result: Dictionary = manager.call(
		"_prepare_card_data",
		invalid
	)
	_expect(
		not bool(invalid_result.get("ok", true)),
		"ShareManager must reject an invalid QR destination."
	)
	await process_frame


func _test_share_card() -> void:
	var manager := get_root().get_node_or_null("ShareManager")
	var packed := load("res://ui/components/share_card.tscn") as PackedScene
	_expect(packed != null, "The redesigned share card scene must load.")
	if manager == null or packed == null:
		return

	var card := packed.instantiate() as SessionShareCard
	_expect(card != null, "The share card scene must use SessionShareCard.")
	if card == null:
		return

	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	get_root().add_child(card)
	card.size = Vector2(1200.0, 630.0)
	await process_frame

	var prepared: Dictionary = manager.call(
		"_prepare_card_data",
		_base_payload()
	)
	card.configure(prepared["data"])
	await process_frame

	_expect(
		(card.get_node("%GameTitle") as Label).text == "TARGET RUSH",
		"The score card must prominently show the game name."
	)
	_expect(
		(card.get_node("%Website") as Label).text == "deskcansaw.com",
		"The information panel must show the website."
	)
	_expect(
		(card.get_node("%QRCode") as TextureRect).texture != null,
		"The information panel must show the generated QR code."
	)
	_expect(
		(card.get_node("%Cta") as Label).text.contains("BEAT IT"),
		"The information panel must include a play-focused call to action."
	)
	_expect(
		(card.get_node("%Challenge") as Label).text == "CAN YOU BEAT 12,450?",
		"A solo result must challenge viewers to beat the shared score."
	)
	_expect_card_fits(card)

	var desk_data: Dictionary = prepared["data"].duplicate(true)
	desk_data["score"] = "-1"
	desk_data["score_values"] = [-1]
	card.configure(desk_data)
	_expect(
		(card.get_node("%Challenge") as Label).text == "CAN YOU BEAT -1?",
		"A negative solo score must not be mistaken for a versus score."
	)

	desk_data["game_id"] = GameInfo.SLICE_AND_SLASH_ID
	desk_data["game_title"] = GameInfo.DESK_CAN_SAW_TITLE
	desk_data["score"] = "28 - 24"
	desk_data["score_values"] = [28, 24]
	desk_data["result"] = "PLAYER 1 WINS"
	card.configure(desk_data)
	await process_frame

	_expect(
		(card.get_node("%GameTitle") as Label).text == "DESK-CAN-SAW",
		"The Desk-Can-Saw variant must show its own game name."
	)
	_expect(
		(card.get_node("%Challenge") as Label).text
		== "WHO TAKES THE NEXT ROUND?",
		"A multiplayer result must use a rematch-focused challenge."
	)
	var action_art := card.get_node("%ActionArt") as ShareCardArt
	_expect(
		str(action_art.get("_game_id")) == GameInfo.SLICE_AND_SLASH_ID,
		"The art panel must switch to the Desk-Can-Saw visual variant."
	)
	_expect_card_fits(card)

	card.queue_free()
	await process_frame


func _expect_card_fits(card: Control) -> void:
	var info_panel := card.get_node("%InfoPanel") as Control
	var achievement_panel := card.get_node("%AchievementPanel") as Control
	_expect(
		info_panel.position.x + info_panel.size.x <= card.size.x + 0.5,
		"The QR information panel must fit inside the 1200 px card."
	)
	_expect(
		achievement_panel.position.y + achievement_panel.size.y
		<= card.size.y + 0.5,
		"The achievement section must fit inside the 630 px card."
	)


func _base_payload() -> Dictionary:
	return {
		"game_id": GameInfo.TARGET_RUSH_ID,
		"game_title": GameInfo.TARGET_RUSH_TITLE,
		"studio": GameInfo.STUDIO,
		"website": GameInfo.WEBSITE,
		"stats_url": GameInfo.stats_url_for(GameInfo.TARGET_RUSH_ID),
		"mode": "Solo",
		"result": "Round Complete",
		"score_caption": "Solo Score",
		"score": "12,450",
		"score_values": [12450],
		"accuracy": "92%",
		"hits": "48",
		"combo": "x17",
		"achievements": PackedStringArray(["Solo Starter"]),
		"achievements_are_new": true,
		"achievement_count": 1,
		"achievement_badge": "1P",
		"accent_color": Color("4da3ff"),
		"secondary_color": Color("ffd34e"),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	await process_frame
	if _failures.is_empty():
		print("Share card tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
