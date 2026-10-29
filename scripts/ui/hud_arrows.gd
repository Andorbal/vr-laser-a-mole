class_name HudArrows
extends Node3D
## Head-locked chevrons around the edge of your view, pointing at every bot
## you can't currently see. Bigger arrows mean further behind you; faster
## pulsing means the bot is about to hide. Bombs get no arrow.
## Add as a child of the camera.

const MAX_ARROWS := 12
const DISTANCE := 1.2
const RING_RADIUS := 0.55
const VISIBLE_CONE := 0.7 ## Radians from view center where no arrow is needed.

var bots: Array[Bot] = []
var _arrows: Array[MeshInstance3D] = []


func _ready() -> void:
	var mat := Mat.shader_material("res://shaders/hud_arrow.gdshader")
	var mesh := Mat.quad(Vector2(1.0, 1.0))
	for i in MAX_ARROWS:
		var a := Mat.add_mesh(self, mesh, mat)
		a.visible = false
		_arrows.append(a)


func _process(_delta: float) -> void:
	var cam := get_parent() as Node3D
	if cam == null:
		return
	var inv := cam.global_transform.affine_inverse()
	var used := 0
	for bot in bots:
		if used >= MAX_ARROWS:
			break
		if not bot.is_out() or bot.kind == BotModel.Kind.BOMB:
			continue
		var local := inv * bot.head_global()
		var dist := local.length()
		if dist < 0.01:
			continue
		var off_center := acos(clampf(-local.z / dist, -1.0, 1.0))
		if off_center < VISIBLE_CONE:
			continue
		var d2 := Vector2(local.x, local.y)
		if d2.length() < 0.001:
			d2 = Vector2(0.0, -1.0)
		d2 = d2.normalized()
		var behind := clampf((off_center - VISIBLE_CONE) / (PI - VISIBLE_CONE), 0.0, 1.0)
		var r := RING_RADIUS * (1.0 + behind * 0.12)
		var arrow := _arrows[used]
		used += 1
		arrow.visible = true
		arrow.position = Vector3(d2.x * r, d2.y * r, -DISTANCE)
		arrow.rotation = Vector3(0.0, 0.0, atan2(d2.y, d2.x))
		var s := 0.065 + 0.055 * behind
		arrow.scale = Vector3(s, s, s)
		var c := BotModel.eye_color_for(bot.kind)
		c.a = 0.75 + 0.25 * behind
		arrow.set_instance_shader_parameter("arrow_color", c)
		arrow.set_instance_shader_parameter("urgency", bot.urgency())
	for i in range(used, MAX_ARROWS):
		_arrows[i].visible = false
