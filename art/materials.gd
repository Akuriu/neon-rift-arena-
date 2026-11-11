extends RefCounted

static var textures := {}

static func texture(kind: String) -> Texture2D:
	if not textures.has(kind):
		textures[kind] = load("res://assets/surfaces/%s.png" % kind)
	return textures[kind]

static var finishes := {}
static var vertex_finishes := {}

static func finish(color: Color, kind: String, frequency: float, metallic := 0.0) -> StandardMaterial3D:
	var key := [color, kind, frequency, metallic]
	if not finishes.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.albedo_texture = texture(kind)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * frequency
		material.metallic = metallic
		material.roughness = 0.65 if metallic > 0.20 else 0.89
		finishes[key] = material
	return finishes[key]

static func vertex_finish(kind: String, frequency: float, metallic := 0.0) -> StandardMaterial3D:
	var key := [kind, frequency, metallic]
	if not vertex_finishes.has(key):
		var material: StandardMaterial3D = finish(Color.WHITE, kind, frequency, metallic).duplicate()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		vertex_finishes[key] = material
	return vertex_finishes[key]
