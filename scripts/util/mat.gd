class_name Mat
## Small helpers for building materials and meshes in code.

static var _shaders: Dictionary = {}


static func shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	return _shaders[path]


static func shader_material(path: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(path)
	for key in params:
		m.set_shader_parameter(key, params[key])
	return m


## Lit PBR material.
static func pbr(albedo: Color, metallic: float, roughness: float, emission := Color.BLACK, emission_energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = roughness
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m


## Glossy toy plastic with a soft rim light.
static func plastic(albedo: Color, roughness := 0.28) -> StandardMaterial3D:
	var m := pbr(albedo, 0.0, roughness)
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	return m


## Unshaded glowing material (for neon accents).
static func neon(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy)
	m.disable_fog = true
	return m


## Adds a MeshInstance3D child with shadows off.
static func add_mesh(parent: Node3D, mesh: Mesh, material: Material = null, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if material:
		mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func sphere(radius: float, height := -1.0, segments := 24, rings := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 if height < 0.0 else height
	m.radial_segments = segments
	m.rings = rings
	return m


static func cylinder(top: float, bottom: float, height: float, segments := 16, caps := true) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	m.cap_top = caps
	m.cap_bottom = caps
	return m


static func torus(inner: float, outer: float, rings := 32, ring_segments := 10) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = rings
	m.ring_segments = ring_segments
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func quad(size: Vector2) -> QuadMesh:
	var m := QuadMesh.new()
	m.size = size
	return m


## Basis that maps the local +Y axis onto [param dir] (for cylinders/capsules).
static func basis_y_to(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
