extends PanelContainer
## Carte : surface, ombre douce ; interactive (survol animé, signal pressed) ; selected (anneau accent).
signal pressed
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var interactive := false: set = _set_inter
var selected := false: set = _set_sel
var pad := Tokens.S4
var radius := Tokens.R_LG
var flat := false
var _h := 0.0: set = _set_h
var _tw: Tween
var _hov := false
var _down := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_vertical = Control.SIZE_FILL

func _ready() -> void:
	Tokens.bus.changed.connect(_apply)
	mouse_entered.connect(func(): _hov = true; _go())
	mouse_exited.connect(func(): _hov = false; _down = false; _go())
	_apply()

func _set_inter(v: bool) -> void:
	interactive = v
	mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW
	focus_mode = Control.FOCUS_ALL if v else Control.FOCUS_NONE
	_apply()

func _set_sel(v: bool) -> void:
	selected = v
	_apply()

func _set_h(v: float) -> void:
	_h = v
	_apply()

func _go() -> void:
	if not interactive:
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "_h", 1.0 if _hov else 0.0, Tokens.DUR)

## Fond effectif (pour le contraste).
func k_bg() -> Color:
	return Tokens.surface1.lerp(Tokens.surface2, _h) if not selected else Tokens.surface1.lerp(Tokens.accent, 0.1)

func _apply() -> void:
	var bd := Tokens.border
	var bw := 1
	if selected:
		bd = Tokens.accent
		bw = 2
	elif has_focus() and interactive:
		bd = Tokens.ring_color()
		bw = 2
	var sb := KS.box(k_bg() if not flat else Color(Tokens.surface2, _h * 0.8 + (0.0 if not selected else 0.3)), radius, pad, pad, bd if not flat or selected else Color(0, 0, 0, 0), bw if not flat or selected else 0)
	if not flat:
		Tokens.shadow(sb, 1 + int(round(_h)))
	add_theme_stylebox_override("panel", sb)

func _gui_input(e: InputEvent) -> void:
	if not interactive:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			pass
		elif _down and Rect2(Vector2.ZERO, size).has_point(e.position):
			_down = false
			pressed.emit()
		accept_event()
	elif e is InputEventKey and e.pressed and e.is_action("ui_accept"):
		pressed.emit()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		_apply()
