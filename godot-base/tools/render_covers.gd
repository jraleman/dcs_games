extends SceneTree

## Rebuild square cartridge art from game-owned tools/cover_art.gd compositions.
## Requires Compatibility graphics. --games=id,id and --output-dir=path are optional.

const Canvas = preload("res://tools/cover_canvas.gd")
const SIZE := 1024
const SUPERSAMPLE := 1.5
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Cover photography requires a graphics window.")
		quit(1)
		return
	var selected := PackedStringArray()
	var destination := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--games="):
			var selector := argument.trim_prefix("--games=").strip_edges()
			selected = selector.split(",", false)
			if selected.is_empty():
				printerr("Provide at least one game after --games=.")
				quit(1)
				return
		elif argument.begins_with("--output-dir="):
			destination = argument.trim_prefix("--output-dir=").strip_edges()
			if destination.is_empty():
				printerr("Provide a nonempty cover output directory.")
				quit(1)
				return
		elif argument != "--game=all":
			printerr("Unknown cover argument: " + argument)
			quit(1)
			return
	var jobs: Array[Dictionary] = []
	var planned := PackedStringArray()
	for folder in DirAccess.get_directories_at("res://games"):
		if folder.begins_with("_") or folder.begins_with("."):
			continue
		var path := "res://games/%s/" % folder
		if not ResourceLoader.exists(path + "game.gd"):
			continue
		var manifest: GameManifest = load(path + "game.gd").call("manifest")
		if not selected.is_empty() and manifest.id not in selected:
			continue
		var source := path + "tools/cover_art.gd"
		if not ResourceLoader.exists(source):
			printerr("No game-owned cover composition: " + source)
			_failed = true
			continue
		var factory := load(source) as Script
		if factory == null or not factory.can_instantiate():
			printerr("Cannot load cover composition: " + source)
			_failed = true
			continue
		var output := path + "assets/cover.png" if destination.is_empty() \
			else destination.path_join(manifest.id + ".png")
		jobs.append({"factory": factory, "output": output})
		planned.append(manifest.id)
	for id in selected:
		if id not in planned:
			printerr("Unknown game or missing cover composition: " + id)
			_failed = true
	if planned.is_empty():
		printerr("No cover compositions were selected.")
		_failed = true
	if _failed:
		quit(1)
		return
	if not destination.is_empty():
		var error := DirAccess.make_dir_recursive_absolute(destination)
		if error != OK:
			printerr("Cannot create cover destination: " + error_string(error))
			quit(1)
			return
	for job in jobs:
		await _capture(job["factory"], job["output"])
	quit(1 if _failed else 0)


func _capture(factory: Script, output: String) -> void:
	var design: Dictionary = factory.call("design")
	var photo: Rect2 = design["photo"]
	var stage := SubViewport.new()
	stage.size = Vector2i(photo.size * SUPERSAMPLE)
	stage.transparent_bg = true
	stage.own_world_3d = true
	stage.gui_disable_input = true
	stage.msaa_3d = Viewport.MSAA_4X
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(stage)
	var subject: Node = factory.call("build", stage)
	if subject == null:
		printerr("Cover composition returned no subject: " + output)
		_failed = true
		stage.free()
		return
	if subject is Node3D:
		_light(stage)
		if not _frame(stage, subject as Node3D, design.get("camera", Vector3(25, 16, 0))):
			stage.free()
			return
	else:
		stage.canvas_transform = Transform2D(0, Vector2.ONE * SUPERSAMPLE, 0, Vector2.ZERO)
		if subject is Control:
			(subject as Control).size = photo.size
	await _settle()
	var photograph := stage.get_texture().get_image()
	if photograph == null or photograph.is_empty() or photograph.is_invisible():
		printerr("Cover composition produced no visible subject: " + output)
		_failed = true
		stage.free()
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i.ONE * roundi(SIZE * SUPERSAMPLE)
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var canvas := Canvas.new()
	canvas.design = design
	canvas.photograph = ImageTexture.create_from_image(photograph)
	canvas.size = Vector2(viewport.size)
	viewport.add_child(canvas)
	await _settle()
	var image := viewport.get_texture().get_image()
	image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(output)
	if error != OK:
		printerr("Cannot save cover %s: %s" % [output, error_string(error)])
		_failed = true
	else:
		print("Cover: " + output)
	viewport.free()
	stage.free()
	await process_frame


func _light(stage: SubViewport) -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce7ef")
	environment.ambient_light_energy = 0.24
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	stage.add_child(world)
	for setup in [
		[Vector3(-42, -38, 0), Color("fff4e5"), 0.55],
		[Vector3(-24, 140, 0), Color("c9e0f2"), 0.16],
	]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = setup[0]
		light.light_color = setup[1]
		light.light_energy = setup[2]
		light.shadow_enabled = true
		light.directional_shadow_max_distance = 120
		stage.add_child(light)


func _frame(stage: SubViewport, subject: Node3D, angles: Vector3) -> bool:
	var points := PackedVector3Array()
	for node in subject.find_children("*", "VisualInstance3D", true, false):
		if not (node is MeshInstance3D or node is MultiMeshInstance3D) \
			or not node.is_visible_in_tree():
			continue
		var bounds: AABB = node.get_aabb()
		for corner in 8:
			points.append(node.global_transform * bounds.get_endpoint(corner))
	if subject is MeshInstance3D:
		var bounds := (subject as MeshInstance3D).get_aabb()
		for corner in 8:
			points.append(subject.global_transform * bounds.get_endpoint(corner))
	if points.is_empty():
		printerr("Cover subject has no visible geometry.")
		_failed = true
		return false
	var bounds := AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	var yaw := deg_to_rad(angles.x)
	var pitch := deg_to_rad(angles.y)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.01
	camera.far = 1000
	stage.add_child(camera)
	camera.position = center + Vector3(sin(yaw) * cos(pitch),
		sin(pitch), cos(yaw) * cos(pitch)) * maxf(20, bounds.size.length() * 2)
	camera.look_at(center)
	camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(angles.z))
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in points:
		var local := camera.to_local(point)
		minimum = minimum.min(Vector2(local.x, local.y))
		maximum = maximum.max(Vector2(local.x, local.y))
	var span := maximum - minimum
	var shift := (minimum + maximum) * 0.5
	camera.position += camera.basis.x * shift.x + camera.basis.y * shift.y
	camera.size = maxf(span.y, span.x * stage.size.y / stage.size.x) * 1.08
	camera.current = true
	return true


func _settle() -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
