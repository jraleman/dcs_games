class_name GameUISoundBank
extends Resource

## Optional menu cues. Unset streams retain the framework's corresponding cue.
## A focus stream may be an AudioStreamRandomizer to provide matched variations.
@export var focus: AudioStream
@export var click: AudioStream
@export var back: AudioStream

@export_range(-40.0, 0.0) var focus_volume_db := -4.0
@export_range(-40.0, 0.0) var click_volume_db := 0.0
@export_range(-40.0, 0.0) var back_volume_db := 0.0
@export_range(0, 250, 1) var focus_cooldown_ms := 60
