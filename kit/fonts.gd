extends RefCounted
## Inter (400/500/600/700) en woff2 avec repli latin-ext puis police système pour les glyphes manquants.

const Tokens := preload("res://kit/tokens.gd")
const BASE := "res://kit/fonts/"
static var _cache := {}
static var _sys: SystemFont

static func _load(file: String) -> Font:
	var p := BASE + file
	if ResourceLoader.exists(p):
		var r: Variant = load(p)
		if r is Font:
			return r
	if FileAccess.file_exists(p):
		var f := FontFile.new()
		f.data = FileAccess.get_file_as_bytes(p)
		return f
	return null

static var _pcache := {}

## Police pixel art (Pixelify Sans, variable) : mêmes repli que Inter pour les glyphes manquants.
static func _pixel(w: int) -> Font:
	var wk := 700 if w >= 600 else 400
	if _pcache.has(wk):
		return _pcache[wk]
	var base: Font = _load("PixelifySans.ttf")
	if base == null:
		return ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": wk}
	var fb: Array[Font] = []
	var ext := _load("Inter-ext-400.woff2")
	if ext != null:
		fb.append(ext)
	if _sys == null:
		_sys = SystemFont.new()
		_sys.font_names = PackedStringArray(["sans-serif", "Noto Color Emoji"])
	fb.append(_sys)
	fv.fallbacks = fb
	if base is FontFile:
		(base as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_NONE
		(base as FontFile).hinting = TextServer.HINTING_NONE
		(base as FontFile).subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_pcache[wk] = fv
	return fv

static func weight(w: int) -> Font:
	if Tokens.pixel:
		return _pixel(w)
	w = clampi(int(round(w / 100.0)) * 100, 400, 700)
	if w == 500 or w == 600 or w == 400 or w == 700:
		pass
	else:
		w = 400
	if _cache.has(w):
		return _cache[w]
	var f := _load("Inter-%d.woff2" % w)
	if f == null:
		return ThemeDB.fallback_font
	var fb: Array[Font] = []
	var ext := _load("Inter-ext-%d.woff2" % w)
	if ext != null:
		fb.append(ext)
	if _sys == null:
		_sys = SystemFont.new()
		_sys.font_names = PackedStringArray(["sans-serif", "Noto Color Emoji"])
	fb.append(_sys)
	f.fallbacks = fb
	if f is FontFile:
		(f as FontFile).subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		(f as FontFile).hinting = TextServer.HINTING_NONE
	_cache[w] = f
	return f

static func is_inter(f: Font) -> bool:
	return f != null and f != ThemeDB.fallback_font and (_cache.values().has(f) or _pcache.values().has(f))

static func all() -> Array:
	for w in [400, 500, 600, 700]:
		weight(w)
	return _cache.values()
