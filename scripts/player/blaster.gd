class_name Blaster
extends Node3D
## A laser blaster held in one hand (or attached to the camera in desktop mode).
## Shows an aiming laser, fires hitscan beams, and has a little screen on top
## that displays the score and timer.

signal fired(blaster: Blaster, hit: Targeting.Hit)

const FIRE_INTERVAL := 0.1
const BEAM_TIME := 0.13
const BEAM_RADIUS := 0.02
const MUZZLE := Vector3(0.0, 0.0, -0.215)
const TRIGGER_ON := 0.55
const TRIGGER_OFF := 0.35

var color := Palette.CYAN
var controller: XRController3D ## Null in desktop mode.
var aim_camera: Camera3D ## Desktop mode aims from the camera center.
var hover_target: Shootable

var _model: Node3D
var _muzzle: Node3D
var _sight: MeshInstance3D
var _dot: MeshInstance3D
var _beam: MeshInstance3D
var _flash: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _display: Label3D
var _display_sub: Label3D
var _cooldown := 0.0
var _recoil := 0.0
var _beam_t := 10.0
var _beam_from := Vector3.ZERO
var _beam_to := Vector3.ZERO
var _trigger_down := false
var _charge := 1.0


func setup(p_color: Color, p_controller: XRController3D, p_camera: Camera3D) -> void:
	color = p_color
	controller = p_controller
	aim_camera = p_camera
	_build_model()
	_build_lasers()


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var shell := Mat.plastic(Color(0.9, 0.92, 0.98), 0.3)
	var dark := Mat.pbr(Color(0.06, 0.06, 0.09), 0.7, 0.35)
	var rubber := Mat.pbr(Color(0.03, 0.03, 0.04), 0.0, 0.8)
	_ring_mat = Mat.neon(color, 3.0)

	# Main body, a rounded capsule lying along the barrel.
	var body := CapsuleMesh.new()
	body.radius = 0.03
	body.height = 0.2
	var body_mi := Mat.add_mesh(_model, body, shell, Vector3(0.0, 0.0, -0.03))
	body_mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	# Dark spine on top.
	Mat.add_mesh(_model, Mat.box(Vector3(0.022, 0.012, 0.15)), dark, Vector3(0.0, 0.03, -0.03))
	# Barrel and emitter coils.
	var barrel := Mat.add_mesh(_model, Mat.cylinder(0.012, 0.016, 0.09, 12), dark, Vector3(0.0, 0.0, -0.165))
	barrel.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	for i in 3:
		var ring := Mat.add_mesh(_model, Mat.torus(0.016, 0.024, 20, 6), _ring_mat, Vector3(0.0, 0.0, -0.135 - 0.025 * float(i)))
		ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_muzzle = Node3D.new()
	_muzzle.position = MUZZLE
	_model.add_child(_muzzle)
	Mat.add_mesh(_model, Mat.sphere(0.011, -1.0, 10, 5), _ring_mat, MUZZLE + Vector3(0.0, 0.0, 0.01))
	# Glowing energy cells on both sides.
	for side in [-1.0, 1.0]:
		var cell := CapsuleMesh.new()
		cell.radius = 0.008
		cell.height = 0.08
		var cell_mi := Mat.add_mesh(_model, cell, _ring_mat, Vector3(float(side) * 0.028, 0.006, -0.02))
		cell_mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	# Grip, angled like a pistol so it sits over the controller handle.
	var grip := Mat.add_mesh(_model, Mat.box(Vector3(0.03, 0.095, 0.042)), rubber, Vector3(0.0, -0.055, 0.045))
	grip.rotation = Vector3(deg_to_rad(-20.0), 0.0, 0.0)
	var guard := Mat.add_mesh(_model, Mat.torus(0.018, 0.024, 16, 6), dark, Vector3(0.0, -0.035, 0.0))
	guard.rotation = Vector3(0.0, 0.0, PI * 0.5)
	guard.scale = Vector3(1.0, 1.0, 1.4)

	# Little screen on the back of the gun, tilted toward the player's eye.
	var screen := Node3D.new()
	screen.position = Vector3(0.0, 0.043, 0.055)
	screen.rotation = Vector3(deg_to_rad(-62.0), 0.0, 0.0)
	_model.add_child(screen)
	var panel_mat := Mat.shader_material("res://shaders/panel.gdshader", {"corner": 0.006, "border": 0.0015, "fill_alpha": 0.85})
	var panel := Mat.add_mesh(screen, Mat.quad(Vector2(0.088, 0.046)), panel_mat)
	panel.set_instance_shader_parameter("panel_color", color)
	panel.set_instance_shader_parameter("panel_size", Vector2(0.088, 0.046))
	_display = GameFonts.make_label("", 52, GameFonts.display(), Color(1.0, 1.0, 1.0))
	_display.pixel_size = 0.00028
	_display.position = Vector3(0.0, 0.007, 0.001)
	_display.render_priority = 2
	screen.add_child(_display)
	_display_sub = GameFonts.make_label("", 38, GameFonts.body(), color.lightened(0.3))
	_display_sub.pixel_size = 0.00028
	_display_sub.position = Vector3(0.0, -0.013, 0.001)
	_display_sub.render_priority = 2
	screen.add_child(_display_sub)


