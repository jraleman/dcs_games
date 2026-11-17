extends RefCounted

## The real electric saw and cans, enlarged into a playful hazard-label composition.
const Saw = preload("res://games/desk_can_saw/chainsaw_cursor.gd")
const Can = preload("res://games/desk_can_saw/slice_can.gd")


## High-contrast workshop printing, not a replacement gameplay palette.
static func design() -> Dictionary:
	return {
		"paper": Color("f5c64c"), "ink": Color("18262b"), "accent": Color("ef7947"),
		"motif": "hazard", "photo": Rect2(0, 335, 1024, 600), "cutout": 3,
		"lettering": [
			{"text": "DESK-CAN", "at": Vector2(56, 168), "size": 160},
			{"text": "SAW", "at": Vector2(52, 356), "size": 233},
			{"text": "MAKE A MESS.", "at": Vector2(560, 298), "width": 400, "size": 43,
				"font": "mono", "angle": -8},
		],
	}


## No motor is powered or given an audio stream during photography.
static func build(parent: Node) -> Node:
	var root := Node2D.new()
	parent.add_child(root)
	var saw := Saw.new()
	root.add_child(saw)
	saw.configure(0, Color("58bad4"))
	saw.set_player_label_visible(false)
	saw.set_process(false)
	saw.position = Vector2(425, 370)
	saw.scale = Vector2.ONE * 3.45
	saw.rotation_degrees = -24
	for index in 3:
		var can := Can.new()
		root.add_child(can)
		can.configure(64 - index * 12, Vector2.ZERO, 0,
			Color("91d6db") if index % 2 == 0 else Color("ffd34e"), 0)
		can.position = [Vector2(760, 150), Vector2(905, 320), Vector2(530, 35)][index]
		can.rotation_degrees = [23, -25, -15][index]
	return root
