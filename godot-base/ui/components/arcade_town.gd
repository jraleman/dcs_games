extends Node3D

## Original Compatibility meshes for a catalog-sized town. No game scenes run
## here: storefronts borrow only manifest branding, never gameplay or save state.

signal game_approached(id: String)

const WALK_SPEED := 6.0
const DOOR_REACH := 2.4
const SHOP_PITCH := Vector2(11.0, 13.0)
const CAMERA_OFFSET := Vector3(15.0, 23.0, 18.0)
const SPAWN := Vector3(0.0, 0.0, 12.0)
const SHOP_PROFILES := [
	{"style": &"gable", "height": 3.55, "roof": Color("a96850")},
	{"style": &"deco", "height": 4.45, "roof": Color("536b76")},
	{"style": &"dome", "height": 3.35, "roof": Color("668f89")},
	{"style": &"sawtooth", "height": 3.85, "roof": Color("65767e")},
	{"style": &"clocktower", "height": 3.95, "roof": Color("826654")},
	{"style": &"diner", "height": 3.15, "roof": Color("778d91")},
	{"style": &"butterfly", "height": 3.65, "roof": Color("6b8090")},
]

var _shops: Dictionary[String, Node3D] = {}
var _doors: Dictionary[String, Vector3] = {}
var _statuses: Dictionary[String, Label3D] = {}
var _locks: Dictionary[String, Node3D] = {}
var _shop_materials: Dictionary[String, Array] = {}
var _shop_bounds: Dictionary[String, AABB] = {}
var _faded: Dictionary[String, bool] = {}
var _box_meshes: Dictionary[Vector3, BoxMesh] = {}
var _walker: CharacterBody3D
var _mascot: Node3D
var _limbs: Array[Node3D] = []
var _camera: Camera3D
var _destination: Node3D
var _walk_input := Vector2.ZERO
var _nearby_id := ""
var _bounds := Rect2()
var _reduced_motion := false
var _stride := 0.0
var _stone: StandardMaterial3D
var _ink: StandardMaterial3D
var _cream: StandardMaterial3D
var _grass: StandardMaterial3D
var _foliage: StandardMaterial3D
var _wood: StandardMaterial3D


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("bedde0")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce9ec")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)
	_camera = Camera3D.new()
	_camera.name = "TownCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 23.0
	_camera.far = 150.0
	add_child(_camera)
	_camera.current = true
	set_physics_process(false)


## The catalog supplies order and identity; adding a game needs no town edit.
func configure(manifests: Array[GameManifest]) -> void:
	assert(_walker == null, "ArcadeTown is configured once per visit.")
	_stone = _material(Color("d8d1bc"))
	_ink = _material(Color("263e48"))
	_cream = _material(Color("f6ead3"))
	_grass = _material(Color("89b79a"))
	_foliage = _material(Color("65947d"))
	_wood = _material(Color("ad8462"))
	var columns := mini(4, maxi(1, ceili(sqrt(float(manifests.size())))))
	var rows := maxi(1, ceili(float(manifests.size()) / columns))
	var width := columns * SHOP_PITCH.x + 8.0
	_bounds = Rect2(-width * 0.5, -rows * SHOP_PITCH.y - 1.0,
		width, rows * SHOP_PITCH.y + 17.0)
	_build_streets(columns, rows)
	for index in manifests.size():
		var at := Vector3(
			(index % columns - (columns - 1) * 0.5) * SHOP_PITCH.x,
			0.0, -7.0 - (index / columns) * SHOP_PITCH.y
		)
		_build_shop(manifests[index], index, at)
	_build_plaza()
	_build_walker()
	_destination = Node3D.new()
	_destination.name = "Destination"
	add_child(_destination)
	_cylinder(_destination, 1.0, 0.045, Vector3(0, 0.08, 0),
		_material(Color("f6c76c")))
	_cylinder(_destination, 0.79, 0.05, Vector3(0, 0.1, 0), _stone)
	var beacon := _label(_destination, "HERE", Vector3(0, 3.0, 0), 56)
	beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	beacon.no_depth_test = true
	_destination.hide()
	_follow_camera(0.0, true)
	set_physics_process(true)


## Movement is screen-relative even though the streets run in world X/Z.
func set_walk_input(direction: Vector2) -> void:
	_walk_input = direction.limit_length()


## Essential walking remains; bob, limb swing and camera easing do not.
func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	if _mascot != null and enabled:
		_pose_walker(false, 0.0)
		_follow_camera(0.0, true)


## Door shutters and words carry lock state independently of their colours.
func set_game_open(id: String, is_open: bool) -> void:
	assert(_statuses.has(id), "Only catalog storefronts can change status.")
	_statuses[id].text = "OPEN" if is_open else "LOCKED"
	_statuses[id].modulate = Color("effce9") if is_open else Color("ffe0ad")
	_locks[id].visible = not is_open


## Returning from setup restores the chosen doorstep, not an unlocked mode flag.
func stand_at_game(id: String) -> void:
	_walker.position = door_position(id) + Vector3(0, 0, 0.9)
	_walk_input = Vector2.ZERO
	_walker.velocity = Vector3.ZERO
	_follow_camera(0.0, true)
	_update_nearby()


## A directory choice marks a door; it never teleports or launches the player.
func mark_destination(id: String) -> void:
	_destination.visible = not id.is_empty()
	if not id.is_empty():
		_destination.position = door_position(id)


## Shared by proximity, wayfinding and the menu's final launch recheck.
func door_position(id: String) -> Vector3:
	assert(_doors.has(id), "A destination must belong to this town.")
	return _doors[id]


## Read-only position for the directory's distance hint.
func walker_position() -> Vector3:
	return _walker.position


