extends Node3D

## Original, game-neutral menu hardware. Only the cartridge moves; its receiver
## stays put so pressing Play reads as insertion rather than another logo spin.

const READY_POSITION := Vector3(0.0, 3.35, -0.41)
const SEATED_POSITION := Vector3(0.0, 2.05, -0.41)

@export var cartridge: Node3D

var insertion := 0.0:
	set(value):
		insertion = clampf(value, 0.0, 1.0)
		if is_instance_valid(cartridge):
			cartridge.position = READY_POSITION.lerp(SEATED_POSITION, insertion)
		_update_power()

var _power: StandardMaterial3D
var _accent := Color.WHITE
var _meshes: Dictionary[Vector3, ArrayMesh] = {}


func _ready() -> void:
	var shell := _material(Color("25292f"), 0.15, 0.62)
	var edge := _material(Color("15191f"), 0.12, 0.7)
	var rubber := _material(Color("090e14"), 0.0, 0.82)
	var metal := _material(Color("75838d"), 0.7, 0.3)
	var gold := _material(Color("ad8951"), 0.65, 0.35)
	_power = _material(Color("253b46"), 0.15, 0.3)
	_power.emission_enabled = true
	_build_console(shell, edge, rubber, metal)
	_build_cartridge(shell, edge, rubber, metal, gold)
	_build_controller(shell, edge, rubber, metal)
	_build_shadow()
	park()


## Hardware remains neutral while its power light follows the game's branding.
func configure(presentation: GameTheme) -> void:
	_accent = presentation.accent
	_update_power()


## A stationary pose is also the reduced-motion resting frame.
func park() -> void:
	cartridge.position = READY_POSITION.lerp(SEATED_POSITION, insertion)
	cartridge.rotation = Vector3.ZERO
	cartridge.scale = Vector3.ONE


## Small idle movement makes the loose cartridge distinct from the fixed slot.
func idle_pose(time: float, focus_bias: float) -> void:
	cartridge.position = READY_POSITION + Vector3(0, sin(time * 0.8) * 0.035, 0)
	cartridge.rotation = Vector3(
		0, sin(time * 0.55) * 0.018 + focus_bias, sin(time * 0.4) * 0.008
	)


func _update_power() -> void:
	if _power == null:
		return
	var powered := smoothstep(0.82, 1.0, insertion)
	_power.albedo_color = Color("253b46").lerp(_accent, 0.3 + powered * 0.7)
	_power.emission = _accent
	_power.emission_energy_multiplier = 0.15 + powered * 0.65


func _build_console(
	shell: Material, edge: Material, rubber: Material, metal: Material
) -> void:
	var console := Node3D.new()
	console.name = "Receiver"
	add_child(console)
	_box(console, "Foot", Vector3(5.65, 0.18, 3.15), Vector3(0, 0.13, 0), rubber)
	_box(console, "LowerCase", Vector3(6.0, 0.22, 3.42), Vector3(0, 0.32, 0), edge)
	_box(console, "Housing", Vector3(6.04, 0.66, 3.46), Vector3(0, 0.77, 0), shell)
	_box(console, "Seam", Vector3(6.055, 0.025, 3.475), Vector3(0, 0.47, 0), rubber)
	_box(console, "SlotWell", Vector3(3.58, 0.035, 0.78),
		Vector3(0, 1.105, -0.41), rubber)
	# Four separate lid pieces leave a real opening around the cartridge.
	_box(console, "FrontLid", Vector3(6.04, 0.19, 1.81),
		Vector3(0, 1.19, 0.825), shell)
	_box(console, "BackLid", Vector3(6.04, 0.19, 0.99),
		Vector3(0, 1.19, -1.235), shell)
	for side in [-1.0, 1.0]:
		_box(console, "SlotCheek", Vector3(1.28, 0.19, 0.66),
			Vector3(side * 2.38, 1.19, -0.41), edge)
		_box(console, "Port", Vector3(0.68, 0.2, 0.07),
			Vector3(side * 1.83, 0.72, 1.74), rubber)
		_box(console, "PortInset", Vector3(0.48, 0.065, 0.025),
			Vector3(side * 1.83, 0.72, 1.784), metal)
		for index in 5:
			_box(console, "FrontVent", Vector3(0.27, 0.027, 0.025),
				Vector3(side * 2.52, 0.65 + index * 0.073, 1.74), rubber)
	for index in 18:
		_box(console, "TopVent", Vector3(0.042, 0.015, 0.43),
			Vector3(-1.36 + index * 0.16, 1.291, -1.26), rubber)
	_box(console, "PowerSocket", Vector3(0.94, 0.12, 0.055),
		Vector3(0, 0.75, 1.752), rubber)
	_box(console, "PowerLight", Vector3(0.73, 0.043, 0.028),
		Vector3(0, 0.75, 1.79), _power)
	_cylinder(console, "PowerButtonRim", 0.16, 0.04,
		Vector3(-2.25, 1.3, 0.94), metal)
	_cylinder(console, "PowerButton", 0.12, 0.048,
		Vector3(-2.25, 1.33, 0.94), edge)


