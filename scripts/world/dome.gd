class_name Dome
extends Node3D
## The geodesic jungle-gym of glowing pipes that wraps all the way around the
## player, studded with hatches the bots pop out of. Hatches are drawn with
## MultiMeshes so the whole dome costs only a handful of draw calls.

const RADIUS := 5.0
const ROW_ELEVATIONS: Array[float] = [-8.0, 13.0, 34.0, 56.0]
const ROW_COUNTS: Array[int] = [11, 11, 9, 6]
const ROW_OFFSETS: Array[float] = [0.0, 0.5, 0.25, 0.0]
const MOUTH_RADIUS := 0.38
const TUBE_LENGTH := 1.3
const FLANGE_RADIUS := 0.62
const STRUT_RADIUS := 0.045
const BASE_RADIUS := 5.35
const SHIELD_RADIUS := 6.7
const SWEEP_SPEED := 2.6 ## Radians per second when new sections power on.

var hatches: Array[Hatch] = []
var sector_half := PI
var boost := 0.0
var danger := 0.0
var now := 0.0

var _row_start: Array[int] = []
var _rim_mm: MultiMesh
var _iris_mm: MultiMesh
var _tube_mm: MultiMesh
var _strut_mat: ShaderMaterial
var _shield_mat: ShaderMaterial
var _core_mat: ShaderMaterial
var _core_rings: Array[Node3D] = []
var _impacts: Array = []
var _impact_index := 0
var _sweep_sound_cooldown := 0.0


func _ready() -> void:
	_create_hatches()
	_build_hatch_meshes()
	_build_struts()
	_build_core()
	_build_base()
	if not WorldBuilder.is_low_power():
		_build_shield()
	set_sector(PI, false)


## Unit direction from the head center for an elevation (radians) and azimuth.
static func dir_from(elevation: float, azimuth: float) -> Vector3:
	return Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))


## Head center in world space (the point every hatch faces).
func center_global() -> Vector3:
	return global_transform * Palette.HEAD_CENTER


## Slides the dome up or down so it is centered on the player's real head height.
func fit_to_head_height(head_y: float) -> void:
	position.y = clampf(head_y - Palette.HEAD_CENTER.y, -0.45, 0.45)
	if Targeting.instance:
		Targeting.instance.shield_center = center_global()


## Powers hatches within [param half_angle] radians of straight ahead.
## With [param animate], newly powered hatches light up in a sweep.
func set_sector(half_angle: float, animate: bool) -> void:
	var old_half := sector_half
	sector_half = half_angle
	for h in hatches:
		var inside := absf(h.azimuth) <= half_angle + 0.001
		if inside and not h.powered:
			if animate:
				h.power_delay = maxf(absf(h.azimuth) - old_half, 0.0) / SWEEP_SPEED + 0.05 * float(h.row)
			else:
				h.powered = true
				h.power_delay = -1.0
		elif not inside:
			h.powered = false
			h.power_delay = -1.0
	if animate:
		boost = 1.0


func powered_hatches() -> Array[Hatch]:
	var out: Array[Hatch] = []
	for h in hatches:
		if h.powered:
			out.append(h)
	return out


## Shows a ripple on the force field where a missed shot hit it.
func add_impact(world_point: Vector3) -> void:
	if not _shield_mat:
		return
	var d := (world_point - center_global()).normalized()
	_impacts[_impact_index] = Vector4(d.x, d.y, d.z, now)
	_impact_index = (_impact_index + 1) % _impacts.size()
	_shield_mat.set_shader_parameter("impacts", _impacts)


func _process(delta: float) -> void:
	now += delta
	boost = maxf(boost - delta * 0.8, 0.0)
	danger = maxf(danger - delta * 1.5, 0.0)
	_sweep_sound_cooldown -= delta
	for h in hatches:
		_update_hatch(h, delta)
	_strut_mat.set_shader_parameter("boost", boost)
	_strut_mat.set_shader_parameter("danger", danger)
	_core_mat.set_shader_parameter("boost", boost)
	if _shield_mat:
		_shield_mat.set_shader_parameter("now", now)
		_shield_mat.set_shader_parameter("boost", boost)
	for i in _core_rings.size():
		var ring := _core_rings[i]
		ring.rotate_object_local(Vector3.UP, delta * (0.6 + 0.5 * float(i)) * (1.0 + boost * 3.0))


