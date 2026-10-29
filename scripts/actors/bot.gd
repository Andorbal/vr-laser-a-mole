class_name Bot
extends Shootable
## A "mole": pops out of a hatch, taunts the player and ducks back in.
## Lives as a child of the Dome, positioned on its hatch's frame.

signal destroyed(bot: Bot, blaster: Blaster) ## Final hit landed.
signal armor_cracked(bot: Bot, blaster: Blaster)
signal escaped(bot: Bot) ## Started hiding without being hit.
signal released(bot: Bot) ## Back in the hatch; free for reuse.

enum State { IDLE, PRE, RISING, UP, RETREAT, DYING }

const HIDE_Z := 0.5
const UP_Z := -0.52
const HIT_RADIUS := 0.45
const BOT_SCALE := 1.15 ## Visual size multiplier for the model.
const RISE_TIME := 0.2
const RETREAT_TIME := 0.2
const DIE_TIME := 0.55
const TAUNT_TIME := 0.45

var kind := BotModel.Kind.NORMAL
var state := State.IDLE
var hatch: Hatch
var model: BotModel
var up_time := 2.0
var pre_time := 0.4
var time_left := 0.0
var time_fully_up := 0.0 ## Seconds spent fully up (for the reaction bonus).
var hp := 1
var points_scale := 1.0
var look_provider: Callable ## Returns a world point the eyes should follow.

var _t := 0.0
var _extend := 0.0
var _phase := 0.0
var _blink_timer := 2.0
var _blink := 0.0
var _surprise := 0.0
var _flash := 0.0
var _spin := 0.0
var _retreat_from := 1.0
var _last_face := -1
var _tick_timer := 0.0


func _init() -> void:
	model = BotModel.new()
	add_child(model)
	visible = false


## Starts popping out of [param h].
func spawn(h: Hatch, p_kind: BotModel.Kind, p_up_time: float, p_pre_time: float) -> void:
	hatch = h
	h.bot = self
	kind = p_kind
	transform = h.xform
	model.set_kind(p_kind)
	hp = 2 if p_kind == BotModel.Kind.ARMORED else 1
	up_time = p_up_time * (1.25 if p_kind == BotModel.Kind.ARMORED else 1.0)
	pre_time = p_pre_time
	time_left = up_time
	time_fully_up = 0.0
	_extend = 0.0
	_t = 0.0
	_phase = randf() * TAU
	_blink_timer = randf_range(0.6, 2.5)
	_surprise = 0.0
	_flash = 0.0
	_spin = 0.0
	_last_face = -1
	h.color = BotModel.eye_color_for(p_kind)
	h.glow = 0.0
	state = State.PRE
	visible = true
	_apply_pose()


func is_active() -> bool:
	return state != State.IDLE


## True while the bot is out and worth shooting (not dying or hidden).
func is_out() -> bool:
	return state == State.RISING or state == State.UP or state == State.RETREAT


func head_global() -> Vector3:
	return model.head.global_position


## 0..1, how close the bot is to hiding again.
func urgency() -> float:
	if state != State.UP:
		return 0.0
	return clampf(1.0 - time_left / maxf(up_time, 0.01), 0.0, 1.0)


func is_target_active() -> bool:
	return is_out() and _extend > 0.3 and can_process()


func ray_test(origin: Vector3, dir: Vector3) -> float:
	return Shootable.ray_sphere(origin, dir, head_global(), HIT_RADIUS)


func hover_changed(_hovered: bool) -> void:
	_last_face = -1


func on_shot(_point: Vector3, blaster: Blaster) -> void:
	if not is_out():
		return
	_flash = 1.0
	if hatch:
		hatch.flash = 1.0
	hp -= 1
	if hp > 0:
		model.pop_helmet()
		_surprise = 0.5
		time_left = maxf(time_left, 0.9)
		if state == State.RETREAT:
			state = State.UP
			_t = 0.0
		armor_cracked.emit(self, blaster)
		return
	state = State.DYING
	_t = 0.0
	_spin = (1.0 if randf() < 0.5 else -1.0) * randf_range(14.0, 20.0)
	destroyed.emit(self, blaster)


## Hides immediately (end of a round).
func force_hide() -> void:
	if state == State.IDLE or state == State.DYING:
		return
	_start_retreat()


func _start_retreat() -> void:
	state = State.RETREAT
	_t = 0.0
	_retreat_from = clampf(_extend, 0.0, 1.0)