## A fixed-angle compass uses the same screen axes as walking.
func direction_to_game(id: String) -> Vector2:
	var delta := door_position(id) - _walker.position
	var down := Vector3(CAMERA_OFFSET.x, 0, CAMERA_OFFSET.z).normalized()
	return Vector2(delta.dot(Vector3(down.z, 0, -down.x)), delta.dot(down))


## Recomputed from actual physics position, so a stale prompt cannot launch remotely.
func nearby_game() -> String:
	var nearest := ""
	var distance := DOOR_REACH * DOOR_REACH
	for id in _doors:
		var squared := _walker.position.distance_squared_to(_doors[id])
		if squared < distance:
			nearest = id
			distance = squared
	return nearest


## Match the real viewport rather than rendering a desktop canvas on a phone.
func fit_camera(aspect: float) -> void:
	_camera.size = clampf(24.0 / sqrt(maxf(aspect, 0.2)), 20.0, 35.0)


func _physics_process(delta: float) -> void:
	var down := Vector3(CAMERA_OFFSET.x, 0, CAMERA_OFFSET.z).normalized()
	var right := Vector3(down.z, 0, -down.x)
	var direction := right * _walk_input.x + down * _walk_input.y
	_walker.velocity = direction * WALK_SPEED
	_walker.move_and_slide()
	_walker.position.x = clampf(
		_walker.position.x, _bounds.position.x + 0.6, _bounds.end.x - 0.6
	)
	_walker.position.z = clampf(
		_walker.position.z, _bounds.position.y + 0.6, _bounds.end.y - 0.6
	)
	var moving := _walker.get_real_velocity().length_squared() > 0.02
	if direction.length_squared() > 0.001:
		var heading := atan2(direction.x, direction.z)
		_mascot.rotation.y = heading if _reduced_motion else lerp_angle(
			_mascot.rotation.y, heading, 1.0 - exp(-18.0 * delta)
		)
	_pose_walker(moving, delta)
	_follow_camera(delta)
	_update_nearby()
	_update_occlusion()


func _update_nearby() -> void:
	var id := nearby_game()
	if id != _nearby_id:
		_nearby_id = id
		game_approached.emit(id)


func _follow_camera(delta: float, snap := false) -> void:
	var target := _walker.position + Vector3(0, 1.0, 0)
	var desired := target + CAMERA_OFFSET
	_camera.position = desired if snap or _reduced_motion else _camera.position.lerp(
		desired, 1.0 - exp(-12.0 * delta)
	)
	# Translation only: the isometric angle never rotates as the character walks.
	_camera.rotation = Vector3(-atan2(CAMERA_OFFSET.y,
		Vector2(CAMERA_OFFSET.x, CAMERA_OFFSET.z).length()),
		atan2(CAMERA_OFFSET.x, CAMERA_OFFSET.z), 0)


func _update_occlusion() -> void:
	var target := _walker.position + Vector3.UP
	for id in _shop_bounds:
		var faded := _shop_bounds[id].intersects_segment(_camera.position, target) != null
		if faded == _faded.get(id, false):
			continue
		_faded[id] = faded
		for material: StandardMaterial3D in _shop_materials[id]:
			material.transparency = (
				BaseMaterial3D.TRANSPARENCY_ALPHA if faded
				else BaseMaterial3D.TRANSPARENCY_DISABLED
			)
			material.albedo_color.a = 0.16 if faded else 1.0


func _build_streets(columns: int, rows: int) -> void:
	var center := _bounds.get_center()
	var area := Vector3(_bounds.size.x, 0.45, _bounds.size.y)
	_box(self, area + Vector3(1, 0, 1), Vector3(center.x, -0.5, center.y), _ink)
	_box(self, area, Vector3(center.x, -0.23, center.y), _grass)
	var road := _material(Color("607e83"))
	var joint := _material(Color("b4b5a4"))
	var light := _material(Color("fff0bc"))
	for row in rows:
		var street := Node3D.new()
		street.name = "Street_%02d" % row
		add_child(street)
		var z := -0.5 - row * SHOP_PITCH.y
		_box(street, Vector3(_bounds.size.x - 2, 0.04, 3.4),
			Vector3(0, 0.035, z), road)
		for side: float in [-1.0, 1.0]:
			_box(street, Vector3(_bounds.size.x - 2, 0.065, 1.8),
				Vector3(0, 0.025, z + side * 2.65), _stone)
			_box(street, Vector3(_bounds.size.x - 2, 0.03, 0.12),
				Vector3(0, 0.065, z + side * 1.8), _cream)
			_tree(street,
				Vector3(side * (_bounds.size.x * 0.5 - 2.1), 0, z + 1.9), row)
		for column in columns:
			var x := (column - (columns - 1) * 0.5) * SHOP_PITCH.x
			_box(street, Vector3(1.1, 0.012, 0.08), Vector3(x, 0.065, z), _cream)
			_lamp(street, Vector3(x + 4.5, 0, z + 2.05), light)
			for tile in 5:
				_box(street, Vector3(0.025, 0.008, 1.6),
					Vector3(x - 4.4 + tile * 2.2, 0.062, z - 2.65), joint)
		for column in columns + 1:
			var x := (column - columns * 0.5) * SHOP_PITCH.x
			for stripe in 5:
				_box(street, Vector3(2.6, 0.012, 0.28),
					Vector3(x, 0.075, z - 1.25 + stripe * 0.62), _cream)
		_batch_geometry(street, true)
	for column in columns + 1:
		var x := (column - columns * 0.5) * SHOP_PITCH.x
		_box(self, Vector3(3.6, 0.04, _bounds.size.y - 2),
			Vector3(x, 0.01, center.y), _stone)
		for side: float in [-1.0, 1.0]:
			_box(self, Vector3(0.07, 0.018, _bounds.size.y - 2),
				Vector3(x + side * 1.7, 0.035, center.y), joint)
	for side: float in [-1.0, 1.0]:
		var x := side * (_bounds.size.x * 0.5 - 0.3)
		var z := center.y
		_box(self, Vector3(0.18, 0.55, _bounds.size.y),
			Vector3(x, 0.27, z), _cream)
		_solid(self, Vector3(0.4, 2, _bounds.size.y),
			Vector3(x, 1, z))
		var end_z := _bounds.position.y if side < 0 else _bounds.end.y
		_box(self, Vector3(_bounds.size.x, 0.55, 0.18),
			Vector3(0, 0.27, end_z), _cream)
		_solid(self, Vector3(_bounds.size.x, 2, 0.4),
			Vector3(0, 1, end_z))
	_batch_geometry(self)


