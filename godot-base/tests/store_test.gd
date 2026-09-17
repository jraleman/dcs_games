extends SceneTree

## Framework regression checks for the cosmetics [Store].
##
## The store is declared data, exactly like achievements and options, so this
## test iterates [method GameCatalog.all] and covers every game that sells
## anything. Nothing here names a game to decide behaviour.
##
## Headless `--script` runs compile before autoloads exist, so the [Store] and
## [AchievementManager] instances are resolved from the tree and poked with
## `call`. [StoreItemCard] is named directly on purpose: it is a `class_name`
## view that touches no autoload, and this test is what keeps it that way.

var _failures := PackedStringArray()
## The store file as it was before the test spent anything, restored on the way
## out so a run never leaves a player — or the next test — richer or poorer.
var _saved_store := PackedByteArray()
var _had_store_file := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var store := get_root().get_node_or_null("Store")
	if store == null:
		printerr("The Store autoload is required.")
		quit(1)
		return
	_back_up_save()

	var selling := _games_with_stores(store)
	_test_declarations(store)
	_test_currency(store)
	for manifest in selling:
		_test_defaults(store, manifest)
		_test_payout(store, manifest)
		_test_buying(store, manifest)
		_test_locked_items(store, manifest)
	_test_persistence(store, selling)
	await _test_screen(selling)
	await _test_empty_screen()
	await _test_menu_entry_points(store, selling)
	# Menu sounds release their stopped playbacks on the mixer thread.
	await create_timer(0.25, true, false, true).timeout
	_finish()


func _games_with_stores(store: Node) -> Array[GameManifest]:
	var selling: Array[GameManifest] = []
	for manifest in GameCatalog.all():
		_expect(
			bool(store.call("has_store", manifest.id)) == manifest.has_store(),
			"%s: the registry and the manifest must agree there is a store."
			% manifest.id
		)
		if manifest.has_store():
			selling.append(manifest)
	_expect(
		not selling.is_empty(),
		"At least one game must ship a store, or this test proves nothing."
	)
	return selling


## Every declaration has to be well formed before a shelf can render it, and an
## item has to be wearable somewhere or the points spent on it buy nothing.
func _test_declarations(store: Node) -> void:
	for manifest in GameCatalog.all():
		if manifest.store_items.is_empty() and manifest.store_slots.is_empty():
			continue
		var kinds := PackedStringArray()
		var slot_ids := PackedStringArray()
		for slot: Dictionary in manifest.store_slots:
			var slot_id := str(slot.get("id", ""))
			_expect(
				not slot_id.is_empty() and not slot_ids.has(slot_id),
				"%s declares a duplicate or unnamed slot: '%s'." % [manifest.id, slot_id]
			)
			slot_ids.append(slot_id)
			_expect(
				not str(slot.get("title", "")).strip_edges().is_empty(),
				"%s must give slot '%s' a title." % [manifest.id, slot_id]
			)
			var kind := str(slot.get("kind", Store.DEFAULT_KIND))
			if not kinds.has(kind):
				kinds.append(kind)

		var item_ids := PackedStringArray()
		var defaults := PackedStringArray()
		for item: Dictionary in manifest.store_items:
			var item_id := str(item.get("id", ""))
			_expect(
				not item_id.is_empty() and not item_ids.has(item_id),
				"%s declares a duplicate or unnamed item: '%s'." % [manifest.id, item_id]
			)
			item_ids.append(item_id)
			_expect(
				not str(item.get("title", "")).strip_edges().is_empty(),
				"%s must give item '%s' a title." % [manifest.id, item_id]
			)
			var kind := str(item.get("kind", Store.DEFAULT_KIND))
			_expect(
				kinds.has(kind),
				"%s sells '%s' as a '%s', which no slot accepts."
				% [manifest.id, item_id, kind]
			)
			_expect(
				int(item.get("price", 0)) >= 0,
				"%s must not price '%s' below nothing." % [manifest.id, item_id]
			)
			var requirement := str(item.get("requires_achievement", ""))
			_expect(
				requirement.is_empty() or manifest.achievements.has(requirement),
				"%s gates '%s' behind an achievement it does not declare."
				% [manifest.id, item_id]
			)
			if bool(item.get("default", false)):
				_expect(
					int(item.get("price", 0)) == 0 and requirement.is_empty(),
					"%s must leave its default item '%s' free and ungated."
					% [manifest.id, item_id]
				)
				defaults.append(kind)

		# Without a default, a slot has no look to fall back to when a saved
		# choice names something this build no longer ships.
		for kind in kinds:
			_expect(
				defaults.has(kind),
				"%s must declare one free default '%s'." % [manifest.id, kind]
			)

		_expect(
			(store.call("items", manifest.id) as Array).size() == item_ids.size()
			and (store.call("slots", manifest.id) as Array).size() == slot_ids.size(),
			"The registry must hold everything %s declares." % manifest.id
		)


