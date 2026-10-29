class_name GameManager
extends Node
## Runs the game: menus -> countdown -> play -> results, scoring, combos,
## lives, and all the feedback that makes hits feel great.

enum State { MENU, COUNTDOWN, PLAYING, PAUSED, RESULTS }

const BOT_POOL := 12
const COMBO_STEP := 5 ## Hits per multiplier step.
const MAX_MULTIPLIER := 8
const QUICK_WINDOW := 0.8 ## Seconds after popping up that earn a reaction bonus.

var dome: Dome
var player: PlayerRig
var menu: Menu
var announcer: Announcer
var hud: HudArrows
var radar: Radar
var platform_mat: ShaderMaterial
var modes: Array[GameMode] = []
var mode: GameMode
var state := State.MENU
var bots: Array[Bot] = []
var director: Director

# Current run.
var score := 0
var streak := 0
var best_streak := 0
var lives := 0
var time_left := 0.0
var elapsed := 0.0
var shots := 0
var shots_hit := 0
var spawned := 0
var whacked := 0
var escapes := 0

var _countdown := 0.0
var _countdown_step := 0
var _last_second := -1
var _danger := 0.0


func setup(p_dome: Dome, p_player: PlayerRig, p_menu: Menu, p_announcer: Announcer, p_hud: HudArrows, p_radar: Radar, p_platform_mat: ShaderMaterial) -> void:
	dome = p_dome
	player = p_player
	menu = p_menu
	announcer = p_announcer
	hud = p_hud
	radar = p_radar
	platform_mat = p_platform_mat
	modes = GameMode.all()

	for i in BOT_POOL:
		var b := Bot.new()
		b.name = "Bot%d" % i
		b.look_provider = _bot_look_target
		b.destroyed.connect(_on_bot_destroyed)
		b.armor_cracked.connect(_on_bot_armor_cracked)
		b.escaped.connect(_on_bot_escaped)
		dome.add_child(b)
		bots.append(b)
	hud.bots = bots
	radar.bots = bots

	for blaster in player.blasters:
		blaster.fired.connect(_on_fired)
	player.menu_pressed.connect(_on_menu_pressed)
	player.focus_lost.connect(_on_focus_lost)

	menu.build(modes)
	menu.mode_chosen.connect(start_mode)
	menu.recenter_requested.connect(_on_recenter_requested)
	menu.music_toggled.connect(_on_music_toggled)
	menu.play_again_requested.connect(func() -> void: start_mode(mode))
	menu.menu_requested.connect(go_to_menu)
	menu.resume_requested.connect(resume)

	director = Director.new(self)
	go_to_menu()


# --- Flow -------------------------------------------------------------------

func go_to_menu() -> void:
	state = State.MENU
	mode = null
	_hide_all_bots()
	director.reset(true)
	menu.show_main()
	Sfx.play_music(&"music_menu")
	_update_display()


func start_mode(m: GameMode) -> void:
	if m == null:
		return
	mode = m
	score = 0
	streak = 0
	best_streak = 0
	lives = m.lives
	time_left = m.duration
	elapsed = 0.0
	shots = 0
	shots_hit = 0
	spawned = 0
	whacked = 0
	escapes = 0
	_last_second = -1
	_hide_all_bots()
	menu.hide_all()
	dome.fit_to_head_height(player.head_position().y)
	director.reset(false)
	state = State.COUNTDOWN
	_countdown = 0.0
	_countdown_step = 0
	Sfx.play_music(&"music_game")
	_update_display()


func pause() -> void:
	if state != State.PLAYING and state != State.COUNTDOWN:
		return
	state = State.PAUSED
	for b in bots:
		b.process_mode = Node.PROCESS_MODE_DISABLED
	menu.show_pause(_player_yaw())
	Sfx.play(&"ui_select", -6.0, 0.8)


func resume() -> void:
	if state != State.PAUSED:
		return
	for b in bots:
		b.process_mode = Node.PROCESS_MODE_INHERIT
	menu.hide_all()
	state = State.PLAYING
	announcer.announce("GO!", Palette.GREEN, 0.6)
	Sfx.play(&"go", -1.0)