func _build_shop(manifest: GameManifest, index: int, at: Vector3) -> void:
	var shop := Node3D.new()
	shop.name = "Shop_" + manifest.id
	shop.position = at
	add_child(shop)
	_shops[manifest.id] = shop
	_doors[manifest.id] = at + Vector3(0, 0, 4.0)
	var presentation := manifest.theme if manifest.theme != null else GameTheme.studio_default()
	var profile: Dictionary = SHOP_PROFILES[index % SHOP_PROFILES.size()]
	var style: StringName = profile["style"]
	var height := float(profile["height"]) + posmod(manifest.id.hash(), 3) * 0.1
	var accent := _material(presentation.accent.lerp(Color("f6ead3"), 0.14))
	var wall := _material(Color("eee3cf").lerp(presentation.accent, 0.12))
	var dark := _material(presentation.plaque_color.lerp(Color("263e48"), 0.7))
	var glass := _material(Color("648c9b").lerp(presentation.accent, 0.12))
	glass.roughness = 0.35
	var roof_color: Color = profile["roof"]
	var roof := _material(roof_color.lerp(presentation.accent, 0.28))
	var trim := _material(Color("d9b67f").lerp(presentation.accent, 0.12))
	_box(shop, Vector3(7.8, 0.16, 5.85), Vector3(0, 0.1, 0), _stone)
	if style in [&"diner", &"dome"]:
		var body := _profile_mesh(shop, _clipped_rectangle(Vector2(7, 5), 0.55),
			height, Vector3(0, height * 0.5, 0), wall)
		body.rotation.x = PI * 0.5
	else:
		_box(shop, Vector3(7, height, 5), Vector3(0, height * 0.5, 0), wall)
	_box(shop, Vector3(7.15, 0.42, 5.12), Vector3(0, 0.39, 0), roof)
	for side: float in [-1.0, 1.0]:
		_box(shop, Vector3(0.18, height, 0.2),
			Vector3(side * 3.35, height * 0.5, 2.53), trim)
	_box(shop, Vector3(7.25, 0.14, 5.2), Vector3(0, height - 0.12, 0), trim)
	_solid(shop, Vector3(7.1, height + 1.5, 5.2), Vector3(0, height * 0.5, 0))
	_build_roof(shop, style, height, [wall, roof, accent, trim, dark, glass])
	for side: float in [-1.0, 1.0]:
		_build_window(shop, style, Vector3(side * 2.2, 1.65, 2.59),
			[dark, glass, trim, wall])
		_box(shop, Vector3(0.82, 0.48, 0.64), Vector3(side * 3.0, 0.38, 3.05), roof)
		for slat in 3:
			_box(shop, Vector3(0.85, 0.055, 0.67),
				Vector3(side * 3, 0.22 + slat * 0.16, 3.05), trim)
		_sphere(shop, Vector3(0.46, 0.3, 0.35),
			Vector3(side * 3, 0.76, 3.05), _foliage)
		for flower in 3:
			_sphere(shop, Vector3.ONE * 0.105,
				Vector3(side * 3 - 0.25 + flower * 0.25, 0.99, 3.1), accent)
		_solid(shop, Vector3(0.85, 1.1, 0.7), Vector3(side * 3, 0.6, 3.05))
	_box(shop, Vector3(1.45, 2.35, 0.16), Vector3(0, 1.2, 2.56), dark)
	_box(shop, Vector3(1.14, 2.08, 0.08), Vector3(0, 1.2, 2.68), glass)
	_box(shop, Vector3(1.1, 0.07, 0.06), Vector3(0, 0.89, 2.74), trim)
	_box(shop, Vector3(0.1, 0.28, 0.07), Vector3(0.37, 1.08, 2.76), accent)
	_build_canopy(shop, style, [roof, accent, wall, trim])
	var sign_y := height + (0.65 if style == &"diner" else 0.35)
	if style == &"deco":
		sign_y = height - 0.05
	var sign_shape := _clipped_rectangle(Vector2(7.55, 1.35), 0.19)
	if style == &"diner":
		sign_shape = PackedVector2Array([
			Vector2(-3.75, -0.68), Vector2(2.95, -0.68),
			Vector2(3.95, 0), Vector2(2.95, 0.68), Vector2(-3.75, 0.68),
		])
	for side: float in [-1.0, 1.0]:
		_box(shop, Vector3(0.18, 0.18, 0.7),
			Vector3(side * 3.1, sign_y, 2.8), trim)
	_profile_mesh(shop, sign_shape, 0.3, Vector3(0, sign_y, 3.06), trim)
	var inset_shape := Transform2D(0.0, Vector2.ZERO).scaled(
		Vector2(0.965, 0.84)) * sign_shape
	_profile_mesh(shop, inset_shape, 0.08, Vector3(0, sign_y, 3.26), dark)
	if style == &"deco":
		for bulb in 13:
			for side: float in [-1.0, 1.0]:
				_box(shop, Vector3.ONE * 0.09,
					Vector3(-3.35 + bulb * 0.56, sign_y + side * 0.61, 3.28), wall)
	var title := _label(shop, manifest.title,
		Vector3(0.65, sign_y, 3.32), 62)
	title.width = 530
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.pixel_size = 0.008
	var cover := presentation.cover_texture()
	var texture := cover if cover != null else presentation.logo_texture()
	if texture != null:
		var logo := Sprite3D.new()
		logo.texture = texture
		logo.modulate = Color.WHITE if cover != null else presentation.logo_color
		logo.pixel_size = 1.02 / maxf(texture.get_width(), texture.get_height())
		logo.position = Vector3(-2.85, sign_y, 3.33)
		shop.add_child(logo)
		_box(shop, Vector3(0.12, 2.15, 2.15), Vector3(3.55, 1.9, -0.55), trim)
		_box(shop, Vector3(0.1, 1.95, 1.95), Vector3(3.64, 1.9, -0.55), dark)
		var poster := logo.duplicate() as Sprite3D
		poster.position = Vector3(3.71, 1.9, -0.55)
		poster.rotation.y = PI * 0.5
		poster.pixel_size *= 1.7
		shop.add_child(poster)
	_label(shop, "%02d" % (index + 1), Vector3(-0.91, 1.8, 2.73), 36)
	var status := _label(shop, "OPEN", Vector3(0, 0.4, 2.8), 34)
	_statuses[manifest.id] = status
	var shutter := Node3D.new()
	shop.add_child(shutter)
	for bar in 3:
		_box(shutter, Vector3(1.2, 0.12, 0.12),
			Vector3(0, 0.8 + bar * 0.48, 2.82), _cream)
	shutter.hide()
	_locks[manifest.id] = shutter
	_box(shop, Vector3(2.2, 0.06, 1.1), Vector3(0, 0.07, 3.8), accent)
	_shop_bounds[manifest.id] = shop.transform * _facade_bounds(shop)
	_shop_materials[manifest.id] = _batch_geometry(shop)


