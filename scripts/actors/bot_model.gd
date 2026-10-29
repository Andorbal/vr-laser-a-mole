class_name BotModel
extends Node3D
## Visual model of a bot: a glossy toy robot with a screen face.
## Faces -Z. The head center is at the origin; the body trails off along +Z
## (into the hatch tube).

enum Kind { NORMAL, GOLDEN, ARMORED, BOMB, MEDIC }

const FACE_IDLE := 0
const FACE_HAPPY := 1
const FACE_DIZZY := 2
const FACE_SCARED := 3
const FACE_ANGRY := 4
const FACE_STARS := 5
const FACE_HEARTS := 6
const FACE_SURPRISED := 7

const HEAD_RADIUS := 0.3
const BOT_LAYER := 2 ## Render layer bit lit by the head light (see WorldBuilder).
const FACE_RADIUS := 0.23
# The armor sits like a cap, tilted back so the eyes stay visible.
const HELMET_POS := Vector3(0.0, 0.1, 0.05)
const HELMET_ROT := Vector3(0.3, 0.0, 0.0)

static var _shared: Dictionary = {}

var kind := Kind.NORMAL
var head: Node3D ## Pivot for tilts and spins.
var face_mesh: MeshInstance3D
var helmet: MeshInstance3D
var bulb: MeshInstance3D
var _shell: MeshInstance3D
var _ears: Array[MeshInstance3D] = []
var _ear_rings: Array[MeshInstance3D] = []
var _helmet_tween: Tween


func _init(p_kind: Kind = Kind.NORMAL) -> void:
	_build()
	set_kind(p_kind)


static func eye_color_for(k: Kind) -> Color:
	match k:
		Kind.GOLDEN:
			return Color(1.0, 0.82, 0.3)
		Kind.ARMORED:
			return Color(0.85, 0.45, 1.0)
		Kind.BOMB:
			return Color(1.0, 0.12, 0.15)
		Kind.MEDIC:
			return Color(0.3, 1.0, 0.55)
	return Palette.CYAN


static func default_face_for(k: Kind) -> int:
	match k:
		Kind.GOLDEN:
			return FACE_STARS
		Kind.BOMB:
			return FACE_ANGRY
		Kind.MEDIC:
			return FACE_HEARTS
	return FACE_IDLE


static func _res(key: String) -> Resource:
	if _shared.is_empty():
		_shared["head"] = Mat.sphere(HEAD_RADIUS, HEAD_RADIUS * 1.86, 32, 16)
		_shared["face"] = Mat.sphere(FACE_RADIUS, FACE_RADIUS * 1.5, 32, 16)
		_shared["helmet"] = _helmet_mesh()
		_shared["antenna"] = Mat.cylinder(0.008, 0.014, 0.16, 8)
		_shared["bulb"] = Mat.sphere(0.042, -1.0, 12, 6)
		_shared["ear"] = Mat.cylinder(0.075, 0.075, 0.07, 20)
		_shared["ear_ring"] = Mat.torus(0.045, 0.07, 24, 6)
		_shared["collar"] = Mat.torus(0.15, 0.22, 32, 8)
		_shared["body"] = Mat.cylinder(0.2, 0.17, 0.7, 24)
		_shared["face_mat"] = Mat.shader_material("res://shaders/bot_face.gdshader", {"face_radius": FACE_RADIUS})
		_shared["metal_mat"] = Mat.pbr(Palette.METAL_DARK, 0.85, 0.3)
		_shared["body_mat"] = Mat.pbr(Color(0.16, 0.16, 0.22), 0.6, 0.35)
		_shared["shell_" + str(Kind.NORMAL)] = Mat.plastic(Color(0.88, 0.9, 0.98))
		_shared["shell_" + str(Kind.MEDIC)] = Mat.plastic(Color(0.85, 1.0, 0.92))
		_shared["shell_" + str(Kind.ARMORED)] = Mat.plastic(Color(0.62, 0.56, 0.86))
		var bomb := Mat.plastic(Color(0.13, 0.12, 0.15), 0.35)
		bomb.rim_tint = 0.0
		_shared["shell_" + str(Kind.BOMB)] = bomb
		var gold := Mat.pbr(Color(1.0, 0.74, 0.25), 1.0, 0.2)
		gold.rim_enabled = true
		gold.rim = 0.3
		_shared["shell_" + str(Kind.GOLDEN)] = gold
		_shared["helmet_mat"] = Mat.pbr(Color(0.3, 0.16, 0.62), 0.9, 0.22, Color(0.5, 0.2, 1.0), 0.6)
		for k in Kind.values():
			_shared["accent_" + str(k)] = Mat.neon(eye_color_for(k), 3.0)
	return _shared[key]


