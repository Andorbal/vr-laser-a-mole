class_name PlayerRig
extends Node3D
## The player: an OpenXR origin with a blaster in each hand, or a mouse-look
## camera with one blaster when no headset is available (handy for testing).

signal menu_pressed
signal focus_lost
signal focus_gained

const DESKTOP_EYE_HEIGHT := 1.6
const MOUSE_SENSITIVITY := 0.0025
const PREFERRED_REFRESH_RATE := 90.0

var xr_active := false
var xr_interface: OpenXRInterface
var camera: Camera3D
var origin: XROrigin3D
var blasters: Array[Blaster] = []

var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	var iface := XRServer.find_interface("OpenXR")
	if iface and iface.is_initialized() and iface is OpenXRInterface:
		xr_interface = iface as OpenXRInterface
		_setup_xr()
	else:
		_setup_desktop()


func _setup_xr() -> void:
	xr_active = true
	var vp := get_viewport()
	vp.use_xr = true
	vp.vrs_mode = Viewport.VRS_XR
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	xr_interface.session_begun.connect(_on_session_begun)
	xr_interface.session_visible.connect(func() -> void: focus_lost.emit())
	xr_interface.session_focussed.connect(func() -> void: focus_gained.emit())
	xr_interface.session_stopping.connect(func() -> void: focus_lost.emit())
	xr_interface.pose_recentered.connect(recenter)

	origin = XROrigin3D.new()
	origin.name = "XROrigin"
	add_child(origin)
	origin.current = true
	var cam := XRCamera3D.new()
	cam.name = "XRCamera"
	cam.near = 0.03
	cam.far = 600.0
	origin.add_child(cam)
	camera = cam

	var hands: Array[StringName] = [&"left_hand", &"right_hand"]
	var colors: Array[Color] = [Palette.LEFT_HAND, Palette.RIGHT_HAND]
	for i in 2:
		var c := XRController3D.new()
		c.name = "LeftHand" if i == 0 else "RightHand"
		c.tracker = hands[i]
		c.pose = &"aim"
		origin.add_child(c)
		var b := Blaster.new()
		b.setup(colors[i], c, null)
		c.add_child(b)
		blasters.append(b)
		c.button_pressed.connect(_on_controller_button)


func _setup_desktop() -> void:
	xr_active = false
	var cam := Camera3D.new()
	cam.name = "DesktopCamera"
	cam.position = Vector3(0.0, DESKTOP_EYE_HEIGHT, 0.0)
	cam.fov = 78.0
	cam.near = 0.03
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	camera = cam
	var b := Blaster.new()
	b.setup(Palette.RIGHT_HAND, null, cam)
	b.position = Vector3(0.2, -0.2, -0.38)
	cam.add_child(b)
	blasters.append(b)


func _on_session_begun() -> void:
	var rates: Array = xr_interface.get_available_display_refresh_rates()
	var best := 0.0
	for r in rates:
		var rate := float(r)
		if rate <= PREFERRED_REFRESH_RATE + 0.5 and rate > best:
			best = rate
	if best > 0.0:
		xr_interface.display_refresh_rate = best
		Engine.physics_ticks_per_second = int(roundf(best))
	# The "Local Floor" reference space already starts centered on the player.


func _on_controller_button(button_name: String) -> void:
	if button_name == "menu_button" or button_name == "by_button":
		menu_pressed.emit()


## Puts the player back in the middle of the dome, facing forward.
func recenter() -> void:
	if xr_active:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
	else:
		_yaw = 0.0
		_pitch = 0.0
		camera.rotation = Vector3.ZERO


func head_position() -> Vector3:
	return camera.global_position


func head_forward() -> Vector3:
	return -camera.global_transform.basis.z


## Vibrates every hand.
func pulse_all(amplitude: float, duration: float) -> void:
	for b in blasters:
		b.pulse(amplitude, duration)


func set_display(main_text: String, sub_text: String) -> void:
	for b in blasters:
		b.set_display(main_text, sub_text)


## The aiming point closest to [param p] (bots use this to eye your laser dot).
func nearest_aim_point(p: Vector3) -> Vector3:
	var best := head_position()
	var best_d := INF
	for b in blasters:
		if not b.is_tracking():
			continue
		var ap := b.aim_point()
		var d := ap.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = ap
	if best_d > 2.5:
		return head_position()
	return best


func _unhandled_input(event: InputEvent) -> void:
	if xr_active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
		camera.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				blasters[0].fire()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ESCAPE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				menu_pressed.emit()
			elif key.keycode == KEY_SPACE:
				blasters[0].fire()
