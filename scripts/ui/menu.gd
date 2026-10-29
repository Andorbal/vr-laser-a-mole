class_name Menu
extends Node3D
## All 3D menus: title screen, results and pause. Everything is shot with the
## lasers, like the bots.

signal mode_chosen(mode: GameMode)
signal recenter_requested
signal music_toggled
signal play_again_requested
signal menu_requested
signal resume_requested

const BUTTON_DIST := 2.5
const SIDE_ANGLE := 0.9
const SIDE_DIST := 2.15
const PANEL_ALPHA := 0.88

var _modes: Array[GameMode] = []
var _main: Node3D
var _results: Node3D
var _pause: Node3D
var _mode_buttons: Array[Button3D] = []
var _music_button: Button3D
var _title: Label3D
var _bestiary: Array[BotModel] = []
var _result_title: Label3D
var _result_score: Label3D
var _result_best: Label3D
var _result_stats: Label3D
var _result_rank: Label3D
var _new_best := false
var _t := 0.0


func build(modes: Array[GameMode]) -> void:
	_modes = modes
	_main = Node3D.new()
	_main.name = "Main"
	add_child(_main)
	_results = Node3D.new()
	_results.name = "Results"
	add_child(_results)
	_pause = Node3D.new()
	_pause.name = "Pause"
	add_child(_pause)
	_build_main()
	_build_results()
	_build_pause()
	show_main()


## Places a node at [param pos] (relative to the menu) facing the player.
static func _face_player(node: Node3D, pos: Vector3) -> void:
	node.position = pos
	node.rotation = Vector3(0.0, atan2(-pos.x, -pos.z), 0.0)


static func _polar(angle: float, dist: float, height: float) -> Vector3:
	return Vector3(sin(angle) * dist, height, -cos(angle) * dist)


func _panel(parent: Node3D, size: Vector2, color: Color, alpha := 0.6) -> MeshInstance3D:
	var mat := Mat.shader_material("res://shaders/panel.gdshader", {"fill_alpha": alpha})
	var p := Mat.add_mesh(parent, Mat.quad(size), mat)
	p.set_instance_shader_parameter("panel_color", color)
	p.set_instance_shader_parameter("panel_size", size)
	return p


func _label(parent: Node3D, text: String, size: int, font: Font, color: Color, pos: Vector3) -> Label3D:
	var l := GameFonts.make_label(text, size, font, color)
	l.position = pos
	l.render_priority = 3
	l.outline_render_priority = 2
	parent.add_child(l)
	return l


func _button(parent: Node3D, text: String, sub_text: String, size: Vector2, color: Color, pos: Vector3, font_size := 72) -> Button3D:
	var b := Button3D.new(text, sub_text, size, color, font_size)
	_face_player(b, pos)
	parent.add_child(b)
	return b


func _build_main() -> void:
	# Title.
	var title_root := Node3D.new()
	_face_player(title_root, Vector3(0.0, 2.28, -3.0))
	_main.add_child(title_root)
	var marquee := _panel(title_root, Vector2(2.75, 0.7), Palette.MAGENTA, 0.9)
	marquee.position = Vector3(0.0, -0.08, -0.01)
	_title = _label(title_root, "LASER-A-MOLE", 240, GameFonts.title(), Color(1.0, 0.86, 0.97), Vector3(0.0, 0.03, 0.0))
	_title.outline_size = 42
	_title.outline_modulate = Color(1.0, 0.1, 0.7, 0.75)
	var underline := Mat.add_mesh(title_root, Mat.box(Vector3(2.4, 0.014, 0.014)), Mat.neon(Palette.CYAN, 3.0), Vector3(0.0, -0.15, 0.0))
	underline.name = "Underline"
	var tag := _label(title_root, "POINT.  SHOOT.  WHACK.", 70, GameFonts.display(), Palette.CYAN, Vector3(0.0, -0.29, 0.0))
	tag.outline_size = 10
	tag.outline_modulate = Color(0.0, 0.2, 0.4, 0.8)

	# Mode buttons.
	var xs: Array[float] = [-0.8, 0.0, 0.8]
	for i in _modes.size():
		var m := _modes[i]
		var b := _button(_main, m.title, "", Vector2(0.72, 0.46), m.color, Vector3(xs[i], 1.42, -BUTTON_DIST), 84)
		b.label.position.y = 0.09
		b.sub_label.position.y = -0.07
		b.pressed.connect(func(_b: Button3D) -> void: mode_chosen.emit(m))
		_mode_buttons.append(b)
	refresh_bests()

	var recenter := _button(_main, "RECENTER", "", Vector2(0.5, 0.15), Palette.PURPLE, Vector3(-0.4, 0.98, -BUTTON_DIST + 0.1), 40)
	recenter.pressed.connect(func(_b: Button3D) -> void: recenter_requested.emit())
	_music_button = _button(_main, "MUSIC: ON", "", Vector2(0.5, 0.15), Palette.PURPLE, Vector3(0.4, 0.98, -BUTTON_DIST + 0.1), 40)
	_music_button.pressed.connect(func(_b: Button3D) -> void: music_toggled.emit())
	set_music_label(Save.music_enabled)

	_build_bestiary()
	_build_instructions()


