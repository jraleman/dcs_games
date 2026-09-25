extends Node

## Persistent cosmetic store: one wallet, one owned set and one equipped map per
## game.
##
## Everything on sale is declared on a [GameManifest], exactly like achievements
## and options, so this registry never learns what a particular game sells or
## what any of it looks like. A game reads back only the ids it declared, through
## [method equipped_id], and draws them itself.
##
## Wallets are per game rather than shared. Scores differ by orders of magnitude
## between games — Chicken Pit banks thousands of points of held ground where a
## target game counts hits — so one pooled currency would let the loudest game
## buy out every other game's shop. Each game converts its own rounds with its
## own [member GameManifest.store_currency] rule.

## Emitted after a wallet changes, including when a purchase spends from it.
signal points_changed(game_id: String, points: int)
signal purchased(game_id: String, item_id: String)
## Emitted with an empty [param item_id] when a slot is cleared.
signal equipped_changed(game_id: String, slot_id: String, item_id: String)

## Progression, not preferences, so this sits beside `achievements.cfg` rather
## than in `settings.cfg`. It is a file of its own because two autoloads writing
## one `ConfigFile` would have to agree on merge order forever.
const SAVE_PATH := "user://store.cfg"
const POINTS_SECTION := "points"
const OWNED_SECTION := "owned"
const EQUIPPED_SECTION := "equipped"

## The kind an item declares when it does not say, and the kind a slot accepts
## when it does not say, so the simplest possible store needs neither field.
const DEFAULT_KIND := "cosmetic"

## Payout and naming defaults for a game that declares a partial — or no —
## [member GameManifest.store_currency].
const DEFAULT_CURRENCY := {
	"name": "Point",
	"plural": "Points",
	"points_per_score": 1.0,
	"round_bonus": 0,
	"win_bonus": 0,
	"max_per_round": 0,
}

## Registered catalogues, keyed by game id.
var _items: Dictionary = {}
var _slots: Dictionary = {}
var _currency: Dictionary = {}

## Saved state, keyed by game id. `_owned[game_id]` keeps ids this build does
## not recognise as well, so a build that ships fewer cosmetics cannot spend a
## player's points twice on the same hat.
var _points: Dictionary = {}
var _owned: Dictionary = {}
var _equipped: Dictionary = {}

var _game_ids := PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for manifest in GameCatalog.all():
		register_game(manifest)
	_load_state()


# --------------------------------------------------------------------------
# Registration
# --------------------------------------------------------------------------


## Normalizes one game's declarations so every reader downstream can rely on
## every field being present and correctly typed.
func register_game(manifest: GameManifest) -> void:
	if manifest == null or manifest.id.is_empty():
		return
	var game_id := manifest.id
	var slots: Array[Dictionary] = []
	var kinds := PackedStringArray()
	for raw_slot: Variant in manifest.store_slots:
		if typeof(raw_slot) != TYPE_DICTIONARY:
			push_warning("Store: %s declares a slot that is not a Dictionary." % game_id)
			continue
		var slot := _normalize_slot(raw_slot, game_id)
		if slot.is_empty():
			continue
		slots.append(slot)
		if not kinds.has(str(slot["kind"])):
			kinds.append(str(slot["kind"]))

	var items: Array[Dictionary] = []
	var seen := PackedStringArray()
	for raw_item: Variant in manifest.store_items:
		if typeof(raw_item) != TYPE_DICTIONARY:
			push_warning("Store: %s declares an item that is not a Dictionary." % game_id)
			continue
		var item := _normalize_item(raw_item, game_id, manifest.store_preview_scene_path)
		if item.is_empty():
			continue
		if seen.has(str(item["id"])):
			push_warning("Store: duplicate item '%s' in %s." % [item["id"], game_id])
			continue
		if not kinds.is_empty() and not kinds.has(str(item["kind"])):
			push_warning(
				"Store: '%s' is a '%s', which no %s slot accepts."
				% [item["id"], item["kind"], game_id]
			)
		seen.append(str(item["id"]))
		items.append(item)

	if items.is_empty() and slots.is_empty():
		return
	_items[game_id] = items
	_slots[game_id] = slots
	_currency[game_id] = _normalize_currency(manifest.store_currency)
	if not _game_ids.has(game_id):
		_game_ids.append(game_id)
	_points.get_or_add(game_id, 0)
	_owned.get_or_add(game_id, {})
	_equipped.get_or_add(game_id, {})
	_grant_defaults(game_id)


