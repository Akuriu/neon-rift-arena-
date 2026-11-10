extends RefCounted

static var paints := {}

static func paint(color: Color, glow := false, metal := 0.12) -> StandardMaterial3D:
	var key := [color, glow, metal]
	if not paints.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.71
		material.metallic = metal
		if glow:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paints[key] = material
	return paints[key]

static func cube(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func tube(radius: float, height: float, segments := 12, top := -1.0) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	return mesh

static func orb(radius: float, height: float, segments := 14) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 6
	return mesh

static func ring(radius: float, width: float, segments := 32) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width
	mesh.outer_radius = radius
	mesh.rings = segments
	mesh.ring_segments = 8
	return mesh

static func bevel(size: Vector3, cut: float) -> ArrayMesh:
	var x := size.x * 0.5
	var z := size.z * 0.5
	var y := size.y * 0.5
	var c := minf(cut, minf(x, z) * 0.92)
	var rim := PackedVector2Array([Vector2(-x + c, -z), Vector2(x - c, -z),
		Vector2(x, -z + c), Vector2(x, z - c), Vector2(x - c, z), Vector2(-x + c, z),
		Vector2(-x, z - c), Vector2(-x, -z + c)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		var p := Vector3(a.x, y, a.y)
		var q := Vector3(b.x, y, b.y)
		var r := Vector3(a.x, -y, a.y)
		var s := Vector3(b.x, -y, b.y)
		var normal := Vector3(b.y - a.y, 0, a.x - b.x).normalized()
		_tri(st, p, q, r, normal)
		_tri(st, r, q, s, normal)
		_tri(st, Vector3.UP * y, p, q, Vector3.UP)
		_tri(st, Vector3.DOWN * y, r, s, Vector3.DOWN)
	st.index()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var other := b
		b = c
		c = other
	for point in [a, b, c]:
		st.set_normal(outward)
		st.set_uv(Vector2(point.x, point.z))
		st.add_vertex(point)

static func place(parent: Node3D, mesh: Mesh, material: Material, at: Vector3,
		rotation := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = rotation
	if not shadow:
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part

class Batch:
	var groups := {}
	var world_materials := false

	func put(mesh: Mesh, material: Material, at: Vector3, rotation := Vector3.ZERO, sector := true) -> void:
		var cell := Vector2i(floori(at.x / 13.0), floori(at.z / 13.0)) if sector else Vector2i.ZERO
		var key := [cell, material]
		if not groups.has(key):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = tool
		var tool: SurfaceTool = groups[key]
		var xform := Transform3D(Basis.from_euler(rotation), at - Vector3(cell.x * 13.0, 0.0, cell.y * 13.0))
		tool.append_from(mesh, 0, xform)

	func commit(parent: Node3D, shadows := true) -> void:
		for key in groups:
			var tool: SurfaceTool = groups[key]
			tool.index()
			var at := Vector3(key[0].x * 13.0, 0.0, key[0].y * 13.0)
			var material: Material = key[1]
			var casts := shadows
			if material is StandardMaterial3D:
				casts = casts and material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED
				if world_materials:
					material = Art.surface(material)
			var part := MeshInstance3D.new()
			part.mesh = tool.commit()
			part.material_override = material
			part.position = at
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(part)
		groups.clear()
