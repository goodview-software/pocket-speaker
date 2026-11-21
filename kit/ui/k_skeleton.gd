extends Control
## Bloc fantôme à reflet animé (shimmer). shape : rect | circle.
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var shape := "rect"
var radius := Tokens.R_SM
var _x := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	if is_visible_in_tree():
		_x = fmod(_x + dt * 0.9, 1.6)
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if shape == "circle":
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, Tokens.surface3)
		return
	draw_style_box(KS.box(Tokens.surface3, radius), r)
	var cx := (_x - 0.3) * size.x
	var hw := size.x * 0.3
	var pts := PackedVector2Array([Vector2(cx - hw, 0), Vector2(cx, 0), Vector2(cx, size.y), Vector2(cx - hw, size.y)])
	var cols := PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0)])
	pts = PackedVector2Array([Vector2(maxf(cx - hw, 0), 0), Vector2(clampf(cx, 0, size.x), 0), Vector2(clampf(cx, 0, size.x), size.y), Vector2(maxf(cx - hw, 0), size.y)])
	draw_polygon(pts, cols)
