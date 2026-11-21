extends RefCounted
## Petits utilitaires de construction partagés par les composants.
const Tokens := preload("res://kit/tokens.gd")
const Fonts := preload("res://kit/fonts.gd")

static func box(bg: Color, r := Tokens.R_MD, ph := 0, pv := -1, bc := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if Tokens.pixel:
		# coins carrés ; bordure 2 px (assombrie par défaut) sur tout ce qui a un fond
		r = 4 if (r >= 8 and r < Tokens.R_FULL) else 0  # chanfrein = coin pixel
		if bw == 0 and bg.a > 0.2:
			bc = bg.darkened(0.55)
			bw = Tokens.PX
		elif bw > 0:
			bw = maxi(bw, Tokens.PX)
		sb.anti_aliasing = false
	sb.set_corner_radius_all(r)
	if Tokens.pixel:
		sb.corner_detail = 1
	sb.content_margin_left = ph
	sb.content_margin_right = ph
	sb.content_margin_top = ph if pv < 0 else pv
	sb.content_margin_bottom = ph if pv < 0 else pv
	if bw > 0:
		sb.border_color = bc
		sb.set_border_width_all(bw)
	if not Tokens.pixel:
		sb.anti_aliasing_size = 1.0
	return sb

## Label stylé : size = taille Tokens.FS_*, color null = texte, weight 400..700, wrap = retour à la ligne.
static func label(parent: Node, text: String, size := Tokens.FS_BASE, color: Variant = null, weight := 400, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, size, color, weight, wrap)
	if parent != null:
		parent.add_child(l)
	return l

static func style_label(l: Label, size: int, color: Variant, weight: int, wrap: bool) -> void:
	l.add_theme_font_override("font", Fonts.weight(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("line_spacing", Tokens.line_extra(size))
	l.add_theme_color_override("font_color", color if color != null else Tokens.text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if wrap:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 1  # peut rétrécir (évite le min-size = texte entier)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func spacer(parent: Node, expand := true) -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else 0
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)
	return s

static func vbox(parent: Node, gap := Tokens.S2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	if parent != null:
		parent.add_child(v)
	return v

static func hbox(parent: Node, gap := Tokens.S2) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	if parent != null:
		parent.add_child(h)
	return h

static func margin(parent: Node, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	if parent != null:
		parent.add_child(m)
	return m

static func text_w(text: String, size: int, weight := 400) -> float:
	return Fonts.weight(weight).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Dessine un texte centré verticalement dans une bande [y0,y1].
static func draw_text(ci: CanvasItem, text: String, x: float, cy: float, size: int, color: Color, weight := 400, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := Fonts.weight(weight)
	var y := cy + (f.get_ascent(size) - f.get_descent(size)) * 0.5
	f.draw_string(ci.get_canvas_item(), Vector2(x, y), text, align, width, size, color)