func _update_hatch(h: Hatch, delta: float) -> void:
	if h.power_delay >= 0.0:
		h.power_delay -= delta
		if h.power_delay < 0.0:
			h.powered = true
			h.flash = 1.0
			if _sweep_sound_cooldown <= 0.0:
				Sfx.play_at(&"hatch", h.mouth_global(self), -10.0, randf_range(1.2, 1.5))
				_sweep_sound_cooldown = 0.06
	h.cooldown = maxf(h.cooldown - delta, 0.0)
	h.power_level = move_toward(h.power_level, 1.0 if h.powered else 0.0, delta * 2.5)
	h.open = move_toward(h.open, h.open_target, delta * 7.0)
	h.flash = maxf(h.flash - delta * 2.5, 0.0)
	if h.bot == null:
		h.telegraph = move_toward(h.telegraph, 0.0, delta * 4.0)
		h.glow = move_toward(h.glow, 0.0, delta * 2.0)
		h.taunt = 0.0
		h.color = h.color.lerp(Palette.CYAN, minf(delta * 3.0, 1.0))

	var lin := h.color.srgb_to_linear()
	var energy := lerpf(0.05, 0.32, h.power_level) + h.glow * 0.7 + boost * 0.3 * h.power_level
	var i := h.index
	_rim_mm.set_instance_color(i, Color(lin.r, lin.g, lin.b, energy))
	_rim_mm.set_instance_custom_data(i, Color(h.telegraph, h.flash, h.taunt, 0.0))
	_iris_mm.set_instance_color(i, Color(lin.r, lin.g, lin.b, 1.0))
	_iris_mm.set_instance_custom_data(i, Color(h.open, h.power_level * 0.5 + h.glow, 0.0, 0.0))
	_tube_mm.set_instance_color(i, Color(lin.r, lin.g, lin.b, 1.0))
	_tube_mm.set_instance_custom_data(i, Color(h.glow * 0.7 + h.open * 0.5, 0.0, 0.0, 0.0))


func _create_hatches() -> void:
	var center := Palette.HEAD_CENTER
	for r in ROW_COUNTS.size():
		_row_start.append(hatches.size())
		var count := ROW_COUNTS[r]
		var elev := deg_to_rad(ROW_ELEVATIONS[r])
		for k in count:
			var az := wrapf(_row_angle(r, k), -PI, PI)
			var h := Hatch.new()
			h.index = hatches.size()
			h.row = r
			h.azimuth = az
			h.elevation = elev
			var d := dir_from(elev, az)
			h.xform = Transform3D(Basis.looking_at(-d, Vector3.UP), center + d * RADIUS)
			hatches.append(h)


func _row_angle(r: int, k: int) -> float:
	return (float(k) + ROW_OFFSETS[r]) * TAU / float(ROW_COUNTS[r])


func hatch_at(r: int, k: int) -> Hatch:
	return hatches[_row_start[r] + posmod(k, ROW_COUNTS[r])]


## The hatch in [param r] whose azimuth is closest to [param azimuth].
func nearest_hatch(r: int, azimuth: float) -> Hatch:
	var best: Hatch = null
	var best_d := INF
	for k in ROW_COUNTS[r]:
		var h := hatch_at(r, k)
		var d := absf(angle_difference(h.azimuth, azimuth))
		if d < best_d:
			best_d = d
			best = h
	return best


