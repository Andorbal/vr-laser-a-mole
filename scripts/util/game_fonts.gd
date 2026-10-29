class_name GameFonts
## Loads the game's fonts once and switches them to MSDF rendering so Label3D
## text stays razor sharp at any distance in VR.

const TITLE_PATH := "res://assets/fonts/Orbitron-Black.woff2"
const DISPLAY_PATH := "res://assets/fonts/Orbitron-Bold.woff2"
const BODY_PATH := "res://assets/fonts/Exo2-SemiBold.woff2"

static var _cache: Dictionary = {}


static func title() -> Font:
	return _font_at(TITLE_PATH)


static func display() -> Font:
	return _font_at(DISPLAY_PATH)


static func body() -> Font:
	return _font_at(BODY_PATH)


static func _font_at(path: String) -> Font:
	if _cache.has(path):
		return _cache[path]
	var font: Font = null
	var res: Resource = load(path)
	if res is FontFile:
		var ff: FontFile = res
		ff.multichannel_signed_distance_field = true
		ff.msdf_pixel_range = 12
		ff.msdf_size = 64
		ff.generate_mipmaps = true
		font = ff
	elif res is Font:
		font = res
	else:
		font = ThemeDB.fallback_font
	_cache[path] = font
	return font


## Creates a Label3D configured with the game's look.
static func make_label(text: String, size: int, font: Font, color: Color = Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = 0.001
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
