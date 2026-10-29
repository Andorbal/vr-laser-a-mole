class_name Announcer
extends Node3D
## Big callouts ("3", "2", "1", "GO!", "DOME EXPANDING") that appear in front
## of wherever the player is looking, then stay put in the world.

var camera: Camera3D
var _label: Label3D
var _sub: Label3D
var _age := 99.0
var _life := 1.0
var _color := Color.WHITE


func _ready() -> void:
	_label = GameFonts.make_label("", 220, GameFonts.title())
	_label.pixel_size = 0.0016
	_label.outline_size = 36
	_label.no_depth_test = true
	_label.render_priority = 20
	_label.outline_render_priority = 19
	add_child(_label)
	_sub = GameFonts.make_label("", 80, GameFonts.body())
	_sub.pixel_size = 0.0016
	_sub.outline_size = 16
	_sub.position = Vector3(0.0, -0.32, 0.0)
	_sub.no_depth_test = true
	_sub.render_priority = 20
	_sub.outline_render_priority = 19
	add_child(_sub)
	visible = false


func announce(text: String, color: Color, life := 1.1, sub_text := "", distance := 3.2) -> void:
	_label.text = text
	_sub.text = sub_text
	_color = color
	_life = life
	_age = 0.0
	visible = true
	if camera:
		var cam_pos := camera.global_position
		var fwd := -camera.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length() < 0.01:
			fwd = Vector3.FORWARD
		fwd = fwd.normalized()
		var pos := cam_pos + fwd * distance + Vector3.UP * 0.25
		global_transform = Transform3D(Basis.looking_at(pos - cam_pos, Vector3.UP), pos)


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	var k := _age / _life
	if k >= 1.0:
		visible = false
		return
	var pop := 1.0 + 0.6 * pow(maxf(0.0, 1.0 - _age * 6.0), 2.0)
	scale = Vector3.ONE * pop
	var a := 1.0 - smoothstep(0.7, 1.0, k)
	_label.modulate = Color(_color.r, _color.g, _color.b, a)
	_label.outline_modulate = Color(_color.r * 0.3, _color.g * 0.1, _color.b * 0.4, a * 0.8)
	_sub.modulate = Color(1.0, 1.0, 1.0, a)
	_sub.outline_modulate = Color(0.05, 0.0, 0.1, a * 0.8)
