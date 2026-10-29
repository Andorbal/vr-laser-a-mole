extends Node
## Renders a fixed set of screenshots for reviewing the look (needs a real
## renderer, not --headless):
##
##   godot --path . res://tests/screenshots.tscn --fixed-fps 30 -- --shots=/abs/dir

var main: Node3D
var game: GameManager
var player: PlayerRig
var shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	if shots_dir == "":
		shots_dir = OS.get_user_data_dir().path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(shots_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	game = main.get_node("Game")
	player = main.get_node("Player")
	await _frames(40)
	_aim(Vector3(0.0, -0.05, -1.0))
	await _shot("menu")

	game.start_mode(game.modes[0])
	await _wait(3.0)
	# Stage a busy moment in front of the player.
	var dome: Dome = main.get_node("Dome")
	var kinds: Array[BotModel.Kind] = [BotModel.Kind.NORMAL, BotModel.Kind.GOLDEN, BotModel.Kind.ARMORED, BotModel.Kind.BOMB, BotModel.Kind.MEDIC, BotModel.Kind.NORMAL]
	var spots: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 10), Vector2i(0, 1), Vector2i(0, 10), Vector2i(2, 0), Vector2i(0, 0)]
	for i in spots.size():
		var h := dome.hatch_at(spots[i].x, spots[i].y)
		game.spawn_bot(h, kinds[i], 30.0, 0.2)
	await _wait(1.0)
	_aim(Vector3(0.0, 0.12, -1.0))
	await _shot("bots_front")
	# Close look at one bot.
	var close := dome.hatch_at(1, 0)
	_aim(close.bot.head_global() - player.head_position())
	var cam := player.camera
	var fov := cam.fov
	cam.fov = 22.0
	await _frames(2)
	await _shot("bot_closeup")
	var armored := dome.hatch_at(0, 1)
	_aim(armored.bot.head_global() - player.head_position())
	await _frames(2)
	await _shot("armored_closeup")
	cam.fov = fov
	_aim(close.bot.head_global() - player.head_position())
	await _frames(2)
	# Shoot it and catch the explosion.
	player.blasters[0].fire()
	await _frames(4)
	await _shot("explosion")
	await _frames(10)
	await _shot("popup")
	# Bots behind the player: HUD arrows.
	for k in [4, 5, 6]:
		var h := dome.hatch_at(1, k)
		if h.is_free():
			game.spawn_bot(h, BotModel.Kind.NORMAL, 30.0, 0.2)
	await _wait(0.8)
	_aim(Vector3(0.0, 0.0, -1.0))
	await _shot("hud_arrows")
	_aim(Vector3(0.0, -0.75, -0.66))
	await _shot("radar")
	_aim(Vector3(0.0, 0.0, 1.0))
	await _shot("behind")
	# Results screen.
	_aim(Vector3(0.0, -0.05, -1.0))
	game.score = 23456
	game.whacked = 51
	game.spawned = 63
	game.shots = 70
	game.shots_hit = 55
	game.best_streak = 19
	game.end_run("TIME UP!")
	await _wait(1.0)
	await _shot("results")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _aim(dir: Vector3) -> void:
	var d := dir.normalized()
	player.camera.rotation = Vector3(asin(clampf(d.y, -1.0, 1.0)), atan2(-d.x, -d.z), 0.0)


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(file_name + ".png"))
	print("screenshot ", file_name)