func _build_bestiary() -> void:
	var root := Node3D.new()
	_face_player(root, _polar(-SIDE_ANGLE, SIDE_DIST, 1.42))
	_main.add_child(root)
	_panel(root, Vector2(1.6, 0.95), Palette.CYAN, PANEL_ALPHA)
	_label(root, "KNOW YOUR BOTS", 72, GameFonts.display(), Palette.CYAN, Vector3(0.0, 0.37, 0.005))
	var kinds: Array[BotModel.Kind] = [BotModel.Kind.NORMAL, BotModel.Kind.GOLDEN, BotModel.Kind.ARMORED, BotModel.Kind.MEDIC, BotModel.Kind.BOMB]
	var names: Array[String] = ["BOT\n+100", "GOLDEN\n+500 FAST!", "ARMORED\n2 HITS", "MEDIC\n+1 LIFE", "BOMB\nDON'T SHOOT"]
	for i in kinds.size():
		var x := (float(i) - 2.0) * 0.3
		var bot := BotModel.new(kinds[i])
		bot.scale = Vector3.ONE * 0.44
		bot.position = Vector3(x, 0.08, 0.06)
		bot.rotation = Vector3(0.0, PI, 0.0)
		root.add_child(bot)
		_bestiary.append(bot)
		var c := BotModel.eye_color_for(kinds[i])
		var cap := _label(root, names[i], 44, GameFonts.body(), c.lightened(0.3), Vector3(x, -0.3, 0.005))
		cap.line_spacing = -4.0


func _build_instructions() -> void:
	var root := Node3D.new()
	_face_player(root, _polar(SIDE_ANGLE, SIDE_DIST, 1.42))
	_main.add_child(root)
	_panel(root, Vector2(1.6, 0.95), Palette.MAGENTA, PANEL_ALPHA)
	_label(root, "HOW TO PLAY", 72, GameFonts.display(), Palette.MAGENTA, Vector3(0.0, 0.37, 0.005))
	var text := "\n".join(PackedStringArray([
		"•  TRIGGER fires. You have a blaster in each hand.",
		"•  Zap bots before they duck back in.",
		"•  Hits in a row build a COMBO. Misses break it.",
		"•  Arrows and floor blips point to bots you can't see. Look behind you!",
		"•  Never shoot a BOMB.",
		"•  MENU / B / Y pauses.",
	]))
	var body := _label(root, text, 42, GameFonts.body(), Color(0.95, 0.9, 1.0), Vector3(0.0, -0.08, 0.005))
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.width = 1.48 / body.pixel_size
	body.line_spacing = 2.0


func _build_results() -> void:
	var root := Node3D.new()
	_face_player(root, Vector3(0.0, 1.62, -BUTTON_DIST - 0.1))
	_results.add_child(root)
	_panel(root, Vector2(1.7, 1.0), Palette.CYAN, 0.96)
	_result_title = _label(root, "TIME UP!", 96, GameFonts.title(), Palette.CYAN, Vector3(0.0, 0.36, 0.005))
	_result_score = _label(root, "0", 220, GameFonts.title(), Color.WHITE, Vector3(-0.12, 0.1, 0.005))
	_result_score.outline_size = 30
	_result_score.outline_modulate = Color(0.0, 0.6, 1.0, 0.6)
	_result_best = _label(root, "", 52, GameFonts.display(), Palette.GOLD, Vector3(-0.12, -0.1, 0.005))
	_result_stats = _label(root, "", 44, GameFonts.body(), Color(0.9, 0.9, 1.0), Vector3(0.0, -0.33, 0.005))
	_result_rank = _label(root, "S", 300, GameFonts.title(), Palette.GOLD, Vector3(0.62, 0.06, 0.005))
	_result_rank.outline_size = 40
	var again := _button(_results, "PLAY AGAIN", "", Vector2(0.62, 0.17), Palette.GREEN, Vector3(-0.4, 0.92, -BUTTON_DIST + 0.15), 48)
	again.pressed.connect(func(_b: Button3D) -> void: play_again_requested.emit())
	var back := _button(_results, "MENU", "", Vector2(0.62, 0.17), Palette.PURPLE, Vector3(0.4, 0.92, -BUTTON_DIST + 0.15), 48)
	back.pressed.connect(func(_b: Button3D) -> void: menu_requested.emit())