## A game that declares nothing about money still has to be describable, and a
## game that declares some of it must not lose the rest.
func _test_currency(store: Node) -> void:
	var missing: Dictionary = store.call("currency", "not_a_game")
	_expect(
		missing == Store.DEFAULT_CURRENCY,
		"An unknown game must fall back to the default currency."
	)
	_expect(
		int(store.call("points", "not_a_game")) == 0
		and int(store.call("add_points", "not_a_game", 50)) == 0
		and not bool(store.call("purchase", "not_a_game", "anything")),
		"A game with no store must not hold or take points."
	)
	for manifest in GameCatalog.all():
		if not manifest.has_store():
			continue
		var rule: Dictionary = store.call("currency", manifest.id)
		for key: String in Store.DEFAULT_CURRENCY:
			_expect(
				rule.has(key),
				"%s's currency must keep the '%s' default." % [manifest.id, key]
			)
		_expect(
			str(store.call("currency_name", manifest.id, 1))
			!= str(store.call("currency_name", manifest.id, 2))
			or str(rule["name"]) == str(rule["plural"]),
			"%s must name one unit differently from many, or say they match."
			% manifest.id
		)
		_expect(
			str(store.call("format_points", manifest.id, 1)).begins_with("1 "),
			"%s must format a balance as an amount and a name." % manifest.id
		)


## The bare look is a real, free, already-worn item rather than a special case,
## so every slot starts filled and the player can always come back to it.
func _test_defaults(store: Node, manifest: GameManifest) -> void:
	for slot: Dictionary in store.call("slots", manifest.id):
		var slot_id := str(slot["id"])
		var worn := str(store.call("equipped_id", manifest.id, slot_id))
		_expect(
			not worn.is_empty() or bool(slot["allows_empty"]),
			"%s must dress slot '%s' out of the box." % [manifest.id, slot_id]
		)
		if worn.is_empty():
			continue
		_expect(
			bool(store.call("is_owned", manifest.id, worn)),
			"%s must own whatever it is wearing in '%s'." % [manifest.id, slot_id]
		)
		var equipped: Dictionary = store.call("equipped_item", manifest.id, slot_id)
		_expect(
			str(equipped.get("id", "")) == worn,
			"%s must describe the item worn in '%s'." % [manifest.id, slot_id]
		)

	# A saved look this build no longer ships must not strand a slot empty.
	var slots: Array = store.call("slots", manifest.id)
	if slots.is_empty():
		return
	var first := str((slots[0] as Dictionary)["id"])
	var equipped_map: Dictionary = (store.get("_equipped") as Dictionary)[manifest.id]
	var restore := str(equipped_map.get(first, ""))
	equipped_map[first] = "a_hat_from_another_build"
	_expect(
		not str(store.call("equipped_id", manifest.id, first)).is_empty(),
		"%s must fall back to a default when a saved look is gone." % manifest.id
	)
	equipped_map[first] = restore