func _normalize_slot(source: Dictionary, game_id: String) -> Dictionary:
	var id := str(source.get("id", "")).strip_edges()
	if id.is_empty():
		push_warning("Store: %s declares a slot with no id." % game_id)
		return {}
	var empty_title := str(source.get("empty_title", "")).strip_edges()
	return {
		"id": id,
		"game_id": game_id,
		"kind": str(source.get("kind", DEFAULT_KIND)),
		"title": str(source.get("title", _title_from_id(id))),
		"description": str(source.get("description", "")),
		"empty_title": empty_title,
		# A slot only offers "take it off" when the game named the bare state,
		# because "nothing" is a look a game has to be able to draw.
		"allows_empty": not empty_title.is_empty(),
	}


func _normalize_item(
	source: Dictionary, game_id: String, preview_scene_path: String
) -> Dictionary:
	var id := str(source.get("id", "")).strip_edges()
	if id.is_empty():
		push_warning("Store: %s declares an item with no id." % game_id)
		return {}
	var color := _to_color(source.get("color", null), Color("5c6b7a"), game_id, id)
	return {
		"id": id,
		"game_id": game_id,
		"kind": str(source.get("kind", DEFAULT_KIND)),
		"title": str(source.get("title", _title_from_id(id))),
		"description": str(source.get("description", "")),
		"badge": str(source.get("badge", "")),
		"color": color,
		"price": maxi(int(source.get("price", 0)), 0),
		"default": bool(source.get("default", false)),
		"requires_achievement": str(source.get("requires_achievement", "")).strip_edges(),
		"heading": str(source.get("heading", "")),
		"preview_scene_path": str(source.get("preview_scene_path", preview_scene_path)),
	}


## Coerces a manifest-supplied colour. Game data reaches the store as plain
## dictionaries, so a `"color"` written as a hex string — the obvious mistake —
## must degrade to the declared value or the default rather than raising a type
## error inside the autoload. Every neighbouring field is coerced the same way.
func _to_color(raw: Variant, fallback: Color, game_id: String, item_id: String) -> Color:
	if raw == null:
		return fallback
	if raw is Color:
		return raw
	if raw is String:
		var text := str(raw)
		if Color.html_is_valid(text.trim_prefix("#")):
			return Color(text)
	push_warning(
		"Store: %s item '%s' declares an unreadable color; using the default."
		% [game_id, item_id]
	)
	return fallback


func _normalize_currency(source: Dictionary) -> Dictionary:
	var rule := DEFAULT_CURRENCY.duplicate(true)
	for raw_key: Variant in source:
		var key := str(raw_key)
		if rule.has(key):
			rule[key] = source[raw_key]
	if str(rule["plural"]).is_empty():
		rule["plural"] = str(rule["name"])
	return rule


## Free items are handed over at registration and equipped into any matching
## slot that is still empty, so a game's bare look is a real item the player can
## always come back to rather than a special case in the store screen.
func _grant_defaults(game_id: String) -> void:
	var owned: Dictionary = _owned[game_id]
	var equipped: Dictionary = _equipped[game_id]
	for item: Dictionary in _items[game_id]:
		if not bool(item["default"]):
			continue
		owned[str(item["id"])] = true
		for slot: Dictionary in _slots[game_id]:
			if str(slot["kind"]) != str(item["kind"]):
				continue
			if not equipped.has(str(slot["id"])):
				equipped[str(slot["id"])] = str(item["id"])


static func _title_from_id(id: String) -> String:
	return id.replace("_", " ").strip_edges().capitalize()


# --------------------------------------------------------------------------
# Reading a catalogue
# --------------------------------------------------------------------------


