class_name SliceAndSlashUnlockRule
extends GameUnlockRule

## Gates Desk-Can-Saw behind a strong Target Rush result.
##
## The player qualifies by either scoring [constant
## SliceUnlockRules.SCORE_THRESHOLD]+ in a solo round, or winning a multiplayer
## round as Player 1 with that score (Medium difficulty when facing the CPU).
## Both flags are sticky, so a later weak round never re-locks the game.
##
## The pure maths lives in [SliceUnlockRules] so it stays unit-testable; this
## class only adapts it to the framework's [GameUnlockRule] contract.

## Only results from this game count towards the unlock.
const SOURCE_GAME_ID := "target_rush"
const RACE_CONDITION_ACHIEVEMENT := "race_condition"


func progression_keys() -> Array[String]:
	var keys: Array[String] = []
	for key: String in SliceUnlockRules.PROGRESSION_KEYS:
		keys.append(key)
	return keys


func normalized_state(state: Dictionary) -> Dictionary:
	return SliceUnlockRules.normalized_state(state)


func is_unlocked(state: Dictionary) -> bool:
	return bool(
		SliceUnlockRules.normalized_state(state).get(
			SliceUnlockRules.UNLOCKED_KEY, false
		)
	)


func solo_qualified(state: Dictionary) -> bool:
	return bool(
		SliceUnlockRules.normalized_state(state).get(
			SliceUnlockRules.SOLO_QUALIFIED_KEY, false
		)
	)


func multiplayer_qualified(state: Dictionary) -> bool:
	return bool(
		SliceUnlockRules.normalized_state(state).get(
			SliceUnlockRules.MULTIPLAYER_QUALIFIED_KEY, false
		)
	)


func apply_result(state: Dictionary, result: Dictionary) -> Dictionary:
	if str(result.get("source_game_id", "")) != SOURCE_GAME_ID:
		return {
			"state": normalized_state(state),
			"changed": false,
		}

	var single_player := bool(result.get("single_player", true))
	var player_one_score := int(result.get("player_one_score", 0))
	var player_two_score := int(result.get("player_two_score", 0))
	var outcome := SliceUnlockRules.apply_match(
		state,
		single_player,
		player_one_score,
		player_two_score,
		bool(result.get("multiplayer_result_is_eligible", false))
	)

	var notes := PackedStringArray()
	if bool(outcome.get("unlocked_now", false)):
		notes.append("%s unlocked!" % str(result.get("target_title", "New game")))
	elif bool(outcome.get("solo_qualified_now", false)):
		notes.append("Solo unlock condition complete")
	elif bool(outcome.get("multiplayer_qualified_now", false)):
		notes.append("Multiplayer unlock condition complete")
	outcome["notes"] = notes

	var achievements := PackedStringArray()
	if SliceUnlockRules.earns_race_condition(
		single_player, player_one_score, player_two_score
	):
		achievements.append(RACE_CONDITION_ACHIEVEMENT)
	outcome["achievements"] = achievements
	return outcome


func requirement_text(state: Dictionary) -> String:
	var solo_state := "DONE" if solo_qualified(state) else "NEEDED"
	var multiplayer_state := "DONE" if multiplayer_qualified(state) else "NEEDED"
	return (
		"Unlock either: Solo score %d+ [%s]  |  "
		+ "OR P1 multiplayer win with %d+ [%s] (Medium when facing CPU)"
	) % [
		SliceUnlockRules.SCORE_THRESHOLD,
		solo_state,
		SliceUnlockRules.SCORE_THRESHOLD,
		multiplayer_state,
	]


## Each Target Rush route unlocks the matching Desk-Can-Saw route, so the menu
## only advertises the modes the player actually earned.
func unlocked_modes(state: Dictionary) -> PackedStringArray:
	var modes := PackedStringArray()
	if solo_qualified(state):
		modes.append("Single Player")
	if multiplayer_qualified(state):
		modes.append("Local Multiplayer")
	return modes
