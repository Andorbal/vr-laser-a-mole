extends Node
## Runs the game through a real OpenXR runtime (e.g. Monado's simulated
## headset) and reports whether the XR rig came up:
##
##   godot --path . res://tests/xr_check.tscn -- [--shots=/abs/dir]

var main: Node3D
var shots_dir := ""
var _mirror: SubViewport
var _mirror_cam: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	# The headset image never reaches the window, so mirror the head camera
	# into an offscreen viewport for screenshots.
	_mirror = SubViewport.new()
	_mirror.size = Vector2i(1280, 720)
	_mirror.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_mirror.world_3d = get_viewport().world_3d
	add_child(_mirror)
	_mirror_cam = Camera3D.new()
	_mirror_cam.fov = 90.0
	_mirror.add_child(_mirror_cam)
	_run.call_deferred()


func _process(_delta: float) -> void:
	var player := main.get_node_or_null("Player") as PlayerRig
	if player and player.camera and _mirror_cam:
		_mirror_cam.global_transform = player.camera.global_transform


func _run() -> void:
	var player: PlayerRig = main.get_node("Player")
	var game: GameManager = main.get_node("Game")
	for i in 120:
		await get_tree().process_frame
	print("XR active: ", player.xr_active)
	if player.xr_interface:
		print("XR session running: ", player.xr_interface.is_initialized(), "  refresh rate: ", player.xr_interface.display_refresh_rate)
	print("camera: ", player.camera.get_class(), " at ", player.camera.global_position)
	for b in player.blasters:
		print("blaster ", b.controller.tracker if b.controller else &"desktop", " tracking=", b.is_tracking(), " at ", b.global_position)
	if shots_dir != "":
		await RenderingServer.frame_post_draw
		_mirror.get_texture().get_image().save_png(shots_dir.path_join("xr_view.png"))
	game.start_mode(game.modes[0])
	for i in 200:
		await get_tree().process_frame
	print("state after start: ", GameManager.State.keys()[game.state], " bots out: ", game.active_bot_count())
	if shots_dir != "":
		await RenderingServer.frame_post_draw
		_mirror.get_texture().get_image().save_png(shots_dir.path_join("xr_play.png"))
	get_tree().quit()
