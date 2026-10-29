class_name Hatch
extends RefCounted
## One opening in the dome. Pure data + animation state; the Dome renders all
## hatches at once with MultiMeshes.
##
## Local frame ([member xform], relative to the Dome node): origin at the
## mouth, -Z points at the player's head, +Y is roughly world up.

var index := 0
var row := 0
var azimuth := 0.0 ## Radians, 0 = straight ahead (-Z), positive = to the right.
var elevation := 0.0
var xform := Transform3D.IDENTITY

var powered := false ## Inside the currently active part of the dome.
var power_delay := -1.0 ## Seconds until this hatch powers on (sweep effect).
var bot: Bot = null
var cooldown := 0.0

# Animation state written to the MultiMeshes every frame.
var color := Palette.CYAN
var power_level := 0.0
var open := 0.0
var open_target := 0.0
var telegraph := 0.0
var flash := 0.0
var glow := 0.0
var taunt := 0.0


func is_free() -> bool:
	return powered and bot == null and cooldown <= 0.0


## World-space point at the hatch mouth.
func mouth_global(dome: Node3D) -> Vector3:
	return dome.global_transform * xform.origin