func _build_pause() -> void:
	var root := Node3D.new()
	_face_player(root, Vector3(0.0, 1.55, -2.2))
	_pause.add_child(root)
	_panel(root, Vector2(1.1, 0.42), Palette.PURPLE, PANEL_ALPHA)
	_label(root, "PAUSED", 120, GameFonts.title(), Color.WHITE, Vector3(0.0, 0.04, 0.005))
	var resume := _button(_pause, "RESUME", "", Vector2(0.5, 0.17), Palette.GREEN, Vector3(-0.3, 1.1, -2.1), 48)
	resume.pressed.connect(func(_b: Button3D) -> void: resume_requested.emit())
	var quit := _button(_pause, "QUIT RUN", "", Vector2(0.5, 0.17), Palette.RED, Vector3(0.3, 1.1, -2.1), 48)
	quit.pressed.connect(func(_b: Button3D) -> void: menu_requested.emit())


func refresh_bests() -> void:
	for i in _mode_buttons.size():
		var m := _modes[i]
		var best := Save.best_score(m.id)
		var best_text := "BEST  %s" % format_score(best) if best > 0 else "NEW!"
		_mode_buttons[i].set_text(m.title, "%s\n%s" % [m.subtitle, best_text])


func set_music_label(on: bool) -> void:
	_music_button.set_text("MUSIC: ON" if on else "MUSIC: OFF")


## Turns the whole menu to face [param yaw] (so results appear where the player looks).
func face_yaw(yaw: float) -> void:
	rotation = Vector3(0.0, yaw, 0.0)


func show_main() -> void:
	face_yaw(0.0)
	_set_group(_main, true)
	_set_group(_results, false)
	_set_group(_pause, false)
	refresh_bests()


func show_pause(yaw: float) -> void:
	face_yaw(yaw)
	_set_group(_main, false)
	_set_group(_results, false)
	_set_group(_pause, true)


func show_results(yaw: float, title: String, mode: GameMode, score: int, new_best: bool, stats: String) -> void:
	face_yaw(yaw)
	_result_title.text = title
	_result_title.modulate = mode.color
	_result_score.text = format_score(score)
	_new_best = new_best
	if new_best:
		_result_best.text = "NEW BEST!"
	else:
		_result_best.text = "BEST  %s" % format_score(Save.best_score(mode.id))
	_result_stats.text = stats
	var rank := mode.rank_for(score)
	_result_rank.text = rank
	_result_rank.modulate = _rank_color(rank)
	_result_rank.outline_modulate = Color(_rank_color(rank), 0.4)
	_set_group(_main, false)
	_set_group(_results, true)
	_set_group(_pause, false)


func hide_all() -> void:
	_set_group(_main, false)
	_set_group(_results, false)
	_set_group(_pause, false)


func _set_group(group: Node3D, on: bool) -> void:
	group.visible = on
	group.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


static func _rank_color(rank: String) -> Color:
	match rank:
		"S":
			return Palette.GOLD
		"A":
			return Palette.MAGENTA
		"B":
			return Palette.CYAN
		"C":
			return Palette.GREEN
	return Palette.PURPLE


static func format_score(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func _process(delta: float) -> void:
	_t += delta
	if _main.visible:
		var glow := 0.65 + 0.2 * sin(_t * 2.2) + 0.1 * sin(_t * 7.3)
		_title.outline_modulate = Color(1.0, 0.1, 0.7, glow)
		for i in _bestiary.size():
			var bot := _bestiary[i]
			var t := _t + float(i) * 1.3
			bot.head.rotation = Vector3(0.0, sin(t * 0.9) * 0.3, sin(t * 2.0) * 0.12)
			bot.position.y = 0.05 + sin(t * 2.4) * 0.012
			var blink := maxf(0.0, 1.0 - absf(fmod(t, 3.7) - 0.1) * 12.0)
			bot.set_blink(blink)
	if _results.visible and _new_best:
		_result_best.modulate = Palette.GOLD.lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 8.0))
