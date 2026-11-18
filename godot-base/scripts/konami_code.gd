extends RefCounted

## A title-local sequence, not a saved unlock or a change to the input map.
## Direction keys still navigate menus; only the final B/A are intercepted.

enum Result { PASS, CONSUME, COMPLETE }

const SEQUENCE := [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT,
	KEY_RIGHT, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_A,
]
const PREFIX_LENGTHS := [0, 1, 0, 0, 0, 0, 0, 0, 0, 0]
const PAD_KEYS := {
	JOY_BUTTON_DPAD_UP: KEY_UP,
	JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
	JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
	JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
	JOY_BUTTON_B: KEY_B,
	JOY_BUTTON_A: KEY_A,
}

var _position := 0


## No time limit: deliberate, slower entry must work just as well as fast entry.
func feed(event: InputEvent) -> Result:
	var key := 0
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return Result.PASS
		if event.alt_pressed or event.ctrl_pressed or event.meta_pressed:
			reset()
			return Result.PASS
		key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	elif event is InputEventJoypadButton:
		if not event.pressed:
			return Result.PASS
		key = PAD_KEYS.get(event.button_index, 0)
	elif (event is InputEventMouseButton or event is InputEventScreenTouch) \
		and event.is_pressed():
		reset()
		return Result.PASS
	else:
		return Result.PASS

	while _position > 0 and key != SEQUENCE[_position]:
		_position = PREFIX_LENGTHS[_position - 1]
	if key == SEQUENCE[_position]:
		_position += 1
	if _position == SEQUENCE.size():
		reset()
		return Result.COMPLETE
	if _position == SEQUENCE.size() - 1:
		return Result.CONSUME
	return Result.PASS


## Leaving the title or losing application focus abandons any partial entry.
func reset() -> void:
	_position = 0
