class_name Button3D
extends Shootable
## A holographic menu button. Aim at it to highlight, shoot it to press.

signal pressed(button: Button3D)

var size := Vector2(0.6, 0.3)
var color := Palette.CYAN
var enabled := true
var label: Label3D
var sub_label: Label3D
var _panel: MeshInstance3D
var _highlight := 0.0
var _press := 0.0


func _init(text: String, sub_text: String, p_size: Vector2, p_color: Color, font_size := 72) -> void:
	size = p_size
	color = p_color
	_panel = Mat.add_mesh(self, Mat.quad(p_size), Mat.shader_material("res://shaders/panel.gdshader", {"fill_alpha": 0.88}))
	_panel.set_instance_shader_parameter("panel_color", p_color)
	_panel.set_instance_shader_parameter("panel_size", p_size)
	label = GameFonts.make_label(text, font_size, GameFonts.display())
	label.position = Vector3(0.0, 0.03 if sub_text != "" else 0.0, 0.004)
	label.render_priority = 2
	label.outline_render_priority = 1
	label.width = p_size.x / label.pixel_size
	add_child(label)
	sub_label = GameFonts.make_label(sub_text, int(font_size * 0.58), GameFonts.body(), p_color.lightened(0.45))
	sub_label.position = Vector3(0.0, -p_size.y * 0.24, 0.004)
	sub_label.render_priority = 2
	sub_label.outline_render_priority = 1
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.width = (p_size.x - 0.04) / sub_label.pixel_size
	add_child(sub_label)


func set_text(text: String, sub_text := "") -> void:
	label.text = text
	sub_label.text = sub_text


func is_target_active() -> bool:
	return enabled


func ray_test(origin: Vector3, dir: Vector3) -> float:
	var n := global_transform.basis.z.normalized()
	var denom := dir.dot(n)
	if absf(denom) < 0.0001:
		return -1.0
	var t := (global_position - origin).dot(n) / denom
	if t < 0.0:
		return -1.0
	var local := global_transform.affine_inverse() * (origin + dir * t)
	if absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5:
		return t
	return -1.0


func hover_changed(hovered: bool) -> void:
	if hovered and enabled:
		Sfx.play(&"ui_hover", -16.0, 1.2)


func on_shot(point: Vector3, blaster: Blaster) -> void:
	if not enabled:
		return
	_press = 1.0
	Sfx.play(&"ui_select", -4.0)
	if blaster:
		blaster.pulse(0.6, 0.07)
	if Fx.instance:
		Fx.instance.spark(point, color)
	pressed.emit(self)


func _process(delta: float) -> void:
	var target := 1.0 if hover_count > 0 and enabled else 0.0
	_highlight = move_toward(_highlight, target, delta * 8.0)
	_press = move_toward(_press, 0.0, delta * 4.0)
	_panel.set_instance_shader_parameter("highlight", _highlight + _press)
	var s := 1.0 + _highlight * 0.04 - _press * 0.06
	_panel.scale = Vector3(s, s, 1.0)
	var c := color if enabled else color.darkened(0.6)
	_panel.set_instance_shader_parameter("panel_color", c)
	label.modulate = Color.WHITE if enabled else Color(0.6, 0.6, 0.7)
