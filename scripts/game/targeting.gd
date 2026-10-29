class_name Targeting
extends Node
## Resolves laser rays against every registered Shootable, then against the
## world (the dome's energy shield and the floor) so beams always end somewhere.

enum Surface { NONE, TARGET, SHIELD, FLOOR }

class Hit:
	var target: Shootable = null
	var point := Vector3.ZERO
	var normal := Vector3.UP
	var distance := 0.0
	var surface := 0 ## A Targeting.Surface value.

static var instance: Targeting

const MAX_DISTANCE := 60.0

var shootables: Array[Shootable] = []
var shield_center := Palette.HEAD_CENTER
var shield_radius := 6.7


func _init() -> void:
	instance = self


func register(s: Shootable) -> void:
	if not shootables.has(s):
		shootables.append(s)


func unregister(s: Shootable) -> void:
	shootables.erase(s)


func cast(origin: Vector3, dir: Vector3) -> Hit:
	var hit := Hit.new()
	var best_t := INF
	var best: Shootable = null
	for s in shootables:
		if not s.is_target_active() or not s.is_visible_in_tree():
			continue
		var t := s.ray_test(origin, dir)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = s
	if best:
		hit.target = best
		hit.surface = Surface.TARGET
		hit.distance = best_t
		hit.point = origin + dir * best_t
		hit.normal = -dir
		return hit

	var t_world := MAX_DISTANCE
	hit.surface = Surface.NONE
	if dir.y < -0.0001 and origin.y > 0.0:
		var t_floor := -origin.y / dir.y
		if t_floor < t_world:
			t_world = t_floor
			hit.surface = Surface.FLOOR
			hit.normal = Vector3.UP
	var t_shield := Shootable.ray_sphere(origin, dir, shield_center, shield_radius)
	if t_shield >= 0.0 and t_shield < t_world:
		t_world = t_shield
		hit.surface = Surface.SHIELD
		hit.normal = (shield_center - (origin + dir * t_shield)).normalized()
	hit.distance = t_world
	hit.point = origin + dir * t_world
	return hit