func _make_mm(mesh: Mesh, material: Material, use_custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = use_custom
	mm.mesh = mesh
	mm.instance_count = hatches.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


func _build_hatch_meshes() -> void:
	var face_out := Basis(Vector3.RIGHT, PI * 0.5) # Local +Y -> hatch +Z (outward).
	var tube_mesh := Mat.cylinder(MOUTH_RADIUS, MOUTH_RADIUS, TUBE_LENGTH, 20)
	tube_mesh.cap_bottom = false
	_tube_mm = _make_mm(tube_mesh, Mat.shader_material("res://shaders/hatch_tube.gdshader"), true)

	var rim_mesh := Mat.torus(MOUTH_RADIUS - 0.02, MOUTH_RADIUS + 0.085, 40, 10)
	_rim_mm = _make_mm(rim_mesh, Mat.shader_material("res://shaders/hatch_rim.gdshader"), true)

	var iris_mesh := Mat.quad(Vector2(MOUTH_RADIUS * 2.0, MOUTH_RADIUS * 2.0))
	_iris_mm = _make_mm(iris_mesh, Mat.shader_material("res://shaders/hatch_iris.gdshader"), true)

	var flange_mesh := Mat.torus(MOUTH_RADIUS + 0.06, FLANGE_RADIUS, 40, 8)
	var flange_mat := Mat.pbr(Palette.METAL_DARK, 0.85, 0.3)
	var flange_mm := _make_mm(flange_mesh, flange_mat, false)

	for h in hatches:
		var i := h.index
		_tube_mm.set_instance_transform(i, h.xform * Transform3D(face_out, Vector3(0.0, 0.0, TUBE_LENGTH * 0.5)))
		_rim_mm.set_instance_transform(i, h.xform * Transform3D(face_out, Vector3(0.0, 0.0, -0.01)))
		_iris_mm.set_instance_transform(i, h.xform * Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.0, 0.035)))
		var flat := face_out * Basis.from_scale(Vector3(1.0, 0.3, 1.0))
		flange_mm.set_instance_transform(i, h.xform * Transform3D(flat, Vector3(0.0, 0.0, 0.07)))
		flange_mm.set_instance_color(i, Color.WHITE)
		_update_hatch(h, 0.0)


## Point on a hatch's flange facing [param toward], where a pipe attaches.
func _attach_point(h: Hatch, toward: Vector3) -> Vector3:
	var p := h.xform.origin
	var inward := -h.xform.basis.z
	var to := toward - p
	var tangent := (to - inward * to.dot(inward)).normalized()
	return p + tangent * (FLANGE_RADIUS - 0.04) + h.xform.basis.z * 0.08


func _build_struts() -> void:
	var a_pts: Array[Vector3] = []
	var b_pts: Array[Vector3] = []
	var add_edge := func(ha: Hatch, hb: Hatch) -> void:
		a_pts.append(_attach_point(ha, hb.xform.origin))
		b_pts.append(_attach_point(hb, ha.xform.origin))

	# Around each row.
	for r in ROW_COUNTS.size():
		for k in ROW_COUNTS[r]:
			add_edge.call(hatch_at(r, k), hatch_at(r, k + 1))
	# Between neighbouring rows: zip the two rings together into triangles.
	for r in ROW_COUNTS.size() - 1:
		var na := ROW_COUNTS[r]
		var nb := ROW_COUNTS[r + 1]
		var m0 := roundi(ROW_OFFSETS[r] * float(nb) / float(na) - ROW_OFFSETS[r + 1])
		var k := 0
		var m := m0
		add_edge.call(hatch_at(r, k), hatch_at(r + 1, m))
		while k < na or m < m0 + nb:
			var next_a := _row_angle(r, k + 1)
			var next_b := _row_angle(r + 1, m + 1)
			if m >= m0 + nb or (k < na and next_a <= next_b):
				k += 1
			else:
				m += 1
			if k == na and m == m0 + nb:
				break
			add_edge.call(hatch_at(r, k), hatch_at(r + 1, m))

	var center := Palette.HEAD_CENTER
	# Legs from the bottom row down into the floor.
	for k in ROW_COUNTS[0]:
		var h := hatch_at(0, k)
		for side in [-0.5, 0.5]:
			var az := _row_angle(0, k) + float(side) * TAU / float(ROW_COUNTS[0])
			var foot := Vector3(sin(az) * BASE_RADIUS, -0.6, -cos(az) * BASE_RADIUS)
			a_pts.append(_attach_point(h, foot))
			b_pts.append(foot)
	# Spokes from the top row up to the core.
	var apex := center + Vector3.UP * (RADIUS + 0.25)
	var top := ROW_COUNTS.size() - 1
	for k in ROW_COUNTS[top]:
		var h := hatch_at(top, k)
		var a := _attach_point(h, apex)
		a_pts.append(a)
		b_pts.append(apex + (a - apex).normalized() * 0.45)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for e in a_pts.size():
		_add_tube(verts, normals, uvs, colors, indices, a_pts[e], b_pts[e], STRUT_RADIUS, rng.randf())

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_strut_mat = Mat.shader_material("res://shaders/strut.gdshader")
	var mi := Mat.add_mesh(self, mesh, _strut_mat)
	mi.name = "Pipes"