## The payout rule is the whole reason a round is worth finishing, so the
## arithmetic is checked against the game's own declared numbers.
func _test_payout(store: Node, manifest: GameManifest) -> void:
	var rule: Dictionary = store.call("currency", manifest.id)
	var rate := float(rule["points_per_score"])
	var bonus := int(rule["round_bonus"])
	var win := int(rule["win_bonus"])
	var cap := int(rule["max_per_round"])

	var duel := {
		"single_player": false, "player_one_score": 40, "player_two_score": 100
	}
	var expected := int(roundf(100.0 * rate)) + bonus
	if cap > 0:
		expected = mini(expected, cap)
	_expect(
		int(store.call("default_round_points", manifest.id, duel)) == expected,
		"%s must pay the best score on the mat, with no win bonus in a duel."
		% manifest.id
	)

	var solo := {
		"single_player": true, "player_one_score": 100, "player_two_score": 40
	}
	var solo_expected := int(roundf(100.0 * rate)) + bonus + win
	if cap > 0:
		solo_expected = mini(solo_expected, cap)
	_expect(
		int(store.call("default_round_points", manifest.id, solo)) == solo_expected,
		"%s must add its win bonus to a round a solo player won." % manifest.id
	)

	var wipeout := {
		"single_player": true, "player_one_score": -30, "player_two_score": -10
	}
	_expect(
		int(store.call("default_round_points", manifest.id, wipeout)) >= 0,
		"%s must never charge a player for a bad round." % manifest.id
	)
	if cap > 0:
		var blowout := {
			"single_player": true,
			"player_one_score": 1_000_000,
			"player_two_score": 0,
		}
		_expect(
			int(store.call("default_round_points", manifest.id, blowout)) == cap,
			"%s must hold one round to its declared ceiling." % manifest.id
		)


## Buying is the one place points leave a wallet, so it is checked from both
## sides: too little money buys nothing, and enough money buys once.
func _test_buying(store: Node, manifest: GameManifest) -> void:
	var target := _cheapest_buyable(store, manifest)
	if target.is_empty():
		_expect(
			false,
			"%s must offer something a player could still buy." % manifest.id
		)
		return
	var item_id := str(target["id"])
	var price := int(target["price"])

	var opening := int(store.call("points", manifest.id))
	if opening >= price:
		# A wallet left full by an earlier run would skip the "cannot afford"
		# half of this check, so it is spent down first.
		(store.get("_points") as Dictionary)[manifest.id] = 0
	_expect(
		not bool(store.call("purchase", manifest.id, item_id)),
		"%s must refuse a purchase nobody can afford yet." % manifest.id
	)
	_expect(
		not bool(
			(store.call("describe", manifest.id, item_id) as Dictionary)["affordable"]
		),
		"%s must say so when an item is out of reach." % manifest.id
	)

	store.call("add_points", manifest.id, price)
	_expect(
		int(store.call("points", manifest.id)) == price,
		"%s must bank exactly what a round paid." % manifest.id
	)
	_expect(
		bool(store.call("purchase", manifest.id, item_id)),
		"%s must sell '%s' to a player who can afford it." % [manifest.id, item_id]
	)
	_expect(
		int(store.call("points", manifest.id)) == 0
		and bool(store.call("is_owned", manifest.id, item_id)),
		"%s must charge the price once and hand the item over." % manifest.id
	)

	# Paying for a hat and not seeing it on would be indistinguishable from a
	# failed purchase.
	var described: Dictionary = store.call("describe", manifest.id, item_id)
	_expect(
		bool(described["equipped"]),
		"%s must wear '%s' the moment it is bought." % [manifest.id, item_id]
	)
	store.call("add_points", manifest.id, price)
	_expect(
		not bool(store.call("purchase", manifest.id, item_id))
		and int(store.call("points", manifest.id)) == price,
		"%s must not sell '%s' twice." % [manifest.id, item_id]
	)

	_test_wearing(store, manifest, item_id)


## An owned item can move between every slot that accepts it, which is what
## makes one purchase dress both ends of a two-sided match.
func _test_wearing(store: Node, manifest: GameManifest, item_id: String) -> void:
	var slots: Array = store.call("slots_for_item", manifest.id, item_id)
	_expect(
		not slots.is_empty(),
		"%s sells '%s' with nowhere to wear it." % [manifest.id, item_id]
	)
	for slot: Dictionary in slots:
		var slot_id := str(slot["id"])
		store.call("equip", manifest.id, item_id, slot_id)
		_expect(
			str(store.call("equipped_id", manifest.id, slot_id)) == item_id,
			"%s must wear '%s' in '%s' when asked." % [manifest.id, item_id, slot_id]
		)
		var cleared := bool(store.call("unequip", manifest.id, slot_id))
		_expect(
			cleared == bool(slot["allows_empty"]),
			"%s must only empty slot '%s' if it said a bare one is a look."
			% [manifest.id, slot_id]
		)
		if cleared:
			_expect(
				str(store.call("equipped_id", manifest.id, slot_id)).is_empty(),
				"%s must leave slot '%s' empty once it is cleared."
				% [manifest.id, slot_id]
			)
	_expect(
		not bool(store.call("equip", manifest.id, "a_hat_nobody_owns")),
		"%s must not wear something nobody bought." % manifest.id
	)
	_expect(
		not bool(store.call("unequip", manifest.id, "not_a_slot")),
		"%s must not empty a slot it does not have." % manifest.id
	)


