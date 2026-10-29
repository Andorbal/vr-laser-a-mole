class_name Director
extends RefCounted
## Decides when, where and what pops out. Difficulty rises by spawning more
## often, keeping more bots out at once, shortening how long they stay up,
## mixing in trickier bots, powering more of the dome (front -> all around),
## and throwing in the occasional pattern event.

const SECTORS: Array[float] = [1.3, 2.2, PI] ## Half-angles of the active dome.
const STAGE_AT: Array[float] = [0.0, 0.17, 0.4] ## Intensity where each sector unlocks.

var game: GameManager
var attract := false ## Gentle demo mode behind the menus.
var rng := RandomNumberGenerator.new()

var _spawn_timer := 0.8
var _event_timer := 16.0
var _stage := 0
var _queue: Array[Dictionary] = []


func _init(p_game: GameManager) -> void:
	game = p_game
	rng.randomize()


func reset(p_attract: bool) -> void:
	attract = p_attract
	_queue.clear()
	_spawn_timer = 1.2 if p_attract else 0.6
	_event_timer = rng.randf_range(14.0, 18.0)
	_stage = SECTORS.size() - 1 if p_attract else 0
	game.dome.set_sector(SECTORS[_stage], false)


func update(delta: float, k: float) -> void:
	var kc := clampf(k, 0.0, 1.0)
	var over := maxf(k - 1.0, 0.0)

	# Bots scheduled by pattern events.
	for i in range(_queue.size() - 1, -1, -1):
		var q: Dictionary = _queue[i]
		q["t"] = float(q["t"]) - delta
		if float(q["t"]) <= 0.0:
			var h: Hatch = q["hatch"]
			if h.is_free():
				game.spawn_bot(h, q["kind"], float(q["up"]), 0.3)
			_queue.remove_at(i)

	# Open up more of the dome as things heat up.
	if not attract:
		var stage := 0
		for s in STAGE_AT.size():
			if kc >= STAGE_AT[s]:
				stage = s
		if stage > _stage:
			_stage = stage
			game.dome.set_sector(SECTORS[stage], true)
			game.on_dome_expanded(stage == SECTORS.size() - 1)

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		var interval := lerpf(1.05, 0.36, kc) / (1.0 + over)
		var max_active := int(lerpf(2.0, 7.0, kc) + over * 5.0)
		if attract:
			interval = rng.randf_range(1.4, 2.6)
			max_active = 2
		_spawn_timer = interval * rng.randf_range(0.7, 1.3)
		if game.active_bot_count() < max_active:
			_spawn_one(kc, over)

	if not attract and game.mode and game.mode.allow_events and k > 0.3:
		_event_timer -= delta
		if _event_timer <= 0.0:
			_event_timer = rng.randf_range(13.0, 19.0)
			_start_event()


func _spawn_one(kc: float, over: float) -> void:
	var h := _pick_hatch(kc)
	if h == null:
		return
	var kind := _pick_kind(kc)
	var up := lerpf(2.5, 1.05, kc) / (1.0 + over * 0.6)
	var pre := lerpf(0.45, 0.28, kc)
	match kind:
		BotModel.Kind.GOLDEN:
			up *= 0.6
		BotModel.Kind.BOMB:
			up *= 1.15
		BotModel.Kind.MEDIC:
			up *= 0.85
	if attract:
		up = 3.2
		pre = 0.5
	game.spawn_bot(h, kind, maxf(up, 0.7), pre)


func _pick_kind(kc: float) -> BotModel.Kind:
	if attract:
		return BotModel.Kind.GOLDEN if rng.randf() < 0.1 else BotModel.Kind.NORMAL
	var mode := game.mode
	var golden := 0.045
	var bomb := lerpf(0.07, 0.16, kc) if mode.allow_bombs and kc > 0.12 else 0.0
	var armored := lerpf(0.06, 0.16, kc) if kc > 0.28 else 0.0
	var medic := 0.06 if mode.allow_medics and game.lives < mode.lives else 0.0
	var r := rng.randf()
	if r < golden:
		return BotModel.Kind.GOLDEN
	r -= golden
	if r < bomb:
		return BotModel.Kind.BOMB
	r -= bomb
	if r < armored:
		return BotModel.Kind.ARMORED
	r -= armored
	if r < medic:
		return BotModel.Kind.MEDIC
	return BotModel.Kind.NORMAL


## Random free hatch; later on, hatches behind the player are favoured a bit.
func _pick_hatch(kc: float) -> Hatch:
	var candidates: Array[Hatch] = []
	var weights: Array[float] = []
	var total := 0.0
	var fwd := game.player.head_forward()
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	for h in game.dome.hatches:
		if not h.is_free():
			continue
		var dir := Dome.dir_from(0.0, h.azimuth)
		var away := acos(clampf(dir.dot(fwd), -1.0, 1.0)) / PI
		var w := 1.0 + (0.7 * away if kc > 0.35 else 0.0)
		# Neck saver: the top row is used less often.
		if h.row == Dome.ROW_COUNTS.size() - 1:
			w *= 0.55
		candidates.append(h)
		weights.append(w)
		total += w
	if candidates.is_empty():
		return null
	var r := rng.randf() * total
	for i in candidates.size():
		r -= weights[i]
		if r <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]


func _start_event() -> void:
	var roll := rng.randi_range(0, 2)
	var dome := game.dome
	if roll == 0:
		# Ring rush: a wave of bots racing around a row.
		var row := rng.randi_range(0, 1)
		var start := rng.randi_range(0, Dome.ROW_COUNTS[row] - 1)
		var step := 1 if rng.randf() < 0.5 else -1
		var count := mini(7, Dome.ROW_COUNTS[row])
		for i in count:
			_queue_spawn(dome.hatch_at(row, start + step * i), BotModel.Kind.NORMAL, 0.14 * float(i), 1.7)
		game.announce_event("RING RUSH!", Palette.CYAN)
	elif roll == 1:
		# Surround: four at once, one in each direction.
		var base := rng.randf() * TAU
		for i in 4:
			var h := dome.nearest_hatch(1, base + TAU * 0.25 * float(i))
			_queue_spawn(h, BotModel.Kind.NORMAL, 0.0, 2.0)
		game.announce_event("SURROUNDED!", Palette.MAGENTA)
	else:
		for i in 3:
			var h := _pick_hatch(1.0)
			if h:
				_queue_spawn(h, BotModel.Kind.GOLDEN, 0.3 * float(i), 1.3)
		game.announce_event("GOLD RUSH!", Palette.GOLD)


func _queue_spawn(h: Hatch, kind: BotModel.Kind, delay: float, up: float) -> void:
	if h == null or not h.powered:
		return
	_queue.append({"t": delay, "hatch": h, "kind": kind, "up": up})
