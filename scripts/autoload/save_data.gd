extends Node
## Persistent settings and high scores (autoload "Save").

const PATH := "user://laser_a_mole.cfg"

var music_enabled := true
var sfx_volume := 1.0
var _best: Dictionary = {}
var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(PATH) == OK:
		music_enabled = bool(_cfg.get_value("settings", "music", true))
		sfx_volume = float(_cfg.get_value("settings", "sfx_volume", 1.0))
		if _cfg.has_section("best"):
			for key in _cfg.get_section_keys("best"):
				_best[key] = int(_cfg.get_value("best", key, 0))


func best_score(mode_id: String) -> int:
	return int(_best.get(mode_id, 0))


## Records a score; returns true if it is a new best.
func submit_score(mode_id: String, score: int) -> bool:
	if score <= best_score(mode_id):
		return false
	_best[mode_id] = score
	_cfg.set_value("best", mode_id, score)
	_write()
	return true


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	_cfg.set_value("settings", "music", on)
	_write()


func _write() -> void:
	_cfg.set_value("settings", "sfx_volume", sfx_volume)
	var err := _cfg.save(PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % error_string(err))
