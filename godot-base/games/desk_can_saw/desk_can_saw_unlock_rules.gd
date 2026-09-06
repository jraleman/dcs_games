class_name DeskCanSawUnlockRules
extends RefCounted

const SCORE_THRESHOLD := 25
const SOLO_QUALIFIED_KEY := "desk_can_saw_solo_qualified"
const MULTIPLAYER_QUALIFIED_KEY := "desk_can_saw_multiplayer_qualified"
const UNLOCKED_KEY := "desk_can_saw_unlocked"
const PROGRESSION_KEYS := [
	SOLO_QUALIFIED_KEY,
	MULTIPLAYER_QUALIFIED_KEY,
	UNLOCKED_KEY,
]


static func normalized_state(state: Dictionary) -> Dictionary:
	var solo_qualified := bool(state.get(SOLO_QUALIFIED_KEY, false))
	var multiplayer_qualified := bool(state.get(MULTIPLAYER_QUALIFIED_KEY, false))
	var unlocked := bool(state.get(UNLOCKED_KEY, false))
	unlocked = unlocked or solo_qualified or multiplayer_qualified
	return {
		SOLO_QUALIFIED_KEY: solo_qualified,
		MULTIPLAYER_QUALIFIED_KEY: multiplayer_qualified,
		UNLOCKED_KEY: unlocked,
	}


static func apply_match(
	state: Dictionary,
	single_player: bool,
	player_one_score: int,
	player_two_score: int,
	multiplayer_result_is_eligible: bool
) -> Dictionary:
	var previous := normalized_state(state)
	var next := previous.duplicate(true)
	var solo_qualified_now := false
	var multiplayer_qualified_now := false

	if single_player:
		if (
			player_one_score >= SCORE_THRESHOLD
			and not bool(next[SOLO_QUALIFIED_KEY])
		):
			next[SOLO_QUALIFIED_KEY] = true
			solo_qualified_now = true
	elif (
		multiplayer_result_is_eligible
		and player_one_score >= SCORE_THRESHOLD
		and player_one_score > player_two_score
		and not bool(next[MULTIPLAYER_QUALIFIED_KEY])
	):
		next[MULTIPLAYER_QUALIFIED_KEY] = true
		multiplayer_qualified_now = true

	var unlocked_now := false
	if (
		not bool(next[UNLOCKED_KEY])
		and (
			bool(next[SOLO_QUALIFIED_KEY])
			or bool(next[MULTIPLAYER_QUALIFIED_KEY])
		)
	):
		next[UNLOCKED_KEY] = true
		unlocked_now = true

	return {
		"state": next,
		"changed": solo_qualified_now or multiplayer_qualified_now or unlocked_now,
		"solo_qualified_now": solo_qualified_now,
		"multiplayer_qualified_now": multiplayer_qualified_now,
		"unlocked_now": unlocked_now,
	}


static func earns_race_condition(
	single_player: bool,
	player_one_score: int,
	player_two_score: int
) -> bool:
	return (
		not single_player
		and player_two_score >= SCORE_THRESHOLD
		and player_two_score > player_one_score
	)
