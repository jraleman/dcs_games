extends RefCounted

## Offline staging helpers. Subjects and their materials still belong to each game.

## Attach before posing so game rigs have their normal ready-time parts.
static func group(parent: Node) -> Node3D:
	var result := Node3D.new()
	parent.add_child(result)
	return result


## Reuse an actual game mesh, without changing its shared resource.
static func mesh(
	parent: Node3D, source: Mesh, material: Material, at := Vector3.ZERO
) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = source
	result.material_override = material
	result.position = at
	parent.add_child(result)
	return result


## A staged transform never reaches the game's simulation.
static func place(
	parent: Node3D, subject: Node3D, at := Vector3.ZERO,
	angles := Vector3.ZERO, scale_value := 1.0
) -> Node3D:
	subject.position = at
	subject.rotation_degrees = angles
	subject.scale = Vector3.ONE * scale_value
	parent.add_child(subject)
	return subject


## Vertex-painted props can use a neutral studio finish when no game finish exists.
static func paint() -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.roughness = 0.72
	return result
