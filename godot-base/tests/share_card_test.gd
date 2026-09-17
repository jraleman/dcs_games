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
		GameCatalog.get_manifest("triangle_rush").resolved_stats_url()
		== "https://deskcansaw.com/stats/tr",
		"Triangle Rush must expose its configured stats route."
	)
	_expect(
		GameCatalog.get_manifest("desk_can_saw").resolved_stats_url()
		== "https://deskcansaw.com/stats/dcs",
		"Desk-Can-Saw must expose its configured stats route."
	)
	_expect(
		StudioInfo.website_label() == "deskcansaw.com",
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
	var game_script := load("res://games/desk_can_saw/desk_can_saw.gd") as Script
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
			str(data.get("stats_url")) == GameCatalog.get_manifest("triangle_rush").resolved_stats_url(),
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
		(card.get_node("%GameTitle") as Label).text == "TRIANGLE RUSH",
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

	var heading_data: Dictionary = prepared["data"].duplicate(true)
	heading_data["qr_heading"] = "Discover more games"
	card.configure(heading_data)
	_expect((card.get_node("%InfoTitle") as Label).text == "DISCOVER MORE GAMES",
		"A QR heading must describe a game-supplied destination without promising run stats.")
	card.configure(prepared["data"])
	_expect((card.get_node("%InfoTitle") as Label).text == "SCAN TO VIEW STATS",
		"An omitted QR heading must restore the existing stats wording.")

	var desk_data: Dictionary = prepared["data"].duplicate(true)
	desk_data["score"] = "-1"
	desk_data["score_values"] = [-1]
	card.configure(desk_data)
	_expect(
		(card.get_node("%Challenge") as Label).text == "CAN YOU BEAT -1?",
		"A negative solo score must not be mistaken for a versus score."
	)

	desk_data["game_id"] = "desk_can_saw"
	desk_data["game_title"] = GameCatalog.get_manifest("desk_can_saw").title
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
		str(action_art.get("_art_style")) == ShareCardArt.STYLE_DESK_CAN_SAW,
		"The art panel must switch to the Desk-Can-Saw visual variant."
	)
	_expect_card_fits(card)

	_test_game_supplied_art(card, desk_data)
	await _test_game_theme(card, desk_data)

	card.queue_free()
	await process_frame


func _test_game_theme(card: SessionShareCard, base: Dictionary) -> void:
	var manifest := GameCatalog.get_manifest("chicken_pit")
	if manifest == null:
		return
	var original_game := GameCatalog.current_id()
	GameCatalog.select("desk_can_saw")
	var data := base.duplicate(true)
	data.merge({
		"game_id": manifest.id,
		"game_title": manifest.title,
		"stats_url": manifest.resolved_stats_url(),
		"mode": "Red vs Rooster - 3 Lives",
		"result": "BLUE COOP PINS RED!",
		"score": "12340 - 14340",
		"score_values": [12340, 14340],
		"score_caption": "RED COOP - BLUE COOP",
		"challenge": "WHO RULES THE ROOST NEXT?",
		"accuracy_caption": "PULLS",
		"accuracy": "420",
		"hits_caption": "NOTCHES TAKEN",
		"hits": "32",
		"combo_caption": "BEST NOTCH RUN",
		"combo": "x12",
		"cta": "GRAB THE ROPE",
		"qr_copy": "Study the tug, challenge a rival, and take the pit.",
		"rematch_title": "TWO COOPS. ONE ROPE.",
		"rematch_copy": "The pit is ready for a rematch. Bring your best pulling rhythm.",
		"achievements": PackedStringArray(),
		"achievement_count": 0,
	}, true)
	card.configure(data)
	await process_frame
	await process_frame
	_expect(
		(card.get_node("%ActionArt") as TextureRect).texture == manifest.theme.logo_texture(),
		"Chicken Pit must reuse its full-colour original farm portrait."
	)
	var backdrop := card.get_node_or_null("CardBackdrop") as ColorRect
	_expect(backdrop != null, "An opted-in card must install the game's backdrop.")
	if backdrop != null:
		var mat := backdrop.material as ShaderMaterial
		_expect(mat != manifest.theme.background_material,
			"The card must not mutate the menu's shared material.")
		_expect(is_zero_approx(float(mat.get_shader_parameter("speed"))),
			"Share-card decoration must be frozen.")
		_expect(float(manifest.theme.background_material.get_shader_parameter("speed")) > 0.0,
			"Rendering a card must not freeze the game's menus.")
		_expect(mat.get_shader_parameter("top_color") == manifest.theme.background_top,
			"The payload's game must select the palette, not the active collection game.")
	_expect((card.get_node("%Score") as Label).get_theme_color("font_color")
		== manifest.theme.accent.lightened(0.08),
		"The score must use the game's gold accent rather than the result's team colour.")
	_expect((card.get_node("%AccuracyPanel/Layout/Caption") as Label).text == "PULLS"
		and (card.get_node("%HitsPanel/Layout/Caption") as Label).text == "NOTCHES TAKEN"
		and (card.get_node("%ComboPanel/Layout/Caption") as Label).text == "BEST NOTCH RUN",
		"The card must accept game-native stat captions.")
	_expect((card.get_node("%AchievementTitle") as Label).text == "TWO COOPS. ONE ROPE.",
		"A card without achievements must use the game's rematch copy.")
	_expect_card_fits(card)

	if DisplayServer.get_name() != "headless":
		var manager := get_root().get_node("ShareManager")
		for headline in ["BLUE COOP PINS RED!", "RED COOP HOLDS THE PIT", "DEAD EVEN"]:
			data["result"] = headline
			if headline == "RED COOP HOLDS THE PIT":
				data["score"] = "14340 - 12340"
				data["score_values"] = [14340, 12340]
				data["achievements"] = PackedStringArray(["Chicken Run", "Fowl Play"])
				data["achievement_count"] = 2
				data["achievement_badge"] = "RUN"
			if headline == "DEAD EVEN":
				data["score"] = "0 - 0"
				data["score_values"] = [0, 0]
				data["accuracy"] = "0"
				data["hits"] = "0"
				data["combo"] = "x0"
				data["achievements"] = PackedStringArray()
				data["achievement_count"] = 0
			card.configure(data)
			await process_frame
			await process_frame
			_expect_card_fits(card)
			var rendered: Dictionary = await manager.call("preview_score_image", data)
			_expect(bool(rendered.get("ok", false)),
				"The themed card must render through the actual share manager.")
			if bool(rendered.get("ok", false)):
				var texture: Texture2D = rendered["texture"]
				_expect(texture.get_size() == Vector2(1200, 630),
					"The themed share image must retain the standard export dimensions.")
				for argument in OS.get_cmdline_user_args():
					if argument.begins_with("--share-capture-dir="):
						var directory := argument.trim_prefix("--share-capture-dir=")
						var path := directory.path_join(headline.validate_filename() + ".png")
						_expect(texture.get_image().save_png(path) == OK,
							"The requested rendered card must be saved.")

	card.configure(base)
	await process_frame
	await process_frame
	_expect(card.get_node_or_null("CardBackdrop") == null,
		"A reused card must remove a previous game's backdrop.")
	_expect((card.get_node("%AccuracyPanel/Layout/Caption") as Label).text == "ACCURACY"
		and (card.get_node("%ComboPanel/Layout/Caption") as Label).text == "BEST COMBO",
		"A reused card must restore default stat captions.")
	_expect((card.get_node("%GameTitle") as Label).get_theme_color("font_color")
		.is_equal_approx(Color(0.94902, 0.968627, 0.976471, 1)),
		"A reused card must restore its authored label colours.")
	_expect(card.get_node("%ActionArt") is ShareCardArt,
		"A reused card must restore the next game's art.")
	_expect_card_fits(card)
	GameCatalog.select(original_game)