func _build_roof(
	shop: Node3D, style: StringName, height: float,
	materials: Array[StandardMaterial3D]
) -> void:
	var wall := materials[0]
	var roof := materials[1]
	var accent := materials[2]
	var trim := materials[3]
	var dark := materials[4]
	var glass := materials[5]
	_box(shop, Vector3(7.6, 0.18, 5.55), Vector3(0, height + 0.04, 0), roof)
	match style:
		&"gable":
			_profile_mesh(shop, PackedVector2Array([
				Vector2(-3.8, 0), Vector2(3.8, 0), Vector2(0, 1.85),
			]), 5.4, Vector3(0, height, 0), wall)
			for side: float in [-1.0, 1.0]:
				var slope := _box(shop, Vector3(4.43, 0.18, 5.9),
					Vector3(side * 2, height + 0.95, 0), roof)
				slope.rotation.z = side * -atan2(1.9, 4.0)
				_bar(shop, Vector3(side * 4, height, 3.01),
					Vector3(0, height + 1.9, 3.01), 0.12, 0.16, trim)
			_disc(shop, 0.46, 0.1, Vector3(0, height + 1.14, 2.77), trim)
			_disc(shop, 0.32, 0.12, Vector3(0, height + 1.14, 2.84), glass)
			_box(shop, Vector3(0.7, 1.8, 0.75),
				Vector3(-2.1, height + 1.45, -1.15), wall)
			_box(shop, Vector3(0.9, 0.2, 0.95),
				Vector3(-2.1, height + 2.35, -1.15), roof)
		&"deco":
			for tier in 3:
				_box(shop, Vector3(6.7 - tier * 1.4, 0.65, 4.5 - tier * 0.8),
					Vector3(0, height + 0.4 + tier * 0.6, -0.25), roof)
				_box(shop, Vector3(6.8 - tier * 1.4, 0.1, 4.6 - tier * 0.8),
					Vector3(0, height + 0.74 + tier * 0.6, -0.25), trim)
			_box(shop, Vector3(1.15, 2.7, 1.3),
				Vector3(0, height + 1.15, -0.35), accent)
			for side: float in [-1.0, 1.0]:
				for fin in 3:
					_box(shop, Vector3(0.13, 1.2 - fin * 0.23, 0.3),
						Vector3(side * (2.65 + fin * 0.3),
							height + 0.3 - fin * 0.12, 2.65), trim)
			_box(shop, Vector3(1.5, 0.16, 1.55),
				Vector3(0, height + 2.55, -0.35), trim)
		&"dome":
			_sphere(shop, Vector3(3.65, 1.85, 2.65),
				Vector3(0, height + 0.15, 0), roof)
			var orbit := _ring(shop, 3.9, 4.03,
				Vector3(0, height + 0.8, 0), trim)
			orbit.scale.z = 0.76
			orbit.rotation_degrees.z = 17
			_cylinder(shop, 0.1, 0.65, Vector3(0, height + 2.1, 0), trim)
			_sphere(shop, Vector3.ONE * 0.19,
				Vector3(0, height + 2.5, 0), accent)
		&"sawtooth":
			_profile_mesh(shop, PackedVector2Array([
				Vector2(-3.95, 0), Vector2(3.95, 0), Vector2(3.95, 1.25),
				Vector2(1.3, 0.25), Vector2(1.3, 1.25),
				Vector2(-1.3, 0.25), Vector2(-1.3, 1.25), Vector2(-3.95, 0.25),
			]), 5.65, Vector3(0, height + 0.07, 0), roof)
			for tooth in 3:
				_box(shop, Vector3(0.07, 0.7, 4.9),
					Vector3(-1.25 + tooth * 2.6, height + 0.83, 0), glass)
			for stack in 2:
				var chimney_y := height + 1.55 + stack * 0.3
				_cylinder(shop, 0.23, 2.1,
					Vector3(-2.3 + stack * 1.05, chimney_y, -1.35), trim)
				_cylinder(shop, 0.34, 0.15,
					Vector3(-2.3 + stack * 1.05, chimney_y + 1.05, -1.35), dark)
			for side: float in [-1.0, 1.0]:
				_box(shop, Vector3(0.16, height, 0.25),
					Vector3(side * 3.05, height * 0.5, 2.58), dark)
		&"clocktower":
			_box(shop, Vector3(2.0, 2.7, 2.0),
				Vector3(2.15, height + 1.35, -0.15), wall)
			_box(shop, Vector3(2.3, 0.18, 2.3),
				Vector3(2.15, height + 2.7, -0.15), trim)
			_cylinder(shop, 1.65, 1.2,
				Vector3(2.15, height + 3.35, -0.15), roof, 0.0)
			_disc(shop, 0.72, 0.1, Vector3(2.15, height + 1.7, 0.9), trim)
			_disc(shop, 0.59, 0.12, Vector3(2.15, height + 1.7, 0.98), wall)
			_bar(shop, Vector3(2.15, height + 1.7, 1.06),
				Vector3(2.15, height + 2.12, 1.06), 0.07, 0.04, dark)
			_bar(shop, Vector3(2.15, height + 1.7, 1.07),
				Vector3(2.49, height + 1.55, 1.07), 0.08, 0.04, dark)
			for tick in 4:
				var angle := tick * PI * 0.5
				_box(shop, Vector3(0.08, 0.08, 0.03),
					Vector3(2.15 + sin(angle) * 0.48,
						height + 1.7 + cos(angle) * 0.48, 1.06), dark)
		&"diner":
			var cap := _profile_mesh(shop,
				_clipped_rectangle(Vector2(8.05, 5.85), 0.7),
				0.2, Vector3(0, height + 0.13, 0), trim)
			cap.rotation.x = PI * 0.5
			var inset := _profile_mesh(shop,
				_clipped_rectangle(Vector2(7.6, 5.4), 0.6),
				0.12, Vector3(0, height + 0.32, 0), accent)
			inset.rotation.x = PI * 0.5
			for vent in 3:
				_box(shop, Vector3(0.6, 0.16, 1.15),
					Vector3(-1.1 + vent * 1.1, height + 0.48, -0.8), roof)
			for band in 3:
				_box(shop, Vector3(7.2, 0.055, 5.18),
					Vector3(0, 0.65 + band * 0.15, 0), trim)
		&"butterfly":
			for side: float in [-1.0, 1.0]:
				var wing := _box(shop, Vector3(4.25, 0.22, 5.9),
					Vector3(side * 2, height + 0.75, 0), roof)
				wing.rotation.z = side * 0.23
				_bar(shop, Vector3(0, height + 0.28, 3.04),
					Vector3(side * 4.1, height + 1.23, 3.04), 0.12, 0.16, trim)
			_box(shop, Vector3(0.3, 0.3, 5.8),
				Vector3(0, height + 0.35, 0), accent)
			for side: float in [-1.0, 1.0]:
				_box(shop, Vector3(0.18, height + 1.1, 0.22),
					Vector3(side * 3.35, (height + 1.1) * 0.5, 2.53), trim)