func _process(delta: float) -> void:
	if state == State.IDLE:
		return
	_t += delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_surprise = maxf(_surprise - delta, 0.0)
	_update_blink(delta)
	match state:
		State.PRE:
			var k := clampf(_t / pre_time, 0.0, 1.0)
			hatch.telegraph = k
			hatch.glow = k * 0.6
			if k > 0.45:
				hatch.open_target = 1.0
			_extend = 0.0
			if _t >= pre_time:
				state = State.RISING
				_t = 0.0
				Sfx.play_at(&"pop", hatch.mouth_global(get_parent() as Node3D), -4.0, randf_range(0.92, 1.12))
		State.RISING:
			var k := clampf(_t / RISE_TIME, 0.0, 1.0)
			_extend = _ease_out_back(k)
			hatch.telegraph = 0.0
			hatch.glow = 1.0
			if _t >= RISE_TIME:
				state = State.UP
				_t = 0.0
		State.UP:
			time_left -= delta
			time_fully_up += delta
			_extend = 1.0 + sin(_t * 5.0 + _phase) * 0.025
			hatch.glow = 0.8 + 0.2 * sin(_t * 6.0)
			hatch.taunt = 1.0 if time_left < TAUNT_TIME else 0.0
			if kind == BotModel.Kind.BOMB:
				_tick_timer -= delta
				if _tick_timer <= 0.0:
					_tick_timer = 0.5
					Sfx.play_at(&"tick", head_global(), -14.0, 1.6)
			if time_left <= 0.0:
				_start_retreat()
				Sfx.play_at(&"escape", head_global(), -8.0, randf_range(0.95, 1.1))
				escaped.emit(self)
		State.RETREAT:
			var k := clampf(_t / RETREAT_TIME, 0.0, 1.0)
			_extend = _retreat_from * (1.0 - k * k)
			hatch.taunt = 0.0
			hatch.glow = 1.0 - k
			if _t >= RETREAT_TIME:
				_release()
				return
		State.DYING:
			var k := clampf(_t / DIE_TIME, 0.0, 1.0)
			# Knocked back, then sucked into the hatch.
			if k < 0.25:
				_extend = 1.0 + sin(k / 0.25 * PI) * 0.12
			else:
				var kk := (k - 0.25) / 0.75
				_extend = 1.0 - kk * kk
			hatch.glow = 1.0 - k
			if _t >= DIE_TIME:
				_release()
				return
	_apply_pose()


func _apply_pose() -> void:
	model.position = Vector3(0.0, 0.0, lerpf(HIDE_Z, UP_Z, _extend))
	var t := _t + _phase
	if state == State.DYING:
		model.head.rotation = Vector3(0.0, 0.0, _spin * _t)
		model.scale = Vector3.ONE * BOT_SCALE * (1.0 + _flash * 0.15)
	else:
		var wobble := 0.12
		if state == State.UP and time_left < TAUNT_TIME:
			wobble = 0.35
		model.head.rotation = Vector3(sin(t * 3.1) * 0.05, sin(t * 1.7) * 0.08, sin(t * 2.3) * wobble)
		var stretch := 0.0
		if state == State.RISING:
			stretch = (1.0 - clampf(_t / RISE_TIME, 0.0, 1.0)) * 0.18
		model.scale = Vector3(1.0 - stretch * 0.5, 1.0 - stretch * 0.5, 1.0 + stretch) * BOT_SCALE * (1.0 + _flash * 0.12)
	_update_face()


func _update_face() -> void:
	var f := BotModel.default_face_for(kind)
	if state == State.DYING:
		f = BotModel.FACE_DIZZY
	elif _surprise > 0.0:
		f = BotModel.FACE_SURPRISED
	elif hover_count > 0 and kind != BotModel.Kind.BOMB:
		f = BotModel.FACE_SCARED
	elif state == State.UP and time_left < TAUNT_TIME:
		f = BotModel.FACE_HAPPY
	elif state == State.RETREAT:
		f = BotModel.FACE_HAPPY
	if f != _last_face:
		model.set_face(f)
		_last_face = f
	model.set_blink(_blink if f == BotModel.FACE_IDLE or f == BotModel.FACE_ANGRY else 0.0)
	model.set_flash(_flash)
	if look_provider.is_valid():
		var target: Vector3 = look_provider.call(self)
		var local := model.head.global_transform.affine_inverse() * target
		var v := Vector2(local.x, local.y) / maxf(absf(local.z), 0.5)
		model.set_look(v.limit_length(1.0))


func _update_blink(delta: float) -> void:
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = randf_range(1.8, 4.0)
		_blink = 1.0
	_blink = maxf(_blink - delta * 7.0, 0.0)


func _release() -> void:
	state = State.IDLE
	visible = false
	hover_count = 0
	if hatch:
		hatch.open_target = 0.0
		hatch.telegraph = 0.0
		hatch.taunt = 0.0
		hatch.cooldown = 0.5
		hatch.bot = null
	hatch = null
	released.emit(self)


static func _ease_out_back(x: float) -> float:
	var c1 := 1.9
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