## True when [param game_id] has something to sell and somewhere to wear it.
func has_store(game_id: String) -> bool:
	return not items(game_id).is_empty() and not slots(game_id).is_empty()


func items(game_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in _items.get(game_id, [] as Array[Dictionary]):
		result.append(describe(game_id, str(item["id"])))
	return result


func slots(game_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: Dictionary in _slots.get(game_id, [] as Array[Dictionary]):
		result.append(slot.duplicate(true))
	return result


## The slots [param item_id] may be worn in, in declaration order.
func slots_for_item(game_id: String, item_id: String) -> Array[Dictionary]:
	var item := _find_item(game_id, item_id)
	if item.is_empty():
		return []
	var result: Array[Dictionary] = []
	for slot: Dictionary in _slots.get(game_id, [] as Array[Dictionary]):
		if str(slot["kind"]) == str(item["kind"]):
			result.append(slot.duplicate(true))
	return result


## One item plus everything the store screen needs to decide what to offer:
## `owned`, `equipped_slots`, `affordable`, `locked` and `locked_reason`.
func describe(game_id: String, item_id: String) -> Dictionary:
	var item := _find_item(game_id, item_id)
	if item.is_empty():
		return {}
	var result := item.duplicate(true)
	var owned := is_owned(game_id, item_id)
	var equipped_slots := PackedStringArray()
	for slot: Dictionary in _slots.get(game_id, [] as Array[Dictionary]):
		if equipped_id(game_id, str(slot["id"])) == item_id:
			equipped_slots.append(str(slot["id"]))
	var requirement := str(item["requires_achievement"])
	var locked := not requirement.is_empty() and not _achievement_unlocked(requirement)
	result["owned"] = owned
	result["equipped_slots"] = equipped_slots
	result["equipped"] = not equipped_slots.is_empty()
	result["affordable"] = points(game_id) >= int(item["price"])
	result["locked"] = locked and not owned
	result["locked_reason"] = (
		_achievement_requirement_text(requirement) if bool(result["locked"]) else ""
	)
	return result


func _find_item(game_id: String, item_id: String) -> Dictionary:
	for item: Dictionary in _items.get(game_id, [] as Array[Dictionary]):
		if str(item["id"]) == item_id:
			return item
	return {}


func _find_slot(game_id: String, slot_id: String) -> Dictionary:
	for slot: Dictionary in _slots.get(game_id, [] as Array[Dictionary]):
		if str(slot["id"]) == slot_id:
			return slot
	return {}


# --------------------------------------------------------------------------
# Wallet
# --------------------------------------------------------------------------


func points(game_id: String) -> int:
	return int(_points.get(game_id, 0))


## Banks [param amount] and returns the new balance. Negative amounts are
## ignored: points are spent through [method purchase], which checks the price.
func add_points(game_id: String, amount: int) -> int:
	if amount <= 0 or not _items.has(game_id):
		return points(game_id)
	_points[game_id] = points(game_id) + amount
	_save_state()
	points_changed.emit(game_id, points(game_id))
	return points(game_id)


## The points a finished round pays out under this game's declared rule.
##
## [param result] is the shell's round summary (`single_player`, `vs_cpu`,
## `player_one_score`, `player_two_score`, optional `player_scores`). The best
## score across all participants pays into the one shared local wallet.
## The win bonus needs an opponent worth beating, so it pays only when the
## human beat the CPU: in a two-human match somebody always wins, and in a
## round with no opponent at all there is nothing to have won.
func default_round_points(game_id: String, result: Dictionary) -> int:
	if not _items.has(game_id):
		return 0
	var rule := currency(game_id)
	var player_one := int(result.get("player_one_score", 0))
	var player_two := int(result.get("player_two_score", 0))
	var best := maxi(maxi(player_one, player_two), 0)
	for score: Variant in result.get("player_scores", []):
		best = maxi(best, int(score))
	var earned := int(roundf(float(best) * float(rule["points_per_score"])))
	earned += int(rule["round_bonus"])
	if bool(result.get("vs_cpu", false)) and player_one > player_two:
		earned += int(rule["win_bonus"])
	var cap := int(rule["max_per_round"])
	if cap > 0:
		earned = mini(earned, cap)
	return maxi(earned, 0)


func currency(game_id: String) -> Dictionary:
	var values: Dictionary = _currency.get(game_id, DEFAULT_CURRENCY)
	return values.duplicate(true)


## "Feather" or "Feathers", depending on [param amount].
func currency_name(game_id: String, amount := 2) -> String:
	var rule := currency(game_id)
	return str(rule["name"] if absi(amount) == 1 else rule["plural"])


## "40 Feathers", ready to drop into a sentence.
func format_points(game_id: String, amount: int) -> String:
	return "%d %s" % [amount, currency_name(game_id, amount)]


# --------------------------------------------------------------------------
# Buying and wearing
# --------------------------------------------------------------------------


func is_owned(game_id: String, item_id: String) -> bool:
	var owned: Dictionary = _owned.get(game_id, {})
	return owned.has(item_id)


## Buys [param item_id] and wears it immediately in the first slot that will
## take it, because a player who just paid for a hat wants to see it on.
##
## Returns false — spending nothing — when the item is unknown, already owned,
## still gated behind an achievement, or simply too expensive.
func purchase(game_id: String, item_id: String) -> bool:
	var item := _find_item(game_id, item_id)
	if item.is_empty() or is_owned(game_id, item_id):
		return false
	var requirement := str(item["requires_achievement"])
	if not requirement.is_empty() and not _achievement_unlocked(requirement):
		return false
	var price := int(item["price"])
	if points(game_id) < price:
		return false

	_points[game_id] = points(game_id) - price
	var owned: Dictionary = _owned[game_id]
	owned[item_id] = true
	var worn := _wear(game_id, item_id, _first_free_slot(game_id, item))
	if not worn:
		_save_state()
	points_changed.emit(game_id, points(game_id))
	purchased.emit(game_id, item_id)
	return true


## Wears an owned item. Without a [param slot_id] the first matching slot is
## used, which is the whole interaction for a game with a single wearer.
func equip(game_id: String, item_id: String, slot_id := "") -> bool:
	if not is_owned(game_id, item_id):
		return false
	var item := _find_item(game_id, item_id)
	if item.is_empty():
		return false
	var target := slot_id
	if target.is_empty():
		target = _first_free_slot(game_id, item)
	var slot := _find_slot(game_id, target)
	if slot.is_empty() or str(slot["kind"]) != str(item["kind"]):
		return false
	return _wear(game_id, item_id, target)


## Clears a slot, if the game declared what an empty one looks like.
func unequip(game_id: String, slot_id: String) -> bool:
	var slot := _find_slot(game_id, slot_id)
	if slot.is_empty() or not bool(slot["allows_empty"]):
		return false
	return _wear(game_id, "", slot_id)


## The item worn in [param slot_id], or "" when the slot is empty or unknown.
##
## A slot holding an id this build does not recognise reads as the slot's
## default instead: an equip is a free, reversible choice, so presenting a look
## the build cannot draw would be worse than quietly falling back. Ownership,
## which is what the points bought, is never discarded this way.
func equipped_id(game_id: String, slot_id: String) -> String:
	var equipped: Dictionary = _equipped.get(game_id, {})
	var item_id := str(equipped.get(slot_id, ""))
	if item_id.is_empty():
		return ""
	if _find_item(game_id, item_id).is_empty() or not is_owned(game_id, item_id):
		return _default_item_id(game_id, slot_id)
	return item_id


## The worn item's full description, or `{}` for an empty slot.
func equipped_item(game_id: String, slot_id: String) -> Dictionary:
	var item_id := equipped_id(game_id, slot_id)
	return describe(game_id, item_id) if not item_id.is_empty() else {}


func _wear(game_id: String, item_id: String, slot_id: String) -> bool:
	if slot_id.is_empty():
		return false
	var equipped: Dictionary = _equipped.get_or_add(game_id, {})
	if str(equipped.get(slot_id, "")) == item_id:
		return false
	equipped[slot_id] = item_id
	_save_state()
	equipped_changed.emit(game_id, slot_id, item_id)
	return true


## Prefers a slot that is not already wearing something the player chose, so
## dressing a second wearer does not undress the first.
func _first_free_slot(game_id: String, item: Dictionary) -> String:
	var fallback := ""
	for slot: Dictionary in _slots.get(game_id, [] as Array[Dictionary]):
		if str(slot["kind"]) != str(item["kind"]):
			continue
		if fallback.is_empty():
			fallback = str(slot["id"])
		var worn := equipped_id(game_id, str(slot["id"]))
		if worn.is_empty() or worn == _default_item_id(game_id, str(slot["id"])):
			return str(slot["id"])
	return fallback


func _default_item_id(game_id: String, slot_id: String) -> String:
	var slot := _find_slot(game_id, slot_id)
	if slot.is_empty():
		return ""
	for item: Dictionary in _items.get(game_id, [] as Array[Dictionary]):
		if bool(item["default"]) and str(item["kind"]) == str(slot["kind"]):
			return str(item["id"])
	return ""


## Resolved from the tree rather than named, so the catalogue can be registered
## before [AchievementManager] finishes booting.
func _achievement_unlocked(id: String) -> bool:
	var manager := get_tree().root.get_node_or_null("AchievementManager")
	return manager != null and bool(manager.call("is_unlocked", id))


func _achievement_requirement_text(id: String) -> String:
	var manager := get_tree().root.get_node_or_null("AchievementManager")
	if manager == null:
		return "Locked."
	var achievement: Dictionary = manager.call("get_achievement", id)
	var title := str(achievement.get("title", ""))
	return "Earn %s to unlock." % title if not title.is_empty() else "Locked."


# --------------------------------------------------------------------------
# Saves
# --------------------------------------------------------------------------


## What [param game_id]'s save holds here, for [GameSaves]: `has_store`,
## `points`, `points_text`, `items_bought`, `items_total`, `customised` and
## `has_progress`.
##
## Every registered game is written to the file, so a key being there proves
## nothing; progress is judged by content instead. Free defaults are owned and
## worn from the start, so they are not progress. An owned id this build does
## not sell still is — somebody paid for it — although only items this build
## can name are counted in `items_bought`.
func save_summary(game_id: String) -> Dictionary:
	var summary := {
		"has_store": _items.has(game_id),
		"points": points(game_id),
		"points_text": "",
		"items_bought": 0,
		"items_total": 0,
		"customised": false,
		"has_progress": false,
	}
	if not _items.has(game_id):
		return summary
	var defaults := _default_item_ids(game_id)
	var unknown_owned := false
	for raw_id: Variant in _owned.get(game_id, {}):
		var id := str(raw_id)
		if defaults.has(id):
			continue
		if _find_item(game_id, id).is_empty():
			unknown_owned = true
		else:
			summary["items_bought"] = int(summary["items_bought"]) + 1
	for item: Dictionary in _items[game_id]:
		if not bool(item["default"]):
			summary["items_total"] = int(summary["items_total"]) + 1
	var equipped: Dictionary = _equipped.get(game_id, {})
	for slot: Dictionary in _slots[game_id]:
		var slot_id := str(slot["id"])
		if str(equipped.get(slot_id, "")) != _default_item_id(game_id, slot_id):
			summary["customised"] = true
	summary["points_text"] = format_points(game_id, int(summary["points"]))
	summary["has_progress"] = (
		int(summary["points"]) > 0 or int(summary["items_bought"]) > 0
		or unknown_owned or bool(summary["customised"])
	)
	return summary


## [param game_id]'s wallet, purchases and worn items, in the shape
## [method import_save] takes back. Empty when this build sells nothing for it.
func export_save(game_id: String) -> Dictionary:
	if not _items.has(game_id):
		return {}
	var equipped: Dictionary = _equipped.get(game_id, {})
	return {
		"points": points(game_id),
		"owned": _owned_ids(game_id),
		"equipped": equipped.duplicate(true),
	}


## Empties [param game_id]'s wallet and leaves it only its free defaults.
func erase_save(game_id: String) -> Error:
	return import_save(game_id, {})


## Replaces [param game_id]'s wallet, purchases and worn items with [param data],
## as written by [method export_save]. Free defaults are granted again exactly
## as at boot, so a restored save cannot leave a slot without its bare look.
## A game this build sells nothing for is left alone: its entries in the file,
## if any, belong to a build that knows what they mean.
func import_save(game_id: String, data: Dictionary) -> Error:
	if not _items.has(game_id):
		return OK
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		# Saving now would replace a file we could not read with one game's keys.
		push_warning("Could not read the store from %s (error %d)." % [SAVE_PATH, err])
		return err
	var balance: Variant = data.get("points", 0)
	_points[game_id] = (
		maxi(int(balance), 0) if balance is int or balance is float else 0
	)
	var owned: Dictionary = {}
	var stored_owned: Variant = data.get("owned", PackedStringArray())
	if stored_owned is PackedStringArray or stored_owned is Array:
		for raw_id: Variant in stored_owned:
			owned[str(raw_id)] = true
	_owned[game_id] = owned
	var equipped: Dictionary = {}
	var stored_equipped: Variant = data.get("equipped", {})
	if typeof(stored_equipped) == TYPE_DICTIONARY:
		for raw_slot: Variant in stored_equipped:
			equipped[str(raw_slot)] = str(stored_equipped[raw_slot])
	_equipped[game_id] = equipped
	_grant_defaults(game_id)
	_write_game(config, game_id)
	err = config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save the store to %s (error %d)." % [SAVE_PATH, err])
	points_changed.emit(game_id, points(game_id))
	for slot: Dictionary in _slots[game_id]:
		var slot_id := str(slot["id"])
		equipped_changed.emit(game_id, slot_id, equipped_id(game_id, slot_id))
	return err


func _default_item_ids(game_id: String) -> PackedStringArray:
	var ids := PackedStringArray()
	for item: Dictionary in _items.get(game_id, [] as Array[Dictionary]):
		if bool(item["default"]):
			ids.append(str(item["id"]))
	return ids


func _owned_ids(game_id: String) -> PackedStringArray:
	var owned := PackedStringArray()
	for raw_id: Variant in _owned.get(game_id, {}):
		owned.append(str(raw_id))
	owned.sort()
	return owned


# --------------------------------------------------------------------------
# Persistence
# --------------------------------------------------------------------------


func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	for game_id in _game_ids:
		_points[game_id] = maxi(int(config.get_value(POINTS_SECTION, game_id, 0)), 0)
		var owned: Dictionary = _owned[game_id]
		for raw_id: Variant in config.get_value(OWNED_SECTION, game_id, PackedStringArray()):
			owned[str(raw_id)] = true
		var stored: Variant = config.get_value(EQUIPPED_SECTION, game_id, {})
		if typeof(stored) == TYPE_DICTIONARY:
			var equipped: Dictionary = _equipped[game_id]
			for raw_slot: Variant in stored:
				equipped[str(raw_slot)] = str(stored[raw_slot])
		_grant_defaults(game_id)


func _save_state() -> void:
	var config := ConfigFile.new()
	# Merge into the stored file instead of replacing it, for the same reason
	# achievements do: a build that ships one game must not wipe another build's
	# purchases out of a shared `user://`.
	config.load(SAVE_PATH)
	for game_id in _game_ids:
		_write_game(config, game_id)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save the store to %s (error %d)." % [SAVE_PATH, err])


## One game's entries in the file's shape — the only place that shape is written.
func _write_game(config: ConfigFile, game_id: String) -> void:
	config.set_value(POINTS_SECTION, game_id, points(game_id))
	config.set_value(OWNED_SECTION, game_id, _owned_ids(game_id))
	config.set_value(EQUIPPED_SECTION, game_id, _equipped.get(game_id, {}))
