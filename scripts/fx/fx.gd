class_name Fx
extends Node3D
## Pooled visual effects: bot explosions, impact sparks and floating score text.

static var instance: Fx

const EXPLOSIONS := 8
const SPARKS := 8
const POPUPS := 12

class Burst:
	var root: Node3D
	var debris: CPUParticles3D
	var sparks: CPUParticles3D
	var flash: MeshInstance3D
	var light: OmniLight3D
	var age := 99.0
	var size := 1.0
	var color := Color.WHITE

class TextPopup:
	var label: Label3D
	var age := 99.0
	var life := 1.0
	var start := Vector3.ZERO
	var rise := 0.6
	var size := 1.0
	var color := Color.WHITE

var _bursts: Array[Burst] = []
var _sparks: Array[Burst] = []
var _popups: Array[TextPopup] = []
var _next_burst := 0
var _next_spark := 0
var _next_popup := 0
var _use_lights := true


func _init() -> void:
	instance = self


func _ready() -> void:
	_use_lights = not WorldBuilder.is_low_power()
	var debris_mat := Mat.shader_material("res://shaders/debris.gdshader", {"energy": 2.2})
	var spark_mat := Mat.shader_material("res://shaders/debris.gdshader", {"energy": 6.0})
	var glow_mat := Mat.shader_material("res://shaders/glow_sprite.gdshader", {"energy": 2.5, "sharpness": 3.5})
	var shard := Mat.box(Vector3(0.08, 0.08, 0.04))
	shard.material = debris_mat
	var streak := Mat.box(Vector3(0.012, 0.11, 0.012))
	streak.material = spark_mat
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))

	for i in EXPLOSIONS:
		var b := Burst.new()
		b.root = Node3D.new()
		add_child(b.root)
		b.debris = _make_particles(shard, 22, 0.9, 2.5, 6.0, shrink)
		b.debris.gravity = Vector3(0.0, -7.0, 0.0)
		b.debris.angular_velocity_min = -720.0
		b.debris.angular_velocity_max = 720.0
		b.debris.particle_flag_rotate_y = true
		b.root.add_child(b.debris)
		b.sparks = _make_particles(streak, 28, 0.45, 4.0, 10.0, shrink)
		b.sparks.particle_flag_align_y = true
		b.sparks.damping_min = 4.0
		b.sparks.damping_max = 8.0
		b.sparks.gravity = Vector3(0.0, -3.0, 0.0)
		b.root.add_child(b.sparks)
		b.flash = Mat.add_mesh(b.root, Mat.quad(Vector2(1.0, 1.0)), glow_mat)
		b.flash.visible = false
		if _use_lights:
			b.light = OmniLight3D.new()
			b.light.omni_range = 3.5
			b.light.light_energy = 0.0
			b.light.shadow_enabled = false
			b.root.add_child(b.light)
		_bursts.append(b)

	for i in SPARKS:
		var s := Burst.new()
		s.root = Node3D.new()
		add_child(s.root)
		s.sparks = _make_particles(streak, 12, 0.35, 2.0, 5.0, shrink)
		s.sparks.particle_flag_align_y = true
		s.sparks.damping_min = 4.0
		s.sparks.damping_max = 6.0
		s.sparks.gravity = Vector3(0.0, -4.0, 0.0)
		s.root.add_child(s.sparks)
		s.flash = Mat.add_mesh(s.root, Mat.quad(Vector2(1.0, 1.0)), glow_mat)
		s.flash.visible = false
		_sparks.append(s)

	for i in POPUPS:
		var p := TextPopup.new()
		p.label = GameFonts.make_label("", 120, GameFonts.title())
		p.label.pixel_size = 0.0022
		p.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p.label.no_depth_test = true
		p.label.render_priority = 10
		p.label.outline_render_priority = 9
		p.label.outline_size = 28
		p.label.visible = false
		add_child(p.label)
		_popups.append(p)


func _make_particles(mesh: Mesh, amount: int, lifetime: float, v_min: float, v_max: float, scale_curve: Curve) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.randomness = 0.3
	p.mesh = mesh
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3(0.0, 0.0, 1.0)
	p.spread = 180.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.scale_amount_curve = scale_curve
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Big colorful pop when a bot is destroyed.
func explode(pos: Vector3, color: Color, size := 1.0) -> void:
	var b := _bursts[_next_burst]
	_next_burst = (_next_burst + 1) % _bursts.size()
	b.root.global_position = pos
	b.age = 0.0
	b.size = size
	b.color = color
	b.debris.color = color
	b.debris.amount = int(22.0 * size)
	b.debris.restart()
	b.debris.emitting = true
	b.sparks.color = color.lerp(Color.WHITE, 0.6)
	b.sparks.restart()
	b.sparks.emitting = true
	b.flash.visible = true
	b.flash.set_instance_shader_parameter("tint", color)
	if b.light:
		b.light.light_color = color


## Small spark burst where a beam hits a surface.
func spark(pos: Vector3, color: Color) -> void:
	var s := _sparks[_next_spark]
	_next_spark = (_next_spark + 1) % _sparks.size()
	s.root.global_position = pos
	s.age = 0.0
	s.size = 0.35
	s.color = color
	s.sparks.color = color.lerp(Color.WHITE, 0.5)
	s.sparks.restart()
	s.sparks.emitting = true
	s.flash.visible = true
	s.flash.set_instance_shader_parameter("tint", color)


## Floating text (scores, combo callouts) that rises and fades.
func popup(pos: Vector3, text: String, color: Color, size := 1.0, life := 0.95) -> void:
	var p := _popups[_next_popup]
	_next_popup = (_next_popup + 1) % _popups.size()
	p.label.text = text
	p.start = pos
	p.age = 0.0
	p.life = life
	p.size = size
	p.color = color
	p.label.visible = true
	p.label.global_position = pos


func _process(delta: float) -> void:
	for b in _bursts:
		if b.age > 1.0:
			continue
		b.age += delta
		var k := clampf(b.age / 0.4, 0.0, 1.0)
		if k >= 1.0:
			b.flash.visible = false
		else:
			var s := (0.6 + 2.2 * sqrt(k)) * b.size
			b.flash.scale = Vector3(s, s, s)
			var c := b.color
			c.a = 1.6 * pow(1.0 - k, 1.5)
			b.flash.set_instance_shader_parameter("tint", c)
		if b.light:
			b.light.light_energy = maxf(0.0, 1.0 - b.age / 0.3) * 4.0 * b.size
	for s in _sparks:
		if s.age > 1.0:
			continue
		s.age += delta
		var k := clampf(s.age / 0.15, 0.0, 1.0)
		if k >= 1.0:
			s.flash.visible = false
		else:
			var sc := 0.25 * (1.0 - k * 0.5)
			s.flash.scale = Vector3(sc, sc, sc)
			var c := s.color
			c.a = 1.0 - k
			s.flash.set_instance_shader_parameter("tint", c)
	for p in _popups:
		if not p.label.visible:
			continue
		p.age += delta
		var k := p.age / p.life
		if k >= 1.0:
			p.label.visible = false
			continue
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - p.age * 8.0)
		var s := p.size * pop
		p.label.scale = Vector3(s, s, s)
		p.label.global_position = p.start + Vector3.UP * (p.rise * (1.0 - pow(1.0 - k, 2.0)))
		var a := 1.0 - smoothstep(0.65, 1.0, k)
		p.label.modulate = Color(p.color.r, p.color.g, p.color.b, a)
		p.label.outline_modulate = Color(0.05, 0.0, 0.12, a * 0.85)
