extends Node3D
## Entry point: builds the world, the player and the game, and wires them up.
## Everything is created in code so the whole look lives in a few scripts and
## shaders (see README for where to tweak things).


func _ready() -> void:
	var targeting := Targeting.new()
	targeting.name = "Targeting"
	add_child(targeting)

	var world := WorldBuilder.build(self)

	var dome := Dome.new()
	dome.name = "Dome"
	add_child(dome)

	var fx := Fx.new()
	fx.name = "Fx"
	add_child(fx)

	var player := PlayerRig.new()
	player.name = "Player"
	add_child(player)

	var hud := HudArrows.new()
	hud.name = "HudArrows"
	player.camera.add_child(hud)

	var radar := Radar.new()
	radar.name = "Radar"
	radar.player = player
	add_child(radar)

	var announcer := Announcer.new()
	announcer.name = "Announcer"
	announcer.camera = player.camera
	add_child(announcer)

	var menu := Menu.new()
	menu.name = "Menu"
	add_child(menu)

	var game := GameManager.new()
	game.name = "Game"
	add_child(game)
	game.setup(dome, player, menu, announcer, hud, radar, world["platform_material"])
