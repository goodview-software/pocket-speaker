extends Control
## Barre de progression 0..1 animée ; indeterminate = reflet qui défile.
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var value := 0.0: set = set_value
var indeterminate := false: set = _si
var _shown := 0.0
var _x := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(0, 8)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_method(func(x: float): _shown = x; queue_redraw(), _shown, value, Tokens.DUR * 1.5)
	else:
		_shown = value

func _si(v: bool) -> void:
	indeterminate = v
	set_process(v)
	queue_redraw()

func _process(dt: float) -> void:
	_x = fmod(_x + dt * 0.8, 1.0)
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(size.x, 8))
	r.position.y = (size.y - 8) * 0.5
	draw_style_box(KS.box(Tokens.surface3, Tokens.R_FULL), r)
	if indeterminate:
		var w := size.x * 0.35
		var x := lerpf(-w, size.x, _x)
		var a := maxf(x, 0.0)
		var b := minf(x + w, size.x)
		if b > a:
			draw_style_box(KS.box(Tokens.accent, Tokens.R_FULL), Rect2(a, r.position.y, b - a, 8))
	elif _shown > 0.0:
		draw_style_box(KS.box(Tokens.accent, Tokens.R_FULL), Rect2(r.position, Vector2(maxf(8.0, size.x * _shown), 8)))