## An item behind an achievement stays behind it no matter how rich the player
## is, because the price is not what is being asked for.
func _test_locked_items(store: Node, manifest: GameManifest) -> void:
	for item: Dictionary in store.call("items", manifest.id):
		if not bool(item["locked"]):
			continue
		var item_id := str(item["id"])
		_expect(
			not str(item["locked_reason"]).strip_edges().is_empty(),
			"%s must say why '%s' is locked." % [manifest.id, item_id]
		)
		store.call("add_points", manifest.id, int(item["price"]) + 1000)
		_expect(
			not bool(store.call("purchase", manifest.id, item_id)),
			"%s must not sell '%s' before it is unlocked." % [manifest.id, item_id]
		)


## The save file is shared between builds, so it is merged rather than rebuilt:
## a build that ships one game must not wipe another game's purchases.
func _test_persistence(store: Node, selling: Array[GameManifest]) -> void:
	var seed_config := ConfigFile.new()
	seed_config.load(Store.SAVE_PATH)
	seed_config.set_value(Store.POINTS_SECTION, "a_game_this_build_lacks", 4200)
	seed_config.set_value(
		Store.OWNED_SECTION, "a_game_this_build_lacks", PackedStringArray(["a_hat"])
	)
	_expect(
		seed_config.save(Store.SAVE_PATH) == OK,
		"The store save file must be writable."
	)

	if selling.is_empty():
		return
	var manifest := selling[0]
	store.call("add_points", manifest.id, 7)

	var written := ConfigFile.new()
	_expect(
		written.load(Store.SAVE_PATH) == OK,
		"Banking points must write the store to disk."
	)
	_expect(
		int(written.get_value(Store.POINTS_SECTION, "a_game_this_build_lacks", 0)) == 4200,
		"Saving must not spend an absent game's points."
	)
	_expect(
		(
			written.get_value(
				Store.OWNED_SECTION, "a_game_this_build_lacks", PackedStringArray()
			) as PackedStringArray
		).has("a_hat"),
		"Saving must not throw away an absent game's purchases."
	)
	_expect(
		int(written.get_value(Store.POINTS_SECTION, manifest.id, -1))
		== int(store.call("points", manifest.id)),
		"%s's balance must survive a restart." % manifest.id
	)
	var owned: PackedStringArray = written.get_value(
		Store.OWNED_SECTION, manifest.id, PackedStringArray()
	)
	for item: Dictionary in store.call("items", manifest.id):
		if bool(item["owned"]):
			_expect(
				owned.has(str(item["id"])),
				"%s must remember owning '%s'." % [manifest.id, str(item["id"])]
			)


## The shelves are generated, so a game gets a card per item — and a place to
## start pressing — without this screen knowing what any of them are.
func _test_screen(selling: Array[GameManifest]) -> void:
	if selling.is_empty():
		return
	var manifest := selling[0]
	var screen := await _open_store(manifest.id)
	if screen == null:
		return

	var cards: Array = screen.get("_cards")
	_expect(
		cards.size() == manifest.store_items.size(),
		"%s must get a card for every item it sells." % manifest.id
	)
	var ids := PackedStringArray()
	for card: StoreItemCard in cards:
		ids.append(card.item_id())
		_expect(
			not card.tooltip_text.is_empty()
			and card.accessibility_description == card.tooltip_text,
			"Every store card must describe itself for assistive tech."
		)
	for item: Dictionary in manifest.store_items:
		_expect(
			ids.has(str(item.get("id", ""))),
			"%s must put '%s' on a shelf." % [manifest.id, str(item.get("id", ""))]
		)

	_expect(
		(screen.get_node("%Title") as Label).text.contains(manifest.title)
		and not (screen.get_node("%Intro") as Label).text.is_empty()
		and not (screen.get_node("%Empty") as Control).visible,
		"%s must title and introduce its own store." % manifest.id
	)
	_expect(
		(screen.get_node("%Balance") as Label).text.is_empty() == false,
		"The store must show what the player has to spend."
	)
	_expect(
		screen.call("_first_focusable_control") != null,
		"The store must open on something the player can press."
	)
	await _free_scene(screen)


