class_name TargetRushOptions
extends RefCounted

## Setting keys and ranges owned by Target Rush.
##
## The framework stores and clamps these through [method Settings.tunable];
## only this file and the game's own scenes decide what they mean.
##
## Constants only: this class is loaded by headless test scripts before
## autoloads exist, so it must not reference [Settings] or any other singleton.

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

## Triangles ship large and slow: a 150% target that drifts at half speed is
## far easier to read and to aim at than the original 100%/100% pairing.
const DEFAULT_SIZE := 1.5
const DEFAULT_SPEED := 0.5
const DEFAULT_SPEED_RUSH := 0.35
const DEFAULT_ROUND_LENGTH := 30.0

## Declared on the manifest so [Settings] can register the keys at boot.
const TUNABLES: Array[Dictionary] = [
	{
		"key": SIZE_KEY,
		"default": DEFAULT_SIZE,
		"min": MIN_SIZE,
		"max": MAX_SIZE,
	},
	{
		"key": SPEED_KEY,
		"default": DEFAULT_SPEED,
		"min": MIN_SPEED,
		"max": MAX_SPEED,
	},
	{
		"key": SPEED_RUSH_KEY,
		"default": DEFAULT_SPEED_RUSH,
		"min": MIN_SPEED_RUSH,
		"max": MAX_SPEED_RUSH,
	},
	{
		"key": ROUND_LENGTH_KEY,
		"default": DEFAULT_ROUND_LENGTH,
		"min": MIN_ROUND_LENGTH,
		"max": MAX_ROUND_LENGTH,
	},
]
