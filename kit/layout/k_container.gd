extends Container
## Conteneur centré à largeur maximale par point de rupture ; marges 16 (xs/sm), 24 (md), 32 (lg+).
signal breakpoint_changed(bp: String)
const Tokens := preload("res://kit/tokens.gd")
const MAX_W := {"xs": 100000, "sm": 100000, "md": 720, "lg": 960, "xl": 1200}
var max_widths := MAX_W
var fill_height := false
var bp := "": set = _setbp
var pad_v := 0

func _setbp(_v: String) -> void:
	pass

func margin_for(b: String) -> int:
	return Tokens.S4 if (b == "xs" or b == "sm") else (Tokens.S6 if b == "md" else Tokens.S8)

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var b := Tokens.bp(size.x)
		if b != bp:
			bp = b
			breakpoint_changed.emit(b)
		var m := margin_for(b)
		var w := minf(size.x - m * 2, float(max_widths.get(b, 100000)))
		w = maxf(w, 1.0)
		for c in get_children():
			if c is Control and c.visible:
				var h: float = size.y - pad_v * 2 if fill_height else (c as Control).get_combined_minimum_size().y
				fit_child_in_rect(c, Rect2(floorf((size.x - w) * 0.5), pad_v, w, h))

func _get_minimum_size() -> Vector2:
	var h := 0.0
	var m := margin_for(bp if bp != "" else "sm")
	var w := 0.0
	for c in get_children():
		if c is Control and c.visible:
			h = maxf(h, (c as Control).get_combined_minimum_size().y)
			w = maxf(w, (c as Control).get_combined_minimum_size().x)
	return Vector2(w + m * 2, h + pad_v * 2)