func end_run(title: String) -> void:
	if state != State.PLAYING:
		return
	state = State.RESULTS
	_hide_all_bots()
	var new_best := Save.submit_score(mode.id, score)
	var accuracy := 0 if shots == 0 else roundi(100.0 * float(shots_hit) / float(shots))
	var whack_pct := 0 if spawned == 0 else roundi(100.0 * float(whacked) / float(spawned))
	var stats := "WHACKED %d / %d (%d%%)   ACCURACY %d%%   BEST COMBO %d" % [whacked, spawned, whack_pct, accuracy, best_streak]
	menu.show_results(_player_yaw(), title, mode, score, new_best, stats)
	Sfx.play(&"game_over", 1.0)
	if new_best:
		get_tree().create_timer(1.0).timeout.connect(func() -> void: Sfx.play(&"new_best", 1.0))
	player.pulse_all(0.6, 0.3)
	director.reset(true)
	Sfx.play_music(&"music_menu")
	_update_display()


func _on_menu_pressed() -> void:
	if state == State.PLAYING or state == State.COUNTDOWN:
		pause()
	elif state == State.PAUSED:
		resume()


func _on_focus_lost() -> void:
	pause()


func _on_recenter_requested() -> void:
	player.recenter()
	announcer.announce("CENTERED", Palette.PURPLE, 0.8)


func _on_music_toggled() -> void:
	Sfx.set_music_enabled(not Save.music_enabled)
	menu.set_music_label(Save.music_enabled)


# --- Per-frame --------------------------------------------------------------

func _process(delta: float) -> void:
	_danger = maxf(_danger - delta * 1.8, 0.0)
	if platform_mat:
		platform_mat.set_shader_parameter("now", dome.now)
		platform_mat.set_shader_parameter("danger", _danger)
	match state:
		State.MENU, State.RESULTS:
			director.update(delta, 0.05)
		State.COUNTDOWN:
			_update_countdown(delta)
		State.PLAYING:
			_update_playing(delta)
	_update_display()


func _update_countdown(delta: float) -> void:
	_countdown += delta
	var step := int(_countdown / 0.75)
	if step != _countdown_step or _countdown <= delta:
		_countdown_step = step
		if step < 3:
			announcer.announce(str(3 - step), mode.color, 0.7, mode.title if step == 0 else "")
			Sfx.play(&"countdown", -5.0, 1.0)
		else:
			state = State.PLAYING
			announcer.announce("GO!", Palette.GREEN, 0.8)
			Sfx.play(&"go", 1.0)
			player.pulse_all(0.4, 0.12)


func _update_playing(delta: float) -> void:
	elapsed += delta
	director.update(delta, mode.intensity_at(elapsed))
	if mode.duration > 0.0:
		time_left -= delta
		var sec := int(ceilf(time_left))
		if sec != _last_second:
			_last_second = sec
			if sec <= 10 and sec > 0:
				Sfx.play(&"tick", -4.0, 1.25 if sec <= 3 else 1.0)
				if sec == 10:
					announcer.announce("10 SECONDS!", Palette.ORANGE, 1.0)
		if time_left <= 0.0:
			time_left = 0.0
			end_run("TIME UP!")


func _update_display() -> void:
	var main_text := ""
	var sub_text := ""
	match state:
		State.MENU:
			main_text = "READY"
			sub_text = "shoot a mode"
		State.RESULTS:
			main_text = Menu.format_score(score)
			sub_text = "final score"
		State.PAUSED:
			main_text = "PAUSED"
			sub_text = Menu.format_score(score)
		_:
			if mode.duration > 0.0:
				var t := maxi(0, int(ceilf(time_left)))
				main_text = "%d:%02d" % [floori(t / 60.0), t % 60]
			elif mode.lives > 0:
				main_text = "LIVES %d" % lives
			else:
				main_text = Menu.format_score(score)
			sub_text = Menu.format_score(score) if mode.lives > 0 or mode.duration > 0.0 else ""
			var mult := multiplier()
			if mult > 1:
				sub_text += ("  " if sub_text != "" else "") + "x%d" % mult
	player.set_display(main_text, sub_text)


