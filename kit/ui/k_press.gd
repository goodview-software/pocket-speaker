extends Control
## Base interactive : survol / pression / focus clavier / désactivé animés (Tween 150 ms). Cible tactile >= 44 px.
signal pressed
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var disabled := false: set = _set_disabled
var hover := 0.0: set = _set_hover
var down := 0.0: set = _set_down
var ring := 0.0: set = _set_ring
var _tw: Tween
var _mouse_focus := false
var _pressing := false

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = Tokens.TOUCH

func _ready() -> void:
	mouse_entered.connect(func(): _hov_flag = true; _refresh())
	mouse_exited.connect(func(): _hov_flag = false; _pressing = false; _refresh())
	focus_entered.connect(_refresh)
	focus_exited.connect(func(): _mouse_focus = false; _refresh())
	Tokens.bus.changed.connect(queue_redraw)

func _set_hover(v: float) -> void:
	hover = v
	queue_redraw()
func _set_down(v: float) -> void:
	down = v
	queue_redraw()
func _set_ring(v: float) -> void:
	ring = v
	queue_redraw()
func _set_disabled(v: bool) -> void:
	disabled = v
	mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE if v else Control.FOCUS_ALL
	queue_redraw()

func _refresh() -> void:
	var h := 1.0 if (is_hovering() and not disabled) else 0.0
	var d := 1.0 if (_pressing and not disabled) else 0.0
	var r := 1.0 if (has_focus() and not _mouse_focus and not disabled) else 0.0
	if not is_inside_tree() or not is_visible_in_tree():
		hover = h
		down = d
		ring = r
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "hover", h, Tokens.DUR)
	_tw.tween_property(self, "down", d, Tokens.DUR * 0.8)
	_tw.tween_property(self, "ring", r, Tokens.DUR)

func is_hovering() -> bool:
	return _hov_flag and mouse_filter != Control.MOUSE_FILTER_IGNORE

var _hov_flag := false
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if disabled:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = true
			_mouse_focus = true
			_refresh()
		else:
			var was := _pressing
			_pressing = false
			_refresh()
			if was and Rect2(Vector2.ZERO, size).has_point(e.position):
				_activate()
		accept_event()
	elif e is InputEventKey and e.pressed and not e.echo and (e.is_action("ui_accept") or e.keycode == KEY_SPACE):
		_activate()
		accept_event()

func _activate() -> void:
	pressed.emit()

## Surcharge possible : disponibilité du texte en largeur (lint).
func k_overflow() -> bool:
	return false

func draw_ring(r: Rect2, rad: float) -> void:
	if ring > 0.01:
		var sb := KS.box(Color(0, 0, 0, 0), int(rad) + 2, 0, 0, Color(Tokens.ring_color(), Tokens.ring_color().a * ring), 2)
		draw_style_box(sb, r.grow(2))
