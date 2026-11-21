extends RefCounted
## Jetons de design (inspirés de Tailwind) : espacements, rayons, textes, couleurs dynamiques, ombres, points de rupture.
## Les couleurs sont des variables statiques recalculées par apply(accent, overrides) ; Tokens.bus.changed est émis.

class Bus extends RefCounted:
	signal changed
static var bus := Bus.new()

# --- Espacements (échelle ×4 px) : 0/1/2/3/4/6/8/12/16
const SCALE := [0, 1, 2, 3, 4, 6, 8, 12, 16]
const S0 := 0
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S6 := 24
const S8 := 32
const S12 := 48
const S16 := 64
const TOUCH := 44  # taille tactile minimale

static func sp(n: int) -> int:
	assert(n in SCALE, "espacement hors échelle : %d" % n)
	return n * 4

## Valeurs de pixels autorisées pour marges et gouttières (échelle + demi-pas 2 px pour les filets).
static func allowed_px() -> Array:
	var l: Array = [2]
	for n in SCALE:
		l.append(n * 4)
	return l

# --- Rayons
const R_SM := 6
const R_MD := 10
const R_LG := 14
const R_XL := 20
const R_FULL := 999

# --- Tailles de texte : [taille, interligne]
const FS_XS := 12
const FS_SM := 14
const FS_BASE := 16
const FS_LG := 18
const FS_XL := 20
const FS_2XL := 24
const FS_3XL := 30
const TEXT_SIZES := {"xs": [12, 16], "sm": [14, 20], "base": [16, 24], "lg": [18, 28], "xl": [20, 28], "2xl": [24, 32], "3xl": [30, 36]}

static func line_height(size: int) -> int:
	for k in TEXT_SIZES:
		if TEXT_SIZES[k][0] == size:
			return TEXT_SIZES[k][1]
	return int(size * 1.5)

## Espace supplémentaire (line_spacing Godot) pour obtenir l'interligne Tailwind.
static func line_extra(size: int) -> int:
	return maxi(0, line_height(size) - int(round(size * 1.21)))

# --- Graisses
const W_NORMAL := 400
const W_MEDIUM := 500
const W_SEMI := 600
const W_BOLD := 700

# --- Points de rupture
const BP_SM := 480
const BP_MD := 768
const BP_LG := 1024
const BP_XL := 1280
const WIDTHS_TEST := [320, 360, 480, 768, 1100, 1600]

## Nom du point de rupture pour une largeur : xs (<480), sm, md, lg, xl.
static func bp(w: float) -> String:
	if w < BP_SM:
		return "xs"
	if w < BP_MD:
		return "sm"
	if w < BP_LG:
		return "md"
	if w < BP_XL:
		return "lg"
	return "xl"

static func bp_at_least(w: float, name: String) -> bool:
	return w >= {"sm": BP_SM, "md": BP_MD, "lg": BP_LG, "xl": BP_XL}.get(name, 0)

# --- Mouvement
const DUR := 0.15  # 120-180 ms
const RING_W := 2.0

# --- Skin pixel art : coins carrés, bordure 2 px, ombre dure, police pixel, icônes sur grille
static var pixel := false
const PX := 2  # taille d'un « pixel » de bordure/ombre

static func set_pixel(on: bool) -> void:
	pixel = on
	bus.changed.emit()

# --- Couleurs (dynamiques)
static var accent := Color("4de1b4")
static var pal: Array = []  # 11 teintes : 50,100,200,...,900,950
const PAL_KEYS := [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]
static var surface0 := Color("0e1116")  # fond de page
static var surface1 := Color("171b22")  # cartes
static var surface2 := Color("1e242d")  # survol / éléments relevés
static var surface3 := Color("232a34")  # champs, contrôles
static var text := Color("e8ecf1")
static var text_muted := Color("98a2b0")
static var border := Color(1, 1, 1, 0.07)
static var border_strong := Color(1, 1, 1, 0.14)
static var on_accent := Color("0e1116")
static var accent_fg := Color("4de1b4")  # accent lisible comme texte sur surface1
static var success := Color("4ade80")
static var warn := Color("fbbf24")
static var danger := Color("f87171")
static var danger_solid := Color("b91c1c")
static var info := Color("60a5fa")
static var scrim := Color(0, 0, 0, 0.6)