# --- Bots -------------------------------------------------------------------

func active_bot_count() -> int:
	var n := 0
	for b in bots:
		if b.is_active():
			n += 1
	return n


func spawn_bot(h: Hatch, kind: BotModel.Kind, up_time: float, pre_time: float) -> void:
	if h == null or not h.is_free():
		return
	for b in bots:
		if not b.is_active():
			b.process_mode = Node.PROCESS_MODE_INHERIT
			b.spawn(h, kind, up_time, pre_time)
			if state == State.PLAYING and kind != BotModel.Kind.BOMB:
				spawned += 1
			return


func multiplier() -> int:
	return mini(1 + floori(float(streak) / float(COMBO_STEP)), MAX_MULTIPLIER)


func _bot_look_target(b: Bot) -> Vector3:
	return player.nearest_aim_point(b.head_global())


func _hide_all_bots() -> void:
	for b in bots:
		b.process_mode = Node.PROCESS_MODE_INHERIT
		b.force_hide()


func _on_bot_destroyed(bot: Bot, blaster: Blaster) -> void:
	var pos := bot.head_global()
	var color := BotModel.eye_color_for(bot.kind)
	if bot.kind == BotModel.Kind.BOMB:
		_on_bomb_hit(bot, blaster)
		return
	Fx.instance.explode(pos, color, 1.25 if bot.kind == BotModel.Kind.GOLDEN else 1.0)
	if blaster:
		blaster.pulse(0.9, 0.09)
	if state != State.PLAYING:
		Sfx.play_at(&"hit", pos, 0.0, randf_range(0.95, 1.05))
		return

	whacked += 1
	streak += 1
	best_streak = maxi(best_streak, streak)
	var mult := multiplier()
	var base := 100
	match bot.kind:
		BotModel.Kind.GOLDEN:
			base = 500
		BotModel.Kind.ARMORED:
			base = 200
		BotModel.Kind.MEDIC:
			base = 150
	var quick := roundi(50.0 * clampf(1.0 - bot.time_fully_up / QUICK_WINDOW, 0.0, 1.0))
	var points := (base + quick) * mult
	score += points
	Sfx.play_at(&"hit", pos, 0.0, minf(1.0 + float(streak) * 0.012, 1.45) * randf_range(0.97, 1.03))
	var label := "+%d" % points
	Fx.instance.popup(pos + Vector3.UP * 0.35, label, color.lerp(Color.WHITE, 0.35), 1.0 + 0.08 * float(mult - 1))
	if platform_mat:
		platform_mat.set_shader_parameter("pulse_time", dome.now)

	match bot.kind:
		BotModel.Kind.GOLDEN:
			Sfx.play_at(&"gold", pos, 0.0)
			Fx.instance.popup(pos + Vector3.UP * 0.75, "GOLD!", Palette.GOLD, 1.3)
		BotModel.Kind.MEDIC:
			if mode.lives > 0 and lives < mode.lives:
				lives += 1
				Sfx.play(&"heal", -2.0)
				Fx.instance.popup(pos + Vector3.UP * 0.75, "+1 LIFE", Palette.GREEN, 1.2)
	if streak % COMBO_STEP == 0 and mult > 1:
		Sfx.play(&"combo", -3.0, 1.0 + 0.06 * float(mult - 2))
		Fx.instance.popup(pos + Vector3.UP * 0.8, "COMBO x%d" % mult, Palette.MAGENTA.lerp(Palette.GOLD, float(mult) / float(MAX_MULTIPLIER)), 1.4, 1.2)
		player.pulse_all(0.3, 0.06)
	elif quick >= 40:
		Fx.instance.popup(pos + Vector3.UP * 0.75, "QUICK!", Palette.CYAN, 0.8, 0.7)


