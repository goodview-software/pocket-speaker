extends Control
## Pastille / badge : kind neutral|accent|success|warn|danger|info.
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
const Icon := preload("res://kit/icon.gd")
var text := "": set = _s
var kind := "neutral": set = _s
var icon := "": set = _s

static func make(txt: String, knd := "neutral", ico := "") -> Control:
	var b: Control = load("res://kit/ui/k_badge.gd").new()
	b.text = txt
	b.kind = knd
	b.icon = ico
	return b

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _ready() -> void:
	Tokens.bus.changed.connect(queue_redraw)

func _s(_v: Variant = null) -> void:
	queue_redraw()
	update_minimum_size()

func _get_minimum_size() -> Vector2:
	var w := KS.text_w(text, Tokens.FS_XS, 600) + Tokens.S3 * 2
	if icon != "":
		w += 12 + Tokens.S1
	return Vector2(w, 24)

func k_overflow() -> bool:
	return size.x + 1.0 < _get_minimum_size().x

func fg() -> Color:
	match kind:
		"accent":
			return Tokens.accent_fg
		"success":
			return Tokens.success
		"warn":
			return Tokens.warn
		"danger":
			return Tokens.danger
		"info":
			return Tokens.info
	return Tokens.text_muted

func k_colors() -> Array:
	return [[fg(), Tokens.over(Color(fg(), 0.14 if kind != "neutral" else 0.0), Tokens.surface1) if kind != "neutral" else Tokens.surface3]]

func _draw() -> void:
	var c := fg()
	draw_style_box(KS.box(Color(c, 0.14) if kind != "neutral" else Tokens.surface3, Tokens.R_FULL), Rect2(Vector2.ZERO, size))
	var x := Tokens.S3
	if icon != "":
		var t := Icon.texture(icon, 16)
		if t != null:
			draw_texture_rect(t, Rect2(x, size.y * 0.5 - 6, 12, 12), false, c)
		x += 12 + Tokens.S1
	KS.draw_text(self, text, x, size.y * 0.5, Tokens.FS_XS, c, 600)