static func _helmet_mesh() -> SphereMesh:
	var m := Mat.sphere(HEAD_RADIUS + 0.02, 0.22, 32, 10)
	m.is_hemisphere = true
	return m


func _build() -> void:
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	_shell = Mat.add_mesh(head, _res("head"), null)
	face_mesh = Mat.add_mesh(head, _res("face"), _res("face_mat"), Vector3(0.0, -0.01, -0.19))
	face_mesh.scale = Vector3(1.0, 1.0, 0.55)
	Mat.add_mesh(head, _res("antenna"), _res("metal_mat"), Vector3(0.0, HEAD_RADIUS * 0.93 + 0.06, 0.02))
	bulb = Mat.add_mesh(head, _res("bulb"), null, Vector3(0.0, HEAD_RADIUS * 0.93 + 0.15, 0.02))
	for side in [-1.0, 1.0]:
		var ear := Mat.add_mesh(head, _res("ear"), _res("metal_mat"), Vector3(float(side) * (HEAD_RADIUS - 0.01), 0.02, 0.02))
		ear.rotation = Vector3(0.0, 0.0, PI * 0.5)
		_ears.append(ear)
		var ring := Mat.add_mesh(head, _res("ear_ring"), null, Vector3(float(side) * (HEAD_RADIUS + 0.03), 0.02, 0.02))
		ring.rotation = Vector3(0.0, 0.0, PI * 0.5)
		_ear_rings.append(ring)
	helmet = Mat.add_mesh(head, _res("helmet"), _res("helmet_mat"), HELMET_POS)
	helmet.rotation = HELMET_ROT

	var collar := Mat.add_mesh(self, _res("collar"), _res("metal_mat"), Vector3(0.0, -0.05, 0.24))
	collar.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	var body := Mat.add_mesh(self, _res("body"), _res("body_mat"), Vector3(0.0, -0.05, 0.6))
	body.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_put_on_bot_layer(self)


## Bots also live on render layer 2, the only layer the player's head light touches.
static func _put_on_bot_layer(node: Node) -> void:
	for child in node.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = 1 | BOT_LAYER
		_put_on_bot_layer(child)


func set_kind(k: Kind) -> void:
	kind = k
	_shell.material_override = _res("shell_" + str(k))
	var accent: Material = _res("accent_" + str(k))
	bulb.material_override = accent
	for r in _ear_rings:
		r.material_override = accent
	reset_helmet()
	set_face(default_face_for(k))
	face_mesh.set_instance_shader_parameter("eye_color", eye_color_for(k))
	set_flash(0.0)
	set_blink(0.0)
	set_look(Vector2.ZERO)


func reset_helmet() -> void:
	if _helmet_tween:
		_helmet_tween.kill()
	helmet.visible = kind == Kind.ARMORED
	helmet.position = HELMET_POS
	helmet.rotation = HELMET_ROT
	helmet.scale = Vector3.ONE


## Knocks the armor plate off with a spin.
func pop_helmet() -> void:
	if not helmet.visible:
		return
	if _helmet_tween:
		_helmet_tween.kill()
	_helmet_tween = create_tween().set_parallel(true)
	var side := -1.0 if randf() < 0.5 else 1.0
	_helmet_tween.tween_property(helmet, "position", Vector3(side * 0.35, 0.55, 0.25), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_helmet_tween.tween_property(helmet, "rotation", Vector3(-2.5, side * 3.0, side * 2.0), 0.45)
	_helmet_tween.tween_property(helmet, "scale", Vector3(0.01, 0.01, 0.01), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_helmet_tween.chain().tween_callback(func() -> void: helmet.visible = false)


func set_face(f: int) -> void:
	face_mesh.set_instance_shader_parameter("face", float(f))


func set_blink(b: float) -> void:
	face_mesh.set_instance_shader_parameter("blink", b)


func set_look(v: Vector2) -> void:
	face_mesh.set_instance_shader_parameter("look", v)


func set_flash(f: float) -> void:
	face_mesh.set_instance_shader_parameter("flash", f)


func set_eye_alpha(a: float) -> void:
	var c := eye_color_for(kind)
	c.a = a
	face_mesh.set_instance_shader_parameter("eye_color", c)


func set_bulb_visible(on: bool) -> void:
	bulb.visible = on
