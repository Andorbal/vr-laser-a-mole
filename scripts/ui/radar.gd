class_name Radar
extends Node3D
## Glowing blips on the floor ring around the player, one per bot that is
## out, placed in the bot's direction. Look down for a quick 360° overview.

const MAX_BLIPS := 12
const RADIUS := 1.14

var bots: Array[Bot] = []
var player: PlayerRig
var _blips: Array[MeshInstance3D] = []
var _t := 0.0


func _ready() -> void:
	var mat := Mat.shader_material("res://shaders/glow_sprite.gdshader", {"billboard": false, "energy": 2.2, "sharpness": 2.5})
	var mesh := Mat.quad(Vector2(1.0, 1.0))
	for i in MAX_BLIPS:
		var b := Mat.add_mesh(self, mesh, mat)
		b.visible = false
		_blips.append(b)


func _process(delta: float) -> void:
	_t += delta
	var center := Vector3.ZERO
	if player:
		center = player.head_position()
		center.y = 0.0
	var used := 0
	for bot in bots:
		if used >= MAX_BLIPS:
			break
		if not bot.is_out():
			continue
		var d := bot.head_global() - center
		var az := atan2(d.x, -d.z)
		var blip := _blips[used]
		used += 1
		blip.visible = true
		blip.position = Vector3(sin(az) * RADIUS, 0.06, -cos(az) * RADIUS)
		blip.rotation = Vector3(-PI * 0.5, -az, 0.0)
		var u := bot.urgency()
		var pulse := 1.0 + 0.25 * sin(_t * (6.0 + u * 14.0))
		blip.scale = Vector3(0.42 * pulse, 0.16 * pulse, 1.0)
		var c := BotModel.eye_color_for(bot.kind)
		blip.set_instance_shader_parameter("tint", c)
	for i in range(used, MAX_BLIPS):
		_blips[i].visible = false