## A collection's main menu has not chosen a game, so the screen must say there
## is nothing to sell rather than guess or crash.
func _test_empty_screen() -> void:
	var screen := await _open_store("")
	if screen == null:
		return
	_expect(
		(screen.get("_cards") as Array).is_empty()
		and (screen.get_node("%Empty") as Control).visible
		and not (screen.get_node("%Intro") as Control).visible,
		"A store with no game must show its empty state."
	)
	await _free_scene(screen)


## The store is reached from two places, and both of them have to know which
## game they would be selling for.
##
## A collection's title screen has not chosen one, so it must not offer a shop
## at all; the pause menu always has a round running, so it offers the shop of
## the game being played — and nothing when that game sells nothing.
func _test_menu_entry_points(store: Node, selling: Array[GameManifest]) -> void:
	var menu: Node = (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	await process_frame
	_expect(
		not (menu.get_node("%StoreButton") as Button).visible,
		"A collection's title screen must not offer a store it cannot name."
	)
	await _free_scene(menu)

	for manifest in GameCatalog.all():
		GameCatalog.select(manifest.id)
		var pause: Node = (
			load("res://scenes/menus/pause_menu.tscn") as PackedScene
		).instantiate()
		get_root().add_child(pause)
		await process_frame
		_expect(
			(pause.get_node("%StoreButton") as Button).visible
			== bool(store.call("has_store", manifest.id)),
			"The pause menu must offer %s's store exactly when it has one."
			% manifest.id
		)
		# A nested store must come up over the paused round and hand focus back.
		if bool(store.call("has_store", manifest.id)):
			pause.call("_on_store_pressed")
			await process_frame
			var overlay: Node = pause.get("_store_overlay")
			_expect(
				overlay != null
				and str(overlay.get("game_context_id")) == manifest.id
				and not (pause as Control).visible,
				"Pausing into the store must sell for the running game."
			)
			if overlay != null:
				overlay.call("go_back")
				await process_frame
				await process_frame
				_expect(
					(pause as Control).visible,
					"Leaving the store must return to the pause menu."
				)
		pause.free()
		paused = false
		await process_frame
	if not selling.is_empty():
		GameCatalog.select(selling[0].id)


func _cheapest_buyable(store: Node, manifest: GameManifest) -> Dictionary:
	var best: Dictionary = {}
	for item: Dictionary in store.call("items", manifest.id):
		if bool(item["owned"]) or bool(item["locked"]) or int(item["price"]) <= 0:
			continue
		if best.is_empty() or int(item["price"]) < int(best["price"]):
			best = item
	return best


func _open_store(game_id: String) -> Node:
	var packed := load("res://scenes/menus/store.tscn") as PackedScene
	if packed == null:
		_failures.append("Could not load the store scene.")
		return null
	var screen := packed.instantiate()
	# Assigned before `add_child`, which is when `_ready` builds the shelves.
	screen.set("game_context_id", game_id)
	get_root().add_child(screen)
	await process_frame
	return screen


func _free_scene(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _back_up_save() -> void:
	_had_store_file = FileAccess.file_exists(Store.SAVE_PATH)
	if not _had_store_file:
		return
	var file := FileAccess.open(Store.SAVE_PATH, FileAccess.READ)
	if file != null:
		_saved_store = file.get_buffer(file.get_length())


## Puts the player's wallet back exactly as it was found. The autoload's own
## copy is not rewound, but the process ends here, so the file is the truth.
func _restore_save() -> void:
	if not _had_store_file:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.SAVE_PATH))
		return
	var file := FileAccess.open(Store.SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_buffer(_saved_store)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	_restore_save()
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Store: all checks passed.")
	quit(0 if _failures.is_empty() else 1)