func _build_window(
	shop: Node3D, style: StringName, at: Vector3,
	materials: Array[StandardMaterial3D]
) -> void:
	var dark := materials[0]
	var glass := materials[1]
	var trim := materials[2]
	var glint := materials[3]
	if style == &"dome":
		_disc(shop, 0.94, 0.14, at, trim)
		_disc(shop, 0.78, 0.16, at + Vector3(0, 0, 0.06), glass)
		for side: float in [-1.0, 1.0]:
			_box(shop, Vector3(0.08, 0.08, 0.05),
				at + Vector3(side * 0.86, 0, 0.12), dark)
		_bar(shop, at + Vector3(-0.3, 0.1, 0.17),
			at + Vector3(0.02, 0.48, 0.17), 0.07, 0.03, glint)
		return
	var dimensions := Vector2(1.8, 1.65)
	if style in [&"diner", &"sawtooth"]:
		dimensions = Vector2(2.0, 1.2)
	var cut := 0.32 if style in [&"deco", &"clocktower"] else 0.06
	_profile_mesh(shop, _clipped_rectangle(dimensions, cut), 0.14, at, dark)
	_profile_mesh(shop, _clipped_rectangle(dimensions - Vector2.ONE * 0.2,
		cut * 0.8), 0.1, at + Vector3(0, 0, 0.11), glass)
	_box(shop, Vector3(0.07, dimensions.y - 0.15, 0.05),
		at + Vector3(0, 0, 0.19), trim)
	if style not in [&"diner", &"sawtooth"]:
		_box(shop, Vector3(dimensions.x - 0.15, 0.07, 0.05),
			at + Vector3(0, 0, 0.19), trim)
	_bar(shop, at + Vector3(-0.54, 0.05, 0.2),
		at + Vector3(-0.25, dimensions.y * 0.34, 0.2), 0.065, 0.025, glint)
	_box(shop, Vector3(dimensions.x + 0.16, 0.1, 0.32),
		at + Vector3(0, -dimensions.y * 0.5 - 0.04, 0.03), trim)