func _build_lasers() -> void:
	var beam_mesh := Mat.cylinder(1.0, 1.0, 1.0, 10, false)
	var beam_mat := Mat.shader_material("res://shaders/beam.gdshader", {"energy": 3.0})
	_beam = Mat.add_mesh(self, beam_mesh, beam_mat)
	_beam.top_level = true
	_beam.visible = false
	_beam.set_instance_shader_parameter("beam_color", color)

	var sight_mat := Mat.shader_material("res://shaders/beam.gdshader", {"energy": 1.0, "core_power": 3.0})
	_sight = Mat.add_mesh(self, beam_mesh, sight_mat)
	_sight.top_level = true
	_sight.set_instance_shader_parameter("beam_color", Color(color.r, color.g, color.b, 0.35))

	var glow_mat := Mat.shader_material("res://shaders/glow_sprite.gdshader", {"energy": 2.0, "sharpness": 5.0})
	_dot = Mat.add_mesh(self, Mat.quad(Vector2(1.0, 1.0)), glow_mat)
	_dot.top_level = true
	_dot.set_instance_shader_parameter("tint", color)

	_flash = Mat.add_mesh(_model, Mat.quad(Vector2(1.0, 1.0)), glow_mat, MUZZLE)
	_flash.visible = false
	_flash.set_instance_shader_parameter("tint", color)


func set_display(main_text: String, sub_text: String) -> void:
	if _display.text != main_text:
		_display.text = main_text
	if _display_sub.text != sub_text:
		_display_sub.text = sub_text


func is_tracking() -> bool:
	if controller == null:
		return true
	return controller.get_has_tracking_data()


func aim_origin() -> Vector3:
	if aim_camera:
		return aim_camera.global_position
	return _muzzle.global_position


func aim_dir() -> Vector3:
	if aim_camera:
		return -aim_camera.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()


func muzzle_position() -> Vector3:
	return _muzzle.global_position


## Point the aiming laser currently rests on.
func aim_point() -> Vector3:
	return _dot.global_position


func _process(delta: float) -> void:
	_cooldown -= delta
	_recoil = move_toward(_recoil, 0.0, delta * 9.0)
	_charge = move_toward(_charge, 1.0, delta * 6.0)
	_model.position = Vector3(0.0, 0.0, _recoil * 0.025)
	_model.rotation = Vector3(_recoil * 0.2, 0.0, 0.0)
	var c := color * (1.5 + 2.5 * _charge)
	_ring_mat.albedo_color = Color(c.r, c.g, c.b)

	var tracking := is_tracking()
	_model.visible = tracking
	_sight.visible = tracking
	_dot.visible = tracking
	if not tracking:
		_set_hover(null)
		_beam.visible = false
		return

	if controller:
		var v := controller.get_float(&"trigger")
		if not _trigger_down and v > TRIGGER_ON:
			_trigger_down = true
			fire()
		elif _trigger_down and v < TRIGGER_OFF:
			_trigger_down = false

	var origin := aim_origin()
	var dir := aim_dir()
	var hit := Targeting.instance.cast(origin, dir)
	_set_hover(hit.target)
	var from := muzzle_position()
	var on_target := hit.target != null
	_orient_cylinder(_sight, from, hit.point, 0.0022 if on_target else 0.0015)
	_sight.set_instance_shader_parameter("beam_color", Color(color.r, color.g, color.b, 0.7 if on_target else 0.3))
	var dist := origin.distance_to(hit.point)
	var dot_size := (0.02 + dist * 0.012) * (1.6 if on_target else 1.0)
	_dot.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * dot_size), hit.point - dir * 0.02)
	_dot.set_instance_shader_parameter("tint", Color.WHITE.lerp(color, 0.4) if on_target else color)

	_beam_t += delta
	if _beam_t < BEAM_TIME:
		var k := 1.0 - _beam_t / BEAM_TIME
		_beam.visible = true
		_orient_cylinder(_beam, muzzle_position(), _beam_to, BEAM_RADIUS * (0.3 + 0.7 * k))
		_beam.set_instance_shader_parameter("beam_color", Color(color.r, color.g, color.b, k))
	else:
		_beam.visible = false
	_flash.visible = _beam_t < 0.05
	if _flash.visible:
		_flash.scale = Vector3.ONE * randf_range(0.07, 0.1)


## Fires a shot along the current aim. Returns the hit (or null on cooldown).
func fire() -> Targeting.Hit:
	if _cooldown > 0.0 or not is_tracking():
		return null
	_cooldown = FIRE_INTERVAL
	var dir := aim_dir()
	var hit := Targeting.instance.cast(aim_origin(), dir)
	_beam_from = muzzle_position()
	_beam_to = hit.point
	_beam_t = 0.0
	_recoil = 1.0
	_charge = 0.0
	Sfx.play_at(&"shot", _beam_from, -6.0, randf_range(0.94, 1.06))
	pulse(0.35, 0.05)
	if hit.target:
		hit.target.on_shot(hit.point, self)
	fired.emit(self, hit)
	return hit


## Rumbles the controller (no-op on desktop).
func pulse(amplitude: float, duration: float) -> void:
	if controller:
		controller.trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)


func _set_hover(target: Shootable) -> void:
	if hover_target != null and not is_instance_valid(hover_target):
		hover_target = null
	if target == hover_target:
		return
	if hover_target:
		hover_target.add_hover(-1)
	hover_target = target
	if hover_target:
		hover_target.add_hover(1)


## Stretches a unit cylinder (along +Y) between two world points.
static func _orient_cylinder(mi: MeshInstance3D, a: Vector3, b: Vector3, radius: float) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.001:
		mi.visible = false
		return
	var frame := Mat.basis_y_to(axis / length) * Basis.from_scale(Vector3(radius, length, radius))
	mi.global_transform = Transform3D(frame, (a + b) * 0.5)
