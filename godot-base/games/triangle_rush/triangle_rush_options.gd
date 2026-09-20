class_name TriangleRushOptions
extends RefCounted

## Setting keys and ranges owned by Triangle Rush.
##
## The framework stores and clamps these through [method Settings.tunable];
## only this file and the game's own scenes decide what they mean.
##
## Constants only: this class is loaded by headless test scripts before
## autoloads exist, so it must not reference [Settings] or any other singleton.

## Matches the folder name and `games/triangle_rush/game.gd`.
const GAME_ID := "triangle_rush"

const SIZE_KEY := "game/triangle_size"
const SPEED_KEY := "game/triangle_speed"
const SPEED_RUSH_KEY := "game/triangle_speed_rush"
const ROUND_LENGTH_KEY := "game/triangle_round_length"

const MIN_SIZE := 0.6
const MAX_SIZE := 1.6
const MIN_SPEED := 0.5
const MAX_SPEED := 2.0
const MIN_SPEED_RUSH := 0.0
const MAX_SPEED_RUSH := 1.0
const MIN_ROUND_LENGTH := 15.0
const MAX_ROUND_LENGTH := 90.0

## Score Player 2 must reach, while beating Player 1, to earn Race condition.
## It lives beside the tunables rather than in the gameplay scene for the same
## reason they do: a headless test can import the number without an autoload.
const RACE_CONDITION_SCORE := 25

## Triangles ship large and slow: a 150% target that drifts at half speed is
## far easier to read and to aim at than the original 100%/100% pairing.
const DEFAULT_SIZE := 1.5
const DEFAULT_SPEED := 0.5
const DEFAULT_SPEED_RUSH := 0.35
const DEFAULT_ROUND_LENGTH := 30.0

## Declared on the manifest so [Settings] can register the keys at boot and the
## in-game Settings → Game tab can build a row for each one.
const TUNABLES: Array[Dictionary] = [
	{
		"key": SIZE_KEY,
		"default": DEFAULT_SIZE,
		"min": MIN_SIZE,
		"max": MAX_SIZE,
		"step": 0.05,
		"title": "Triangle size",
		"description": "Sets the base Triangle Rush target size next round.",
		"format": GameManifest.FORMAT_PERCENT,
		"heading": "Triangle Rush · next round",
	},
	{
		"key": SPEED_KEY,
		"default": DEFAULT_SPEED,
		"min": MIN_SPEED,
		"max": MAX_SPEED,
		"step": 0.05,
		"title": "Triangle speed",
		"description": "Sets how fast Triangle Rush targets drift next round.",
		"format": GameManifest.FORMAT_PERCENT,
		"heading": "Triangle Rush · next round",
	},
	{
		"key": SPEED_RUSH_KEY,
		"default": DEFAULT_SPEED_RUSH,
		"min": MIN_SPEED_RUSH,
		"max": MAX_SPEED_RUSH,
		"step": 0.05,
		"title": "Final-stretch speed rush",
		"description": "Extra target speed added as the round timer runs out.",
		"format": GameManifest.FORMAT_PLUS_PERCENT,
		"heading": "Triangle Rush · next round",
	},
	{
		"key": ROUND_LENGTH_KEY,
		"default": DEFAULT_ROUND_LENGTH,
		"min": MIN_ROUND_LENGTH,
		"max": MAX_ROUND_LENGTH,
		"step": 1.0,
		"title": "Round length",
		"description": (
			"Sets the base Triangle Rush round length before any extra time."
		),
		"format": GameManifest.FORMAT_SECONDS,
		"heading": "Triangle Rush · next round",
	},
]
