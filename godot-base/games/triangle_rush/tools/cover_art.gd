extends RefCounted

## Actual target scenes staged as a fast, asymmetric arcade cascade.
const Target = preload("res://games/triangle_rush/triangle_target.tscn")


## Diagonal rhythm replaces the old isolated white symbol.
static func design() -> Dictionary:
	return {
		"paper": Color("101634"), "ink": Color("eaffd9"), "accent": Color("5be3c1"),
		"motif": "speed", "photo": Rect2(0, 330, 1024, 620),
		"lettering": [
			{"text": "TRIANGLE", "at": Vector2(62, 172), "size": 157, "angle": -3},
			{"text": "RUSH", "at": Vector2(58, 356), "size": 215, "color": Color("5be3c1"), "angle": -3},
			{"text": "CHASE THE NEXT HIT.", "at": Vector2(62, 982), "size": 37, "font": "mono"},
		],
	}


## Fixed highlights avoid a random or time-dependent cover.
static func build(parent: Node) -> Node:
	var root := Node2D.new()
	parent.add_child(root)
	var positions := [Vector2(285, 405), Vector2(590, 235), Vector2(855, 95)]
	for index in 3:
		var target := Target.instantiate() as TriangleTarget
		root.add_child(target)
		target.configure(str(index + 1), 0, Color("48627d"), Color("5be3c1"), 0)
		target.set_reduced_motion(true)
		target.set_player_label_visible(false)
		target.set_highlighted(index == 0)
		target._process(1.0)
		target.set_process(false)
		target.position = positions[index]
		target.scale = Vector2.ONE * (2.75 - index * 0.72)
		target.rotation_degrees = -12 + index * 11
	return root
