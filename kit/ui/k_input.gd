extends VBoxContainer
## Champ de saisie à libellé flottant, icône, erreur. multiline = true -> zone de texte (KTextarea).
signal text_changed(t: String)
signal text_submitted(t: String)
signal blurred
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
const Fonts := preload("res://kit/fonts.gd")
const Icon := preload("res://kit/icon.gd")
var label_text := "": set = _sl
var icon := ""
var multiline := false
var secret := false
var placeholder := ""
var error := "": set = _se
var field: Control
var edit: Control  # LineEdit ou TextEdit
var err_l: Label
var _t := 0.0: set = _st
var _foc := false

class Field extends Control:
	var owner_input
	func _draw() -> void:
		owner_input._draw_field(self)

func _init() -> void:
	add_theme_constant_override("separation", Tokens.S1)

func _ready() -> void:
	field = Field.new()
	field.owner_input = self
	field.custom_minimum_size.y = 96 if multiline else 56
	field.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(field)
	if multiline:
		var te := TextEdit.new()
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.text_changed.connect(func(): _changed(te.text))
		edit = te
	else:
		var le := LineEdit.new()
		le.secret = secret
		le.text_changed.connect(_changed)
		le.text_submitted.connect(func(t: String): text_submitted.emit(t))
		edit = le
	edit.set_meta("k_inner", true)
	edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	edit.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	edit.add_theme_font_size_override("font_size", Tokens.FS_BASE)
	edit.add_theme_font_override("font", Fonts.weight(400))
	edit.add_theme_color_override("font_color", Tokens.text)
	edit.add_theme_color_override("caret_color", Tokens.accent)
	edit.focus_entered.connect(func(): _foc = true; _anim())
	edit.focus_exited.connect(func(): _foc = false; _anim(); blurred.emit())
	field.add_child(edit)
	field.resized.connect(_layout)
	err_l = KS.label(self, error, Tokens.FS_SM, Tokens.danger, 400, true)
	err_l.visible = error != ""
	if _pending != "":
		edit.text = _pending
	_t = 1.0 if text != "" else 0.0
	_layout()
	Tokens.bus.changed.connect(field.queue_redraw)

var text: String = "":
	get:
		return edit.text if edit != null else _pending
	set(v):
		_pending = v
		if edit != null:
			edit.text = v
			_anim()
var _pending := ""

func set_text(t: String) -> void:
	text = t

func _changed(t: String) -> void:
	_anim()
	text_changed.emit(t)

func _sl(v: String) -> void:
	label_text = v
	if field != null:
		field.queue_redraw()

func _se(v: String) -> void:
	error = v
	if err_l != null:
		err_l.text = v
		err_l.visible = v != ""
	if field != null:
		field.queue_redraw()

func _st(v: float) -> void:
	_t = v
	if field != null:
		field.queue_redraw()
		_layout()

func _anim() -> void:
	var up := 1.0 if (_foc or text != "") else 0.0
	if is_inside_tree():
		create_tween().tween_property(self, "_t", up, Tokens.DUR)
	else:
		_t = up
	field.queue_redraw()

func _left() -> float:
	return Tokens.S4 + (28.0 if icon != "" else 0.0)

func _layout() -> void:
	if edit == null or field == null:
		return
	var top: float = 22.0 if label_text != "" else (Tokens.S3 if multiline else 14.0)
	if multiline:
		edit.position = Vector2(_left() - 4, top - 4)
		edit.size = Vector2(field.size.x - _left() - Tokens.S3, field.size.y - top)
	else:
		edit.position = Vector2(_left(), 24.0 if label_text != "" else 14.0)
		edit.size = Vector2(field.size.x - _left() - Tokens.S4, 28.0)
		if label_text == "":
			edit.position.y = (field.size.y - 28.0) * 0.5
	if placeholder != "" and edit is LineEdit:
		(edit as LineEdit).placeholder_text = placeholder if (_foc or label_text == "") else ""

func k_colors() -> Array:
	return [[Tokens.text, Tokens.surface3], [Tokens.text_muted, Tokens.surface3]]

func _draw_field(f: Control) -> void:
	var bc := Tokens.border_strong
	var bw := 1
	if error != "":
		bc = Tokens.danger
		bw = 2
	elif _foc:
		bc = Tokens.accent
		bw = 2
	if Tokens.pixel:  # champ « Minecraft » : fond noir translucide, cadre gris 2 px (blanc au focus), biseau intérieur sombre
		var rc := Rect2(Vector2.ZERO, f.size)
		var frame := Color("a0a0a0") if _foc else Color("5a5a5a")
		if error != "":
			frame = Tokens.danger
		f.draw_rect(rc, Color(0, 0, 0, 0.85))
		f.draw_rect(rc, frame, false, 2.0)
		f.draw_rect(Rect2(2, 2, f.size.x - 4, 2), Color(1, 1, 1, 0.0 if not _foc else 0.12))
		f.draw_rect(Rect2(2, f.size.y - 4, f.size.x - 4, 2), Color(1, 1, 1, 0.06))
	else:
		f.draw_style_box(KS.box(Tokens.surface3, Tokens.R_MD, 0, 0, bc, bw), Rect2(Vector2.ZERO, f.size))
	if icon != "":
		var t := Icon.texture(icon, 20)
		if t != null:
			f.draw_texture_rect(t, Rect2(Tokens.S4, (f.size.y - 20) * 0.5 if not multiline else 18, 20, 20), false, Tokens.text_muted)
	if label_text != "":
		var fs := int(lerpf(Tokens.FS_BASE, Tokens.FS_XS, _t))
		var cy := lerpf(f.size.y * 0.5 if not multiline else 26.0, 14.0, _t)
		var col := Tokens.text_muted if error == "" else Tokens.danger
		if _foc and error == "":
			col = Tokens.accent_fg
		KS.draw_text(f, label_text, _left(), cy, fs, col, 500)
