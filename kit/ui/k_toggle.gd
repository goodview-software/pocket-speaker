extends "res://kit/ui/k_press.gd"
## Interrupteur animé.
signal toggled(on: bool)
var on := false
var _t := 0.0: set = _set_t

func _init() -> void:
	super()
	custom_minimum_size = Vector2(52, Tokens.TOUCH)
	size_flags_horizontal = 0
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _set_t(v: float) -> void:
	_t = v
	queue_redraw()

func set_on(v: bool, anim := true) -> void:
	on = v
	if anim and is_inside_tree():
		create_tween().tween_property(self, "_t", 1.0 if v else 0.0, Tokens.DUR)
	else:
		_t = 1.0 if v else 0.0

func _activate() -> void:
	set_on(not on)
	toggled.emit(on)
	pressed.emit()

func k_colors() -> Array:
	return []

func _draw() -> void:
	var a := 0.42 if disabled else 1.0
	var r := Rect2((size.x - 44) * 0.5, (size.y - 24) * 0.5, 44, 24)
	var col := Tokens.surface3.lerp(Tokens.accent, _t).lerp(Color.WHITE, hover * 0.06)
	draw_style_box(KS.box(Color(col, a), Tokens.R_FULL, 0, 0, Tokens.border_strong if _t < 0.5 else Color(0, 0, 0, 0), 1), r)
	draw_ring(r, 12)
	var kx := r.position.x + 12 + 20 * _t
	draw_circle(Vector2(kx, r.position.y + 12), 9.0 + down, Color(Tokens.text.lerp(Tokens.on_accent, 0.0) if _t < 0.5 else Tokens.on_accent, a))