func _on_bot_armor_cracked(bot: Bot, blaster: Blaster) -> void:
	var pos := bot.head_global()
	Sfx.play_at(&"armor", pos, 0.0, randf_range(0.95, 1.05))
	Fx.instance.spark(pos + Vector3.UP * 0.2, Palette.PURPLE)
	if blaster:
		blaster.pulse(0.6, 0.06)
	if state == State.PLAYING:
		score += 50 * multiplier()
		Fx.instance.popup(pos + Vector3.UP * 0.4, "CRACK!", Palette.PURPLE.lightened(0.3), 0.8, 0.6)


func _on_bomb_hit(bot: Bot, blaster: Blaster) -> void:
	var pos := bot.head_global()
	Fx.instance.explode(pos, Palette.RED, 1.8)
	Fx.instance.explode(pos + Vector3.UP * 0.1, Palette.ORANGE, 1.2)
	Sfx.play_at(&"bomb", pos, 0.0)
	player.pulse_all(1.0, 0.35)
	if blaster:
		blaster.pulse(1.0, 0.4)
	dome.danger = 1.0
	_danger = 1.0
	if state != State.PLAYING:
		return
	_break_combo(pos)
	if mode.lives > 0:
		_lose_life(pos)
	elif mode.bomb_penalty > 0:
		score = maxi(0, score - mode.bomb_penalty)
		Fx.instance.popup(pos + Vector3.UP * 0.4, "-%d" % mode.bomb_penalty, Palette.RED, 1.3)
	else:
		Fx.instance.popup(pos + Vector3.UP * 0.4, "OOPS!", Palette.RED, 1.1)


func _on_bot_escaped(bot: Bot) -> void:
	if state != State.PLAYING:
		return
	if bot.kind == BotModel.Kind.BOMB:
		return
	escapes += 1
	var pos := bot.head_global()
	_break_combo(pos)
	if mode.lives > 0 and (bot.kind == BotModel.Kind.NORMAL or bot.kind == BotModel.Kind.ARMORED):
		_lose_life(pos)


func _on_fired(blaster: Blaster, hit: Targeting.Hit) -> void:
	var counts := state == State.PLAYING
	if hit.target is Bot:
		if counts and (hit.target as Bot).kind != BotModel.Kind.BOMB:
			shots += 1
			shots_hit += 1
		return
	if hit.target != null:
		return # Menu button.
	Fx.instance.spark(hit.point, blaster.color)
	if hit.surface == Targeting.Surface.SHIELD:
		dome.add_impact(hit.point)
		Sfx.play_at(&"tink", hit.point, -10.0, randf_range(0.9, 1.2))
	if counts:
		shots += 1
		_break_combo(hit.point)


func _break_combo(pos: Vector3) -> void:
	if streak >= COMBO_STEP:
		Fx.instance.popup(pos + Vector3.UP * 0.3, "COMBO LOST", Color(0.75, 0.7, 0.9), 0.75, 0.8)
	streak = 0


func _lose_life(pos: Vector3) -> void:
	lives -= 1
	_danger = 1.0
	dome.danger = 1.0
	Sfx.play(&"life_lost", -6.0)
	player.pulse_all(0.7, 0.2)
	Fx.instance.popup(pos + Vector3.UP * 0.5, "ESCAPED!" if lives > 0 else "LAST ONE!", Palette.RED, 1.1)
	if lives <= 0:
		lives = 0
		end_run("GAME OVER")


# --- Events from the director ----------------------------------------------

func on_dome_expanded(full: bool) -> void:
	announcer.announce("DOME EXPANDING", Palette.PURPLE, 1.4, "LOOK AROUND YOU!" if full else "MORE HATCHES ONLINE")
	Sfx.play(&"expand", 0.0)
	player.pulse_all(0.25, 0.25)


func announce_event(text: String, color: Color) -> void:
	announcer.announce(text, color, 1.2)
	Sfx.play(&"whoosh", -3.0)


func _player_yaw() -> float:
	var f := player.head_forward()
	return atan2(-f.x, -f.z)
