class_name DeskCanSawOptions
extends RefCounted

## Setting keys, ranges and bindings owned by Desk-Can-Saw.
##
## The framework stores, clamps and renders these; only this file and the
## game's own scenes decide what they mean. Everything here reaches the player
## through the in-game Settings screen — the Game tab for the numbers, the
## Controls tab for the keys.
##
## Constants only: this class is loaded by headless test scripts before
## autoloads exist, so it must not reference [Settings] or any other singleton.

## Matches the folder name and `games/desk_can_saw/game.gd`.
const GAME_ID := "desk_can_saw"

const ROUND_LENGTH_KEY := "game/slice_round_length"
const CAN_SPEED_KEY := "game/slice_can_speed"
const SPAWN_RATE_KEY := "game/slice_spawn_rate"
const MAX_CANS_KEY := "game/slice_max_cans"
const CHAINSAW_SPEED_KEY := "game/slice_chainsaw_speed"

const MOVE_UP_KEY := "controls/slice_move_up"
const MOVE_DOWN_KEY := "controls/slice_move_down"
const MOVE_LEFT_KEY := "controls/slice_move_left"
const MOVE_RIGHT_KEY := "controls/slice_move_right"

const MOVE_UP_ACTION := &"slice_move_up"
const MOVE_DOWN_ACTION := &"slice_move_down"
const MOVE_LEFT_ACTION := &"slice_move_left"
const MOVE_RIGHT_ACTION := &"slice_move_right"

const MIN_ROUND_LENGTH := 15.0
const MAX_ROUND_LENGTH := 90.0
const MIN_CAN_SPEED := 0.6
const MAX_CAN_SPEED := 1.8
const MIN_SPAWN_RATE := 0.5
const MAX_SPAWN_RATE := 2.0
const MIN_MAX_CANS := 6
const MAX_MAX_CANS := 40
const MIN_CHAINSAW_SPEED := 0.6
const MAX_CHAINSAW_SPEED := 1.6

## The shipped feel: a 30-second round of cans falling and spawning at the rate
## the game was tuned around, with the desk holding a two-dozen-can pile-up.
const DEFAULT_ROUND_LENGTH := 30.0
const DEFAULT_CAN_SPEED := 1.0
const DEFAULT_SPAWN_RATE := 1.0
const DEFAULT_MAX_CANS := 24
const DEFAULT_CHAINSAW_SPEED := 1.0

const HEADING := "Workshop desk · next round"

const TUNABLES: Array[Dictionary] = [
	{
		"key": ROUND_LENGTH_KEY,
		"default": DEFAULT_ROUND_LENGTH,
		"min": MIN_ROUND_LENGTH,
		"max": MAX_ROUND_LENGTH,
		"step": 1.0,
		"title": "Round length",
		"description": "Sets the base round length before any extra time.",
		"format": GameManifest.FORMAT_SECONDS,
		"heading": HEADING,
	},
	{
		"key": CAN_SPEED_KEY,
		"default": DEFAULT_CAN_SPEED,
		"min": MIN_CAN_SPEED,
		"max": MAX_CAN_SPEED,
		"step": 0.05,
		"title": "Can fall speed",
		"description": "Sets how fast cans drop toward the desk next round.",
		"format": GameManifest.FORMAT_PERCENT,
		"heading": HEADING,
	},
	{
		"key": SPAWN_RATE_KEY,
		"default": DEFAULT_SPAWN_RATE,
		"min": MIN_SPAWN_RATE,
		"max": MAX_SPAWN_RATE,
		"step": 0.05,
		"title": "Can spawn rate",
		"description": "Sets how often a new can is thrown onto the desk.",
		"format": GameManifest.FORMAT_PERCENT,
		"heading": HEADING,
	},
	{
		"key": MAX_CANS_KEY,
		"default": DEFAULT_MAX_CANS,
		"min": float(MIN_MAX_CANS),
		"max": float(MAX_MAX_CANS),
		"step": 1.0,
		"title": "Cans on the desk",
		"description": "Caps how many cans can be falling at the same time.",
		"format": GameManifest.FORMAT_COUNT,
		"heading": HEADING,
	},
	{
		"key": CHAINSAW_SPEED_KEY,
		"default": DEFAULT_CHAINSAW_SPEED,
		"min": MIN_CHAINSAW_SPEED,
		"max": MAX_CHAINSAW_SPEED,
		"step": 0.05,
		"title": "Chainsaw speed",
		"description": "Sets how fast a keyboard or controller chainsaw moves.",
		"format": GameManifest.FORMAT_PERCENT,
		"heading": HEADING,
	},
]

## The keyboard chainsaw. Whoever is on the keyboard drives it — Player 1 in a
## solo round, Player 2 when the mouse is taken — so the bindings are declared
## as shared rather than owned by a player number.
const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": MOVE_UP_KEY,
		"action": MOVE_UP_ACTION,
		"default": KEY_UP,
		"title": "Move up",
		"movement": true,
		"heading": "Keyboard chainsaw",
	},
	{
		"key": MOVE_DOWN_KEY,
		"action": MOVE_DOWN_ACTION,
		"default": KEY_DOWN,
		"title": "Move down",
		"movement": true,
		"heading": "Keyboard chainsaw",
	},
	{
		"key": MOVE_LEFT_KEY,
		"action": MOVE_LEFT_ACTION,
		"default": KEY_LEFT,
		"title": "Move left",
		"movement": true,
		"heading": "Keyboard chainsaw",
	},
	{
		"key": MOVE_RIGHT_KEY,
		"action": MOVE_RIGHT_ACTION,
		"default": KEY_RIGHT,
		"title": "Move right",
		"movement": true,
		"heading": "Keyboard chainsaw",
	},
]