static func pal_at(key: int) -> Color:
	return pal[PAL_KEYS.find(key)]

static func ramp(c: Color) -> Array:
	var ks := [0.92, 0.82, 0.66, 0.46, 0.22, 0.0, -0.15, -0.30, -0.46, -0.62, -0.80]
	var out: Array = []
	for k in ks:
		out.append(c.lerp(Color.WHITE, k) if k > 0.0 else c.lerp(Color.BLACK, -k))
	return out

static func lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)

static func contrast(a: Color, b: Color) -> float:
	var la := lum(a)
	var lb := lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

static func over(fg: Color, bg: Color) -> Color:
	return bg.lerp(Color(fg.r, fg.g, fg.b), fg.a)

## Éclaircit c jusqu'à atteindre le contraste voulu sur bg.
static func ensure_contrast(c: Color, bg: Color, ratio := 4.5) -> Color:
	var r := c
	var i := 0
	while contrast(r, bg) < ratio and i < 20:
		r = r.lerp(Color.WHITE, 0.1)
		i += 1
	return r

## Applique l'accent (et éventuellement des surfaces imposées : bg, card, card_hi, field). Émet bus.changed.
static func apply(acc: Color, overrides := {}) -> void:
	accent = acc
	pal = ramp(acc)
	var h := acc.h
	var s := clampf(acc.s, 0.0, 1.0)
	surface0 = overrides.get("bg", Color.from_hsv(h, s * 0.30, 0.065))
	surface1 = overrides.get("card", Color.from_hsv(h, s * 0.26, 0.105))
	surface2 = overrides.get("card_hi", Color.from_hsv(h, s * 0.22, 0.14))
	surface3 = overrides.get("field", Color.from_hsv(h, s * 0.20, 0.175))
	text = Color.from_hsv(h, s * 0.05, 0.96)
	text_muted = ensure_contrast(Color.from_hsv(h, s * 0.12, 0.62), surface3)
	on_accent = Color("0b0e12") if contrast(Color("0b0e12"), acc) >= contrast(Color.WHITE, acc) else Color.WHITE
	accent_fg = ensure_contrast(acc, surface1)
	bus.changed.emit()

## Fondu doux entre deux jeux de couleurs (nécessite un nœud pour porter le Tween).
static func fade_to(node: Node, acc: Color, overrides := {}, dur := 0.35) -> void:
	var from_acc := accent
	var from := [surface0, surface1, surface2, surface3]
	var to := [overrides.get("bg", null), overrides.get("card", null), overrides.get("card_hi", null), overrides.get("field", null)]
	var tw := node.create_tween()
	tw.tween_method(func(t: float):
		var ov := {}
		var keys := ["bg", "card", "card_hi", "field"]
		for i in 4:
			if to[i] != null:
				ov[keys[i]] = (from[i] as Color).lerp(to[i], t)
		apply(from_acc.lerp(acc, t), ov), 0.0, 1.0, dur)

# --- Ombres douces
static func shadow(sb: StyleBoxFlat, level := 1) -> StyleBoxFlat:
	if pixel:  # ombre dure décalée, sans flou
		sb.shadow_size = 1 if level > 0 else 0
		sb.shadow_offset = Vector2(PX * (1 + mini(level, 2)), PX * (1 + mini(level, 2)))
		sb.shadow_color = Color(0, 0, 0, 0.55)
		return sb
	match level:
		0:
			sb.shadow_size = 0
		1:
			sb.shadow_size = 6
			sb.shadow_offset = Vector2(0, 2)
			sb.shadow_color = Color(0, 0, 0, 0.28)
		2:
			sb.shadow_size = 14
			sb.shadow_offset = Vector2(0, 6)
			sb.shadow_color = Color(0, 0, 0, 0.36)
		_:
			sb.shadow_size = 32
			sb.shadow_offset = Vector2(0, 14)
			sb.shadow_color = Color(0, 0, 0, 0.5)
	return sb

static func ring_color() -> Color:
	return Color(accent, 0.75)

static func soft(c: Color, a := 0.14) -> Color:
	return Color(c, a)

static func _static_init() -> void:
	apply(accent)
