class_name GameMode
extends RefCounted
## Rules for one way to play.

var id := ""
var title := ""
var subtitle := ""
var color := Palette.CYAN
var duration := 0.0 ## Seconds; 0 = no time limit.
var lives := 0 ## 0 = no lives (escapes only break your combo).
var ramp_time := 60.0 ## Seconds to reach full difficulty.
var fixed_intensity := -1.0 ## >= 0 locks the difficulty (Zen).
var bomb_penalty := 300 ## Points lost for shooting a bomb (when there are no lives).
var allow_medics := false
var allow_bombs := true
var allow_events := true


static func all() -> Array[GameMode]:
	var blitz := GameMode.new()
	blitz.id = "blitz"
	blitz.title = "BLITZ"
	blitz.subtitle = "60 seconds. Max score."
	blitz.color = Palette.CYAN
	blitz.duration = 60.0
	blitz.ramp_time = 60.0

	var survival := GameMode.new()
	survival.id = "survival"
	survival.title = "SURVIVAL"
	survival.subtitle = "5 lives. Don't let them escape."
	survival.color = Palette.MAGENTA
	survival.lives = 5
	survival.ramp_time = 150.0
	survival.allow_medics = true

	var zen := GameMode.new()
	zen.id = "zen"
	zen.title = "ZEN"
	zen.subtitle = "No timer. No pressure."
	zen.color = Palette.GREEN
	zen.fixed_intensity = 0.32
	zen.bomb_penalty = 0
	zen.allow_events = false

	var modes: Array[GameMode] = [blitz, survival, zen]
	return modes


## Difficulty from 0 (gentle) to 1 (frantic); survival keeps creeping past 1.
func intensity_at(elapsed: float) -> float:
	if fixed_intensity >= 0.0:
		return fixed_intensity
	var k := elapsed / maxf(ramp_time, 1.0)
	if k > 1.0:
		k = 1.0 + minf((k - 1.0) * 0.4, 0.4)
	return k


## Rank letter for a finished run.
func rank_for(score: int) -> String:
	var thresholds: Array[int] = [55000, 35000, 20000, 10000, 4000]
	if id == "survival":
		thresholds = [80000, 45000, 22000, 10000, 4000]
	var letters: Array[String] = ["S", "A", "B", "C", "D"]
	for i in thresholds.size():
		if score >= thresholds[i]:
			return letters[i]
	return "E"
