class_name Shootable
extends Node3D
## Base class for anything a laser can hit (bots, menu buttons).
## Hit testing is analytic (ray vs. sphere / rectangle), so no physics bodies
## are needed and results are identical on every platform.

var hover_count := 0


func _enter_tree() -> void:
	if Targeting.instance:
		Targeting.instance.register(self)


func _exit_tree() -> void:
	if Targeting.instance:
		Targeting.instance.unregister(self)
	hover_count = 0


## Whether the target can currently be hit.
func is_target_active() -> bool:
	return false


## Returns the distance along the ray to the hit, or -1.0 for a miss.
## [param dir] is normalized.
func ray_test(_origin: Vector3, _dir: Vector3) -> float:
	return -1.0


func on_shot(_point: Vector3, _blaster: Blaster) -> void:
	pass


## Called when the first blaster starts / the last blaster stops aiming at us.
func hover_changed(_hovered: bool) -> void:
	pass


func add_hover(delta: int) -> void:
	var was := hover_count > 0
	hover_count = maxi(0, hover_count + delta)
	if was != (hover_count > 0):
		hover_changed(hover_count > 0)


static func ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.length_squared() - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	var s := sqrt(disc)
	var t := -b - s
	if t < 0.0:
		t = -b + s
	return t if t >= 0.0 else -1.0