func _build_canopy(
	shop: Node3D, style: StringName, materials: Array[StandardMaterial3D]
) -> void:
	var roof := materials[0]
	var accent := materials[1]
	var wall := materials[2]
	var trim := materials[3]
	if style in [&"dome", &"clocktower"]:
		_box(shop, Vector3(2.9, 0.2, 1.6), Vector3(0, 2.85, 3.15), roof)
		for side: float in [-1.0, 1.0]:
			_box(shop, Vector3(0.18, 2.65, 0.18),
				Vector3(side * 1.2, 1.4, 3.55), trim)
			_box(shop, Vector3(0.33, 0.14, 0.33),
				Vector3(side * 1.2, 2.65, 3.55), wall)
			_solid(shop, Vector3(0.2, 2.7, 0.2),
				Vector3(side * 1.2, 1.4, 3.55))
		return
	var canopy := _box(shop, Vector3(7.6, 0.18, 1.65),
		Vector3(0, 2.8, 3.05), roof)
	canopy.rotation.x = 0.08
	if style == &"gable":
		for stripe in 9:
			var canvas := _box(shop, Vector3(0.82, 0.035, 1.65),
				Vector3(-3.36 + stripe * 0.84, 2.905, 3.05),
				accent if stripe % 2 == 0 else wall)
			canvas.rotation.x = 0.08
			_box(shop, Vector3(0.82, 0.22, 0.12),
				Vector3(-3.36 + stripe * 0.84, 2.65, 3.89),
				accent if stripe % 2 == 0 else wall)
	else:
		_box(shop, Vector3(7.7, 0.12, 0.14), Vector3(0, 2.76, 3.9), accent)
		_box(shop, Vector3(7.7, 0.07, 0.15), Vector3(0, 2.64, 3.9), trim)
	if style in [&"gable", &"sawtooth", &"butterfly"]:
		for side: float in [-1.0, 1.0]:
			_box(shop, Vector3(0.12, 2.55, 0.12),
				Vector3(side * 3.4, 1.35, 3.6), trim)
			_solid(shop, Vector3(0.16, 2.7, 0.16),
				Vector3(side * 3.4, 1.35, 3.6))


func _facade_bounds(shop: Node3D) -> AABB:
	var bounds := AABB()
	for child in shop.get_children():
		var instance := child as MeshInstance3D
		if instance == null:
			continue
		var drawn := instance.transform * instance.get_aabb()
		if drawn.end.y > 1.4:
			bounds = bounds.merge(drawn)
	return bounds


func _batch_geometry(
	parent: Node3D, recursive := false
) -> Array[StandardMaterial3D]:
	# Vertex paint joins colour changes without losing the windows' glossier finish.
	# Shop shutters stay separate; static street districts can be baked recursively.
	var surfaces: Dictionary[float, SurfaceTool] = {}
	var children := parent.get_children()
	if recursive:
		children = parent.find_children("*", "MeshInstance3D", true, false)
	for child in children:
		var instance := child as MeshInstance3D
		if instance == null:
			continue
		var material := instance.material_override as StandardMaterial3D
		assert(material != null, "Town geometry requires an explicit material.")
		assert(material.albedo_texture == null, "Town baking expects untextured geometry.")
		var finish := material.roughness
		if not surfaces.has(finish):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[finish] = surface
		var placement := instance.transform
		if instance.get_parent() != parent:
			placement = parent.global_transform.affine_inverse() * instance.global_transform
		for surface_index in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colours := PackedColorArray()
			colours.resize(vertices.size())
			colours.fill(material.albedo_color)
			arrays[Mesh.ARRAY_COLOR] = colours
			var painted := ArrayMesh.new()
			painted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			surfaces[finish].append_from(painted, 0, placement)
		instance.get_parent().remove_child(instance)
		instance.queue_free()
	var materials: Array[StandardMaterial3D] = []
	for finish in surfaces:
		surfaces[finish].index()
		var material := _material(Color.WHITE)
		material.roughness = finish
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		materials.append(material)
		_mesh(parent, surfaces[finish].commit(), Vector3.ZERO, material)
	return materials