func _build_cartridge(
	shell: Material, edge: Material, rubber: Material, metal: Material, gold: Material
) -> void:
	_box(cartridge, "Shell", Vector3(3.28, 2.65, 0.44), Vector3.ZERO, shell)
	_box(cartridge, "LabelRecess", Vector3(2.64, 2.38, 0.055),
		Vector3(0, 0.04, 0.239), rubber)
	for side in [-1.0, 1.0]:
		_box(cartridge, "Grip", Vector3(0.28, 2.51, 0.075),
			Vector3(side * 1.46, 0, 0.25), edge)
		for index in 8:
			_box(cartridge, "GripRib", Vector3(0.24, 0.032, 0.025),
				Vector3(side * 1.46, 0.95 - index * 0.24, 0.298), shell)
		var screw := _cylinder(cartridge, "Screw", 0.042, 0.017,
			Vector3(side * 1.46, -1.12, 0.301), metal)
		screw.rotation.x = PI * 0.5
		_box(cartridge, "ScrewSlot", Vector3(0.046, 0.009, 0.009),
			Vector3(side * 1.46, -1.12, 0.313), rubber)
	_box(cartridge, "Connector", Vector3(2.25, 0.28, 0.16),
		Vector3(0, -1.42, 0), edge)
	for index in 14:
		_box(cartridge, "Contact", Vector3(0.095, 0.21, 0.018),
			Vector3(-0.975 + index * 0.15, -1.43, 0.089), gold)


func _build_controller(
	shell: Material, edge: Material, rubber: Material, metal: Material
) -> void:
	var controller := Node3D.new()
	controller.name = "Controller"
	controller.position = Vector3(2.4, 0.28, 3.25)
	controller.rotation.y = -0.24
	controller.scale = Vector3.ONE * 1.1
	add_child(controller)
	_box(controller, "Body", Vector3(2.86, 0.3, 1.45), Vector3.ZERO, shell)
	_box(controller, "FacePlate", Vector3(2.65, 0.06, 1.25),
		Vector3(0, 0.175, -0.03), edge)
	for side in [-1.0, 1.0]:
		var grip := _box(controller, "Grip", Vector3(0.73, 0.38, 1.22),
			Vector3(side * 1.09, -0.08, 0.52), shell)
		grip.rotation.y = side * -0.2
		_box(controller, "Shoulder", Vector3(0.68, 0.17, 0.16),
			Vector3(side * 0.98, 0.13, -0.75), rubber)
		_cylinder(controller, "StickRing", 0.23, 0.07,
			Vector3(side * 0.43, 0.24, 0.36), metal)
		_cylinder(controller, "Stick", 0.18, 0.14,
			Vector3(side * 0.43, 0.32, 0.36), rubber)
	_box(controller, "DPadVertical", Vector3(0.16, 0.11, 0.55),
		Vector3(-0.92, 0.26, -0.14), rubber)
	_box(controller, "DPadHorizontal", Vector3(0.55, 0.11, 0.16),
		Vector3(-0.92, 0.26, -0.14), rubber)
	for offset in [Vector2(-0.24, 0), Vector2(0.24, 0), Vector2(0, -0.24), Vector2(0, 0.24)]:
		_cylinder(controller, "ActionButton", 0.11, 0.1,
			Vector3(0.92 + offset.x, 0.26, -0.14 + offset.y), metal)
	for side in [-1.0, 1.0]:
		_box(controller, "MenuButton", Vector3(0.15, 0.045, 0.065),
			Vector3(side * 0.16, 0.235, -0.18), rubber)


func _build_shadow() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0.6), Color.TRANSPARENT])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 7)
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = plane
	shadow.material_override = material
	shadow.position = Vector3(0.3, 0.02, 0.7)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _box(
	parent: Node3D, label: String, dimensions: Vector3, at: Vector3, material: Material
) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	if not _meshes.has(dimensions):
		_meshes[dimensions] = _rounded_box(dimensions)
	mesh.mesh = _meshes[dimensions]
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _cylinder(
	parent: Node3D, label: String, radius: float, height: float, at: Vector3,
	material: Material
) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 20
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _rounded_box(dimensions: Vector3) -> ArrayMesh:
	var half := dimensions * 0.5
	var radius := minf(0.09, minf(half.x, minf(half.y, half.z)) * 0.42)
	var inner := half - Vector3.ONE * radius
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var us := [-half[u_axis], -inner[u_axis], inner[u_axis], half[u_axis]]
		var vs := [-half[v_axis], -inner[v_axis], inner[v_axis], half[v_axis]]
		for side in [-1.0, 1.0]:
			for u in 3:
				for v in 3:
					var order := [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0),
						Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
					if side < 0.0:
						order.reverse()
					for corner: Vector2i in order:
						var point := Vector3.ZERO
						point[axis] = half[axis] * side
						point[u_axis] = us[u + corner.x]
						point[v_axis] = vs[v + corner.y]
						var nearest := point.clamp(-inner, inner)
						var normal := (point - nearest).normalized()
						surface.set_normal(normal)
						surface.add_vertex(nearest + normal * radius)
	surface.index()
	return surface.commit()