## A game may bring its own art scene instead of one of the built-in styles.
##
## The swap has to survive being undone. One card is reconfigured for every
## result the player shares, so a card that installed a game's scene and then
## kept it would put Dead Metal Jam's corridor behind a Desk-Can-Saw score.
## Reverting is also where the unique-name lookup breaks if the replacement is
## added without an owner, which is why `%ActionArt` is fetched again each time
## rather than held from before the swap.
func _test_game_supplied_art(card: SessionShareCard, base: Dictionary) -> void:
	var manifest := GameCatalog.get_manifest("dead_metal_jam")
	if manifest == null:
		return
	_expect(
		not manifest.share_art_scene_path.is_empty(),
		"Dead Metal Jam must declare its own share art scene."
	)
	_expect(
		ResourceLoader.exists(manifest.share_art_scene_path),
		"And the scene it names must exist: %s" % manifest.share_art_scene_path
	)

	var jam_data: Dictionary = base.duplicate(true)
	jam_data["game_id"] = "dead_metal_jam"
	jam_data["game_title"] = manifest.title
	jam_data["score"] = "12,450"
	jam_data["score_values"] = [12450]
	jam_data["result"] = ""
	card.configure(jam_data)

	var jam_art := card.get_node_or_null("%ActionArt") as Control
	_expect(
		jam_art != null,
		"The art panel must still answer to %ActionArt after the swap."
	)
	if jam_art != null:
		_expect(
			jam_art.scene_file_path == manifest.share_art_scene_path,
			"The card must draw the game's own art, got '%s'."
			% jam_art.scene_file_path
		)
		_expect(
			not (jam_art is ShareCardArt),
			"The built-in art must have been replaced, not drawn underneath."
		)
	_expect_card_fits(card)

	card.configure(base)
	var reverted := card.get_node_or_null("%ActionArt") as ShareCardArt
	_expect(
		reverted != null,
		"A game with no art scene must get the built-in art back."
	)
	if reverted != null:
		_expect(
			str(reverted.get("_art_style")) == ShareCardArt.STYLE_DESK_CAN_SAW,
			"And it must be styled for the game now on the card."
		)
	_expect_card_fits(card)


func _expect_card_fits(card: Control) -> void:
	for node in card.find_children("*", "Control", true, false):
		var control := node as Control
		_expect(card.get_global_rect().grow(0.5).encloses(control.get_global_rect()),
			"Card content must remain inside the export: %s." % card.get_path_to(control))
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
		"game_id": "triangle_rush",
		"game_title": GameCatalog.get_manifest("triangle_rush").title,
		"studio": StudioInfo.STUDIO,
		"website": StudioInfo.WEBSITE,
		"stats_url": GameCatalog.get_manifest("triangle_rush").resolved_stats_url(),
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
