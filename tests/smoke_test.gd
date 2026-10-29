extends Node
## Automated play-through for testing without a headset.
##
##   godot --path . res://tests/smoke_test.tscn --fixed-fps 30 -- [--shots=/abs/dir] [--quick]
##
## Shoots the menu buttons, plays every mode with an auto-aiming "player",
## exercises pause/resume, prints a summary and exits with code 1 if any
## engine error was logged. With --shots it also saves screenshots
## (needs a real renderer, i.e. not --headless).

class ErrorCounter:
	extends Logger
	var errors := 0
	var messages: PackedStringArray = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		errors += 1
		if messages.size() < 40:
			messages.append("%s:%d %s(): %s %s" % [file, line, function, code, rationale])

	func _log_message(_message: String, _error: bool) -> void:
		pass

var main: Node3D
var game: GameManager
var player: PlayerRig
var shots_dir := ""
var quick := false
var counter := ErrorCounter.new()
var _summary: PackedStringArray = []


func _ready() -> void:
	OS.add_logger(counter)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(shots_dir)
		elif arg == "--quick":
			quick = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	game = main.get_node("Game")
	player = main.get_node("Player")
	_check(not player.xr_active, "desktop fallback active without a headset")
	await _frames(45)
	await _shot("01_menu_front")
	await _look_at_dir(Dome.dir_from(deg_to_rad(-6.0), deg_to_rad(-56.0)))
	await _shot("02_menu_bestiary")
	await _look_at_dir(Dome.dir_from(deg_to_rad(-6.0), deg_to_rad(56.0)))
	await _shot("03_menu_howto")

	# Attract mode: bots should pop up behind the menu.
	await _wait_game_time(4.0)
	_check(game.active_bot_count() > 0, "attract mode spawns bots")

	# Toggle music twice via the real buttons.
	await _shoot_button("MUSIC: ON")
	_check(not Save.music_enabled, "music button turns music off")
	await _shoot_button("MUSIC: OFF")
	_check(Save.music_enabled, "music button turns music back on")
	await _shoot_button("RECENTER")

	# --- Blitz -------------------------------------------------------------
	await _shoot_button("BLITZ")
	_check(game.state == GameManager.State.COUNTDOWN, "BLITZ button starts the countdown")
	await _wait_game_time(2.6)
	_check(game.state == GameManager.State.PLAYING, "countdown reaches PLAYING")
	await _hunt(14.0, "04_blitz_early")
	game.pause()
	_check(game.state == GameManager.State.PAUSED, "pause")
	await _frames(5)
	await _shot("05_paused")
	var paused_score := game.score
	await _wait_game_time(1.0)
	_check(game.score == paused_score, "nothing scores while paused")
	await _shoot_button("RESUME")
	_check(game.state == GameManager.State.PLAYING, "RESUME button resumes")
	await _hunt(28.0, "06_blitz_mid")
	await _look_back()
	await _shot("07_behind_you")
	await _hunt(30.0, "08_blitz_late")
	await _wait_until(func() -> bool: return game.state == GameManager.State.RESULTS, 10.0)
	_check(game.state == GameManager.State.RESULTS, "blitz ends with results")
	_summary.append("BLITZ: score %d, whacked %d/%d, shots %d (hit %d), best combo %d" % [
			game.score, game.whacked, game.spawned, game.shots, game.shots_hit, game.best_streak])
	_check(game.whacked > 15, "aimbot whacked a reasonable number of bots")
	await _frames(20)
	await _look_at_dir(player.head_forward())
	await _shot("09_results")

	# --- Survival: play a bit, then stop shooting until the run is over. -----
	await _shoot_button("MENU")
	_check(game.state == GameManager.State.MENU, "MENU button returns to menu")
	await _shoot_button("SURVIVAL")
	await _wait_game_time(2.6)
	await _hunt(10.0 if quick else 20.0, "10_survival")
	var lives_before := game.lives
	await _wait_until(func() -> bool: return game.state == GameManager.State.RESULTS, 120.0)
	_check(game.state == GameManager.State.RESULTS, "survival ends when lives run out (had %d)" % lives_before)
	_summary.append("SURVIVAL: score %d, whacked %d/%d, escapes %d" % [game.score, game.whacked, game.spawned, game.escapes])

	# --- Zen ----------------------------------------------------------------
	await _shoot_button("MENU")
	await _shoot_button("ZEN")
	await _wait_game_time(2.6)
	await _hunt(12.0, "11_zen")
	_check(game.state == GameManager.State.PLAYING, "zen never ends on its own")
	_summary.append("ZEN: score %d, whacked %d/%d" % [game.score, game.whacked, game.spawned])
	game.pause()
	await _frames(3)
	await _shoot_button("QUIT RUN")
	_check(game.state == GameManager.State.MENU, "QUIT RUN returns to menu")

	await _frames(10)
	print("\n===== SMOKE TEST SUMMARY =====")
	for line in _summary:
		print(line)
	print("engine errors logged: %d" % counter.errors)
	for m in counter.messages:
		print("  ", m)
	get_tree().quit(1 if counter.errors > 0 or _failed else 0)


var _failed := false


func _check(ok: bool, what: String) -> void:
	_summary.append(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failed = true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_game_time(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _wait_until(cond: Callable, max_seconds: float) -> void:
	var t := 0.0
	while t < max_seconds and not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func _shot(file_name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(file_name + ".png"))
	print("screenshot ", file_name)


func _aim(dir: Vector3) -> void:
	var d := dir.normalized()
	var yaw := atan2(-d.x, -d.z)
	var pitch := asin(clampf(d.y, -1.0, 1.0))
	player.camera.rotation = Vector3(pitch, yaw, 0.0)


func _look_at_dir(dir: Vector3) -> void:
	_aim(dir)
	await _frames(3)


func _look_back() -> void:
	var f := player.head_forward()
	_aim(Vector3(-f.x, 0.15, -f.z))
	await _frames(4)


## Aims at the menu button with this label and shoots it.
func _shoot_button(text: String) -> void:
	await _frames(2)
	var target: Button3D = null
	for n in main.get_node("Menu").find_children("*", "", true, false):
		if n is Button3D and (n as Button3D).label.text == text and (n as Button3D).is_visible_in_tree():
			target = n
	_check(target != null, "found button '%s'" % text)
	if target == null:
		return
	_aim(target.global_position - player.head_position())
	await _frames(3)
	var hit := player.blasters[0].fire()
	_check(hit != null and hit.target == target, "shot hits button '%s'" % text)
	await _frames(3)


## Plays like a (slightly too good) human: turns toward the nearest bot that
## isn't a bomb and fires when lined up. Grabs one screenshot mid-way.
func _hunt(seconds: float, shot_name: String) -> void:
	var t := 0.0
	var shot_taken := false
	var turn_speed := 5.0
	while t < seconds and game.state == GameManager.State.PLAYING:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var head := player.head_position()
		var fwd := player.head_forward()
		var best: Bot = null
		var best_angle := INF
		for b in game.bots:
			if not b.is_target_active() or b.kind == BotModel.Kind.BOMB:
				continue
			var a := fwd.angle_to(b.head_global() - head)
			if a < best_angle:
				best_angle = a
				best = b
		if best == null:
			continue
		var want := (best.head_global() - head).normalized()
		var dir := fwd.slerp(want, clampf(turn_speed * dt / maxf(best_angle, 0.001), 0.0, 1.0))
		_aim(dir)
		if not shot_taken and t > seconds * 0.5 and best_angle < 0.6:
			await _shot(shot_name)
			shot_taken = true
		if fwd.angle_to(want) < 0.03:
			player.blasters[0].fire()
