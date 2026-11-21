extends "res://kit/ui/k_press.gd"
## Bouton : kind primary/secondary/ghost/danger/icon ; size sm/md/lg ; icône gauche/droite ; chargement.
const Icon := preload("res://kit/icon.gd")
var text := "": set = _set_text
var kind := "secondary": set = _set_kind
var size_name := "md": set = _set_sz
var icon := "": set = _set_icon
var icon_right := "": set = _set_icon_r
var loading := false: set = _set_loading
var _spin := 0.0

static func make(txt: String, knd := "secondary", sz := "md", ico := "") -> Control:
	var b: Control = load("res://kit/ui/k_button.gd").new()
	b.text = txt
	b.kind = knd
	b.size_name = sz
	b.icon = ico
	return b

func _ready() -> void:
	super()
	_fit()

func _set_text(v: String) -> void:
	text = v
	_fit()
func _set_kind(v: String) -> void:
	kind = v
	_fit()
func _set_sz(v: String) -> void:
	size_name = v
	_fit()
func _set_icon(v: String) -> void:
	icon = v
	_fit()
func _set_icon_r(v: String) -> void:
	icon_right = v
	_fit()
func _set_loading(v: bool) -> void:
	loading = v
	set_process(v)
	queue_redraw()

func _dims() -> Dictionary:
	match size_name:
		"sm":
			return {"h": 32, "fs": Tokens.FS_SM, "px": Tokens.S3, "ic": 16}
		"lg":
			return {"h": 48, "fs": Tokens.FS_BASE, "px": Tokens.S6, "ic": 20}
	return {"h": 40, "fs": Tokens.FS_SM, "px": Tokens.S4, "ic": 20}

func _content_w() -> float:
	var d := _dims()
	var w := 0.0
	var ic: int = d.ic
	if text != "":
		w += KS.text_w(text, d.fs, 600)
	if icon != "":
		w += ic + (Tokens.S2 if text != "" else 0)
	if icon_right != "":
		w += ic + Tokens.S2
	if loading and icon == "":
		w += ic + (Tokens.S2 if text != "" else 0)
	return w

func _fit() -> void:
	var d := _dims()
	var px: int = d.px
	var hh: int = d.h
	var w: float = _content_w() + (0 if kind == "icon" and text == "" else px * 2)
	if kind == "icon" or text == "":
		w = maxf(w, hh)
	if text == "":
		w = maxf(w, Tokens.TOUCH)
	custom_minimum_size = Vector2(w, maxf(hh, Tokens.TOUCH))
	queue_redraw()
	update_minimum_size()

func k_overflow() -> bool:
	return size.x + 1.0 < _content_w()

func _process(dt: float) -> void:
	_spin += dt * 6.0
	queue_redraw()

func _colors() -> Array:  # [fond, texte, bordure]
	var bg := Color(0, 0, 0, 0)
	var fg := Tokens.text
	var bd := Color(0, 0, 0, 0)
	match kind:
		"primary":
			bg = Tokens.accent.lerp(Tokens.pal_at(400), hover).lerp(Tokens.pal_at(600), down)
			fg = Tokens.on_accent
		"danger":
			bg = Tokens.danger_solid.lerp(Tokens.danger_solid.lightened(0.12), hover).lerp(Tokens.danger_solid.darkened(0.15), down)
			fg = Color.WHITE
		"ghost", "icon":
			bg = Color(1, 1, 1, 0.07 * hover + 0.05 * down)
		_:
			bg = Tokens.surface3.lerp(Tokens.surface3.lightened(0.1), hover).lerp(Tokens.surface3.darkened(0.12), down)
			bd = Tokens.border
	return [bg, fg, bd]

func k_colors() -> Array:
	var c := _colors()
	return [[c[1], Tokens.over(c[0], Tokens.surface1) if c[0].a < 1.0 else c[0]]]

func _draw() -> void:
	var d := _dims()
	var c := _colors()
	var a := 0.42 if disabled else 1.0
	var h: float = d.h
	var r := Rect2(0, (size.y - h) * 0.5, size.x, h)
	var sb := KS.box(Color(c[0], c[0].a * a), int(h * 0.5) if (kind == "icon") else Tokens.R_MD, 0, 0, c[2], 1 if c[2].a > 0 else 0)
	draw_style_box(sb, r)
	draw_ring(r, Tokens.R_MD)
	var fg: Color = Color(c[1], a)
	var cw := _content_w()
	var x := (size.x - cw) * 0.5
	var cy := size.y * 0.5
	var ic: int = d.ic
	if icon != "" or (loading):
		if loading:
			draw_arc(Vector2(x + ic * 0.5, cy), ic * 0.35, _spin, _spin + 4.2, 20, fg, 2.0, true)
		else:
			var t := Icon.texture(icon, ic)
			if t != null:
				draw_texture_rect(t, Rect2(x, cy - ic * 0.5, ic, ic), false, fg)
		x += ic + (Tokens.S2 if text != "" else 0)
	if text != "":
		KS.draw_text(self, text, x, cy, d.fs, fg, 600)
		x += KS.text_w(text, d.fs, 600) + Tokens.S2
	if icon_right != "":
		var t2 := Icon.texture(icon_right, ic)
		if t2 != null:
			draw_texture_rect(t2, Rect2(x, cy - ic * 0.5, ic, ic), false, fg)

func _activate() -> void:
	if not loading:
		pressed.emit()