func _build_plaza() -> void:
	var plaza := Node3D.new()
	plaza.name = "Plaza"
	add_child(plaza)
	var gold := _material(Color("d9b16c"))
	var water := _material(Color("68adb7"))
	var ripple := _material(Color("a2d4d1"))
	_cylinder(plaza, 9.3, 0.07, Vector3(0, 0.02, 6), _ink)
	_cylinder(plaza, 9.05, 0.075, Vector3(0, 0.035, 6), _stone)
	var border := _ring(plaza, 8.55, 8.7, Vector3(0, 0.09, 6), _cream)
	border.scale.y = 0.15
	for spoke in 16:
		var angle := spoke * TAU / 16.0
		var seam := _box(plaza, Vector3(0.035, 0.008, 5.6),
			Vector3(sin(angle) * 5.55, 0.077, 6 + cos(angle) * 5.55), _cream)
		seam.rotation.y = angle
	_cylinder(plaza, 2.65, 0.15, Vector3(0, 0.16, 6), _ink)
	_cylinder(plaza, 2.5, 0.34, Vector3(0, 0.33, 6), _cream)
	_cylinder(plaza, 2.22, 0.035, Vector3(0, 0.52, 6), water)
	_ring(plaza, 2.18, 2.5, Vector3(0, 0.49, 6), _cream)
	for radius in [1.2, 1.75]:
		var wave := _ring(plaza, radius, radius + 0.025,
			Vector3(0, 0.55, 6), ripple)
		wave.scale.y = 0.3
	_cylinder(plaza, 0.7, 0.2, Vector3(0, 0.65, 6), gold)
	_cylinder(plaza, 0.48, 1.1, Vector3(0, 1.15, 6), _ink)
	_cylinder(plaza, 0.64, 0.18, Vector3(0, 1.71, 6), gold)
	var sculpture := _box(plaza, Vector3(1.2, 1.2, 1.2),
		Vector3(0, 2.35, 6), gold)
	sculpture.rotation_degrees = Vector3(0, 35, 15)
	var crown := _box(plaza, Vector3(0.48, 0.48, 0.48),
		Vector3(0.12, 3.16, 6), _cream)
	crown.rotation_degrees = Vector3(0, 35, -15)
	var plinth := StaticBody3D.new()
	add_child(plinth)
	var shape := CylinderShape3D.new()
	shape.radius = 2.5
	shape.height = 2.5
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 1.0, 6)
	plinth.add_child(collision)
	for side: float in [-1.0, 1.0]:
		var bench := Node3D.new()
		bench.position = Vector3(side * 6.6, 0, 7.7)
		plaza.add_child(bench)
		for slat in 4:
			_box(bench, Vector3(2.6, 0.09, 0.14),
				Vector3(0, 0.67, -0.3 + slat * 0.19), _wood)
		for slat in 3:
			_box(bench, Vector3(2.6, 0.13, 0.1),
				Vector3(0, 0.92 + slat * 0.18, -0.38), _wood)
		for leg in [-0.95, 0.95]:
			_box(bench, Vector3(0.16, 0.6, 0.65), Vector3(leg, 0.3, 0), _ink)
			_box(bench, Vector3(0.1, 0.45, 0.65), Vector3(leg, 0.94, 0), _ink)
		_solid(bench, Vector3(2.6, 1.3, 0.9), Vector3(0, 0.65, 0))
		_tree(plaza, Vector3(side * 10, 0, 12), 2)
		_box(plaza, Vector3(2.1, 0.28, 1.0), Vector3(side * 9.1, 0.2, 7.7), _cream)
		for bush in 3:
			_sphere(plaza, Vector3(0.5, 0.4, 0.4),
				Vector3(side * 9.1 - 0.6 + bush * 0.6, 0.64, 7.7), _foliage)
			_sphere(plaza, Vector3.ONE * 0.12,
				Vector3(side * 9.1 - 0.6 + bush * 0.6, 1.03, 7.7), gold)
		_solid(plaza, Vector3(2.1, 1.1, 1.0), Vector3(side * 9.1, 0.6, 7.7))
	var sign := Node3D.new()
	sign.position = Vector3(7.0, 0, 13.3)
	plaza.add_child(sign)
	_box(sign, Vector3(0.14, 2.4, 0.14), Vector3(0, 1.2, 0), _ink)
	_profile_mesh(sign, _clipped_rectangle(Vector2(4.7, 1.5), 0.23),
		0.2, Vector3(0, 2.5, 0), gold)
	_profile_mesh(sign, _clipped_rectangle(Vector2(4.45, 1.26), 0.16),
		0.08, Vector3(0, 2.5, 0.15), _ink)
	_label(sign, "DCS\nARCADE TOWN", Vector3(0, 2.5, 0.21), 48)
	_batch_geometry(plaza, true)


func _tree(parent: Node3D, at: Vector3, variant: int) -> void:
	var tree := Node3D.new()
	tree.position = at
	parent.add_child(tree)
	_cylinder(tree, 0.9, 0.18, Vector3(0, 0.13, 0), _cream)
	_cylinder(tree, 0.74, 0.12, Vector3(0, 0.25, 0), _foliage)
	_cylinder(tree, 0.23, 1.8, Vector3(0, 0.9, 0), _ink)
	if variant % 3 == 1:
		_cylinder(tree, 1.35, 2.25, Vector3(0, 2.1, 0), _foliage, 0.12)
		_cylinder(tree, 1.02, 1.8, Vector3(0, 3.2, 0), _grass, 0.05)
	else:
		_sphere(tree, Vector3(1.25, 1.35, 1.15), Vector3(0, 2.5, 0), _foliage)
		_sphere(tree, Vector3(0.95, 1.05, 0.95),
			Vector3(0.4, 3.05, 0.1), _grass)
		if variant % 3 == 2:
			_sphere(tree, Vector3(0.8, 0.9, 0.8),
				Vector3(-0.65, 2.8, 0.1), _grass)
	_solid(tree, Vector3(1.7, 2.0, 1.7), Vector3(0, 1.0, 0))


func _lamp(parent: Node3D, at: Vector3, light: StandardMaterial3D) -> void:
	var lamp := Node3D.new()
	lamp.position = at
	parent.add_child(lamp)
	_cylinder(lamp, 0.23, 0.22, Vector3(0, 0.16, 0), _ink)
	_cylinder(lamp, 0.075, 3.25, Vector3(0, 1.7, 0), _ink)
	_box(lamp, Vector3(0.7, 0.1, 0.1), Vector3(-0.25, 3.3, 0), _ink)
	_cylinder(lamp, 0.28, 0.32, Vector3(-0.53, 3.12, 0), light)
	_cylinder(lamp, 0.4, 0.16, Vector3(-0.53, 3.38, 0), _ink, 0.12)
	_box(lamp, Vector3(0.56, 1.0, 0.055), Vector3(0.35, 2.4, 0), _wood)
	_box(lamp, Vector3(0.1, 0.65, 0.07), Vector3(0.35, 2.4, 0.04), _cream)
	_solid(lamp, Vector3(0.5, 3.3, 0.5), Vector3(0, 1.65, 0))