## Appends a 6-sided pipe from a to b. UV.y runs upward in meters so energy
## pulses always flow up toward the core.
static func _add_tube(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		colors: PackedColorArray, indices: PackedInt32Array, a: Vector3, b: Vector3, radius: float, rnd: float) -> void:
	if a.y > b.y:
		var tmp := a
		a = b
		b = tmp
	var axis := b - a
	var length := axis.length()
	if length < 0.01:
		return
	var frame := Mat.basis_y_to(axis / length)
	var sides := 6
	var base := verts.size()
	for ring in 2:
		var p0 := a if ring == 0 else b
		var v := 0.0 if ring == 0 else length
		for s in sides + 1:
			var ang := TAU * float(s) / float(sides)
			var n := frame.x * cos(ang) + frame.z * sin(ang)
			verts.append(p0 + n * radius)
			normals.append(n)
			uvs.append(Vector2(float(s) / float(sides), v))
			colors.append(Color(rnd, 0.0, 0.0))
	for s in sides:
		var i0 := base + s
		var i1 := i0 + 1
		var j0 := base + sides + 1 + s
		var j1 := j0 + 1
		indices.append_array(PackedInt32Array([i0, i1, j0, i1, j1, j0]))


func _build_core() -> void:
	var apex := Palette.HEAD_CENTER + Vector3.UP * (RADIUS + 0.25)
	_core_mat = Mat.shader_material("res://shaders/core.gdshader")
	var core := Mat.add_mesh(self, Mat.sphere(0.42, -1.0, 32, 16), _core_mat, apex)
	core.name = "Core"
	var ring_specs: Array[Vector3] = [Vector3(0.62, 0.4, 0.0), Vector3(0.8, -0.5, 0.6)]
	for spec in ring_specs:
		var pivot := Node3D.new()
		pivot.position = apex
		pivot.rotation = Vector3(spec.y, spec.z, 0.0)
		add_child(pivot)
		Mat.add_mesh(pivot, Mat.torus(spec.x - 0.025, spec.x + 0.025, 48, 6), Mat.neon(Palette.MAGENTA if spec.y < 0.0 else Palette.CYAN, 3.0))
		_core_rings.append(pivot)
	var halo_mat := Mat.shader_material("res://shaders/glow_sprite.gdshader", {"energy": 0.9, "sharpness": 4.0, "core_amount": 0.0})
	var halo := Mat.add_mesh(self, Mat.quad(Vector2(3.2, 3.2)), halo_mat, apex)
	halo.set_instance_shader_parameter("tint", Color(0.55, 0.3, 1.0, 1.0))


func _build_base() -> void:
	var ring := Mat.add_mesh(self, Mat.torus(BASE_RADIUS - 0.05, BASE_RADIUS + 0.05, 96, 8), Mat.neon(Palette.CYAN, 2.2), Vector3(0.0, 0.03, 0.0))
	ring.name = "BaseRing"


func _build_shield() -> void:
	_shield_mat = Mat.shader_material("res://shaders/shield.gdshader")
	_impacts.clear()
	for i in 4:
		_impacts.append(Vector4(0.0, 0.0, 0.0, -100.0))
	_shield_mat.set_shader_parameter("impacts", _impacts)
	var shield := Mat.add_mesh(self, Mat.sphere(SHIELD_RADIUS, -1.0, 48, 24), _shield_mat, Palette.HEAD_CENTER)
	shield.name = "Shield"
