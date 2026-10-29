class_name WorldBuilder
## Builds the static environment: sky, lighting, neon floor, distant
## wireframe mountains and the player's platform.

const FLOOR_SIZE := 520.0
const MOUNTAIN_INNER := 150.0
const MOUNTAIN_OUTER := 255.0
const PLATFORM_RADIUS := 1.0


## True on standalone headsets (Quest etc.), where we trade some eye candy for frame rate.
static func is_low_power() -> bool:
	return OS.has_feature("android") or OS.has_feature("mobile")


static func build(root: Node3D) -> Dictionary:
	var env_node := WorldEnvironment.new()
	env_node.environment = _make_environment()
	root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.55, 0.75)
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	# Shine from the sunset (in front, -Z) toward the player.
	sun.rotation = Vector3(deg_to_rad(-18.0), PI, 0.0)
	root.add_child(sun)

	var top := DirectionalLight3D.new()
	top.light_color = Color(0.45, 0.65, 1.0)
	top.light_energy = 0.55
	top.shadow_enabled = false
	top.rotation = Vector3(deg_to_rad(-70.0), deg_to_rad(160.0), 0.0)
	root.add_child(top)

	# Cool fill from behind the player so bots in front aren't only back-lit.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.5, 1.0)
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	fill.rotation = Vector3(deg_to_rad(-25.0), 0.0, 0.0)
	root.add_child(fill)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(FLOOR_SIZE, FLOOR_SIZE)
	var floor_mi := Mat.add_mesh(root, floor_mesh, Mat.shader_material("res://shaders/floor_grid.gdshader"))
	floor_mi.name = "Floor"

	var mountains := Mat.add_mesh(root, _make_mountains(), Mat.shader_material("res://shaders/mountains.gdshader"))
	mountains.name = "Mountains"

	var platform_mat := Mat.shader_material("res://shaders/platform.gdshader")
	var platform := _make_platform(platform_mat)
	root.add_child(platform)

	return {"environment": env_node.environment, "platform": platform, "platform_material": platform_mat}


static func _make_environment() -> Environment:
	var sky_mat := Mat.shader_material("res://shaders/sky.gdshader", {
		"sun_dir": Vector3(0.0, 0.12, -1.0).normalized(),
	})
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0

	env.fog_enabled = true
	env.fog_light_color = Palette.FOG
	env.fog_light_energy = 1.0
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0

	env.glow_enabled = not is_low_power()
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.set_glow_level(5, 0.0)
	env.set_glow_level(6, 0.0)
	return env


## A ring of ridged mountains far away, with a valley in front for the sun.
static func _make_mountains() -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 4

	var segments := 150
	var rows := 5
	var max_h := 48.0
	var grid: Array[PackedVector3Array] = []
	var heights: Array[PackedFloat32Array] = []
	for j in rows + 1:
		var ring := PackedVector3Array()
		var hs := PackedFloat32Array()
		var fj := float(j) / float(rows)
		var radius := lerpf(MOUNTAIN_INNER, MOUNTAIN_OUTER, fj)
		var envelope := sin(PI * fj)
		for i in segments + 1:
			var a := TAU * float(i % segments) / float(segments)
			var n := noise.get_noise_3d(cos(a) * 2.2, sin(a) * 2.2, fj * 0.9)
			var n01 := clampf(n * 0.5 + 0.5, 0.0, 1.0)
			var wrapped := absf(wrapf(a, -PI, PI))
			var valley := lerpf(0.18, 1.0, smoothstep(0.12, 0.55, wrapped))
			var h := pow(n01, 1.6) * max_h * envelope * valley * (0.6 + 0.4 * fj)
			if j == 0:
				h = -2.0
			ring.append(Vector3(sin(a) * radius, h, -cos(a) * radius))
			hs.append(clampf(h / max_h, 0.0, 1.0))
		grid.append(ring)
		heights.append(hs)

	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var bary: Array[Color] = [Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1)]
	for j in rows:
		for i in segments:
			var quad_pts: Array[Vector3] = [grid[j][i], grid[j][i + 1], grid[j + 1][i], grid[j + 1][i + 1]]
			var quad_h: Array[float] = [heights[j][i], heights[j][i + 1], heights[j + 1][i], heights[j + 1][i + 1]]
			var tris: Array[PackedInt32Array] = [PackedInt32Array([0, 2, 1]), PackedInt32Array([1, 2, 3])]
			for tri in tris:
				for k in 3:
					verts.append(quad_pts[tri[k]])
					colors.append(bary[k])
					uvs.append(Vector2(0.0, quad_h[tri[k]]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _make_platform(disc_mat: ShaderMaterial) -> Node3D:
	var root := Node3D.new()
	root.name = "Platform"
	var disc := Mat.cylinder(PLATFORM_RADIUS, PLATFORM_RADIUS + 0.04, 0.05, 48)
	var disc_mi := Mat.add_mesh(root, disc, disc_mat, Vector3(0.0, 0.025, 0.0))
	disc_mi.name = "Disc"
	var rim := Mat.torus(PLATFORM_RADIUS + 0.005, PLATFORM_RADIUS + 0.045, 64, 8)
	var rim_mi := Mat.add_mesh(root, rim, Mat.neon(Palette.CYAN, 2.5), Vector3(0.0, 0.05, 0.0))
	rim_mi.name = "Rim"
	var under := Mat.torus(PLATFORM_RADIUS + 0.12, PLATFORM_RADIUS + 0.16, 64, 6)
	var under_mi := Mat.add_mesh(root, under, Mat.neon(Palette.MAGENTA, 1.6), Vector3(0.0, 0.01, 0.0))
	under_mi.scale = Vector3(1.0, 0.3, 1.0)
	return root