func _build_walker() -> void:
	_walker = CharacterBody3D.new()
	_walker.name = "Walker"
	_walker.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_walker.position = SPAWN
	add_child(_walker)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 2.05
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 1.04
	_walker.add_child(collision)
	_mascot = Node3D.new()
	_mascot.name = "Mascot"
	_mascot.rotation.y = 0.55
	_walker.add_child(_mascot)
	var jacket := _material(Color("63b7cc"))
	var boots := _material(Color("ecab56"))
	_box(_mascot, Vector3(0.82, 0.72, 0.52), Vector3(0, 1.07, 0), jacket)
	_sphere(_mascot, Vector3(0.49, 0.38, 0.38), Vector3(0, 1.72, 0), _cream)
	_box(_mascot, Vector3(0.66, 0.24, 0.12), Vector3(0, 1.74, 0.35), _ink)
	for side: float in [-1.0, 1.0]:
		_sphere(_mascot, Vector3.ONE * 0.055,
			Vector3(side * 0.17, 1.76, 0.43), _cream)
	_box(_mascot, Vector3(0.53, 0.48, 0.26), Vector3(0, 1.13, -0.36), boots)
	_cylinder(_mascot, 0.045, 0.22, Vector3(0, 2.15, 0), _ink)
	_sphere(_mascot, Vector3.ONE * 0.1, Vector3(0, 2.28, 0), boots)
	for index in 4:
		var limb := Node3D.new()
		var side := -1.0 if index % 2 == 0 else 1.0
		var arm := index >= 2
		limb.position = Vector3(side * (0.55 if arm else 0.22),
			1.32 if arm else 0.75, 0)
		_mascot.add_child(limb)
		_limbs.append(limb)
		_box(limb, Vector3(0.23, 0.46, 0.3), Vector3(0, -0.22, 0), jacket)
		_box(limb, Vector3(0.29, 0.22, 0.4),
			Vector3(0, -0.49, 0.05), _cream if arm else boots)
	var marker := _label(_walker, "YOU", Vector3(0, 2.9, 0), 32)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true


func _pose_walker(moving: bool, delta: float) -> void:
	if moving:
		_stride += delta * 11.0
	var swing := sin(_stride) if moving and not _reduced_motion else 0.0
	for index in _limbs.size():
		_limbs[index].rotation.x = swing * (0.42 if index % 2 == 0 else -0.42) \
			* (-0.65 if index >= 2 else 1.0)
	_mascot.position.y = absf(swing) * 0.055


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.metallic_specular = 0.25
	return material


func _clipped_rectangle(size: Vector2, cut: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x + cut, -half.y), Vector2(half.x - cut, -half.y),
		Vector2(half.x, -half.y + cut), Vector2(half.x, half.y - cut),
		Vector2(half.x - cut, half.y), Vector2(-half.x + cut, half.y),
		Vector2(-half.x, half.y - cut), Vector2(-half.x, -half.y + cut),
	])


func _profile_mesh(
	parent: Node3D, outline: PackedVector2Array, depth: float, at: Vector3,
	material: Material
) -> MeshInstance3D:
	var triangles := Geometry2D.triangulate_polygon(outline)
	assert(not triangles.is_empty(), "A town profile must form a simple polygon.")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		surface.set_normal(Vector3(0, 0, side))
		for triangle in range(0, triangles.size(), 3):
			for corner in 3:
				# Geometry2D gives CCW triangles; Godot's front face is clockwise.
				var offset := corner if side < 0 else 2 - corner
				var point := outline[triangles[triangle + offset]]
				surface.set_uv(point * 0.25)
				surface.add_vertex(Vector3(point.x, point.y, side * depth * 0.5))
	for edge_index in outline.size():
		var start := outline[edge_index]
		var end := outline[(edge_index + 1) % outline.size()]
		var edge := end - start
		surface.set_normal(Vector3(edge.y, -edge.x, 0).normalized())
		var vertices: Array[Vector3] = [
			Vector3(start.x, start.y, depth * 0.5),
			Vector3(end.x, end.y, depth * 0.5),
			Vector3(end.x, end.y, -depth * 0.5),
			Vector3(start.x, start.y, -depth * 0.5),
		]
		for corner in [0, 1, 2, 0, 2, 3]:
			var point := vertices[corner]
			surface.set_uv(Vector2(point.x, point.y) * 0.25)
			surface.add_vertex(point)
	surface.index()
	return _mesh(parent, surface.commit(), at, material)


func _bar(
	parent: Node3D, start: Vector3, end: Vector3, width: float, depth: float,
	material: Material
) -> void:
	var direction := end - start
	var instance := _box(parent, Vector3(width, direction.length(), depth),
		(start + end) * 0.5, material)
	instance.rotation.z = -atan2(direction.x, direction.y)


func _box(
	parent: Node3D, dimensions: Vector3, at: Vector3, material: Material
) -> MeshInstance3D:
	if not _box_meshes.has(dimensions):
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		_box_meshes[dimensions] = mesh
	return _mesh(parent, _box_meshes[dimensions], at, material)


func _cylinder(
	parent: Node3D, radius: float, height: float, at: Vector3, material: Material,
	top_radius := -1.0
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return _mesh(parent, mesh, at, material)


func _disc(
	parent: Node3D, radius: float, depth: float, at: Vector3, material: Material
) -> void:
	var disc := _cylinder(parent, radius, depth, at, material)
	disc.rotation.x = PI * 0.5


func _ring(
	parent: Node3D, inner_radius: float, outer_radius: float, at: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 48
	mesh.ring_segments = 8
	return _mesh(parent, mesh, at, material)


func _sphere(
	parent: Node3D, radius: Vector3, at: Vector3, material: Material
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := _mesh(parent, mesh, at, material)
	instance.scale = radius
	return instance


func _mesh(
	parent: Node3D, mesh: Mesh, at: Vector3, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


func _solid(parent: Node3D, dimensions: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = at
	body.add_child(collision)


func _label(parent: Node3D, text: String, at: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = font_size
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = Color("fff4db")
	label.outline_modulate = Color("263e48")
	parent.add_child(label)
	return label
