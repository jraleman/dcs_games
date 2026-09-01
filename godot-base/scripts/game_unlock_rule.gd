class_name GameUnlockRule
extends Resource

## Optional gating for a game in the catalog.
##
## A game with no unlock rule is always playable. A game that must be earned
## ships a subclass that owns its own progression keys and thresholds, so the
## reusable [AchievementManager] never needs to know which game it is gating.
##
## Implementations must be pure: they receive the persisted progression state
## and return a new state, never touching disk or the scene tree.


## Progression flags this rule persists, in `user://achievements.cfg`.
func progression_keys() -> Array[String]:
	return []


## Fills in any missing flags and repairs inconsistent combinations.
func normalized_state(state: Dictionary) -> Dictionary:
	return state.duplicate(true)


func is_unlocked(_state: Dictionary) -> bool:
	return true


## Folds one finished round into [param state].
##
## [param result] is the game-agnostic payload built by [GameCatalog]:
## `single_player`, `player_one_score`, `player_two_score` and
## `multiplayer_result_is_eligible`.
##
## Returns `{ "state": Dictionary, "changed": bool, ... }`; extra keys are
## passed through to callers that want to react to a specific transition.
func apply_result(state: Dictionary, _result: Dictionary) -> Dictionary:
	return {
		"state": normalized_state(state),
		"changed": false,
	}


## Player-facing summary of what is still required, shown on the main menu.
func requirement_text(_state: Dictionary) -> String:
	return ""


## Optional: modes this game may be played in, given [param state]. An empty
## array means the game imposes no per-mode restriction once unlocked.
func unlocked_modes(_state: Dictionary) -> PackedStringArray:
	return PackedStringArray()
